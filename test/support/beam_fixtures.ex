defmodule Anchor.Test.BeamFixtures do
  @moduledoc """
  Compiles fixture modules inside a test and hands back their beam binaries,
  with every fixture module unloaded again (DND-5438, epic QA plan).

  `Code.compile_string/2` loads what it compiles. The graph engine must never
  depend on a loaded project module, so `compile_unloaded/2` purges and deletes
  each module (`:code.purge/1`, `:code.delete/1`, `:code.purge/1`) before
  returning, and raises if one is still loaded. Name fixtures under
  `AnchorFixtures.<TestModule>.*` so async test modules never share a name.

  `mix test` compiles with the compiler's debug_info off (Elixir 1.19 compiles
  test files while tests run, so the option is off for them too), which writes
  the debug-info chunk with no metadata. `mix compile` writes it in full, and
  the fixtures must look like what it writes, so `compile_unloaded/2` adds
  `@compile {:debug_info, true}` to every `defmodule` in the source, including
  one inside a `quote` (macro output), without touching any line.
  """

  @doc """
  Compiles `source` (as file `file`) and returns `[{module, binary}]` in
  compile order, every module unloaded.
  """
  @spec compile_unloaded(String.t(), String.t()) :: [{module(), binary()}]
  def compile_unloaded(source, file \\ "nofile"), do: compile_all_unloaded([{source, file}])

  @doc """
  Compiles each `{source, file}` in order, so a later source can `use` a macro
  module an earlier one defines, then unloads every module and returns them
  all, in compile order.
  """
  @spec compile_all_unloaded([{String.t(), String.t()}]) :: [{module(), binary()}]
  def compile_all_unloaded(sources) do
    modules = Enum.flat_map(sources, fn {source, file} -> compile(source, file) end)
    Enum.each(modules, fn {module, _binary} -> unload!(module) end)
    modules
  end

  @doc "The binary of `module` among `compile_unloaded/2`'s results."
  @spec binary!([{module(), binary()}], module()) :: binary()
  def binary!(modules, module) do
    case List.keyfind(modules, module, 0) do
      {^module, binary} ->
        binary

      nil ->
        raise ArgumentError,
              "no fixture module #{inspect(module)} in #{inspect(Keyword.keys(modules))}"
    end
  end

  @doc """
  The Core Erlang `c_fun` of `name/arity` in `binary`, read the way
  `Anchor.Adapters.BeamReader` reads it (`core_v1`, its options).
  """
  @spec core_fun!(binary(), {atom(), arity()}) :: :cerl.cerl()
  def core_fun!(binary, name_arity) do
    {:ok, {module, [debug_info: {:debug_info_v1, backend, data}]}} =
      :beam_lib.chunks(binary, [:debug_info])

    {:ok, core} =
      backend.debug_info(:core_v1, module, data, Anchor.Adapters.BeamReader.core_options())

    case Enum.find(:cerl.module_defs(core), fn {fname, _fun} ->
           :cerl.var_name(fname) == name_arity
         end) do
      {_fname, fun} -> fun
      nil -> raise ArgumentError, "no Core function #{inspect(name_arity)} in #{inspect(module)}"
    end
  end

  @doc "The 1-based line of the first line of `source` that contains `snippet`."
  @spec line_of(String.t(), String.t()) :: pos_integer()
  def line_of(source, snippet) do
    source
    |> String.split("\n")
    |> Enum.find_index(&String.contains?(&1, snippet))
    |> case do
      nil -> raise ArgumentError, "no line contains #{inspect(snippet)}"
      index -> index + 1
    end
  end

  defp compile(source, file) do
    quoted =
      source
      |> Code.string_to_quoted!(file: file, columns: true)
      |> Macro.prewalk(&with_debug_info/1)

    ExUnit.CaptureIO.with_io(:stderr, fn -> Code.compile_quoted(quoted, file) end)
    |> elem(0)
  end

  defp with_debug_info({:defmodule, meta, [name, [{:do, body} | rest]]}) do
    attribute = quote(do: @compile({:debug_info, true}))
    {:defmodule, meta, [name, [{:do, {:__block__, [], [attribute, body]}} | rest]]}
  end

  defp with_debug_info(node), do: node

  defp unload!(module) do
    :code.purge(module)
    :code.delete(module)
    :code.purge(module)

    if :code.is_loaded(module) != false,
      do: raise("fixture #{inspect(module)} is still loaded after purge and delete")
  end
end
