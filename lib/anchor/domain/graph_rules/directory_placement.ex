defmodule Anchor.Domain.GraphRules.DirectoryPlacement do
  @moduledoc """
  The `directory_placement` graph rule, D1 to D3 (DND-5462) — a **Domain** module
  (ADR 001). Pure. Each proposal of `Anchor.Domain.Placement.Directories` about a
  selected module is one violation: a module dominated by another of its bucket and
  context belongs in that module's companion directory, a shared module at its
  bucket root (or in a library context), and an inert directory is flattened. A
  module violation sits at its `defmodule` line; a directory's on the first file in
  it. The `Fix:` is `Anchor.Domain.Placement.render/1`.

  With no roots there is no dominator tree: one `:fail_closed` issue, and no
  finding.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Failures
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :directory_placement

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a directory is a dominator subtree within one bucket of one context, under its " <>
      "public module; a module reached from unrelated places sits at its bucket root"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    placement = model.placement || Placement.build(model)

    if placement.precision.reachability == :no_roots,
      do: [Failures.reachability_no_roots(rule, model.config.path)],
      else: judged(placement, model, rule)
  end

  defp judged(placement, model, rule) do
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    for proposal <- Placement.proposals(placement, model, :directory_placement),
        Enum.any?(Placement.subject_modules(proposal, model), &MapSet.member?(selected, &1)),
        do: Placement.to_violation(proposal, model, rule)
  end
end
