defmodule Anchor.Domain.GraphRules.NoInertHop do
  @moduledoc """
  The `no_inert_hop` graph rule, E5/F4 (DND-5461) — a **Domain** module (ADR 001).
  Pure. A function of a selected module that only forwards to another module's
  function, without crossing a bucket, context, app, aggregate, interface or
  callback boundary (`Anchor.Domain.Placement.Forwarders`), is one violation:
  proposal `inline`, its callers call the target directly. The `Fix:` is
  `Anchor.Domain.Placement.render/1`, and the key names the forwarder and its
  target.

  Framework to Manager to Adapter forwarding is legal by construction (each hop
  crosses a bucket), and so is a context facade's `defdelegate` into its interior
  (it crosses the interface boundary). A hop inside one module is the AST rule
  `no_forwarding_function`'s.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :no_inert_hop

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a function that only forwards to another module crosses a bucket, context, app, " <>
      "aggregate, interface or callback boundary; otherwise its callers call the target"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    placement = model.placement || Placement.build(model)
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    for proposal <- Placement.proposals(placement, model, :no_inert_hop),
        MapSet.member?(selected, elem(proposal.subject, 0)),
        do: Placement.to_violation(proposal, model, rule)
  end
end
