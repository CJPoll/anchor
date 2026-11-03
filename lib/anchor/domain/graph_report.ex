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
    * `counts` — `%{modules, apps, rules, opaque}` for the summary line.
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
  each held one prints as `path:line: [held] <label> <message>`.
  """

  alias Anchor.Domain.GraphReport.Finding

  defstruct findings: [],
            could_not_check: [],
            held: [],
            refused: [],
            counts: %{modules: 0, apps: 0, rules: 0, opaque: 0},
            exit_code: 0

  @type counts :: %{
          modules: non_neg_integer(),
          apps: non_neg_integer(),
          rules: non_neg_integer(),
          opaque: non_neg_integer()
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
  every `:report` finding and `H` every held one. Opaque (Erlang) modules are
  named when there are any.
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{counts: counts} = report) do
    {report_only, enforced} = Enum.split_with(report.findings, &(&1.enforcement == :report))
    violations = length(enforced) + length(report.could_not_check) + length(report.refused)

    "anchor.graph: #{counts.modules} modules#{opaque(counts.opaque)} in #{counts.apps} apps, " <>
      "#{counts.rules} rules, #{violations} violations " <>
      "(#{length(report_only)} report-only, #{length(report.held)} baselined)"
  end

  defp all_findings(report), do: report.could_not_check ++ report.refused ++ report.findings

  defp held_line(%Finding{} = finding) do
    "#{finding.file}:#{finding.line || 1}: [held] #{finding.label} #{finding.message}"
  end

  defp line(%Finding{} = finding) do
    "#{finding.file}:#{finding.line || 1}: [#{finding.enforcement}] #{finding.label} " <>
      finding.message
  end

  defp opaque(0), do: ""
  defp opaque(count), do: " (#{count} opaque)"
end
