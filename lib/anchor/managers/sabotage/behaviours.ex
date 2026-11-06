defmodule Anchor.Managers.Sabotage.Behaviours do
  @moduledoc """
  The flow of `mix anchor.sabotage behaviours` (DND-5489), part of the **Manager**
  `Anchor.Managers.Sabotage` (ADR 001). It returns `{exit_code, lines}` and prints
  nothing. It runs no test; the only thing it can write is a new baseline file.

    1. The `sabotage:` config; none is exit 3.
    2. The coverage map, from `--coverage` or the config's `coverage_map`. None, one
       that cannot be read or is no version-1 map, or one with no tests or modules is
       exit 3, naming the artifact to download.
    3. Every record's kill map. A record that cannot be read or parsed is exit 3, and
       so is no `killed` row at all: nothing confirms any cause yet.
    4. The module-to-file index from the `lib` sources. It only names a directory
       where a kill row names no file, and for display, so an unreadable source file
       is a note, never a failure.
    5. `Anchor.Domain.Sabotage.BehaviourMap.build/3`.
    6. `--write-baseline` creates the baseline (exit 0), or exits 2 over an existing
       one, leaving it as it was.
    7. Otherwise the baseline is read and compared. A file named in the config that is
       absent, or a malformed one, is exit 1 in both modes: a ratchet that cannot be
       read is not a report of no drift. The default path may be absent, and then
       every key is NEW, said loudly. Anything else unreadable is exit 3.
    8. With `--base`, the entries the branch added are GREW; a first landing has none.
       A base that cannot be read is exit 3, never read as no growth.

  ## Adapters (options)

  `:config_loader` (`Anchor.Adapters.ConfigFile`), `:coverage_store`
  (`Anchor.Adapters.CoverageFile`), `:record_store` (`Anchor.Adapters.RecordFile`),
  `:source_source` (`Anchor.Adapters.SourceReader`), `:baseline_store`
  (`Anchor.Adapters.BaselineFile`), `:git_base` (`Anchor.Adapters.GitShow`).
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.CoverageFile
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.RecordFile
  alias Anchor.Adapters.SourceReader
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Sabotage.BehaviourMap
  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Record
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Managers.Sabotage.Runner

  @baseline_id "behaviour-locality"
  @default_baseline ".anchor/baselines/behaviour-locality.txt"
  @download_fix "Fix: download the anchor-coverage artifact (CI) and pass --coverage"

  @type facts :: %{
          required(:root) => String.t(),
          required(:coverage) => String.t() | nil,
          required(:format) => :text | :json,
          required(:write_baseline) => boolean(),
          required(:base) => String.t() | nil
        }

  @spec run(facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def run(facts, opts) do
    ports = ports(opts)

    with {:ok, config} <- Runner.config(facts.root, ports),
         {:ok, coverage} <- coverage(facts, config, ports),
         {:ok, rows} <- kill_rows(facts.root, config, ports) do
      {index, notes} = source_index(facts.root, ports)
      map = BehaviourMap.build(coverage, rows, index)
      path = config.behaviour_locality_baseline || @default_baseline
      judged(facts, config, ports, %{map: map, path: path, notes: notes})
    else
      {:refuse, code, message} -> {code, [message]}
    end
  end

  defp ports(opts) do
    %{
      config: Keyword.get(opts, :config_loader, ConfigFile),
      coverage: Keyword.get(opts, :coverage_store, CoverageFile),
      records: Keyword.get(opts, :record_store, RecordFile),
      sources: Keyword.get(opts, :source_source, SourceReader),
      baseline: Keyword.get(opts, :baseline_store, BaselineFile),
      git_base: Keyword.get(opts, :git_base, GitShow)
    }
  end

  defp refuse(code, message), do: {:refuse, code, message}
  defp could_not_measure(text), do: refuse(3, "COULD NOT MEASURE: " <> text)

  # -- 2. the coverage map -------------------------------------------------------

  defp coverage(facts, config, ports) do
    case facts.coverage || config.coverage_map do
      nil -> could_not_measure("no coverage map was given. " <> @download_fix)
      path -> read_coverage(path, facts.root, ports)
    end
  end

  defp read_coverage(path, root, %{coverage: store}) do
    with {:read, {:ok, term}} <- {:read, store.read(Path.expand(path, root))},
         {:check, {:ok, map}} <- {:check, CoverageMap.check(term)},
         {:validate, :ok} <- {:validate, CoverageMap.validate(map)} do
      {:ok, map}
    else
      {step, {:error, reason}} ->
        could_not_measure(
          "the coverage map #{path} #{coverage_problem(step, reason)}. " <> @download_fix
        )
    end
  end

  defp coverage_problem(:read, reason), do: "cannot be read (#{inspect(reason)})"
  defp coverage_problem(:check, reason), do: "is not a usable version-1 map (#{inspect(reason)})"
  defp coverage_problem(:validate, reason), do: "measured nothing (#{inspect(reason)})"

  # -- 3. the kill maps ----------------------------------------------------------

  defp kill_rows(root, config, %{records: store}) do
    root
    |> store.list(Record.dir_glob(config.records))
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, rows} ->
      case read_rows(root, path, store) do
        {:ok, more} -> {:cont, {:ok, rows ++ more}}
        refused -> {:halt, refused}
      end
    end)
    |> confirming()
  end

  defp read_rows(root, path, store) do
    with {:read, {:ok, text}} <- {:read, store.read(root, path)},
         {:parse, {:ok, rows}} <- {:parse, KillMap.parse(text)} do
      {:ok, rows}
    else
      {:read, {:error, reason}} ->
        could_not_measure(
          "the record #{path} cannot be read (#{inspect(reason)}). Fix: make it readable"
        )

      {:parse, {:error, {line, message}}} ->
        could_not_measure(
          "the record #{path}, line #{line}: #{message}. Fix: correct its anchor-kills block"
        )
    end
  end

  defp confirming({:ok, rows}) do
    if Enum.any?(rows, &(&1.status == "killed")),
      do: {:ok, rows},
      else:
        could_not_measure(
          "nothing confirms any cause yet: no record holds a killed mutant. " <>
            "Fix: run mix anchor.sabotage run and land its record"
        )
  end

  defp confirming(refused), do: refused

  # -- 4. the module index -------------------------------------------------------

  defp source_index(root, %{sources: sources}) do
    facts = sources.read(root, sources.list(root))
    unread = for {path, {:error, _reason}} <- facts, do: path

    {BehaviourMap.files_by_module(facts), unread_note(Enum.sort(unread))}
  end

  defp unread_note([]), do: []

  defp unread_note([first | _rest] = unread) do
    [
      "behaviours: #{length(unread)} source files could not be read (first: #{first}); " <>
        "their modules show as #{BehaviourMap.generated()} where no kill row names a file"
    ]
  end

  # -- 6..8. the baseline --------------------------------------------------------

  defp judged(%{write_baseline: true} = facts, _config, %{baseline: store}, view) do
    keys = BehaviourMap.locality_keys(view.map)

    case store.create(facts.root, view.path, Baseline.render(@baseline_id, keys)) do
      :ok ->
        {0, ["behaviour locality: wrote #{view.path} with #{length(keys)} entries"]}

      {:error, :exists} ->
        {2,
         [
           "#{view.path} already exists and was left as it is: a baseline only shrinks. " <>
             "Fix: delete the lines of what shrank, or remove the file first to start again"
         ]}

      {:error, reason} ->
        {3,
         [
           "COULD NOT MEASURE: #{view.path} cannot be written (#{inspect(reason)}). " <>
             "Fix: make it a writable path inside the project, with no symlink on it"
         ]}
    end
  end

  defp judged(facts, config, ports, view) do
    with {:ok, entries, notes} <- baseline(facts.root, view.path, config, ports),
         {:ok, grew} <- grew(facts, view.path, entries, ports) do
      full = %{
        map: view.map,
        path: view.path,
        mode: config.behaviour_locality_enforcement,
        comparison: Baseline.compare(BehaviourMap.locality_keys(view.map), entries),
        grew: grew,
        base: facts.base,
        format: facts.format,
        notes: view.notes ++ notes
      }

      {Report.behaviours_exit_code(full), Report.render_behaviours(full)}
    else
      {:refuse, code, message} -> {code, [message]}
    end
  end

  defp baseline(root, path, config, %{baseline: store}) do
    named = config.behaviour_locality_baseline

    case store.read(root, path) do
      {:ok, entries} ->
        well_formed(path, entries)

      {:error, :enoent} when is_nil(named) ->
        {:ok, [], ["behaviours: no baseline at #{path}: every locality key is NEW"]}

      {:error, :enoent} ->
        refuse(
          1,
          "baseline #{path} not found. Fix: run mix anchor.sabotage behaviours " <>
            "--write-baseline, or remove sabotage.behaviour_locality_baseline"
        )

      {:error, {:line, line, :invalid_utf8}} ->
        malformed(path, "line #{line} is not UTF-8")

      {:error, reason} ->
        could_not_measure(
          "the baseline #{path} cannot be read (#{inspect(reason)}). " <>
            "Fix: make it a readable file inside the project, with no symlink on its path"
        )
    end
  end

  defp well_formed(path, entries) do
    case BehaviourMap.malformed(entries) do
      [] -> {:ok, entries, []}
      [first | _rest] -> malformed(path, "#{inspect(first)} is no <file>::<test name> key")
    end
  end

  defp malformed(path, why) do
    refuse(
      1,
      "baseline #{path} is malformed: #{why}. Fix: correct the line, or regenerate the " <>
        "file with --write-baseline"
    )
  end

  defp grew(%{base: nil}, _path, _entries, _ports), do: {:ok, nil}

  defp grew(%{base: base, root: root}, path, entries, %{git_base: git_base}) do
    case git_base.show(root, base, path) do
      {:ok, base_entries} ->
        {:ok, Baseline.grew(entries, base_entries)}

      {:error, :absent} ->
        {:ok, []}

      {:error, reason} ->
        could_not_measure(
          "the baseline #{path} cannot be read at #{base} (#{inspect(reason)}), so what this " <>
            "branch adds cannot be judged. Fix: fetch #{base}, or pass --base with a ref that resolves"
        )
    end
  end
end
