defmodule Anchor.Domain.DigraphTest do
  # DND-5444: the plain digraph value the graph algorithms run over.
  # Sabotage record: ../../sabotage_records/graph_algorithms-20261103-dnd_5439.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Digraph

  test "1: an edge to an unknown node adds it" do
    graph = Digraph.new([:a], [{:a, :b}])

    assert Digraph.nodes(graph) == [:a, :b]
    assert Digraph.successors(graph, :a) == [:b]
    assert Digraph.predecessors(graph, :b) == [:a]
    assert Digraph.successors(graph, :b) == []
    assert Digraph.successors(graph, :not_a_node) == []
  end

  test "2: reverse swaps every edge" do
    reversed = Digraph.reverse(Digraph.new([], [{:a, :b}, {:b, :c}]))

    assert Digraph.successors(reversed, :c) == [:b]
    assert Digraph.successors(reversed, :a) == []
    assert Digraph.edges(reversed) == [{:b, :a}, {:c, :b}]
  end

  test "3: subgraph keeps only the edges with both ends kept" do
    sub = Digraph.subgraph(Digraph.new([], [{:a, :b}, {:b, :c}]), [:a, :b, :zz])

    assert Digraph.nodes(sub) == [:a, :b]
    assert Digraph.edges(sub) == [{:a, :b}]
  end

  test "4: a reserved virtual atom is refused as a node; an ordinary atom is not" do
    assert_raise ArgumentError, ~r/reserved/, fn -> Digraph.new([Digraph.virtual_root()], []) end

    assert_raise ArgumentError, ~r/reserved/, fn ->
      Digraph.new([], [{:a, Digraph.virtual_exit()}])
    end

    assert Digraph.nodes(Digraph.new([:"$anchor_other"], [])) == [:"$anchor_other"]
  end

  test "28: the same graph from edges in two orders is the same value" do
    edges = [{:a, :b}, {:b, :c}, {:c, :a}, {:d, :a}]

    assert Digraph.new([:d, :a], edges) == Digraph.new([:a, :d], Enum.reverse(edges))
  end
end
