defmodule Anchor.Domain.GraphReport do
  @moduledoc """
  The verdict of one `mix anchor.graph` run (DND-5440) — a **Domain** module
  (ADR 001). Pure: `new/3` decides the exit code from the findings, and
  `render/2` turns the report into the text or JSON the task prints. No IO.

    * `findings` — every `%Finding{}` the run made: rule findings and the
      fail-closed issues (a module Anchor could not read or classify, a floor,
      a rule that crashed). Each sits on a file and line and carries its
      enforcement.
    * `could_not_check` — `%Finding{}`s for a run that could not measure at
      all (no config, no `architecture:` section, zero modules read).
    * `held` — the rule findings a baseline holds (DND-5441): counted in the
      summary, printed only with `verbose: true`, never failing.
    * `refused` — `%Finding{}`s for a request the run refused (DND-5441:
      `--write-baseline` over an existing file, or naming no rule with a
      baseline), exit 2.
    * `counts` — `%{modules, apps, rules, opaque, no_core, outside_root,
      apply_sites}` for the summary line; `no_core` is the number of
      functions whose Core body the graph lacks, none of whose calls were
      read (DND-5549); `outside_root` the number of modules compiled from a
      source outside the project root, judged like every other module and
      counted so the layout is visible (DND-5588, DND-5630); `apply_sites` is `nil` when no
      rule that ran needed the higher-order flow analysis (DND-5574), else
      `apply_sites/1` of it; `aggregates` (optional, DND-5476) is
      `%{declared, tables_unknown}` when any aggregate is declared, and the
      JSON's `aggregates` is `null` otherwise; `writes` (optional, DND-5459)
      is the write analysis's counts (`Anchor.Domain.Aggregates.Analysis`)
      when the run made one with a repo, and the JSON's `writes` is `null`
      otherwise.
    * `exit_code` — `exit_code/1`.

  ## Exit code

  3 when anything could not be checked (it wins over the rest); 2 when the
  run refused its request; 1 when any finding is `:enforce` (every fail-closed
  issue is); 0 otherwise, including a run whose only findings are `:report`
  ones (printed, never failing) or held ones.

  ## Text

  One line per finding, `path:line: [enforce|report] <label> <message>`, where
  the message ends with `Fix: <shape>`, then the summary
  `anchor.graph: <M> modules in <A> apps, <R> rules, <V> violations (<P>
  report-only, <H> baselined)`. A finding with no line (one on `.anchor.yml`)
  prints line 1. `H` counts the held findings (DND-5441); with `verbose: true`
  each held one prints as `path:line: [held] <label> <message>`. When the run
  computed the higher-order flow analysis, the summary ends with `; apply
  sites: <r> resolved, <a> any`, and with `(step bound hit: every site reads
  any)` after it when the analysis hit its bound (DND-5574, R6).
  """

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.GraphReport.Finding

  defstruct findings: [],
            could_not_check: [],
            held: [],
            refused: [],
            counts: %{
              modules: 0,
              apps: 0,
              rules: 0,
              opaque: 0,
              no_core: 0,
              outside_root: 0,
              apply_sites: nil
            },
            exit_code: 0

  @type site_counts :: %{
          total: non_neg_integer(),
          resolved: non_neg_integer(),
          any: non_neg_integer()
        }

  @type apply_sites :: %{
          total: non_neg_integer(),
          resolved: non_neg_integer(),
          any: non_neg_integer(),
          bound_hit?: boolean(),
          by_function: %{mfa() => site_counts()}
        }

  @type counts :: %{
          required(:modules) => non_neg_integer(),
          required(:apps) => non_neg_integer(),
          required(:rules) => non_neg_integer(),
          required(:opaque) => non_neg_integer(),
          required(:no_core) => non_neg_integer(),
          required(:outside_root) => non_neg_integer(),
          required(:apply_sites) => apply_sites() | nil,
          optional(:aggregates) => %{declared: pos_integer(), tables_unknown: non_neg_integer()},
          optional(:writes) => %{
            writes: non_neg_integer(),
            resolved: non_neg_integer(),
            unresolved: non_neg_integer(),
            scopes: non_neg_integer(),
            complete: non_neg_integer(),
            incomplete: non_neg_integer()
          }
        }

  @type t :: %__MODULE__{
          findings: [Finding.t()],
          could_not_check: [Finding.t()],
          held: [Finding.t()],
          refused: [Finding.t()],
          counts: counts(),
          exit_code: 0 | 1 | 2 | 3
        }

  @doc """
  Builds a report, deciding its exit code (`exit_code/1`). `opts` may hold
  `:held` and `:refused` (DND-5441).
  """
  @spec new([Finding.t()], [Finding.t()], counts(), keyword()) :: t()
  def new(findings, could_not_check, counts, opts \\ []) do
    report = %__MODULE__{
      findings: findings,
      could_not_check: could_not_check,
      held: Keyword.get(opts, :held, []),
      refused: Keyword.get(opts, :refused, []),
      counts: counts
    }

    %{report | exit_code: exit_code(report)}
  end

  @doc """
  The apply-site precision counts of a higher-order flow analysis (R6): total,
  resolved and `any` sites, in all and per function, and whether the analysis
  hit its step bound (then every site is `any`). `nil` for no analysis.
  """
  @spec apply_sites(Cfa.t() | nil) :: apply_sites() | nil
  def apply_sites(nil), do: nil

  def apply_sites(%Cfa{counts: counts, bound_hit?: bound_hit?}) do
    %{
      total: counts.total,
      resolved: counts.resolved,
      any: counts.any,
      bound_hit?: bound_hit?,
      by_function: counts.by_function
    }
  end

  @doc """
  3 when anything could not be checked, 2 when the run refused its request,
  1 for any `:enforce` finding, else 0.
  """
  @spec exit_code(t()) :: 0 | 1 | 2 | 3
  def exit_code(%__MODULE__{could_not_check: [_ | _]}), do: 3
  def exit_code(%__MODULE__{refused: [_ | _]}), do: 2

  def exit_code(%__MODULE__{findings: findings}) do
    if Enum.any?(findings, &(&1.enforcement == :enforce)), do: 1, else: 0
  end

  @doc """
  Renders the report as `:text` (finding lines and the summary) or `:json`.
  With `verbose: true` in `opts`, text also prints each held finding.
  """
  @spec render(t(), :text | :json, keyword()) :: String.t()
  def render(report, format, opts \\ [])

  def render(%__MODULE__{} = report, :text, opts) do
    held =
      if Keyword.get(opts, :verbose, false), do: Enum.map(report.held, &held_line/1), else: []

    report
    |> all_findings()
    |> Enum.map(&line/1)
    |> Enum.concat(held)
    |> Enum.concat([summary(report)])
    |> Enum.join("\n")
  end

  def render(%__MODULE__{} = report, :json, _opts) do
    JSON.encode!(%{
      "modules" => report.counts.modules,
      "apps" => report.counts.apps,
      "rules" => report.counts.rules,
      "opaque" => report.counts.opaque,
      "no_core" => report.counts.no_core,
      "outside_root" => report.counts.outside_root,
      "apply_sites" => apply_sites_json(report.counts.apply_sites),
      "aggregates" => aggregates_json(Map.get(report.counts, :aggregates)),
      "writes" => writes_json(Map.get(report.counts, :writes)),
      "exit_code" => report.exit_code,
      "findings" => Enum.map(report.findings, &Finding.to_json/1),
      "could_not_check" => Enum.map(report.could_not_check, &Finding.to_json/1),
      "refused" => Enum.map(report.refused, &Finding.to_json/1),
      "held" => Enum.map(report.held, &Finding.to_json/1)
    })
  end

  @doc """
  The summary line: `anchor.graph: <M> modules in <A> apps, <R> rules, <V>
  violations (<P> report-only, <H> baselined)`, where `V` counts every
  `:enforce` finding, every could-not-check entry and every refusal, `P`
  every `:report` finding and `H` every held one. Opaque (Erlang) modules,
  functions with no Core body and modules compiled from outside the root are
  counted when there are any, and so are declared aggregates (DND-5476:
  `; aggregates: <N> declared, <U> tables unknown`) and the write analysis
  (DND-5459: `; writes: <W> found, <R> resolved, <U> unresolved;
  transactions: <S>, <C> complete, <I> incomplete`).
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{counts: counts} = report) do
    {report_only, enforced} = Enum.split_with(report.findings, &(&1.enforcement == :report))
    violations = length(enforced) + length(report.could_not_check) + length(report.refused)

    "anchor.graph: #{counts.modules} modules#{notes(counts)} in #{counts.apps} apps, " <>
      "#{counts.rules} rules, #{violations} violations " <>
      "(#{length(report_only)} report-only, #{length(report.held)} baselined)" <>
      apply_sites_note(counts.apply_sites) <>
      aggregates_note(Map.get(counts, :aggregates)) <> writes_note(Map.get(counts, :writes))
  end

  # DND-5459: every write and transaction the analysis found, and how many it
  # could not judge: an unresolved write or an incomplete transaction is
  # counted, never read as clean.
  defp writes_note(nil), do: ""

  defp writes_note(writes) do
    "; writes: #{writes.writes} found, #{writes.resolved} resolved, " <>
      "#{writes.unresolved} unresolved; transactions: #{writes.scopes}, " <>
      "#{writes.complete} complete, #{writes.incomplete} incomplete"
  end

  defp writes_json(nil), do: nil

  defp writes_json(writes),
    do: Map.new(writes, fn {key, value} -> {Atom.to_string(key), value} end)

  # DND-5476: when any aggregate is declared, how many, and how many of their
  # schemas' tables could not be read (a `__schema__(:source)` that is not a
  # literal): an unknown table is counted, never dropped silently.
  defp aggregates_note(nil), do: ""

  defp aggregates_note(%{declared: declared, tables_unknown: unknown}),
    do: "; aggregates: #{declared} declared, #{unknown} tables unknown"

  defp aggregates_json(nil), do: nil

  defp aggregates_json(%{declared: declared, tables_unknown: unknown}),
    do: %{"declared" => declared, "tables_unknown" => unknown}

  defp apply_sites_json(nil), do: nil

  defp apply_sites_json(sites) do
    %{
      "total" => sites.total,
      "resolved" => sites.resolved,
      "any" => sites.any,
      "bound_hit" => sites.bound_hit?,
      "by_function" =>
        Map.new(sites.by_function, fn {{module, name, arity}, counts} ->
          {Exception.format_mfa(module, name, arity), Map.new(counts, &stringify_key/1)}
        end)
    }
  end

  # `nil`: no rule that ran needed the analysis, so there is nothing to count.
  defp apply_sites_note(nil), do: ""

  defp apply_sites_note(%{resolved: resolved, any: any, bound_hit?: bound_hit?}),
    do: "; apply sites: #{resolved} resolved, #{any} any#{bound_note(bound_hit?)}"

  defp bound_note(true), do: " (step bound hit: every site reads any)"
  defp bound_note(false), do: ""

  defp stringify_key({key, value}), do: {Atom.to_string(key), value}

  defp all_findings(report), do: report.could_not_check ++ report.refused ++ report.findings

  defp held_line(%Finding{} = finding) do
    "#{finding.file}:#{finding.line || 1}: [held] #{finding.label} #{finding.message}"
  end

  defp line(%Finding{} = finding) do
    "#{finding.file}:#{finding.line || 1}: [#{finding.enforcement}] #{finding.label} " <>
      finding.message
  end

  # Opaque (Erlang) modules, functions with no Core body and modules outside
  # the root, when there are any. The first two were counted but not read;
  # the last were judged, and are counted so the layout is visible.
  defp notes(counts) do
    [
      {counts.opaque, "opaque"},
      {counts.no_core, "functions with no Core body"},
      {counts.outside_root, "outside the root"}
    ]
    |> Enum.reject(fn {count, _what} -> count == 0 end)
    |> Enum.map_join(", ", fn {count, what} -> "#{count} #{what}" end)
    |> case do
      "" -> ""
      notes -> " (#{notes})"
    end
  end
end
