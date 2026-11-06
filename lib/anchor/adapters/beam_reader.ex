defmodule Anchor.Adapters.BeamReader do
  @moduledoc """
  Reads compiled beams into `Anchor.Domain.Graph.Beam` records — the **Side
  Effect** adapter behind `Anchor.Adapters.BeamSource` (DND-5438).

  Decoding never loads or calls the project's modules. It reads the beam's
  debug-info chunk with `:beam_lib` and asks the chunk's backend for two views
  of it, the way Dialyzer does (`dialyzer_utils.erl`, OTP 28.2):

    * `elixir_v1` — the module-level facts (definitions, persisted attributes,
      struct, source file);
    * `core_v1` — the module as Core Erlang, with `#{inspect(:no_copt)}` so
      Core's optimiser does not fold source calls away (without it,
      `apply(m, :f, [x])` becomes a plain call, `&M.f/1` a literal fun, and an
      unused struct literal disappears).

  plus `Code.Typespec.fetch_specs/1` and `fetch_types/1` on the binary.

  A module's compile options are allowlisted, deny by default (DND-5552):
  lowering replays them, and some make the compiler run code. A module
  compiled with a `parse_transform` or `core_transform` is refused as
  `{:core_v1_refused, {:transform, ...}}`, and one with any other option not
  known to be safe as `{:core_v1_refused, {:option, option}}`; neither is
  lowered. A module's `@behaviour`s are not loaded (pinned by a test with
  the behaviour's beam on the code path).

  This sits in an adapter, not in Domain, because the backend runs the Erlang
  compiler, which can raise on malformed input. Every outcome is turned into
  plain data here: a `%Beam{}`, or a `t:Anchor.Domain.Graph.Beam.decode_error/0`
  naming the cause. A raise, throw or exit while decoding becomes
  `{:decode_crashed, message}`, so one bad beam never ends the run.
  """

  @behaviour Anchor.Adapters.BeamSource

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph.Beam

  @core_options [:no_copt]

  # Compile options that run no code when the backend lowers a module to Core
  # (DND-5552). `{:debug_info, _}`, `{:autoload, _}` and `{:inline_size, _}`
  # are allowed with a boolean or integer value only; `nowarn_*` and `warn_*`
  # options are allowed by name.
  @safe_atoms [:debug_info, :inline, :deterministic]
  @safe_keys [:inline, :no_warn_undefined]

  @doc "The options passed to the backend's `debug_info(:core_v1, ...)`."
  @spec core_options() :: [atom()]
  def core_options, do: @core_options

  @impl Anchor.Adapters.BeamSource
  def read_ebins(ebins) do
    Enum.flat_map(ebins, fn {app, dir} -> read_ebin(app, dir) end)
  end

  @doc """
  Decodes one beam binary. `opts` must hold `:app` and `:path`, which the
  result carries.
  """
  @spec decode(binary(), keyword()) :: Beam.t() | Beam.decode_error()
  def decode(binary, opts) do
    app = Keyword.fetch!(opts, :app)
    path = Keyword.fetch!(opts, :path)

    guarded(nil, path, fn -> decode_chunk(binary, app, path) end)
  end

  defp read_ebin(app, dir) do
    case File.ls(dir) do
      {:ok, names} ->
        names
        |> Enum.filter(&String.ends_with?(&1, ".beam"))
        |> Enum.sort()
        |> Enum.map(&read_beam(app, Path.join(dir, &1)))

      {:error, posix} ->
        [error(dir, nil, {:unreadable, posix})]
    end
  end

  defp read_beam(app, path) do
    case File.read(path) do
      {:ok, binary} -> decode(binary, app: app, path: path)
      {:error, posix} -> error(path, nil, {:unreadable, posix})
    end
  end

  defp decode_chunk(binary, app, path) do
    case :beam_lib.chunks(binary, [:debug_info], [:allow_missing_chunks]) do
      {:ok, {module, [debug_info: {:debug_info_v1, backend, data}]}} ->
        guarded(module, path, fn ->
          decode_debug_info(module, backend, data, binary, app, path)
        end)

      {:ok, {module, [debug_info: _missing]}} ->
        error(path, module, :no_debug_info)

      {:error, :beam_lib, {:key_missing_or_invalid, _file, :debug_info}} ->
        error(path, beam_module(binary), :debug_info_stripped)

      {:error, :beam_lib, reason} ->
        error(path, nil, {:unreadable, reason})
    end
  end

  # The module an unreadable chunk's beam defines, so a call into it is named
  # as a project module whose body was not read (DND-5679), never as a call
  # outside the project. `:beam_lib.chunks/3` has already read this binary's
  # chunk table, so `:beam_lib.info/1` answers a list; were it ever an error,
  # `Keyword.get/2` raises and `guarded/3` makes it `{:decode_crashed, _}`.
  defp beam_module(binary), do: binary |> :beam_lib.info() |> Keyword.get(:module)

  defp guarded(module, path, fun) do
    fun.()
  catch
    kind, reason ->
      error(path, module, {:decode_crashed, Failures.crash_summary(kind, reason, __STACKTRACE__)})
  end

  defp decode_debug_info(module, _backend, :none, _binary, _app, path),
    do: error(path, module, :debug_info_stripped)

  defp decode_debug_info(module, :elixir_erl, data, binary, app, path) do
    with {:ok, elixir} <- view(:elixir_v1, module, data, [], path),
         :ok <- safe_compile_options(elixir, module, path),
         {:ok, core} <- view(:core_v1, module, data, @core_options, path) do
      %Beam{
        module: module,
        app: app,
        path: path,
        elixir: elixir,
        core: core,
        specs: typespecs(Code.Typespec.fetch_specs(binary)),
        types: typespecs(Code.Typespec.fetch_types(binary)),
        callbacks: binary |> Code.Typespec.fetch_callbacks() |> typespecs() |> callback_keys()
      }
    end
  end

  defp decode_debug_info(module, backend, _data, _binary, _app, path),
    do: error(path, module, {:not_elixir, backend})

  defp view(format, module, data, options, path) do
    case :elixir_erl.debug_info(format, module, data, options) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> error(path, module, {refused(format), reason})
    end
  end

  # Lowering to Core runs the Erlang compiler with the module's own compile
  # options, and some options make it load and run code (a `parse_transform`
  # or `core_transform`, a plugin). Anchor runs no project code, so the
  # options are allowlisted, deny by default (DND-5552): every option must be
  # one known to change only warnings, inlining, determinism or loading, or
  # the module is refused, naming the option. A transform is named as one.
  defp safe_compile_options(elixir, module, path) do
    options = elixir |> Map.get(:compile_opts, []) |> List.wrap()

    case {Enum.find(options, &transform?/1), Enum.reject(options, &safe_option?/1)} do
      {nil, []} -> :ok
      {nil, [option | _rest]} -> error(path, module, {:core_v1_refused, {:option, option}})
      {transform, _unsafe} -> error(path, module, {:core_v1_refused, {:transform, transform}})
    end
  end

  defp transform?({kind, _module}), do: kind in [:parse_transform, :core_transform]
  defp transform?(_option), do: false

  defp safe_option?(option) when option in @safe_atoms, do: true
  defp safe_option?(option) when is_atom(option), do: warning_option?(option)
  defp safe_option?({:debug_info, enabled}), do: is_boolean(enabled)
  defp safe_option?({:autoload, enabled}), do: is_boolean(enabled)
  defp safe_option?({:inline_size, size}), do: is_integer(size)
  defp safe_option?({key, _value}) when key in @safe_keys, do: true
  defp safe_option?({key, _value}) when is_atom(key), do: warning_option?(key)
  defp safe_option?(_option), do: false

  # `nowarn_*` and `warn_*` options switch compiler warnings on or off.
  defp warning_option?(option) do
    name = Atom.to_string(option)
    String.starts_with?(name, "nowarn_") or String.starts_with?(name, "warn_")
  end

  defp refused(:elixir_v1), do: :elixir_v1_refused
  defp refused(:core_v1), do: :core_v1_refused

  # `Code.Typespec` answers `{:ok, []}` for a module with no specs or types.
  # `:error` means it could not read the chunk itself, which cannot happen once
  # `elixir_v1` has decoded the same chunk; it is stored as `[]` (the design's
  # rule, DND-5438) rather than failing a beam whose facts were all read.
  defp typespecs({:ok, specs}), do: specs
  defp typespecs(:error), do: []

  # DND-5633: only which callbacks a behaviour declares, never their types.
  defp callback_keys(callbacks),
    do: callbacks |> Enum.map(fn {name_arity, _forms} -> name_arity end) |> Enum.sort()

  defp error(path, module, reason), do: {:error, %{path: path, module: module, reason: reason}}
end
