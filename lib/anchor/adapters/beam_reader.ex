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

  plus `Code.Typespec.fetch_specs/1`, `fetch_types/1` and `fetch_callbacks/1`
  on the binary.

  A module compiled with a `parse_transform` or `core_transform` is refused
  (`{:core_v1_refused, {:transform, ...}}`): lowering it would run the
  transform. A module's `@behaviour`s are not loaded (pinned by a test with
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
        error(path, nil, :debug_info_stripped)

      {:error, :beam_lib, reason} ->
        error(path, nil, {:unreadable, reason})
    end
  end

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
         :ok <- no_transform(elixir, module, path),
         {:ok, core} <- view(:core_v1, module, data, @core_options, path) do
      %Beam{
        module: module,
        app: app,
        path: path,
        elixir: elixir,
        core: core,
        specs: typespecs(Code.Typespec.fetch_specs(binary)),
        types: typespecs(Code.Typespec.fetch_types(binary)),
        callbacks: callbacks(Code.Typespec.fetch_callbacks(binary))
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
  # options, and a `parse_transform` or `core_transform` among them is code the
  # compiler would load and run. Anchor runs no project code, so such a module
  # is refused, naming the transform.
  defp no_transform(elixir, module, path) do
    elixir
    |> Map.get(:compile_opts, [])
    |> List.wrap()
    |> Enum.find(&match?({kind, _module} when kind in [:parse_transform, :core_transform], &1))
    |> case do
      nil -> :ok
      transform -> error(path, module, {:core_v1_refused, {:transform, transform}})
    end
  end

  defp refused(:elixir_v1), do: :elixir_v1_refused
  defp refused(:core_v1), do: :core_v1_refused

  # `Code.Typespec` answers `{:ok, []}` for a module with no specs or types.
  # `:error` means it could not read the chunk itself, which cannot happen once
  # `elixir_v1` has decoded the same chunk; it is stored as `[]` (the design's
  # rule, DND-5438) rather than failing a beam whose facts were all read.
  defp typespecs({:ok, specs}), do: specs
  defp typespecs(:error), do: []

  # DND-5442: the `{name, arity}` of every `@callback` the module declares
  # (a behaviour), sorted; `[]` for a module that declares none.
  defp callbacks(fetched), do: fetched |> typespecs() |> Enum.map(&elem(&1, 0)) |> Enum.sort()

  defp error(path, module, reason), do: {:error, %{path: path, module: module, reason: reason}}
end
