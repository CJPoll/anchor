defmodule Anchor.Domain.GraphRules.FunctionPlacement do
  @moduledoc """
  The `function_placement` graph rule (DND-5448) — a **Domain** module (ADR 001).
  Pure: rules 2 to 4 of `Anchor.Domain.Placement.Rules` over the run's model. Each
  violation is one proposal (`Anchor.Domain.Placement.to_violation/3`): a function
  whose type owner, or whose only caller's module, is not the module it sits in. The
  `Fix:` is `Placement.render/1`, and the key names the proposed place.

  Selected modules of which no function could be judged are one fail-closed issue:
  the rule checked nothing (every function a root, generated, a callback, or in an
  interface module).
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Failures
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.Rules

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :function_placement

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a function sits with the struct it returns or computes from, and one only another " <>
      "module of its bucket and context calls is that module's private function"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    placement = model.placement || Placement.build(model)
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    floor(placement, selected, model, rule) ++
      for proposal <- Placement.proposals(placement, model, :function_placement),
          MapSet.member?(selected, elem(proposal.subject, 0)),
          do: Placement.to_violation(proposal, model, rule)
  end

  defp floor(placement, selected, model, rule) do
    judged? =
      Enum.any?(placement.functions, fn {{module, _f, _a}, facts} ->
        MapSet.member?(selected, module) and Rules.movable?(facts, model, placement.roots)
      end)

    if judged? or MapSet.size(selected) == 0,
      do: [],
      else: [Failures.function_placement_unjudged(rule, model.config.path)]
  end
end
