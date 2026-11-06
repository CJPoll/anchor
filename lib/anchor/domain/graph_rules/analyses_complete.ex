defmodule Anchor.Domain.GraphRules.AnalysesComplete do
  @moduledoc """
  The `analyses_complete` graph rule (DND-5715): the whole-program analyses
  finished over this project — a **Domain** module (ADR 001). Pure, over the
  run's `Anchor.Domain.Model`.

  A bound the analyses hit, or a function they left out, does not make a run
  wrong by itself: each analysis over-approximates what it could not finish
  (`Anchor.Domain.Cfa`: every site reads `any`; `Anchor.Domain.Demand`: every
  parameter of the component reads used). But the run then proves less than it
  says, so a project that holds its analyses to its whole size declares this
  rule, and each of these is one fail-closed violation on the config, never
  held by a baseline and never report-only:

    * the higher-order flow analysis hit its step bound;
    * the demand analysis hit its round bound on some component;
    * a selected module has a `def` or `defp` with a Core body and no demand
      summary (a function with no Core body is the graph's to report:
      `Graph.functions_without_core/1`, and an `unreadable` entry when public);
    * the analyses judged fewer than a declared floor: `min_functions`
      (`Demand` counts), `min_apply_sites` (`Cfa` counts) or
      `min_absent_parameters` (`Demand` counts). These are the positive
      controls: an analysis that hits no bound and judges nothing would pass
      the checks above.

  The bounds and the floors are judged over the whole program, since an
  analysis runs over all of it; the selector narrows only which modules'
  functions must be summarised, and its `min_modules` holds the size of what
  is selected. Anchor's own `.anchor.yml` declares it, so CI's `mix anchor.graph`
  holds the property over Anchor's own code.

  It carries no `@impl`, unlike its siblings: it was written on a base without
  the required `narrows?/2` callback, to compile warning-free with or without
  it (DND-5715).
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model

  def check(%Model{cfa: %Cfa{} = cfa, demand: %Demand{} = demand} = model, rule) do
    path = config_path(model)

    cfa_bound(cfa, rule, path) ++
      demand_bound(demand, rule, path) ++
      unsummarised(model, demand, rule, path) ++ floors(cfa, demand, rule, path)
  end

  def narrows?(_base_key, _key), do: false

  def needs, do: [:cfa, :demand]

  def rule_type, do: :analyses_complete

  def shape(_rule),
    do: "every analysis finishes within its bound, and every function has a demand summary"

  defp cfa_bound(%Cfa{bound_hit?: false}, _rule, _path), do: []

  defp cfa_bound(%Cfa{bound_hit?: true, steps: steps}, rule, path),
    do: [Failures.analyses_cfa_bound_hit(rule, steps, path)]

  defp config_path(%Model{config: %{path: path}}), do: path
  defp config_path(_model), do: nil

  defp demand_bound(%Demand{bound_hit: []}, _rule, _path), do: []

  defp demand_bound(%Demand{bound_hit: members}, rule, path),
    do: [Failures.analyses_demand_bound_hit(rule, members, path)]

  defp floors(cfa, demand, rule, path) do
    for {key, judged} <- [
          min_functions: demand.counts.functions,
          min_apply_sites: cfa.counts.total,
          min_absent_parameters: demand.counts.absent
        ],
        min = Map.get(rule, key),
        min != nil and judged < min,
        do: Failures.analyses_below_floor(rule, key, judged, min, path)
  end

  # Every `def`/`defp` of a selected module with a Core body: what
  # `Anchor.Domain.Demand` says it summarises.
  defp summarised_functions(model, rule) do
    for module <- GraphRules.select(model, rule),
        %{functions: functions} <- [Map.get(model.graph.modules, module)],
        {{name, arity}, %FunctionNode{kind: kind, core: core}} <- functions,
        kind in [:def, :defp] and core != nil,
        do: {module, name, arity}
  end

  defp unsummarised(model, %Demand{summaries: summaries}, rule, path) do
    model
    |> summarised_functions(rule)
    |> Enum.reject(&Map.has_key?(summaries, &1))
    |> Enum.sort()
    |> case do
      [] -> []
      missing -> [Failures.analyses_unsummarised(rule, missing, path)]
    end
  end
end
