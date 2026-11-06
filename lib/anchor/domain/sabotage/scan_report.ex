defmodule Anchor.Domain.Sabotage.ScanReport do
  @moduledoc """
  The report of a nightly improvement scan (DND-5490), `mix anchor.sabotage
  run --scope all --shard I/N --report PATH`. Pure **Domain**: a finished run,
  the survivors list's entries and the scan's facts in, the report out, as
  markdown for people and a term for tools.

  The report's first line says how tests were selected: from the coverage map
  it names, or, with none, from the kill maps and the test mirror. Then the
  shard, the totals by status, the totals by module, the **findings** (each
  survivor the survivors list does not hold: a mutant no test kills and no
  one has explained), and the functions whose mutants had no test. A listed
  survivor is counted, never a finding. The report is written whatever it
  finds; a person files a ticket per module with findings.
  """

  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.Survivors.Entry

  @statuses [:killed, :survived, :timeout, :invalid, :crashed, :no_tests]

  @typedoc "What the scan ran with: its shard (`nil` for all of it) and coverage map path."
  @type meta :: %{shard: nil | {non_neg_integer(), pos_integer()}, coverage: String.t() | nil}

  @doc "The report of `run`, as `{markdown, term}`."
  @spec render(Run.t(), [Entry.t()], meta()) :: {String.t(), map()}
  def render(%Run{} = run, entries, meta) do
    term = term(run, entries, meta)
    {markdown(term), term}
  end

  defp term(run, entries, meta) do
    listed = MapSet.new(entries, & &1.id)
    survived = Enum.filter(run.outcomes, &(&1.status == :survived))

    %{
      version: 1,
      shard: meta.shard,
      coverage: meta.coverage,
      totals: totals(run.outcomes),
      by_module: by_module(run.outcomes),
      findings:
        survived
        |> Enum.reject(&MapSet.member?(listed, &1.mutant.id))
        |> Enum.map(&finding/1),
      listed_survivors: Enum.count(survived, &MapSet.member?(listed, &1.mutant.id)),
      no_tests:
        run.outcomes
        |> Enum.filter(&(&1.status == :no_tests))
        |> Enum.map(&{&1.mutant.file, mfa(&1.mutant)})
        |> Enum.uniq()
    }
  end

  defp totals(outcomes) do
    counts = Enum.frequencies_by(outcomes, & &1.status)
    Map.new(@statuses, &{&1, Map.get(counts, &1, 0)})
  end

  defp by_module(outcomes) do
    outcomes
    |> Enum.group_by(&inspect(&1.mutant.module), & &1.status)
    |> Map.new(fn {module, statuses} -> {module, totals_of(statuses)} end)
  end

  defp totals_of(statuses) do
    counts = Enum.frequencies(statuses)
    Map.new(@statuses, &{&1, Map.get(counts, &1, 0)})
  end

  defp finding(%{mutant: mutant}),
    do: %{
      id: mutant.id,
      file: mutant.file,
      mfa: mfa(mutant),
      operator: Atom.to_string(mutant.operator)
    }

  # -- markdown ----------------------------------------------------------------

  defp markdown(t) do
    Enum.join(
      [
        selection(t.coverage),
        "",
        "- Shard: #{shard(t.shard)}",
        "- Mutants: #{t.totals |> Map.values() |> Enum.sum()}; findings: #{length(t.findings)}; " <>
          "listed survivors: #{t.listed_survivors}",
        "",
        "## Totals",
        "",
        "| " <> Enum.join(@statuses, " | ") <> " |",
        "|" <> String.duplicate("---|", length(@statuses)),
        "| " <> Enum.map_join(@statuses, " | ", &Map.fetch!(t.totals, &1)) <> " |",
        "",
        "## By module",
        ""
      ] ++
        module_table(t.by_module) ++
        [
          "",
          "## Findings: survivors not on the survivors list",
          ""
        ] ++
        findings(t.findings) ++
        ["", "## Functions whose mutants had no test", ""] ++
        no_tests(t.no_tests),
      "\n"
    ) <> "\n"
  end

  defp selection(nil),
    do:
      "# Sabotage scan: no coverage map, so tests were selected from the kill maps and " <>
        "the test mirror"

  defp selection(path), do: "# Sabotage scan: tests selected by the coverage map #{path}"

  defp shard(nil), do: "all"
  defp shard({i, n}), do: "#{i}/#{n}"

  defp module_table(by_module) when map_size(by_module) == 0, do: ["None."]

  defp module_table(by_module) do
    [
      "| module | " <> Enum.join(@statuses, " | ") <> " |",
      "|---|" <> String.duplicate("---|", length(@statuses))
    ] ++
      for {module, counts} <- Enum.sort(by_module) do
        "| #{module} | " <> Enum.map_join(@statuses, " | ", &Map.fetch!(counts, &1)) <> " |"
      end
  end

  defp findings([]), do: ["None."]

  defp findings(findings),
    do: Enum.map(findings, &"- `#{&1.id}` #{&1.file} #{&1.mfa} #{&1.operator}")

  defp no_tests([]), do: ["None."]
  defp no_tests(functions), do: Enum.map(functions, fn {file, mfa} -> "- #{mfa} (#{file})" end)

  defp mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"
end
