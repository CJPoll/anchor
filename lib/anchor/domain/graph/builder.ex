defmodule Anchor.Domain.Graph.Builder do
  @moduledoc """
  Builds `Anchor.Domain.Graph` from decoded beams and source facts —
  **Domain**, pure (DND-5438).

  Module-level facts come from each beam's `elixir_v1` metadata: the source
  file (`relative_file`), behaviours and the other persisted attributes, struct
  fields, and each definition's kind and def line. Each function is joined with
  its Core Erlang `c_fun` (`def`/`defp` keep `name/arity` in Core; a macro is
  `MACRO-name/arity+1`, mapped back), and `Anchor.Domain.Graph.CoreWalker`
  reads its call and struct-use edges. Specs and types are turned into quoted
  form with `Code.Typespec`.

  `generated?` compares the module's name with the literal `defmodule`s of its
  source file (`Anchor.Domain.Graph.SourceFacts`): absent there, the module is
  macro output. With no facts for the file, or facts that are
  `{:error, :unparseable}`, it is `:unknown`, never `false`.

  A decode error is carried into `graph.unreadable` (in path order), never
  dropped; the good beams beside it are all built.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Beam
  alias Anchor.Domain.Graph.CoreWalker
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.SourceFacts

  @doc """
  Builds the graph. `source_facts` maps a source file (as the beams'
  `relative_file` names it) to its `SourceFacts.from_source/2` result.
  """
  @spec build([Beam.t() | Beam.decode_error()], %{
          String.t() => SourceFacts.t() | {:error, :unparseable}
        }) :: Graph.t()
  def build(beams, source_facts) do
    {decoded, errors} = Enum.split_with(beams, &match?(%Beam{}, &1))
    nodes = Enum.map(decoded, &module_node(&1, source_facts))
    edges = Enum.map(nodes, &module_edges/1)

    %Graph{
      modules: Map.new(nodes, &{&1.module, &1}),
      calls: Enum.flat_map(edges, &elem(&1, 0)),
      struct_uses: Enum.flat_map(edges, &elem(&1, 1)),
      unreadable: errors |> Enum.map(fn {:error, error} -> error end) |> Enum.sort_by(& &1.path)
    }
  end

  defp module_node(%Beam{module: module, elixir: elixir} = beam, source_facts) do
    source_file = Map.get(elixir, :relative_file)
    attributes = Map.get(elixir, :attributes, [])
    core_defs = core_defs(beam.core)

    %ModuleNode{
      module: module,
      app: beam.app,
      source_file: source_file,
      behaviours: attributes |> Keyword.get_values(:behaviour) |> List.flatten(),
      attributes: attributes,
      specs: specs(beam.specs),
      types: types(beam.types),
      struct_fields: struct_fields(Map.get(elixir, :struct)),
      functions:
        elixir
        |> Map.get(:definitions, [])
        |> Map.new(&function_node(module, &1, core_defs)),
      generated?: generated(module, Map.get(source_facts, source_file))
    }
  end

  defp module_edges(%ModuleNode{module: module, functions: functions}) do
    functions
    |> Enum.sort_by(fn {name_arity, _node} -> name_arity end)
    |> Enum.map(fn {name_arity, node} -> function_edges(module, name_arity, node) end)
    |> Enum.reduce({[], []}, fn {calls, uses}, {all_calls, all_uses} ->
      {all_calls ++ calls, all_uses ++ uses}
    end)
  end

  defp function_edges(_module, _name_arity, %FunctionNode{core: nil}), do: {[], []}

  defp function_edges(module, name_arity, %FunctionNode{core: core, line: line}),
    do: CoreWalker.walk(module, name_arity, core, line)

  defp function_node(module, {{name, arity}, kind, meta, clauses}, core_defs) do
    node = %FunctionNode{
      module: module,
      name: name,
      arity: arity,
      kind: kind,
      line: Keyword.get(meta, :line),
      clauses: clauses,
      core: Map.get(core_defs, core_name(kind, name, arity))
    }

    {{name, arity}, node}
  end

  defp core_name(kind, name, arity) when kind in [:defmacro, :defmacrop],
    do: {String.to_atom("MACRO-" <> Atom.to_string(name)), arity + 1}

  defp core_name(_kind, name, arity), do: {name, arity}

  defp core_defs(nil), do: %{}

  defp core_defs(core) do
    Map.new(:cerl.module_defs(core), fn {fname, fun} -> {:cerl.var_name(fname), fun} end)
  end

  defp generated(_module, nil), do: :unknown
  defp generated(_module, {:error, :unparseable}), do: :unknown

  defp generated(module, %{defmodules: names}),
    do: module_name(module) not in names

  defp module_name(module), do: module |> Atom.to_string() |> String.replace_prefix("Elixir.", "")

  defp struct_fields(nil), do: nil
  defp struct_fields(fields), do: Enum.map(fields, & &1.field)

  defp specs(specs) do
    Map.new(specs, fn {{name, arity}, forms} ->
      {{name, arity}, Enum.map(forms, &Code.Typespec.spec_to_quoted(name, &1))}
    end)
  end

  defp types(types) do
    Map.new(types, fn {kind, {name, _body, args} = type} ->
      {{name, length(args)}, {kind, Code.Typespec.type_to_quoted(type)}}
    end)
  end
end
