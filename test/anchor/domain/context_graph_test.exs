defmodule Anchor.Domain.ContextGraphTest do
  # DND-5445: the call graph collapsed to contexts. Pure Domain, over
  # hand-built models.
  #
  # Sabotage record: ../../sabotage_records/context_acyclic-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Classification
  alias Anchor.Domain.ContextGraph
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model

  # module => context
  @modules %{
    A.One => "A",
    A.Two => "A",
    B.One => "B",
    C.One => "C",
    Nil.One => nil
  }

  defp model(calls, nodes \\ []) do
    classification =
      Map.new(@modules, fn {module, context} ->
        {module,
         %Classification{
           module: module,
           bucket: "b",
           role: :domain,
           context: context,
           source_file: "lib/#{inspect(module)}.ex"
         }}
      end)

    graph = %Graph{
      modules: Map.new(nodes, &{&1.module, &1}),
      calls:
        Enum.map(calls, fn
          {from, to, line} ->
            %Call{from: from, to: to, kind: :remote, line: line, line_source: :call}

          {from, to, line, kind} ->
            %Call{from: from, to: to, kind: kind, line: line, line_source: :call}
        end)
    }

    %Model{graph: graph, architecture: nil, classification: classification, config: nil}
  end

  defp exporter(module, name, arity) do
    %ModuleNode{
      module: module,
      app: :app,
      functions: %{
        {name, arity} => %FunctionNode{
          module: module,
          name: name,
          arity: arity,
          kind: :def,
          line: 1
        }
      }
    }
  end

  describe "build/1" do
    test "two calls A -> B from different functions are one edge with two witnesses, sorted" do
      graph =
        ContextGraph.build(
          model([{{A.Two, :g, 0}, {B.One, :h, 1}, 9}, {{A.One, :f, 0}, {B.One, :h, 1}, 4}])
        )

      assert graph.nodes == ["A", "B"]
      assert graph.unresolved == []

      assert graph.edges == %{
               {"A", "B"} => [
                 {{A.One, :f, 0}, {B.One, :h, 1}, "lib/A.One.ex", 4},
                 {{A.Two, :g, 0}, {B.One, :h, 1}, "lib/A.Two.ex", 9}
               ]
             }
    end

    test "a call within one context, to a non-project module, or with a nil context: no edge" do
      calls = [
        {{A.One, :f, 0}, {A.Two, :g, 0}, 1},
        {{A.One, :f, 0}, {Enum, :map, 2}, 2},
        {{A.One, :f, 0}, {Nil.One, :g, 0}, 3},
        {{Nil.One, :g, 0}, {B.One, :h, 1}, 4}
      ]

      assert ContextGraph.build(model(calls)) == %{nodes: [], edges: %{}, unresolved: []}

      # Positive control: the same caller to another context is an edge.
      assert %{edges: %{{"A", "B"} => [_one]}} =
               ContextGraph.build(model([{{A.One, :f, 0}, {B.One, :h, 1}, 5} | calls]))
    end

    test "a dynamic call with candidates in B and C is an edge to each" do
      graph =
        ContextGraph.build(
          model([{{A.One, :f, 0}, {:dynamic, :fetch, 1, :variable}, 7}], [
            exporter(B.One, :fetch, 1),
            exporter(C.One, :fetch, 1)
          ])
        )

      assert graph.edges == %{
               {"A", "B"} => [{{A.One, :f, 0}, {B.One, :fetch, 1}, "lib/A.One.ex", 7}],
               {"A", "C"} => [{{A.One, :f, 0}, {C.One, :fetch, 1}, "lib/A.One.ex", 7}]
             }
    end

    test "a dynamic call no project module exports is no edge, and not unresolved" do
      graph = ContextGraph.build(model([{{A.One, :f, 0}, {:dynamic, :info, 1, :call}, 1}]))
      assert graph == %{nodes: [], edges: %{}, unresolved: []}
    end

    # Regression (review floor on d9a61de): a call with a computed function
    # name was dropped silently, so a config with context_acyclic alone read
    # "no cycle" over edges it could not see.
    test "a computed function name is unresolved, with its caller and line; a closure is not" do
      calls = [
        {{A.One, :f, 0}, {:dynamic, nil, 1, :call}, 2, :apply},
        {{A.One, :g, 0}, {:dynamic, nil, 2, :variable}, 3, :remote},
        {{A.One, :h, 0}, {:dynamic, nil, 1, :variable}, 4, :apply}
      ]

      assert ContextGraph.build(model(calls)).unresolved == [
               {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
               {{A.One, :g, 0}, 2, "lib/A.One.ex", 3}
             ]
    end
  end

  describe "build/2" do
    test "only the given callers' calls are read" do
      calls = [{{A.One, :f, 0}, {B.One, :h, 1}, 1}, {{B.One, :h, 1}, {C.One, :i, 0}, 2}]

      assert Map.keys(ContextGraph.build(model(calls), [B.One]).edges) == [{"B", "C"}]
      assert Map.keys(ContextGraph.build(model(calls)).edges) == [{"A", "B"}, {"B", "C"}]
    end
  end
end
