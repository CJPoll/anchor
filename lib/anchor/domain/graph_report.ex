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
      `apply_sites/1` of it; `effects` (optional) is `nil` or absent when no
      rule that ran needed the effect inference (DND-5447), else `effects/1`
      of it; `interface_width` is `nil` when no `interface` rule ran (DND-5443),
      else `%{context => public functions on its interface}`
      (`Anchor.Domain.Interfaces.width/1`); `aggregates` (optional, DND-5476) is
      `%{declared, tables_unknown}` when any aggregate is declared, and the
      JSON's `aggregates` is `null` otherwise; `writes` (optional, DND-5459)
      is the write analysis's counts, its gaps with no transaction read around
      them among them
      (`Anchor.Domain.Aggregates.Analysis`),
      when the run made one with a repo, and the JSON's `writes` is `null`
      otherwise. The optional `dynamic_calls` is
      `Anchor.Domain.DynamicCalls.tally/1` of the graph (DND-5633): the
      dynamic calls narrowed to a declared behaviour's implementers, and those
      fanned out to every module exporting the function.
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
  any)` after it when the analysis hit its bound (DND-5574, R6). When the
  graph has a dynamic call with a known function name, it then has `;
  dynamic calls: <f> fanned out to every exporter, <n> narrowed by behaviour`
  (DND-5633), and the JSON's `dynamic_calls` names each call. When it
  computed the effect inference, the summary then ends with `; effects: <n>
  functions (domain <a>, managers <b>, adapters <c>, framework <d>), <u>
  unresolved dynamic calls`, and `, not analysed: <k>` when some public
  function had no Core body (DND-5447). When it computed the demand analysis,
  the summary then has `; demand: <f> functions, <p> parameters, <a> absent,
  <i> imprecise functions`, and `(round bound hit on <n> functions)` when it
  hit its bound (DND-5715). When an `interface` rule ran, it then has
  `; interface width: <context>=<n>, ...`, by context (DND-5443, R4).
  """

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Effects
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
              apply_sites: nil,
              interface_width: nil
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
          optional(:interface_width) => %{String.t() => non_neg_integer()} | nil,
          optional(:dynamic_calls) => dynamic_calls() | nil,
          optional(:effects) => effects() | nil,
          optional(:demand) => demand() | nil,
          optional(:aggregates) => %{declared: pos_integer(), tables_unknown: non_neg_integer()},
          optional(:writes) => %{
            writes: non_neg_integer(),
            resolved: non_neg_integer(),
            unresolved: non_neg_integer(),
            scopes: non_neg_integer(),
            no_gap_noticed: non_neg_integer(),
            incomplete: non_neg_integer(),
            outside_gaps: non_neg_integer(),
            cleared: non_neg_integer(),
            unread_by_callee: %{String.t() => pos_integer()}
          }
        }

  @type dynamic_calls :: %{
          narrowed: [{mfa(), atom(), arity()}],
          fanned_out: [{mfa(), atom(), arity()}]
        }

  @type demand :: %{
          functions: non_neg_integer(),
          parameters: non_neg_integer(),
          absent: non_neg_integer(),
          imprecise_functions: non_neg_integer(),
          bound_hit: non_neg_integer()
        }

  @type effects :: %{
          functions: non_neg_integer(),
          by_role: %{atom() => non_neg_integer()},
          unresolved: non_neg_integer(),
          not_analysed: non_neg_integer()
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
  The demand-analysis counts (DND-5715) for the summary: functions, parameters,
  absent parameters, imprecise functions, and how many functions hit the round
  bound. `nil` for no analysis.
  """
  @spec demand(Demand.t() | nil) :: demand() | nil
  def demand(nil), do: nil

  def demand(%Demand{counts: counts, bound_hit: bound_hit}) do
    %{
      functions: counts.functions,
      parameters: counts.parameters,
      absent: counts.absent,
      imprecise_functions: counts.imprecise_functions,
      bound_hit: length(bound_hit)
    }
  end

  @doc """
  The effect-inference counts (DND-5447) for the summary: functions per
  inferred role, unresolved dynamic calls, and functions not analysed. `nil`
  for no inference.
  """
  @spec effects(Effects.t() | nil) :: effects() | nil
  def effects(nil), do: nil

  def effects(%Effects{counts: counts, unresolved_calls: unresolved, not_analysed: not_analysed}) do
    %{
      functions: counts |> Map.values() |> Enum.sum(),
      by_role:
        Map.new([:domain, :managers, :adapters, :framework], &{&1, Map.get(counts, &1, 0)}),
      unresolved: unresolved,
      not_analysed: not_analysed
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
      "interface_width" => Map.get(report.counts, :interface_width),
      "dynamic_calls" => dynamic_calls_json(Map.get(report.counts, :dynamic_calls)),
      "effects" => effects_json(Map.get(report.counts, :effects)),
      "demand" => demand_json(Map.get(report.counts, :demand)),
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
  (DND-5459: `; writes: <W> read, <R> resolved, <U> unresolved; transactions:
  <S> read, <N> no gap noticed, <I> incomplete; <G> gaps with no transaction
  read around them; <D> dependency calls cleared by the no-write list; not read:
  the modules under aggregates.no_write_modules, the built-in no-write list and
  dependencies' own internals`).
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{counts: counts} = report) do
    {report_only, enforced} = Enum.split_with(report.findings, &(&1.enforcement == :report))
    violations = length(enforced) + length(report.could_not_check) + length(report.refused)

    "anchor.graph: #{counts.modules} modules#{notes(counts)} in #{counts.apps} apps, " <>
      "#{counts.rules} rules, #{violations} violations " <>
      "(#{length(report_only)} report-only, #{length(report.held)} baselined)" <>
      apply_sites_note(counts.apply_sites) <>
      dynamic_calls_note(Map.get(counts, :dynamic_calls)) <>
      effects_note(Map.get(counts, :effects)) <>
      demand_note(Map.get(counts, :demand)) <>
      width_note(Map.get(counts, :interface_width)) <>
      aggregates_note(Map.get(counts, :aggregates)) <>
      writes_note(Map.get(counts, :writes))
  end

  # DND-5459: the writes and transactions the analysis read, and how many it
  # could not judge: an unresolved write or an incomplete transaction is
  # counted, never read as clean.
  defp writes_note(nil), do: ""

  defp writes_note(writes) do
    "; writes: #{writes.writes} read, #{writes.resolved} resolved, " <>
      "#{writes.unresolved} unresolved; transactions: #{writes.scopes} read, " <>
      "#{writes.no_gap_noticed} no gap noticed, #{writes.incomplete} incomplete; " <>
      "#{writes.outside_gaps} gaps with no transaction read around them; " <>
      "#{writes.cleared} dependency calls cleared by the no-write list; " <>
      "not read: the modules under aggregates.no_write_modules, the built-in no-write " <>
      "list and dependencies' own internals"
  end

  defp writes_json(nil), do: nil

  defp writes_json(writes),
    do: Map.new(writes, fn {key, value} -> {Atom.to_string(key), value} end)

  defp dynamic_calls_json(nil), do: nil

  defp dynamic_calls_json(%{narrowed: narrowed, fanned_out: fanned_out}),
    do: %{
      "narrowed" => Enum.map(narrowed, &dynamic_call_text/1),
      "fanned_out" => Enum.map(fanned_out, &dynamic_call_text/1)
    }

  defp dynamic_call_text({{module, name, arity}, callee, callee_arity}),
    do: "#{Exception.format_mfa(module, name, arity)} -> ?.#{callee}/#{callee_arity || "?"}"

  # DND-5633: a dynamic call judged against every exporter is an
  # over-approximation, so the run says how many there were.
  defp dynamic_calls_note(%{narrowed: [], fanned_out: []}), do: ""

  defp dynamic_calls_note(%{narrowed: narrowed, fanned_out: fanned_out}),
    do:
      "; dynamic calls: #{length(fanned_out)} fanned out to every exporter, " <>
        "#{length(narrowed)} narrowed by behaviour"

  defp dynamic_calls_note(nil), do: ""

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

  defp demand_json(nil), do: nil
  defp demand_json(demand), do: Map.new(demand, &stringify_key/1)

  defp demand_note(nil), do: ""

  defp demand_note(demand) do
    "; demand: #{demand.functions} functions, #{demand.parameters} parameters, " <>
      "#{demand.absent} absent, #{demand.imprecise_functions} imprecise functions" <>
      round_bound_note(demand.bound_hit)
  end

  defp round_bound_note(0), do: ""
  defp round_bound_note(count), do: " (round bound hit on #{count} functions)"

  # `nil`: no interface rule ran (DND-5443).
  defp width_note(nil), do: ""
  defp width_note(widths) when map_size(widths) == 0, do: "; interface width: no context"

  defp width_note(widths) do
    "; interface width: " <>
      (widths |> Enum.sort() |> Enum.map_join(", ", fn {context, n} -> "#{context}=#{n}" end))
  end

  defp effects_json(nil), do: nil

  defp effects_json(effects) do
    %{
      "functions" => effects.functions,
      "by_role" => Map.new(effects.by_role, &stringify_key/1),
      "unresolved" => effects.unresolved,
      "not_analysed" => effects.not_analysed
    }
  end

  # `nil`: no rule that ran needed the effect inference.
  defp effects_note(nil), do: ""

  defp effects_note(%{functions: functions, by_role: by_role} = effects) do
    "; effects: #{functions} functions (domain #{by_role.domain}, managers " <>
      "#{by_role.managers}, adapters #{by_role.adapters}, framework #{by_role.framework}), " <>
      "#{effects.unresolved} unresolved dynamic calls" <> not_analysed_note(effects.not_analysed)
  end

  defp not_analysed_note(0), do: ""
  defp not_analysed_note(count), do: ", not analysed: #{count}"

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
