defmodule Anchor.Domain.GraphRules.AggregateWriteSources do
  @moduledoc """
  The `aggregate_write_sources` graph rule (DND-5459): every database write
  traces to a schema or table, and every transaction's write set is complete
  — a **Domain** module (ADR 001). Pure, over the run's
  `Anchor.Domain.Model`, whose `aggregate_analysis`
  (`Anchor.Domain.Aggregates.Analysis`) holds what it reports. The rule's
  selector chooses whose findings are reported: the module a write or a
  transaction is written in.

  | Finding | Where | Key |
  |---|---|---|
  | a write whose source is unresolved | the write's line | `<id>\\|<M.f/a>\\|unresolved <op> <seen>` |
  | a transaction whose write set is incomplete | the transaction's line | `<id>\\|<M.f/a>\\|incomplete <ordinal>` |
  | raw SQL, or a write on a computed module, outside every transaction | its line | `<id>\\|<M.f/a>\\|unattributed <what>` |

  No key holds a line. Two cases are fail-closed (`Anchor.Domain.Failures`),
  on the config, never baselined and never report-only: the project has no
  Ecto repo (`aggregate_no_repo/2`), and the selected modules hold no write
  (`aggregate_writes_none/3`): either way the rule would check nothing.

  A load of a config that enables this rule with no `aggregates:` section is
  refused (exit 3, `Anchor.Config`).
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSite
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :aggregate_write_sources

  @impl Anchor.Domain.RuleShape
  def shape(_rule),
    do:
      "aggregates: repos: [<Repo>...], write_functions: [\"<Module.fun/arity>\"...], " <>
        "transaction_functions: [\"<Module.fun/arity>\"...]"

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    case model.aggregate_analysis do
      %Analysis{no_repo?: false} = analysis -> findings(analysis, model, rule)
      _none -> [Failures.aggregate_no_repo(rule, config_file(model))]
    end
  end

  defp findings(analysis, model, rule) do
    selected = model |> GraphRules.select(rule) |> MapSet.new()
    selected? = fn {module, _name, _arity} -> MapSet.member?(selected, module) end
    sites = Enum.filter(analysis.sites, &selected?.(&1.mfa))
    unattributed = Enum.filter(analysis.unattributed, &selected?.(&1.mfa))

    incomplete =
      for %Scope{complete?: false} = scope <- analysis.scopes,
          selected?.(scope.mfa),
          do: incomplete(scope, model, rule)

    if sites == [] and unattributed == [] and incomplete == [] do
      [Failures.aggregate_writes_none(rule, selector(rule), config_file(model))]
    else
      unresolved =
        for %WriteSite{unresolved: seen} = site <- sites,
            seen != nil,
            do: unresolved(site, model, rule)

      unresolved ++ incomplete ++ Enum.map(unattributed, &unattributed(&1, model, rule))
    end
  end

  defp unresolved(%WriteSite{} = site, model, rule) do
    subject = ViolationKey.mfa(site.mfa)

    %Violation{
      filename: file(model, site.mfa),
      line: site.line,
      trigger: "#{via(site.via)}.#{site.op}",
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, subject, "unresolved #{site.op} #{site.unresolved}"),
      message:
        "#{via(site.via)}.#{site.op} in #{subject} writes a value Anchor cannot trace to a schema " <>
          "or table (#{site.unresolved}). Fix: pass a struct, changeset or schema the call can " <>
          "see; add @spec with Schema.t() for the parameter; or list a wrapper under " <>
          "aggregates.write_functions."
    }
  end

  defp unattributed(%{mfa: mfa, line: line, what: what}, model, rule) do
    subject = ViolationKey.mfa(mfa)

    %Violation{
      filename: file(model, mfa),
      line: line,
      trigger: what,
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, subject, "unattributed #{what}"),
      message:
        "#{subject} writes, or may write, outside any transaction in a way no schema or table " <>
          "names: #{what}. Fix: write through a schema with Repo, or name the module the call is on."
    }
  end

  defp incomplete(%Scope{} = scope, model, rule) do
    subject = ViolationKey.mfa(scope.mfa)
    calls = for {:dynamic_call, mfa, line} <- scope.gaps, do: {mfa, line}
    writes = for {:unresolved_write, site} <- scope.gaps, do: site

    %Violation{
      filename: file(model, scope.mfa),
      line: scope.line,
      trigger: "transaction #{scope.ordinal}",
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, subject, "incomplete #{scope.ordinal}"),
      message:
        "transaction #{scope.ordinal} in #{subject} reaches " <>
          reaches(calls, writes) <>
          ", so its write set is incomplete. Fix: call a named function instead of a " <>
          "variable, or declare the behaviour so the callee is known; trace each write to a " <>
          "schema or table."
    }
  end

  defp reaches(calls, writes) do
    [
      if(calls != [],
        do: "#{length(calls)} call(s) Anchor cannot resolve (first: #{first_call(calls)})"
      ),
      if(writes != [],
        do: "#{length(writes)} write(s) it cannot trace (first: #{first_write(writes)})"
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" and ")
  end

  defp first_call([{mfa, line} | _rest]), do: "#{ViolationKey.mfa(mfa)} line #{line || "?"}"

  defp first_write([%WriteSite{} = site | _rest]),
    do: "#{via(site.via)}.#{site.op} in #{ViolationKey.mfa(site.mfa)} line #{site.line || "?"}"

  defp via(:repo), do: "Repo"
  defp via(:multi), do: "Ecto.Multi"
  defp via(:write_function), do: "aggregates.write_functions"
  defp via(:run_callback_repo), do: "repo (a Multi.run callback)"

  defp file(%Model{graph: graph} = model, {module, _name, _arity}) do
    case Graph.module(graph, module) do
      %ModuleNode{source_file: file} when is_binary(file) -> file
      _none -> config_file(model)
    end
  end

  defp selector(%{bucket: bucket}) when is_binary(bucket), do: "bucket #{bucket}"
  defp selector(%{paths: [_ | _] = paths}), do: "paths #{inspect(paths)}"
  defp selector(%{pattern: pattern}) when is_binary(pattern), do: "pattern #{inspect(pattern)}"
  defp selector(_rule), do: "the selected modules"

  defp config_file(%Model{config: %{path: path}}) when is_binary(path), do: path
  defp config_file(_model), do: ".anchor.yml"
end
