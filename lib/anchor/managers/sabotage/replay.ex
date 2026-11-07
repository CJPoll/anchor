defmodule Anchor.Managers.Sabotage.Replay do
  @moduledoc """
  The flow of `mix anchor.sabotage replay` (DND-5485), part of the
  **Manager** `Anchor.Managers.Sabotage` (ADR 001): re-applies each recorded
  mutant on the current tree and runs the tests that killed it. It returns an
  `Anchor.Domain.Sabotage.Replay.Result`; it prints nothing, and never writes
  a record or the survivors list.

  It keeps `run`'s discipline (`Anchor.Managers.Sabotage.Runner`, whose
  steps it calls): the run lock for its whole length, a leftover journal
  dealt with first, the `sabotage:` config (else exit 3), the journal
  git-ignored (else exit 2), and each mutant journaled, written, tested
  under the time bound, and restored with its sha256 checked.

    1. Records: every `*.md` under the configured records directories (or
       each `--records` directory glob), their `anchor-kills` rows parsed
       (`KillMap.parse/1`). A record whose kill map does not parse is named
       (`could not read ...`), and the replay ends exit 3 however its other
       rows fare (unless one lost power: 1): its kills went unchecked. Zero
       `killed` or `timeout` rows is exit 3, naming the directories searched.
    2. Plan (`Anchor.Domain.Sabotage.Replay.plan/2`): each row's file read
       (only a path inside the project with no symlink on it,
       `SourceMutation.symlinked/2`; a killer file with one is drifted too),
       its function's mutants regenerated
       with every operator (`Mutator.generate/4`), the row's id looked up,
       and its killers' test files checked. The rest are drifted.
    3. The replayable rows' files must be clean in git (else exit 2), and
       the cap (`--max`, else `max_mutants`) keeps the first rows in (record,
       id) order; the others are `not replayed (cap)`.
    4. The baseline: every replayable row's killers, by name, run once with
       no mutant (and the whole killer files of rows run by file, once);
       anything but a pass is exit 3: main is red, nothing can be judged.
    5. Each row: `Runner.mutant_outcome/6` (journal, write, run, restore),
       judged by `Replay.judge/2`.

  Adapters as `run`'s options, the ones it uses.
  """

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Adapters.GitStatus
  alias Anchor.Adapters.RecordFile
  alias Anchor.Adapters.SourcePatcher
  alias Anchor.Adapters.TestRunner
  alias Anchor.Domain.Sabotage.KillerRef
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Operators
  alias Anchor.Domain.Sabotage.Record
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Domain.Sabotage.Replay.Result
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.Domain.Sabotage.TestRunRefusal
  alias Anchor.Managers.Sabotage.Runner

  @doc """
  Replays the landed records under `root`. `facts`: `root`, `build_path`,
  `max` (`nil`, a count or `:all`), `records` (directory globs; `[]` for the
  configured records directories).
  """
  @spec run(map(), keyword()) :: Result.t()
  def run(%{root: root, build_path: build_path} = facts, opts) when is_binary(build_path) do
    ports = ports(opts)

    Runner.locked(%Result{}, root, ports, fn ->
      case Runner.recover(%Result{}, root, ports) do
        {:ok, result} -> checked(result, facts, ports)
        {:refuse, result, code, message} -> %{result | refusal: {code, message}}
      end
    end)
  end

  # The ports `Runner`'s steps need here, with `run`'s defaults.
  defp ports(opts) do
    %{
      config: Keyword.get(opts, :config_loader, ConfigFile),
      change: Keyword.get(opts, :change_source, GitChangeSource),
      patcher: Keyword.get(opts, :source_mutation, SourcePatcher),
      git: Keyword.get(opts, :git_worktree, GitStatus),
      tests: Keyword.get(opts, :test_execution, TestRunner),
      records: Keyword.get(opts, :record_store, RecordFile),
      opts: opts
    }
  end

  defp checked(result, %{root: root} = facts, ports) do
    with {:ok, config} <- Runner.config(root, ports),
         :ok <- Runner.journal_ignored(root, ports),
         {:ok, result, items} <- records(result, facts, config, ports) do
      planned(result, items, facts, config, ports)
    else
      {:refuse, code, message} -> %{result | refusal: {code, message}}
      {:done, result} -> result
    end
  end

  # -- 1. records --------------------------------------------------------------

  defp records(result, facts, config, %{records: store}) do
    globs =
      case Map.get(facts, :records, []) do
        [] -> Record.dir_globs(config.records)
        globs -> globs
      end

    paths = globs |> Enum.flat_map(&store.list(facts.root, &1)) |> Enum.uniq() |> Enum.sort()

    {rows, unreadable} =
      Enum.reduce(paths, {[], []}, fn path, {rows, bad} ->
        with {:ok, text} <- store.read(facts.root, path),
             {:ok, parsed} <- KillMap.parse(text) do
          {rows ++ [{path, parsed}], bad}
        else
          {:error, {line, message}} -> {rows, bad ++ ["kill map in #{path}:#{line} (#{message})"]}
          {:error, posix} -> {rows, bad ++ ["#{path} (#{inspect(posix)})"]}
        end
      end)

    items = Replay.items(rows)

    result = %{
      result
      | searched: globs,
        records: length(paths),
        rows: length(items),
        unreadable: unreadable
    }

    if items == [], do: {:done, result}, else: {:ok, result, items}
  end

  # -- 2..5. plan, cap, baseline, each row -------------------------------------

  defp planned(result, items, facts, config, ports) do
    symlinked = symlinked(items, facts.root, ports)
    sources = sources(items, facts.root, symlinked, ports)
    tests = existing_tests(items, facts.root, ports)

    generated =
      for %{row: row} <- items, Map.has_key?(sources, row.file), into: %{} do
        {{row.file, row.mfa}, generate(sources[row.file], row, config)}
      end

    plan =
      Replay.plan(items, %{
        sources: Map.new(sources, fn {file, _text} -> {file, true} end),
        generated: generated,
        tests: tests,
        symlinked: symlinked
      })

    {kept, capped} = cap(plan.replayable, Map.get(facts, :max) || config.max_mutants)
    result = %{result | drifted: plan.drifted, not_replayed: capped}

    with :ok <- clean(kept, facts.root, ports),
         :ok <- baseline(kept, facts, config, ports) do
      replay(result, kept, facts, config, sources, ports)
    else
      {:refuse, code, message} -> %{result | refusal: {code, message}}
    end
  end

  # Every row file and killer file inside the project with a symlink on its
  # path: never read, written or run (the plan drifts their rows).
  defp symlinked(items, root, %{patcher: patcher}) do
    killer_files =
      for %{row: row} <- items,
          killer <- row.killers,
          {:ok, ref} <- [KillerRef.parse(killer)],
          do: ref.file

    paths = Enum.uniq(Enum.map(items, & &1.row.file) ++ killer_files)
    MapSet.new(patcher.symlinked(root, Enum.filter(paths, &Replay.inside?/1)))
  end

  # Only a file inside the project, with no symlink on its path, is read; the
  # plan drifts the others.
  defp sources(items, root, symlinked, %{change: change}) do
    items
    |> Enum.map(& &1.row.file)
    |> Enum.uniq()
    |> Enum.filter(&(Replay.inside?(&1) and not MapSet.member?(symlinked, &1)))
    |> Enum.flat_map(fn file ->
      case change.read(root, file) do
        {:ok, text} -> [{file, text}]
        {:error, _posix} -> []
      end
    end)
    |> Map.new()
  end

  defp existing_tests(items, root, %{patcher: patcher}) do
    items
    |> Enum.flat_map(& &1.row.killers)
    |> Enum.flat_map(fn killer ->
      case KillerRef.parse(killer) do
        {:ok, ref} -> [ref.file]
        {:error, _reason} -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.map(&Path.join(root, &1))
    |> patcher.existing()
    |> MapSet.new(&Path.relative_to(&1, root))
  end

  defp generate(text, row, config) do
    case Replay.function(row.mfa) do
      {:ok, mfa} ->
        opts = [operators: Operators.all(), effect_calls: config.effect_calls]

        case Mutator.generate(text, row.file, mfa, opts) do
          {:ok, %{mutants: mutants}} -> {:ok, mutants}
          {:error, why} -> {:error, why}
        end

      :error ->
        {:error, :bad_function}
    end
  end

  defp cap(replayable, cap) do
    ordered = Enum.sort_by(replayable, &{&1.record, &1.row.id})
    if cap == :all, do: {ordered, []}, else: Enum.split(ordered, cap)
  end

  defp clean([], _root, _ports), do: :ok

  defp clean(kept, root, %{git: git}) do
    files = kept |> Enum.map(& &1.mutant.file) |> Enum.uniq()

    case git.dirty_paths(root, files) do
      {:ok, []} ->
        :ok

      {:ok, dirty} ->
        {:refuse, 2,
         "uncommitted changes in #{Enum.join(dirty, ", ")}: a replay starts from committed " <>
           "code. Fix: commit #{Enum.join(dirty, " ")}, then rerun"}

      {:error, reason} ->
        {:refuse, 3,
         "COULD NOT MEASURE: git could not say which files are dirty (#{inspect(reason)})"}
    end
  end

  defp baseline(kept, facts, config, ports) do
    {by_file, by_name} = Enum.split_with(kept, & &1.by_file)

    runs =
      [
        by_name |> Enum.flat_map(&named_refs/1) |> KillerRef.to_test_args(),
        by_file |> Enum.flat_map(& &1.test_args) |> Enum.uniq()
      ]
      |> Enum.reject(&(&1 == []))

    Enum.reduce_while(runs, :ok, fn args, :ok ->
      case Runner.test_run(args, facts, config, ports) do
        {:ok, %TestRun{status: :passed}} ->
          {:cont, :ok}

        {:ok, %TestRun{} = run} ->
          {:halt, {:refuse, 3, red_main(run)}}

        {:error, reason} ->
          {:halt, {:refuse, TestRunRefusal.code(reason), TestRunRefusal.message(reason)}}
      end
    end)
  end

  defp named_refs(%{row: row}) do
    for killer <- row.killers,
        {:ok, ref} <- [KillerRef.parse(killer)],
        do: ref
  end

  defp red_main(%TestRun{failures: [first | _rest]}) do
    "COULD NOT MEASURE: the recorded killers fail with no mutant applied " <>
      "(#{first.file}:#{first.line} #{first.name}: #{first.text}): main is red, so nothing can " <>
      "be judged. Fix: make them pass first"
  end

  # Every killer named by its rows is gone (renamed or deleted), though its
  # file is there: drift, not a red main, but nothing can be judged.
  defp red_main(%TestRun{status: :no_tests}) do
    "COULD NOT MEASURE: no recorded killer test ran with no mutant applied: every test the " <>
      "rows name is gone (renamed or deleted), so every row is drifted (killer test not " <>
      "found). Fix: land a sabotage record for the current tests, written by " <>
      "mix anchor.sabotage run"
  end

  defp red_main(%TestRun{status: status}) do
    "COULD NOT MEASURE: the recorded killers did not pass with no mutant applied (#{status}): " <>
      "nothing can be judged. Fix: run them and make them pass first"
  end

  defp replay(result, kept, facts, config, sources, ports) do
    source_results = Map.new(sources, fn {file, text} -> {file, {:ok, text}} end)

    Enum.reduce_while(kept, result, fn item, result ->
      selection = {:kill_map, item.test_args}

      case Runner.mutant_outcome(item.mutant, selection, facts, config, source_results, ports) do
        {:ok, outcome} ->
          verdict = Replay.judge(item, outcome)
          # How many tests the killers' run ran: by name, the killers alone.
          item = Map.put(item, :tests_run, tests_run(outcome))
          {:cont, %{result | results: result.results ++ [{item, verdict}]}}

        {:refuse, code, message} ->
          {:halt, %{result | refusal: {code, message}}}
      end
    end)
  end

  defp tests_run(%{test_run: %TestRun{total: total}}), do: total
  defp tests_run(_outcome), do: nil
end
