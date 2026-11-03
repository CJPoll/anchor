defmodule Anchor.Domain.DynamicCallsTest do
  # DND-5442: a dynamic call resolved through behaviours. Pure Domain over a
  # hand-built graph.
  #
  # Sabotage record: ../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode

  defp node(module, opts),
    do: struct!(ModuleNode, [module: module, app: :demo] ++ opts)

  defp graph(nodes), do: %Graph{modules: Map.new(nodes, &{&1.module, &1})}

  test "the implementations of the behaviour declaring the callback, sorted" do
    g =
      graph([
        node(B, callbacks: [{:fetch, 1}]),
        node(Y, behaviours: [B]),
        node(X, behaviours: [B]),
        node(Z, behaviours: [])
      ])

    assert DynamicCalls.candidates(g, {:fetch, 1}) == {:ok, [X, Y]}
  end

  test "no behaviour declares it: :unresolved (an arity mismatch included)" do
    g = graph([node(B, callbacks: [{:fetch, 1}]), node(X, behaviours: [B])])

    assert DynamicCalls.candidates(g, {:store, 1}) == :unresolved
    assert DynamicCalls.candidates(g, {:fetch, 2}) == :unresolved
  end

  test "two behaviours declaring it: the union of their implementations" do
    g =
      graph([
        node(B1, callbacks: [{:fetch, 1}]),
        node(B2, callbacks: [{:fetch, 1}, {:other, 0}]),
        node(X, behaviours: [B1]),
        node(Y, behaviours: [B2])
      ])

    assert DynamicCalls.candidates(g, {:fetch, 1}) == {:ok, [X, Y]}
  end

  test "an unknown arity matches the callback's name at any arity" do
    g = graph([node(B, callbacks: [{:fetch, 3}]), node(X, behaviours: [B])])
    assert DynamicCalls.candidates(g, {:fetch, nil}) == {:ok, [X]}
  end

  test "a declared callback no module implements resolves to no candidate" do
    g = graph([node(B, callbacks: [{:fetch, 1}])])
    assert DynamicCalls.candidates(g, {:fetch, 1}) == {:ok, []}
  end
end
