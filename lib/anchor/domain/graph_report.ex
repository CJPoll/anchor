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
    * `counts` — `%{modules, apps, rules, opaque, no_core, excluded}` for
      the summary line; `no_core` is the number of functions whose Core body
      the graph lacks, none of whose calls were read (DND-5549), and
      `excluded` the number of dependency modules (source outside the
      project root) left out of the graph (DND-5588).
    * `exit_code` — `exit_code/1`.

  ## Exit code

  3 when anything could not be checked (it wins over 1); 1 when any
  finding is `:enforce` (every fail-closed issue is); 0 otherwise, including a
  run whose only findings are `:report` ones (printed, never failing).

  ## Text

  One line per finding, `path:line: [enforce|report] <label> <message>`, where
  the message ends with `Fix: <shape>`, then the summary
  `anchor.graph: <M> modules in <A> apps, <R> rules, <V> violations (<P>
  report-only, <H> baselined)`. A finding with no line (one on `.anchor.yml`)
  prints line 1. Baselines are DND-5441's: `H` is 0 until then.
  """

  alias Anchor.Domain.GraphReport.Finding

  defstruct findings: [],
            could_not_check: [],
            counts: %{modules: 0, apps: 0, rules: 0, opaque: 0, no_core: 0, excluded: 0},
            exit_code: 0

  @type counts :: %{
          modules: non_neg_integer(),
          apps: non_neg_integer(),
          rules: non_neg_integer(),
          opaque: non_neg_integer(),
          no_core: non_neg_integer(),
          excluded: non_neg_integer()
        }

  @type t :: %__MODULE__{
          findings: [Finding.t()],
          could_not_check: [Finding.t()],
          counts: counts(),
          exit_code: 0 | 1 | 3
        }

  @doc "Builds a report, deciding its exit code (`exit_code/1`)."
  @spec new([Finding.t()], [Finding.t()], counts()) :: t()
  def new(findings, could_not_check, counts) do
    report = %__MODULE__{findings: findings, could_not_check: could_not_check, counts: counts}
    %{report | exit_code: exit_code(report)}
  end

  @doc "3 when anything could not be checked, 1 for any `:enforce` finding, else 0."
  @spec exit_code(t()) :: 0 | 1 | 3
  def exit_code(%__MODULE__{could_not_check: [_ | _]}), do: 3

  def exit_code(%__MODULE__{findings: findings}) do
    if Enum.any?(findings, &(&1.enforcement == :enforce)), do: 1, else: 0
  end

  @doc "Renders the report as `:text` (finding lines and the summary) or `:json`."
  @spec render(t(), :text | :json) :: String.t()
  def render(%__MODULE__{} = report, :text) do
    report
    |> all_findings()
    |> Enum.map(&line/1)
    |> Enum.concat([summary(report)])
    |> Enum.join("\n")
  end

  def render(%__MODULE__{} = report, :json) do
    JSON.encode!(%{
      "modules" => report.counts.modules,
      "apps" => report.counts.apps,
      "rules" => report.counts.rules,
      "opaque" => report.counts.opaque,
      "no_core" => report.counts.no_core,
      "excluded" => report.counts.excluded,
      "exit_code" => report.exit_code,
      "findings" => Enum.map(report.findings, &Finding.to_json/1),
      "could_not_check" => Enum.map(report.could_not_check, &Finding.to_json/1)
    })
  end

  @doc """
  The summary line: `anchor.graph: <M> modules in <A> apps, <R> rules, <V>
  violations (<P> report-only, 0 baselined)`, where `V` counts every
  `:enforce` finding and every could-not-check entry, and `P` every `:report`
  finding. Opaque (Erlang) modules, functions with no Core body and excluded
  dependency modules are counted when there are any.
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{counts: counts} = report) do
    {report_only, enforced} = Enum.split_with(report.findings, &(&1.enforcement == :report))
    violations = length(enforced) + length(report.could_not_check)

    "anchor.graph: #{counts.modules} modules#{notes(counts)} in #{counts.apps} apps, " <>
      "#{counts.rules} rules, #{violations} violations " <>
      "(#{length(report_only)} report-only, 0 baselined)"
  end

  defp all_findings(report), do: report.could_not_check ++ report.findings

  defp line(%Finding{} = finding) do
    "#{finding.file}:#{finding.line || 1}: [#{finding.enforcement}] #{finding.label} " <>
      finding.message
  end

  # Opaque (Erlang) modules, functions with no Core body and excluded
  # dependency modules, when there are any: each was counted but not read.
  defp notes(counts) do
    [
      {counts.opaque, "opaque"},
      {counts.no_core, "functions with no Core body"},
      {counts.excluded, "dependency modules excluded"}
    ]
    |> Enum.reject(fn {count, _what} -> count == 0 end)
    |> Enum.map_join(", ", fn {count, what} -> "#{count} #{what}" end)
    |> case do
      "" -> ""
      notes -> " (#{notes})"
    end
  end
end
