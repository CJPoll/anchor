defmodule Anchor.Domain.GraphRules.ReachableFromRoot do
  @moduledoc """
  The `reachable_from_root` graph rule, F5 (DND-5448) — a **Domain** module (ADR 001).
  Pure. A public function no root reaches is one violation, proposal `delete`; its
  `Fix:` is `Anchor.Domain.Placement.render/1`. Generated functions are not judged.

  It fails closed rather than judge what it cannot read:

    * a call whose function name is computed, in a reachable function, could reach
      anything: one `:fail_closed` issue naming each call site, and no finding;
    * with no roots nothing is reachable: one `:fail_closed` issue, and no finding;
    * selected modules with no public function it judges: it checked nothing.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Failures
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.Rules

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :reachable_from_root

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule), do: "every public function is reachable from a root"

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    placement = model.placement || Placement.build(model)

    case placement.precision.reachability do
      :lost ->
        [Failures.reachability_lost(rule, placement.precision.lost_sites, model.config.path)]

      :no_roots ->
        [Failures.reachability_no_roots(rule, model.config.path)]

      :precise ->
        judged(placement, model, rule)
    end
  end

  defp judged(placement, model, rule) do
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    floor(placement, selected, model, rule) ++
      for proposal <- Placement.proposals(placement, model, :reachable_from_root),
          MapSet.member?(selected, elem(proposal.subject, 0)),
          do: Placement.to_violation(proposal, model, rule)
  end

  defp floor(placement, selected, model, rule) do
    judged? =
      Enum.any?(placement.functions, fn {{module, _f, _a}, facts} ->
        MapSet.member?(selected, module) and facts.kind == :def and Rules.authored?(facts)
      end)

    if judged? or MapSet.size(selected) == 0,
      do: [],
      else: [Failures.reachable_unjudged(rule, model.config.path)]
  end
end
