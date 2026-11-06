defmodule Anchor.Managers.Sabotage.Runner do
  @moduledoc """
  The flow of `mix anchor.sabotage run` and `restore` (DND-5473), part of the
  **Manager** `Anchor.Managers.Sabotage` (ADR 001): it orchestrates the
  adapters and Domain, and returns an `Anchor.Domain.Sabotage.Run`; it prints
  nothing.

  ## run

    0. The run lock (`Anchor.Domain.Sabotage.Journal.lock_path/0`) is taken
       for the whole run, `restore` included, and released at its end: while
       a live run holds it another run refuses (exit 2) and touches nothing,
       so no two runs share the journal, the results file or `_build`. A host
       with no `/proc` refuses here too (exit 2, `Fix:` run on Linux): the
       lock could name no owner and would protect nothing (DND-5571). A lock
       that cannot be released is said in the notes (the next run takes a
       dead holder's lock over).
    1. A leftover journal is dealt with before anything else
       (`Anchor.Domain.Sabotage.Journal.recovery/2`). A journal whose owner
       is a live process belongs to a run still going: exit 2, nothing
       touched. Otherwise the mutant still in place is restored and the
       journal deleted (said in the run's notes);
       a file already back to the original only loses the journal; a file
       that matches neither refuses the run (exit 2) and is not touched.
    2. The config must have a `sabotage:` section (else exit 3).
    3. The journal path must be git-ignored (else exit 2).
    4. The scope (`Anchor.Managers.Sabotage.scope/2`; a failure is exit 3).
    5. Every target file must be clean in git (else exit 2): sabotage starts
       from committed code.
    6. Mutants per changed function (`Mutator.generate/4`); a function no
       mutant can be made of is an error, listed. Every function an error of
       `:parse_error` or `:unreadable` is exit 3. Each function that yielded
       no mutant is kept with its reason (`NoMutant.reason/1`), and the
       count generated is set, so the report can say a run that measured
       nothing (DND-5617).
    7. `Plan.build/2` (order, `--only`, cap), then `TestSelection.select/2`
       per mutant. With a coverage map (`--coverage PATH`, or the config's
       `coverage_map`; DND-5474) it is read first: one that cannot be read
       or is not a version-2 map is exit 2; one built from a commit that is
       not an ancestor of `HEAD` is used, with a warning in the notes. `--dry-run` stops here: it writes no mutant (step 1 may
       still have restored a leftover one).
    8. The baseline: the union of the selected tests, run once with no
       mutant. Anything but a pass is exit 3 (COULD NOT MEASURE).
    9. Each planned mutant, one at a time: with no selected test it is
       `no_tests` and nothing is written; else journal, write the mutant,
       touch, run its tests (bounded by `timeout`), and in an `after` block
       write the original back, touch, check its sha256 and only then delete
       the journal. A restore that does not reproduce the original stops the
       run (exit 2) with the journal kept. A mutant whose run another mutant
       already made (the same edit to the same file, the same tests:
       `Anchor.Domain.Sabotage.SharedRun`; the targets of one
       `defimpl P, for: [T1, T2]`) is not applied again: it takes that run's
       verdict, and is still listed as its own outcome (DND-5639).
   10. The run is saved to `<build_path>/anchor/sabotage/last-run.etf`, where
       `build_path` is the fact the task gathered from Mix
       (`Mix.Project.build_path/0`: `_build/<env>`, or what `MIX_BUILD_PATH`
       names), never derived from the root (DND-5635, as DND-5585 did for
       the graph artifact). Each test run's results file is
       `<build_path>/anchor/sabotage/results.bin` too (DND-5654), so a run
       under `MIX_BUILD_PATH` writes and reads results in the build it
       measured.
   11. The sabotage records are written (DND-5484; `Anchor.Domain.Sabotage.Record`),
       unless `--no-record`: one per (app, domain) the run touched, created
       or appended, never overwritten. A run that exits 1 still writes them.
       Before step 8 (so a run that could not name its record never applies
       a mutant) the naming is checked: a detached `HEAD` with no `--slot`,
       `ticket_nn_what` with no ticket key and no `--ticket`, and `{app}` in
       the records dir for a file outside `apps/<app>/` are each exit 2. A
       record that cannot be written sets `record_error`: said loudly, and
       exit 2 only when every measured mutant passed (DND-5641).

  ## The survivors list (DND-5483)

  Before any mutant is applied (after step 7's record checks; a dry run skips
  it), the survivors list (`sabotage.survivors`, default
  `Anchor.Domain.Sabotage.Survivors.default_path/0`) is read through
  `Anchor.Adapters.BaselineStore` and its copy at `base` (the ref the scope
  read, `origin/main` by default) through `Anchor.Adapters.GitBase`, the
  ports the graph's baselines use. A named file that is absent, or a list
  that does not parse, refuses the run (exit 1, each entry named); a list
  that cannot be read, or a base copy that cannot be read for any reason but
  its absence, is exit 3. The default path absent is an empty list, said in
  the notes. After the mutants, `Survivors.judge/2` and `Survivors.grew/2`
  set `Run.survivors`; `Report` turns it into the exit code. The run never
  writes the list.

  Selection also reads the kill maps of the records already there (DND-5484):
  a record whose `anchor-kills` block does not parse is skipped for selection
  and named in the notes (`could not read kill map in <path>:<line>`), never
  read as an empty map.

  The exit code is `Anchor.Domain.Sabotage.Report`'s (DND-5570): the Runner
  only sets `Run.changed_functions` (the scope's count, `0` for a good diff
  read that found none) and classifies a raised test run as `:crashed`.

  The `after` block runs on an exception and a throw; a VM kill skips it, and
  the journal covers that on the next run.

  ## Adapters (options)

  `:config_loader` (`Anchor.Adapters.ConfigFile`), `:baseline_store`
  (`Anchor.Adapters.BaselineFile`), `:git_base` (`Anchor.Adapters.GitShow`),
  `:record_store`
  (`Anchor.Adapters.RecordFile`), `:coverage_store`
  (`Anchor.Adapters.CoverageFile`), `:change_source`
  (`Anchor.Adapters.GitChangeSource`), `:source_mutation`
  (`Anchor.Adapters.SourcePatcher`), `:git_worktree`
  (`Anchor.Adapters.GitStatus`), `:test_execution`
  (`Anchor.Adapters.TestRunner`).
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.CoverageFile
  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.GitStatus
  alias Anchor.Adapters.RecordFile
  alias Anchor.Adapters.SourcePatcher
  alias Anchor.Adapters.TestRunner
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.ChangedTests
  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.NoMutant
  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Plan
  alias Anchor.Domain.Sabotage.Record
  alias Anchor.Domain.Sabotage.RecordNaming
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.SharedRun
  alias Anchor.Domain.Sabotage.Survivors
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.Domain.Sabotage.TestRunRefusal
  alias Anchor.Domain.Sabotage.TestSelection
  alias Anchor.Managers.Sabotage

  @default_base "origin/main"
  @restore_failed :anchor_sabotage_restore_failed

  @spec run(map(), keyword()) :: Run.t()
  def run(%{root: root, build_path: build_path} = facts, opts) when is_binary(build_path) do
    ports = ports(opts)
    run = %Run{base: Map.get(facts, :base, @default_base)}

    locked(run, root, ports, fn ->
      case recover(run, root, ports) do
        {:ok, run} -> checked_run(run, facts, ports)
        {:refuse, run, code, message} -> %{run | refusal: {code, message}}
      end
    end)
  end

  @spec restore(%{root: String.t()}, keyword()) :: Run.t()
  def restore(%{root: root}, opts) do
    ports = ports(opts)
    run = %Run{restore: true}

    locked(run, root, ports, fn ->
      case recover(run, root, ports) do
        {:ok, %Run{notes: []} = run} -> %{run | notes: ["nothing to restore"]}
        {:ok, run} -> run
        {:refuse, run, code, message} -> %{run | refusal: {code, message}}
      end
    end)
  end

  # -- 0. the run lock --------------------------------------------------------

  # A raise or a throw releases the lock and goes on up; a VM kill leaves it,
  # and the next run takes a dead holder's lock over.
  @doc false
  # Shared with the replay (DND-5485): the run lock around `body`.
  @spec locked(map(), String.t(), map(), (-> map())) :: map()
  def locked(run, root, %{patcher: patcher}, body) do
    case patcher.take_lock(root) do
      :ok ->
        try do
          body.()
        rescue
          error ->
            _released = patcher.release_lock(root)
            reraise error, __STACKTRACE__
        catch
          kind, reason ->
            _released = patcher.release_lock(root)
            :erlang.raise(kind, reason, __STACKTRACE__)
        else
          result -> released(result, root, patcher)
        end

      {:error, {:held, owner}} ->
        %{run | refusal: {2, lock_held(owner)}}

      {:error, {:stuck, path}} ->
        %{run | refusal: {2, lock_stuck(path)}}

      {:error, :no_proc} ->
        %{run | refusal: {2, no_proc()}}

      {:error, posix} ->
        %{run | refusal: {2, lock_not_taken(posix)}}
    end
  end

  defp released(result, root, patcher) do
    case patcher.release_lock(root) do
      :ok ->
        result

      {:error, posix} ->
        note(
          result,
          "could not remove the run lock #{Journal.lock_path()} (#{inspect(posix)}); " <>
            "the next run takes it over once this one has exited"
        )
    end
  end

  defp lock_held(nil),
    do:
      "another sabotage run holds #{Journal.lock_path()}; nothing was touched. " <>
        "Fix: let that run finish, then rerun"

  defp lock_held(%{os_pid: pid}),
    do:
      "another sabotage run (OS pid #{pid}) is running in this project; nothing was " <>
        "touched. Fix: let that run finish, then rerun"

  defp no_proc,
    do:
      "this host has no /proc, so the run lock cannot tell a live sabotage run from a dead " <>
        "one and would protect nothing; nothing was touched. " <>
        "Fix: run mix anchor.sabotage on Linux (a dev machine or CI)"

  defp lock_stuck(path),
    do:
      "a run was killed while taking over #{Journal.lock_path()}, and left #{path}; " <>
        "nothing was touched. Fix: check no sabotage run is going, delete #{path}, then rerun"

  defp lock_not_taken(posix),
    do:
      "could not take the run lock #{Journal.lock_path()} (#{inspect(posix)}); nothing was " <>
        "touched. Fix: make _build/ writable"

  defp checked_run(run, %{root: root} = facts, ports) do
    with {:ok, config} <- config(root, ports),
         :ok <- journal_ignored(root, ports),
         {:ok, scope} <- scope(facts, ports),
         :ok <- clean_targets(root, scope, ports),
         {:ok, run, sources, mutants} <- generate(run, root, scope, config, ports),
         {:ok, plan} <- plan(mutants, facts, config),
         {:ok, coverage, notes} <- coverage(facts, config, ports),
         {:ok, records} <- existing_records(root, config, ports),
         {:ok, recording} <- recording(facts, config, scope, run, plan, records, ports),
         {:ok, list} <- survivors_list(facts, config, ports) do
      run = %{
        run
        | not_run: plan.not_run,
          notes: run.notes ++ notes ++ records.notes ++ survivor_notes(list),
          scope_functions: Enum.map(scope.functions, &mfa/1),
          not_selected: not_selected(mutants, plan),
          print_survivor_lines: Map.get(facts, :print_survivor_lines, false)
      }

      selection = select(plan.planned, root, config, {coverage, records.kill_map}, ports)
      planned = Enum.zip(plan.planned, selection)

      if Map.get(facts, :dry_run, false),
        do: %{run | dry_run: true, planned: planned},
        else:
          run
          |> measure(facts, config, sources, planned, ports)
          |> judge_survivors(list)
          |> write_records(recording, root, ports)
          |> save(facts, ports)
    else
      {:refuse, run, code, message} -> %{run | refusal: {code, message}}
      {:refuse, code, message} -> %{run | refusal: {code, message}}
    end
  end

  defp ports(opts) do
    %{
      config: Keyword.get(opts, :config_loader, ConfigFile),
      change: Keyword.get(opts, :change_source, GitChangeSource),
      patcher: Keyword.get(opts, :source_mutation, SourcePatcher),
      git: Keyword.get(opts, :git_worktree, GitStatus),
      tests: Keyword.get(opts, :test_execution, TestRunner),
      coverage: Keyword.get(opts, :coverage_store, CoverageFile),
      records: Keyword.get(opts, :record_store, RecordFile),
      baseline_store: Keyword.get(opts, :baseline_store, BaselineFile),
      git_base: Keyword.get(opts, :git_base, GitShow),
      opts: opts
    }
  end

  # -- 1. the leftover journal -------------------------------------------------

  @doc false
  # Step 1, shared with the replay (DND-5485).
  @spec recover(map(), String.t(), map()) ::
          {:ok, map()} | {:refuse, map(), pos_integer(), String.t()}
  def recover(run, root, %{patcher: patcher}) do
    case patcher.read_journal(root) do
      :none ->
        {:ok, run}

      {:ok, entry} ->
        recover_entry(run, root, entry, patcher)

      {:error, reason} ->
        {:refuse, run, 2,
         "#{Journal.path()} cannot be read (#{inspect(reason)}): a mutant may still be in the " <>
           "tree. Fix: check `git diff`, restore any changed file by hand, then delete " <>
           Journal.path()}
    end
  end

  defp recover_entry(run, root, entry, patcher) do
    path = Path.join(root, entry.file)

    if patcher.owner_alive?(entry.owner),
      do: {:refuse, run, 2, live_owner(entry)},
      else: recover_file(run, root, path, entry, patcher)
  end

  defp live_owner(entry) do
    "another sabotage run (OS pid #{entry.owner.os_pid}) is applying mutant " <>
      "#{entry.mutant_id} to #{entry.file}; nothing was touched. Fix: let that run finish, " <>
      "then rerun"
  end

  defp recover_file(run, root, path, entry, patcher) do
    case patcher.sha256_file(path) do
      {:ok, sha} -> recover_verdict(Journal.recovery(entry, sha), run, root, entry, patcher)
      {:error, posix} -> changed(run, entry, "it cannot be read (#{inspect(posix)})")
    end
  end

  defp recover_verdict(:restore, run, root, entry, patcher) do
    path = Path.join(root, entry.file)

    with :ok <- patcher.write_file(path, entry.original),
         :ok <- patcher.touch_ahead(path),
         {:ok, sha} when sha == entry.original_sha <- patcher.sha256_file(path),
         :ok <- patcher.delete_journal(root) do
      {:ok, note(run, "restored leftover mutant #{entry.mutant_id} in #{entry.file}")}
    else
      _failed -> {:refuse, run, 2, restore_failed_message(entry.file)}
    end
  end

  defp recover_verdict(:discard, run, root, entry, patcher) do
    case patcher.delete_journal(root) do
      :ok ->
        {:ok,
         note(
           run,
           "removed the journal of mutant #{entry.mutant_id}: #{entry.file} was already restored"
         )}

      {:error, posix} ->
        {:refuse, run, 2,
         "could not delete #{Journal.path()} (#{inspect(posix)}). Fix: delete it"}
    end
  end

  defp recover_verdict(:changed, run, _root, entry, _patcher),
    do: changed(run, entry, "it matches neither the original nor the mutant")

  defp changed(run, entry, why) do
    {:refuse, run, 2,
     "#{entry.file} changed since mutant #{entry.mutant_id} was applied (#{why}); nothing was " <>
       "written. Fix: git diff #{entry.file}, restore it by hand, then delete #{Journal.path()}"}
  end

  defp note(run, line), do: %{run | notes: run.notes ++ [line]}

  defp restore_failed_message(file) do
    "the restore of #{file} did not reproduce the original; the journal is kept. " <>
      "Fix: mix anchor.sabotage restore"
  end

  # -- 2..5. config, journal ignored, scope, clean targets -------------------

  @doc false
  # Step 2, shared with the replay (DND-5485).
  @spec config(String.t(), map()) :: {:ok, term()} | {:refuse, pos_integer(), String.t()}
  def config(root, %{config: loader}) do
    case loader.load_in(root) do
      {:ok, %{sabotage: nil}} ->
        {:refuse, 3,
         "COULD NOT MEASURE: .anchor.yml has no sabotage: section. " <>
           "Fix: add a sabotage: section (see README, Sabotage)"}

      {:ok, %{sabotage: config}} ->
        {:ok, config}

      {:error, reason} ->
        {:refuse, 3, "COULD NOT MEASURE: " <> Failures.config_violation(reason).message}
    end
  end

  @doc false
  # Step 3, shared with the replay (DND-5485).
  @spec journal_ignored(String.t(), map()) :: :ok | {:refuse, pos_integer(), String.t()}
  def journal_ignored(root, %{git: git}) do
    case git.ignored?(root, Journal.path()) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:refuse, 2,
         "#{Journal.path()} is not git-ignored, so a leftover mutant's journal could be " <>
           "committed. Fix: add #{Journal.path()} to .gitignore"}

      {:error, reason} ->
        {:refuse, 3, Failures.scope_could_not_measure(reason)}
    end
  end

  defp scope(facts, %{change: change, opts: opts}) do
    args = %{root: facts.root, base: Map.get(facts, :base, @default_base)}

    case Sabotage.scope(args, Keyword.put(opts, :change_source, change)) do
      {:ok, scope} -> {:ok, scope}
      {:error, reason} -> {:refuse, 3, Failures.scope_could_not_measure(reason)}
    end
  end

  defp clean_targets(root, scope, %{git: git}) do
    targets = scope.functions |> Enum.map(& &1.file) |> Enum.uniq()

    case git.dirty_paths(root, targets) do
      {:ok, []} ->
        :ok

      {:ok, dirty} ->
        {:refuse, 2,
         "uncommitted changes in #{Enum.join(dirty, ", ")}: sabotage starts from committed code. " <>
           "Fix: commit (or stash) #{Enum.join(dirty, " ")}, then rerun"}

      {:error, reason} ->
        {:refuse, 3, Failures.scope_could_not_measure(reason)}
    end
  end

  # -- 6. mutants -------------------------------------------------------------

  defp generate(run, root, scope, config, %{change: change}) do
    opts = [operators: config.operators, effect_calls: config.effect_calls]

    {results, sources} =
      Enum.map_reduce(scope.functions, %{}, fn function, sources ->
        {source, sources} = source(sources, root, function.file, change)
        {{function, generated(source, function, opts)}, sources}
      end)

    errors = for {function, {:error, reason}} <- results, do: {function, reason}
    oks = for {_function, {:ok, result}} <- results, do: result
    mutants = Enum.flat_map(oks, & &1.mutants)

    run = %{
      run
      | changed_functions: length(scope.functions),
        errors: errors,
        skipped: Enum.flat_map(oks, & &1.skipped),
        generated: length(mutants),
        no_mutant: no_mutant(results)
    }

    if results != [] and oks == [] and Enum.all?(errors, &unmeasured?/1),
      do: {:refuse, run, 3, could_not_read(errors)},
      else: {:ok, run, sources, mutants}
  end

  defp source(sources, root, file, change) do
    case Map.fetch(sources, file) do
      {:ok, source} ->
        {source, sources}

      :error ->
        source = change.read(root, file)
        {source, Map.put(sources, file, source)}
    end
  end

  defp generated({:ok, text}, function, opts),
    do:
      Mutator.generate(
        text,
        function.file,
        {function.module, function.name, function.arity},
        opts
      )

  defp generated({:error, posix}, _function, _opts), do: {:error, {:unreadable, posix}}

  defp no_mutant(results) do
    for {function, result} <- results,
        reason = NoMutant.reason(result),
        reason != nil,
        do: {function, reason}
  end

  defp unmeasured?({_function, {:parse_error, _line, _message}}), do: true
  defp unmeasured?({_function, {:unreadable, _posix}}), do: true
  defp unmeasured?(_error), do: false

  defp could_not_read(errors) do
    detail =
      Enum.map_join(errors, "; ", fn
        {f, {:parse_error, line, message}} -> "#{f.file}:#{line} does not parse (#{message})"
        {f, {:unreadable, posix}} -> "#{f.file} cannot be read (#{inspect(posix)})"
      end)

    "COULD NOT MEASURE: changed functions were found, but no file of theirs could be read: " <>
      detail <> ". Fix: make each file parse and be readable"
  end

  # -- 7. plan and selection -------------------------------------------------

  defp plan(mutants, facts, config) do
    cap = Map.get(facts, :max) || config.max_mutants

    case Plan.build(mutants, cap: cap, only: Map.get(facts, :only, [])) do
      {:ok, plan} -> {:ok, plan}
      {:error, message} -> {:refuse, 2, message}
    end
  end

  defp coverage_inputs(nil), do: %{}

  defp coverage_inputs(%{index: index, stale_tests: stale}),
    do: %{coverage: index, stale_tests: stale}

  # DND-5474: the coverage map, as an index from function to test args, and
  # the test files changed since it was built.
  defp coverage(facts, config, ports) do
    case Map.get(facts, :coverage) || config.coverage_map do
      nil -> {:ok, nil, []}
      path -> read_coverage(path, facts.root, ports)
    end
  end

  defp read_coverage(path, root, %{coverage: store, git: git}) do
    with {:read, {:ok, term}} <- {:read, store.read(Path.expand(path, root))},
         {:check, {:ok, map}} <- {:check, CoverageMap.check(term)} do
      {stale_tests, changed_notes} = stale_tests(map.commit, root, git)

      {:ok, %{index: CoverageMap.index(map), stale_tests: stale_tests},
       stale(map.commit, root, git) ++ changed_notes}
    else
      {:read, {:error, reason}} ->
        {:refuse, 2,
         "the coverage map #{path} cannot be read (#{inspect(reason)}). " <>
           "Fix: download the anchor-coverage artifact again"}

      {:check, {:error, reason}} ->
        {:refuse, 2,
         "#{path} is not a usable version-2 coverage map (#{inspect(reason)}). " <>
           "Fix: download a current anchor-coverage artifact, or rebuild it with " <>
           "mix anchor.sabotage coverage"}
    end
  end

  # The test files whose content differs from the map's commit: a ref into
  # one of them runs its whole file (`TestSelection`).
  defp stale_tests(nil, _root, _git), do: {:all, []}

  defp stale_tests(commit, root, git) do
    case git.changed_since(root, commit) do
      {:ok, paths} ->
        {MapSet.new(paths), []}

      {:error, reason} ->
        {:all,
         [
           "could not tell which files changed since the coverage map's commit #{commit} " <>
             "(#{inspect(reason)}); every test file it selects runs whole"
         ]}
    end
  end

  defp stale(commit, root, git) do
    with true <- is_binary(commit),
         {:ok, head} <- git.head_sha(root),
         {:ok, false} <- git.ancestor?(root, commit) do
      [
        "coverage map built at #{commit} is not an ancestor of HEAD #{head}; " <>
          "selections from it may miss new tests"
      ]
    else
      {:ok, true} ->
        []

      false ->
        ["the coverage map names no commit; selections from it may miss new tests"]

      {:error, reason} ->
        [
          "could not check the coverage map's commit #{commit} against HEAD " <>
            "(#{inspect(reason)}); selections from it may miss new tests"
        ]
    end
  end

  defp select(planned, root, config, {coverage, kill_map}, %{patcher: patcher}) do
    index = if coverage, do: coverage.index

    candidates =
      planned
      |> Enum.flat_map(fn mutant ->
        [TestSelection.mirror_path(mutant, config.test_mirror)] ++
          TestSelection.coverage_files(mutant, index) ++
          TestSelection.kill_map_files(mutant, kill_map)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    existing =
      candidates
      |> Enum.map(&Path.join(root, &1))
      |> patcher.existing()
      |> MapSet.new(&Path.relative_to(&1, root))

    inputs =
      Map.merge(
        %{mirror: config.test_mirror, existing_tests: existing, kill_map: kill_map},
        coverage_inputs(coverage)
      )

    Enum.map(planned, &TestSelection.select(&1, inputs))
  end

  # -- 8..10. baseline, each mutant, save ------------------------------------

  defp measure(run, facts, config, sources, planned, ports) do
    union = planned |> Enum.flat_map(fn {_m, {_source, tests}} -> tests end) |> Enum.uniq()

    case baseline(union, facts, config, ports) do
      {:ok, baseline} ->
        run
        |> Map.put(:baseline, baseline)
        |> mutants(facts, config, sources, planned, ports)

      {:refuse, code, message} ->
        %{run | refusal: {code, message}}
    end
  end

  defp baseline([], _facts, _config, _ports), do: {:ok, :none}

  defp baseline(tests, facts, config, ports) do
    case test_run(tests, facts, config, ports) do
      {:ok, %TestRun{status: :passed}} ->
        {:ok, :passed}

      {:ok, %TestRun{} = test_run} ->
        {:refuse, 3,
         "COULD NOT MEASURE: the selected tests fail with no mutant applied " <>
           "(#{baseline_detail(test_run)}). Fix: make them pass first"}

      {:error, reason} ->
        {:refuse, TestRunRefusal.code(reason), TestRunRefusal.message(reason)}
    end
  end

  defp baseline_detail(%TestRun{failures: [first | _rest]}),
    do: "#{first.file}:#{first.line} #{first.name}: #{first.text}"

  defp baseline_detail(%TestRun{} = test_run),
    do: Outcome.reason(test_run) || Atom.to_string(test_run.status)

  # DND-5639: a mutant whose run (`SharedRun.key/2`) was already measured,
  # another target of the same `defimpl ..., for: [...]` edit selecting the
  # same tests, takes that run's verdict instead of running it again.
  defp mutants(run, facts, config, sources, planned, ports) do
    planned
    |> Enum.reduce_while({run, %{}}, fn {mutant, selection}, {run, measured} ->
      key = SharedRun.key(mutant, selection)

      case measured_outcome(
             Map.fetch(measured, key),
             {mutant, selection},
             facts,
             config,
             sources,
             ports
           ) do
        {:ok, outcome} ->
          {:cont,
           {%{run | outcomes: run.outcomes ++ [outcome]}, measured(measured, key, outcome)}}

        {:refuse, code, message} ->
          {:halt, {%{run | refusal: {code, message}}, measured}}
      end
    end)
    |> elem(0)
  end

  defp measured_outcome({:ok, outcome}, {mutant, selection}, _facts, _config, _sources, _ports),
    do: {:ok, SharedRun.attribute(outcome, mutant, selection)}

  defp measured_outcome(:error, {mutant, selection}, facts, config, sources, ports),
    do: mutant_outcome(mutant, selection, facts, config, sources, ports)

  defp measured(measured, nil, _outcome), do: measured
  defp measured(measured, key, outcome), do: Map.put_new(measured, key, outcome)

  @doc false
  # Step 9 for one mutant (journal, write, run, restore), shared with the
  # replay (DND-5485).
  @spec mutant_outcome(Mutant.t(), Run.selection(), map(), term(), map(), map()) ::
          {:ok, map()} | {:refuse, pos_integer(), String.t()}
  def mutant_outcome(mutant, {:none, []} = selection, _facts, config, _sources, _ports) do
    looked =
      TestSelection.mirror_path(mutant, config.test_mirror) || "(no test_mirror rule matches)"

    {:ok, outcome(mutant, :no_tests, [], selection, looked)}
  end

  def mutant_outcome(
        %Mutant{} = mutant,
        {_source, tests} = selection,
        facts,
        config,
        sources,
        ports
      ) do
    {:ok, original} = Map.fetch!(sources, mutant.file)
    mutated = Patch.apply_range(original, mutant.range, mutant.replacement)
    entry = Journal.entry(mutant.file, mutant.id, original, mutated)

    case ports.patcher.write_journal(facts.root, entry) do
      :ok ->
        applied(mutant, selection, entry, mutated, tests, facts, config, ports)

      {:error, :eexist} ->
        {:refuse, 2,
         "#{Journal.path()} already exists: another sabotage run is applying a mutant, so " <>
           "this one stops before writing anything. Fix: let that run finish, or, if none is " <>
           "running, run mix anchor.sabotage restore"}

      {:error, posix} ->
        {:refuse, 2,
         "could not write #{Journal.path()} (#{inspect(posix)}); no mutant was written. " <>
           "Fix: make .anchor/sabotage/ writable"}
    end
  end

  # The restore is in `after`: it runs when the test run raises or throws.
  # A restore that fails throws, which ends the whole run, journal kept.
  defp applied(mutant, selection, entry, mutated, tests, facts, config, ports) do
    path = Path.join(facts.root, mutant.file)

    try do
      try do
        with :ok <- ports.patcher.write_file(path, mutated),
             :ok <- ports.patcher.touch_ahead(path) do
          test_run(tests, facts, config, ports)
        else
          {:error, posix} -> {:mutant_not_written, posix}
        end
      after
        restore!(path, entry, facts.root, ports.patcher)
      end
    rescue
      error ->
        {:ok,
         outcome(
           mutant,
           :crashed,
           [],
           selection,
           "the test run raised: " <> Exception.message(error)
         )}
    catch
      :throw, {@restore_failed, file, :restore} -> {:refuse, 2, restore_failed_message(file)}
      :throw, {@restore_failed, _file, :journal} -> {:refuse, 2, journal_not_deleted()}
    else
      {:ok, %TestRun{} = test_run} ->
        {status, killers} = Outcome.classify(test_run)
        outcome = outcome(mutant, status, killers, selection, Outcome.reason(test_run))
        {:ok, Map.put(outcome, :test_run, test_run)}

      {:error, reason} ->
        {:refuse, TestRunRefusal.code(reason), TestRunRefusal.message(reason)}

      {:mutant_not_written, posix} ->
        {:refuse, 2,
         "could not write the mutant into #{mutant.file} (#{inspect(posix)}); the original " <>
           "was written back. Fix: make #{mutant.file} writable"}
    end
  end

  defp journal_not_deleted do
    "the original is back, but #{Journal.path()} could not be deleted, so the run stops. " <>
      "Fix: delete #{Journal.path()}"
  end

  # Any failure here, a raise included, is a throw: the outer `rescue` must
  # never read a failed restore as the mutant's own outcome.
  defp restore!(path, entry, root, patcher) do
    verdict =
      try do
        restored(path, entry, root, patcher)
      rescue
        _error -> :restore
      end

    if verdict != :ok, do: throw({@restore_failed, entry.file, verdict})
  end

  defp restored(path, entry, root, patcher) do
    with :ok <- patcher.write_file(path, entry.original),
         :ok <- patcher.touch_ahead(path),
         {:ok, sha} when sha == entry.original_sha <- patcher.sha256_file(path) do
      if patcher.delete_journal(root) == :ok, do: :ok, else: :journal
    else
      _failed -> :restore
    end
  end

  defp outcome(mutant, status, killers, selection, reason),
    do: %{mutant: mutant, status: status, killers: killers, selection: selection, reason: reason}

  @doc false
  # One bounded test run, shared with the replay (DND-5485).
  @spec test_run([String.t()], map(), term(), map()) :: {:ok, TestRun.t()} | {:error, term()}
  def test_run(tests, facts, config, %{tests: runner}) do
    runner.run(config.test_command, tests,
      cd: facts.root,
      results_path: build_path(facts, "results.bin"),
      timeout_seconds: config.timeout_seconds
    )
  end

  # -- DND-5483: the survivors list -------------------------------------------

  # The mutants --only left out (neither planned nor past the cap).
  defp not_selected(mutants, plan) do
    kept = MapSet.new(plan.planned ++ plan.not_run, & &1.id)
    Enum.reject(mutants, &MapSet.member?(kept, &1.id))
  end

  defp mfa(%{module: module, name: name, arity: arity}), do: "#{inspect(module)}.#{name}/#{arity}"

  defp survivor_notes(nil), do: []
  defp survivor_notes(%{notes: notes}), do: notes

  # A dry run applies nothing, so it judges nothing.
  defp survivors_list(%{dry_run: true}, _config, _ports), do: {:ok, nil}

  defp survivors_list(facts, config, ports) do
    path = config.survivors || Survivors.default_path()
    base = Map.get(facts, :base, @default_base)

    with {:ok, entries, notes} <- read_survivors(facts.root, path, config.survivors, ports),
         {:ok, base_lines} <- base_survivors(facts.root, base, path, ports) do
      {:ok, %{path: path, base: base, entries: entries, base_lines: base_lines, notes: notes}}
    end
  end

  defp read_survivors(root, path, named, %{baseline_store: store}) do
    case store.read(root, path) do
      {:ok, lines} ->
        parsed_survivors(path, Survivors.parse(lines))

      {:error, :enoent} when is_nil(named) ->
        {:ok, [], ["no survivors file at #{path}: every survivor is NEW"]}

      {:error, :enoent} ->
        {:refuse, 1,
         "survivors file #{path} not found. Fix: create it (it may be empty) or remove " <>
           "sabotage.survivors"}

      {:error, reason} ->
        {:refuse, 3,
         "COULD NOT MEASURE: the survivors file #{path} cannot be read (#{inspect(reason)}). " <>
           "Fix: make #{path} a readable UTF-8 file inside the project, with no symlink on its path"}
    end
  end

  defp parsed_survivors(_path, {:ok, entries}), do: {:ok, entries, []}

  defp parsed_survivors(path, {:error, errors}) do
    named = Enum.map_join(errors, "\n", fn {n, message} -> "  entry #{n}: #{message}" end)

    {:refuse, 1,
     "survivors file #{path} is malformed; nothing was run:\n" <>
       named <>
       "\nFix: write each entry as `<id> <file> <Module.fun/arity> <operator>  # <reason>`, " <>
       "one per id, with a real reason"}
  end

  defp base_survivors(root, base, path, %{git_base: git_base}) do
    case git_base.show(root, base, path) do
      {:ok, lines} ->
        {:ok, lines}

      {:error, :absent} ->
        {:ok, :absent}

      {:error, reason} ->
        {:refuse, 3,
         "COULD NOT MEASURE: the survivors file #{path} cannot be read at #{base} " <>
           "(#{inspect(reason)}), so what this branch adds to it cannot be shown. " <>
           "Fix: fetch #{base}, or pass --base with a ref that resolves"}
    end
  end

  defp judge_survivors(run, nil), do: run
  defp judge_survivors(%Run{refusal: {_code, _message}} = run, _list), do: run

  defp judge_survivors(run, list) do
    %{
      run
      | survivors: %{
          path: list.path,
          base: list.base,
          judgement: Survivors.judge(run, list.entries),
          grew: Survivors.grew(list.entries, list.base_lines)
        }
    }
  end

  # -- DND-5484: records ------------------------------------------------------

  # The records already there: their kill maps (for selection) and their
  # names (for create vs append, and NN).
  defp existing_records(root, config, %{records: store}) do
    paths = store.list(root, Record.dir_glob(config.records))

    {rows, notes} =
      Enum.reduce(paths, {[], []}, fn path, {rows, notes} ->
        case kill_rows(store, root, path) do
          {:ok, more} -> {rows ++ more, notes}
          {:error, note} -> {rows, notes ++ [note]}
        end
      end)

    kill_map =
      rows
      |> KillMap.killers_by_function()
      |> Map.new(fn {mfa, killers} ->
        {mfa, killers |> Enum.map(&KillMap.killer_file/1) |> Enum.uniq()}
      end)

    names = Enum.group_by(paths, &Path.dirname/1, &Path.basename/1)
    {:ok, %{kill_map: kill_map, names: names, notes: notes}}
  end

  defp kill_rows(store, root, path) do
    with {:read, {:ok, text}} <- {:read, store.read(root, path)},
         {:parse, {:ok, rows}} <- {:parse, KillMap.parse(text)} do
      {:ok, rows}
    else
      {:read, {:error, posix}} ->
        {:error, "could not read kill map in #{path} (#{inspect(posix)}); not used for selection"}

      {:parse, {:error, {line, message}}} ->
        {:error,
         "could not read kill map in #{path}:#{line} (#{message}); not used for selection"}
    end
  end

  # Everything a record needs, checked before any mutant is applied.
  defp recording(%{no_record: true}, _config, _scope, _run, _plan, _records, _ports),
    do: {:ok, nil}

  # A dry run writes nothing, so it needs nothing a record needs.
  defp recording(%{dry_run: true}, _config, _scope, _run, _plan, _records, _ports),
    do: {:ok, nil}

  # No mutant will run, so nothing is measured and no record is written.
  defp recording(_facts, _config, _scope, _run, %{planned: []}, _records, _ports),
    do: {:ok, nil}

  defp recording(facts, config, scope, run, plan, records, ports) do
    cfg = config.records

    with :ok <- name_overrides(facts),
         {:ok, branch} <- branch(facts.root, ports),
         {:ok, slot} <- record_slot(branch, facts),
         :ok <- ticket_for(cfg, slot),
         :ok <- apps_for(cfg, record_files(run, plan)) do
      {:ok,
       %{
         records: cfg,
         date: DateTime.to_date(facts.now),
         time: Calendar.strftime(facts.now, "%H:%M"),
         branch: branch,
         slot: slot,
         base_sha: scope.base_sha,
         head_sha: head_sha(facts.root, ports),
         command: Map.get(facts, :command, "mix anchor.sabotage run"),
         version: Map.get(facts, :version, "unknown"),
         test_command: config.test_command,
         domain: Map.get(facts, :domain),
         changed_tests: changed_tests(facts.root, scope, ports),
         existing: records.names
       }}
    end
  end

  defp branch(root, %{git: git}) do
    case git.branch(root) do
      {:ok, branch} -> {:ok, branch}
      {:error, reason} -> {:refuse, 3, Failures.scope_could_not_measure(reason)}
    end
  end

  defp record_slot(branch, facts) do
    opts = [ticket: Map.get(facts, :ticket), slot: Map.get(facts, :slot)]

    case RecordNaming.slot(branch, opts) do
      {:ok, slot} ->
        {:ok, slot}

      {:error, :no_branch} ->
        {:refuse, 2,
         "HEAD is detached, so the sabotage record has no slot to be named by. " <>
           "Fix: pass --slot S (or --ticket KEY), or --no-record"}
    end
  end

  # --domain and --ticket become part of a file name: only a name, never a path.
  defp name_overrides(facts) do
    domain = Map.get(facts, :domain)
    ticket = Map.get(facts, :ticket)

    cond do
      is_binary(domain) and (domain == "" or RecordNaming.sanitize(domain) != domain) ->
        {:refuse, 2,
         "--domain #{inspect(domain)} must be letters, digits and _ only. " <>
           "Fix: pass a domain such as sabotage or call_tracer"}

      is_binary(ticket) and RecordNaming.ticket_key(ticket) != ticket ->
        {:refuse, 2,
         "--ticket #{inspect(ticket)} is not a ticket key. Fix: pass one such as DND-123"}

      true ->
        :ok
    end
  end

  defp ticket_for(%{naming: :ticket_nn_what}, %{ticket: nil}),
    do:
      {:refuse, 2,
       "records are named <TICKET>-<NN>-..., but the branch names no ticket key. " <>
         "Fix: pass --ticket DND-NNN"}

  defp ticket_for(_cfg, _slot), do: :ok

  defp record_files(run, plan) do
    Enum.map(plan.planned ++ plan.not_run ++ run.skipped, & &1.file) ++
      Enum.map(run.errors, fn {function, _reason} -> function.file end)
  end

  defp apps_for(cfg, files) do
    case Enum.find(files, &(RecordNaming.dir(cfg, RecordNaming.app_for(&1)) == {:error, :no_app})) do
      nil ->
        :ok

      file ->
        {:refuse, 2,
         "records.dir #{cfg.dir} holds {app}, but #{file} is not under apps/<app>/. " <>
           "Fix: set records.dir without {app}"}
    end
  end

  defp head_sha(root, %{git: git}) do
    case git.head_sha(root) do
      {:ok, sha} -> sha
      {:error, _reason} -> nil
    end
  end

  # The tests the diff touched; a test file that cannot be read or parsed
  # adds none (its tests are then not listed as lacking a red).
  defp changed_tests(root, scope, %{change: change}) do
    scope.test_changes
    |> Enum.sort()
    |> Enum.flat_map(fn {path, ranges} ->
      with {:ok, text} <- change.read(root, path),
           {:ok, tests} <- ChangedTests.in_ranges(text, path, ranges) do
        tests
      else
        _unreadable -> []
      end
    end)
  end

  defp write_records(run, nil, _root, _ports), do: run
  defp write_records(%Run{refusal: {_code, _message}} = run, _ctx, _root, _ports), do: run

  defp write_records(run, ctx, root, %{records: store}) do
    case Record.render(run, ctx) do
      {:ok, entries} ->
        Enum.reduce_while(entries, run, fn entry, run ->
          case write_entry(store, root, entry, ctx) do
            {:ok, written} -> {:cont, %{run | records: run.records ++ [written]}}
            {:error, message} -> {:halt, %{run | record_error: message}}
          end
        end)

      {:error, {reason, file}} ->
        %{run | record_error: "could not name the sabotage record of #{file} (#{reason})"}
    end
  end

  defp write_entry(store, root, %{mode: :append, path: path, content: content}, _ctx) do
    case store.append(root, path, content) do
      :ok -> {:ok, {:append, path}}
      {:error, posix} -> {:error, not_written(path, posix)}
    end
  end

  defp write_entry(store, root, %{mode: :create, path: path, content: content}, ctx) do
    case store.create(root, path, content) do
      :ok -> {:ok, {:create, path}}
      {:error, :eexist} -> renumbered(store, root, path, content, ctx)
      {:error, posix} -> {:error, not_written(path, posix)}
    end
  end

  # A ticket-numbered name another run took meanwhile: the next number,
  # once. Any other name that exists is never overwritten.
  defp renumbered(store, root, path, content, %{records: %{naming: :ticket_nn_what}} = ctx) do
    dir = Path.dirname(path)
    names = store.list(root, dir) |> Enum.map(&Path.basename/1)
    naming = %{domain: nil, app: nil, date: ctx.date, slot: ctx.slot, existing_names: names}
    {:ok, retry} = RecordNaming.path(%{ctx.records | dir: dir}, naming)

    case store.create(root, retry, content) do
      :ok -> {:ok, {:create, retry}}
      {:error, posix} -> {:error, not_written(retry, posix)}
    end
  end

  defp renumbered(_store, _root, path, _content, _ctx), do: {:error, not_written(path, :eexist)}

  defp not_written(path, posix),
    do:
      "could not write the sabotage record #{path} (#{inspect(posix)}); nothing was " <>
        "overwritten. Fix: check #{Path.dirname(path)} is writable, then rerun"

  # A refused run is not saved: DND-5483 and DND-5484 read only finished runs. A
  # finished run is saved after its records are written, so it names them.
  defp save(%Run{refusal: {_code, _message}} = run, _facts, _ports), do: run

  defp save(run, facts, %{patcher: patcher}) do
    path = build_path(facts, "last-run.etf")

    case patcher.save_run(path, :erlang.term_to_binary(run)) do
      :ok -> run
      {:error, posix} -> note(run, "could not save #{path} (#{inspect(posix)})")
    end
  end

  # DND-5654: under the build path the task gathered, as last-run.etf is.
  defp build_path(%{build_path: build_path}, name),
    do: Path.join([build_path, "anchor", "sabotage", name])
end
