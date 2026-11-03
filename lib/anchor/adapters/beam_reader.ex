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
         {:ok, core} <- view(:core_v1, module, data, @core_options, path) do
      %Beam{
        module: module,
        app: app,
        path: path,
        elixir: elixir,
        core: core,
        specs: typespecs(Code.Typespec.fetch_specs(binary)),
        types: typespecs(Code.Typespec.fetch_types(binary))
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

  defp refused(:elixir_v1), do: :elixir_v1_refused
  defp refused(:core_v1), do: :core_v1_refused

  defp typespecs({:ok, specs}), do: specs
  defp typespecs(:error), do: []

  defp error(path, module, reason), do: {:error, %{path: path, module: module, reason: reason}}
end
