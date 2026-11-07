defmodule Anchor.Domain.GraphRules.ModuleOneComponent do
  @moduledoc """
  The `module_one_component` graph rule, M1 and M3 (DND-5463) — a **Domain** module
  (ADR 001). Pure. A selected module whose public functions fall into two or more
  causal components (`Anchor.Domain.Placement.ModuleComponents`: no call, own-struct
  use or behaviour links them) is one violation at its `defmodule`: split it, one
  module per component. A private function two components reach is one more, at the
  function: extract it into its own module. Length never triggers anything, and a
  context's interface module is exempt. The `Fix:` is
  `Anchor.Domain.Placement.render/1`.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :module_one_component

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a module's public functions form one causal component (linked by a call, its own " <>
      "struct or one behaviour); a private helper two components share is its own module"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    placement = model.placement || Placement.build(model)
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    for proposal <- Placement.proposals(placement, model, :module_one_component),
        Enum.any?(Placement.subject_modules(proposal, model), &MapSet.member?(selected, &1)),
        do: Placement.to_violation(proposal, model, rule)
  end
end
