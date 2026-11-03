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
        Enum.map(calls, fn {from, to, line} ->
          %Call{from: from, to: to, kind: :remote, line: line, line_source: :call}
        end)
    }

    %Model{graph: graph, architecture: nil, classification: classification, config: nil}
  end

  describe "build/1" do
    test "two calls A -> B from different functions are one edge with two witnesses, sorted" do
      graph =
        ContextGraph.build(
          model([{{A.Two, :g, 0}, {B.One, :h, 1}, 9}, {{A.One, :f, 0}, {B.One, :h, 1}, 4}])
        )

      assert graph.nodes == ["A", "B"]

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

      assert ContextGraph.build(model(calls)) == %{nodes: [], edges: %{}}

      # Positive control: the same caller to another context is an edge.
      assert %{edges: %{{"A", "B"} => [_one]}} =
               ContextGraph.build(model([{{A.One, :f, 0}, {B.One, :h, 1}, 5} | calls]))
    end

    test "a dynamic call with candidates in B and C is an edge to each" do
      port = %ModuleNode{module: Port, app: :app, callbacks: [{:fetch, 1}]}
      b = %ModuleNode{module: B.One, app: :app, behaviours: [Port]}
      c = %ModuleNode{module: C.One, app: :app, behaviours: [Port]}

      graph =
        ContextGraph.build(
          model([{{A.One, :f, 0}, {:dynamic, :fetch, 1, :variable}, 7}], [port, b, c])
        )

      assert graph.edges == %{
               {"A", "B"} => [{{A.One, :f, 0}, {B.One, :fetch, 1}, "lib/A.One.ex", 7}],
               {"A", "C"} => [{{A.One, :f, 0}, {C.One, :fetch, 1}, "lib/A.One.ex", 7}]
             }
    end

    test "an unresolved dynamic call and a computed function name give no edge" do
      calls = [
        {{A.One, :f, 0}, {:dynamic, :nobody, 1, :variable}, 1},
        {{A.One, :f, 0}, {:dynamic, nil, 1, :call}, 2}
      ]

      assert ContextGraph.build(model(calls)).edges == %{}
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
