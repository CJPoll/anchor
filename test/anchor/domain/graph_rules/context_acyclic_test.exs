defmodule Anchor.Domain.GraphRules.ContextAcyclicTest do
  # DND-5445: the context_acyclic graph rule. Pure Domain, over hand-built
  # models.
  #
  # Sabotage record: ../../../sabotage_records/context_acyclic-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.GraphRules.ContextAcyclic
  alias Anchor.Domain.Model

  # One module per context: A.M is in context "A", and so on.
  @contexts ~w(A B C D E F)

  defp mod(context), do: Module.concat([context, M])

  defp model(edges) do
    classification =
      Map.new(@contexts, fn context ->
        {mod(context),
         %Classification{
           module: mod(context),
           bucket: "b",
           role: :domain,
           context: context,
           source_file: "lib/#{String.downcase(context)}.ex"
         }}
      end)

    # Each `{from, to, count}` is `count` calls from `from`'s f/0 to `to`'s g/0,
    # on lines 10, 11, ...
    calls =
      for {from, to, count} <- edges, n <- 1..count//1 do
        %Call{
          from: {mod(from), :f, 0},
          to: {mod(to), :g, 0},
          kind: :remote,
          line: 9 + n,
          line_source: :call
        }
      end

    %Model{
      graph: %Graph{calls: calls},
      architecture: nil,
      classification: classification,
      config: nil
    }
  end

  @rule %{type: :context_acyclic, paths: ["lib/**"]}

  describe "check/2" do
    test "A <-> B is one violation listing both edges; the edge with fewer calls is inverted" do
      assert [v] = ContextAcyclic.check(model([{"A", "B", 3}, {"B", "A", 1}]), @rule)

      assert v.key == "context_acyclic|A,B"
      assert v.filename == "lib/b.ex"
      assert v.line == 10
      assert v.trigger == "B.M.f/0"

      assert v.message ==
               "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 " <>
                 "calls A.M.g/0). Fix: invert B -> A (its 1 call is the fewest): have B publish " <>
                 "an event A subscribes to, or declare the function B needs in an interface B " <>
                 "owns and have A implement it."
    end

    test "a triangle with a tail D -> A is one violation on A, B, C; D is not in it" do
      edges = [{"A", "B", 2}, {"B", "C", 2}, {"C", "A", 2}, {"D", "A", 1}]

      assert [v] = ContextAcyclic.check(model(edges), @rule)
      assert v.key == "context_acyclic|A,B,C"
      assert v.message =~ "contexts A, B, C form a cycle"
      refute v.message =~ "D"
      assert v.message =~ "invert A -> B (its 2 calls are the fewest)"
    end

    test "an acyclic chain is none; closing it is one" do
      chain = [{"A", "B", 1}, {"B", "C", 1}]

      assert ContextAcyclic.check(model(chain), @rule) == []
      assert [_one] = ContextAcyclic.check(model([{"C", "A", 1} | chain]), @rule)
    end

    test "two disjoint cycles are two violations, in context order" do
      edges = [{"E", "F", 1}, {"F", "E", 1}, {"A", "B", 1}, {"B", "A", 1}]

      assert [%{key: "context_acyclic|A,B"}, %{key: "context_acyclic|E,F"}] =
               ContextAcyclic.check(model(edges), @rule)
    end

    test "a tie on calls inverts the lexically first edge" do
      assert [v] = ContextAcyclic.check(model([{"B", "A", 2}, {"A", "B", 2}]), @rule)
      assert v.message =~ "Fix: invert A -> B (its 2 calls are the fewest)"
      assert v.filename == "lib/a.ex"
    end

    test "a context calling itself is not a cycle" do
      model = model([{"A", "B", 1}])

      self_call = %Call{
        from: {A.M, :f, 0},
        to: {A.M, :h, 0},
        kind: :local,
        line: 1,
        line_source: :call
      }

      model = put_in(model.graph.calls, [self_call | model.graph.calls])

      assert ContextAcyclic.check(model, @rule) == []
    end

    test "the rule reads the calls of the modules it selects" do
      cycle = model([{"A", "B", 1}, {"B", "A", 1}])

      assert ContextAcyclic.check(cycle, %{@rule | paths: ["lib/a.ex"]}) == []
      assert [_one] = ContextAcyclic.check(cycle, %{@rule | paths: ["lib/a.ex", "lib/b.ex"]})
    end

    test "with an id, the key starts with it" do
      assert [%{key: "ctx|A,B", rule_id: "ctx"}] =
               ContextAcyclic.check(
                 model([{"A", "B", 1}, {"B", "A", 1}]),
                 Map.put(@rule, :id, "ctx")
               )
    end
  end

  describe "check/2 calls it cannot see" do
    # Regression (review floor on d9a61de): see ContextGraphTest.
    test "a computed function name is one unresolved violation; a closure is none" do
      calls = [
        %Call{
          from: {A.M, :f, 0},
          to: {:dynamic, nil, 1, :call},
          kind: :apply,
          line: 6,
          line_source: :call
        },
        %Call{
          from: {A.M, :f, 0},
          to: {:dynamic, nil, 1, :call},
          kind: :apply,
          line: 3,
          line_source: :call
        },
        %Call{
          from: {A.M, :g, 0},
          to: {:dynamic, nil, 1, :variable},
          kind: :apply,
          line: 4,
          line_source: :call
        }
      ]

      model = put_in(model([]).graph.calls, calls)

      assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
      assert v.key == "ctx|A.M.f/0|-> dynamic ?/1"
      assert v.filename == "lib/a.ex"
      assert v.line == 3

      assert v.message =~
               "A.M.f/0 calls a function it computes (?/1), so its target cannot be checked."
    end
  end

  describe "shape/1" do
    test "the rule's conforming shape" do
      assert ContextAcyclic.shape(@rule) ==
               "the context graph has no cycle; a dependency between contexts runs one way"
    end
  end
end
