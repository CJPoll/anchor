defmodule Anchor.Domain.DynamicCallsTest do
  # DND-5442: a dynamic call resolved to the project modules it can reach.
  # Pure Domain over a hand-built graph.
  #
  # Sabotage record: ../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  # `functions` is a list of `{name, arity, kind}`.
  defp node(module, functions, opts \\ []) do
    struct!(
      ModuleNode,
      [
        module: module,
        app: :demo,
        functions:
          Map.new(functions, fn {name, arity, kind} ->
            {{name, arity},
             %FunctionNode{module: module, name: name, arity: arity, kind: kind, line: 1}}
          end)
      ] ++ opts
    )
  end

  defp graph(nodes), do: %Graph{modules: Map.new(nodes, &{&1.module, &1})}

  test "every project module exporting name/arity, sorted" do
    g =
      graph([
        node(Y, [{:fetch, 1, :def}]),
        node(X, [{:fetch, 1, :def}, {:other, 0, :def}]),
        node(Z, [{:other, 1, :def}])
      ])

    assert DynamicCalls.candidates(g, {:fetch, 1}) == [X, Y]
  end

  # Regression (review floor on d9a61de): candidates were the implementations
  # of a behaviour declaring the callback, but any module exporting the
  # function can be the receiver. A module with no @behaviour, and one beside
  # a behaviour no module implements, were never judged.
  test "a module that exports it with no @behaviour is a candidate" do
    g =
      graph([
        node(Port, [], behaviours: []),
        node(Declared, [{:fetch, 1, :def}], behaviours: [Port]),
        node(Undeclared, [{:fetch, 1, :def}])
      ])

    assert DynamicCalls.candidates(g, {:fetch, 1}) == [Declared, Undeclared]
  end

  test "a private function, a macro and another arity are not candidates" do
    g =
      graph([
        node(P, [{:fetch, 1, :defp}]),
        node(M, [{:fetch, 1, :defmacro}]),
        node(A, [{:fetch, 2, :def}])
      ])

    assert DynamicCalls.candidates(g, {:fetch, 1}) == []
    # Positive control: the right arity is found.
    assert DynamicCalls.candidates(g, {:fetch, 2}) == [A]
  end

  test "an unknown arity matches the name at any arity" do
    g = graph([node(X, [{:fetch, 3, :def}]), node(Y, [{:store, 1, :def}])])
    assert DynamicCalls.candidates(g, {:fetch, nil}) == [X]
  end

  test "no project module exports it: none, so the call reaches no project module" do
    g = graph([node(X, [{:other, 1, :def}])])
    assert DynamicCalls.candidates(g, {:info, 1}) == []
  end
end
