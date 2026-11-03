defmodule Anchor.Domain.GraphRules.ContextAcyclic do
  @moduledoc """
  The `context_acyclic` graph rule (DND-5445): the context graph has no
  cycle — a **Domain** module (ADR 001). Pure, over the run's
  `Anchor.Domain.Model`.

  A cycle between contexts leaves the causal order between them undefined.
  The rule collapses the calls of the modules it selects to context edges
  (`Anchor.Domain.ContextGraph`), takes the strongly connected components
  (`Anchor.Domain.GraphAlgorithms.sccs/1`, Tarjan), and reports each
  component of more than one context as one violation. A context calling
  itself is not a cycle.

  The violation lists every edge inside the component, sorted, each with its
  first witnessing call, and names the edge to invert: the one with the
  fewest witnessing calls (ties: the lexically first `A -> B`), as the
  cheapest to change. It sits on that edge's first witnessing call. Inverting
  `X -> Y` removes X's dependency on Y: X publishes an event Y subscribes to,
  or X declares the function in an interface it owns and Y implements it.
  The key is `<id>|<the component's contexts, sorted, joined by ",">`, stable
  while the cycle's members are the same.

  A call with a computed function name (`apply(M, op, args)`) hides which
  contexts it reaches, so each (caller function, arity) is one violation too,
  keyed `<id>|<Caller.f/a>|-> dynamic ?/<arity>`, like `layering`'s: the rule
  reports what it could not see itself, whatever other rules run.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.ContextGraph
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.GraphAlgorithms
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :context_acyclic

  @impl Anchor.Domain.RuleShape
  def shape(_rule),
    do: "the context graph has no cycle; a dependency between contexts runs one way"

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    graph = ContextGraph.build(model, GraphRules.select(model, rule))

    cycles =
      graph.nodes
      |> Digraph.new(Map.keys(graph.edges))
      |> GraphAlgorithms.sccs()
      |> Enum.filter(&match?([_, _ | _], &1))
      |> Enum.sort()
      |> Enum.map(&violation(&1, graph.edges, rule))

    cycles ++ unseen(graph.unresolved, rule)
  end

  # A call with a computed function name hides its edges: one violation per
  # (caller, arity), at the first such call, so a cycle through it never reads
  # as none.
  defp unseen(unresolved, rule) do
    unresolved
    |> Enum.uniq_by(fn {from, arity, _file, _line} -> {from, arity} end)
    |> Enum.map(fn {from, arity, file, line} ->
      %Violation{
        filename: file,
        line: line,
        trigger: ViolationKey.mfa(from),
        rule_id: Map.get(rule, :id),
        key:
          ViolationKey.graph_key(
            rule,
            ViolationKey.mfa(from),
            "-> " <> DynamicCalls.computed_name_target(arity)
          ),
        message: DynamicCalls.computed_name_message(from, arity)
      }
    end)
  end

  defp violation(contexts, edges, rule) do
    members = MapSet.new(contexts)

    cycle =
      edges
      |> Enum.filter(fn {{a, b}, _witnesses} ->
        MapSet.member?(members, a) and MapSet.member?(members, b)
      end)
      |> Enum.sort()

    {{x, y} = inverted, [{from, _to, file, line} | _rest] = witnesses} =
      Enum.min_by(cycle, fn {edge, witnesses} -> {length(witnesses), edge} end)

    %Violation{
      filename: file,
      line: line,
      trigger: ViolationKey.mfa(from),
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, Enum.join(contexts, ",")),
      message:
        "contexts #{Enum.join(contexts, ", ")} form a cycle: " <>
          Enum.map_join(cycle, ", ", &edge_text/1) <>
          ". Fix: invert #{edge_name(inverted)} (its #{calls(length(witnesses))} the " <>
          "fewest): have #{x} publish an event #{y} subscribes to, or declare the function " <>
          "#{x} needs in an interface #{x} owns and have #{y} implement it."
    }
  end

  defp edge_text({edge, [{from, to, _file, _line} | _rest]}),
    do: "#{edge_name(edge)} (#{ViolationKey.mfa(from)} calls #{ViolationKey.mfa(to)})"

  defp edge_name({a, b}), do: "#{a} -> #{b}"

  defp calls(1), do: "1 call is"
  defp calls(n), do: "#{n} calls are"
end
