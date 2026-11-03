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
       `:parse_error` or `:unreadable` is exit 3.
    7. `Plan.build/2` (order, `--only`, cap), then `TestSelection.select/2`
       per mutant. `--dry-run` stops here: it writes no mutant (step 1 may
       still have restored a leftover one).
    8. The baseline: the union of the selected tests, run once with no
       mutant. Anything but a pass is exit 3 (COULD NOT MEASURE).
    9. Each planned mutant, one at a time: with no selected test it is
       `no_tests` and nothing is written; else journal, write the mutant,
       touch, run its tests (bounded by `timeout`), and in an `after` block
       write the original back, touch, check its sha256 and only then delete
       the journal. A restore that does not reproduce the original stops the
       run (exit 2) with the journal kept.
   10. The run is saved to `_build/<env>/anchor/sabotage/last-run.etf`.

  The exit code is `Anchor.Domain.Sabotage.Report`'s (DND-5570): the Runner
  only sets `Run.changed_functions` (the scope's count, `0` for a good diff
  read that found none) and classifies a raised test run as `:crashed`.

  The `after` block runs on an exception and a throw; a VM kill skips it, and
  the journal covers that on the next run.

  ## Adapters (options)

  `:config_loader` (`Anchor.Adapters.ConfigFile`), `:change_source`
  (`Anchor.Adapters.GitChangeSource`), `:source_mutation`
  (`Anchor.Adapters.SourcePatcher`), `:git_worktree`
  (`Anchor.Adapters.GitStatus`), `:test_execution`
  (`Anchor.Adapters.TestRunner`).
  """

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Adapters.GitStatus
  alias Anchor.Adapters.SourcePatcher
  alias Anchor.Adapters.TestRunner
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.Plan
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.Domain.Sabotage.TestSelection
  alias Anchor.Managers.Sabotage

  @default_base "origin/main"
  @restore_failed :anchor_sabotage_restore_failed

  @spec run(map(), keyword()) :: Run.t()
  def run(%{root: root} = facts, opts) do
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
  defp locked(run, root, %{patcher: patcher}, body) do
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
         {:ok, plan} <- plan(mutants, facts, config) do
      run = %{run | not_run: plan.not_run}
      planned = Enum.zip(plan.planned, select(plan.planned, root, config, ports))

      if Map.get(facts, :dry_run, false),
        do: %{run | dry_run: true, planned: planned},
        else: measure(run, facts, config, sources, planned, ports)
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
      opts: opts
    }
  end

  # -- 1. the leftover journal -------------------------------------------------

  defp recover(run, root, %{patcher: patcher}) do
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

  defp config(root, %{config: loader}) do
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

  defp journal_ignored(root, %{git: git}) do
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

    run = %{
      run
      | changed_functions: length(scope.functions),
        errors: errors,
        skipped: Enum.flat_map(oks, & &1.skipped)
    }

    if results != [] and oks == [] and Enum.all?(errors, &unmeasured?/1),
      do: {:refuse, run, 3, could_not_read(errors)},
      else: {:ok, run, sources, Enum.flat_map(oks, & &1.mutants)}
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

  defp select(planned, root, config, %{patcher: patcher}) do
    candidates =
      planned
      |> Enum.map(&TestSelection.mirror_path(&1, config.test_mirror))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    existing =
      candidates
      |> Enum.map(&Path.join(root, &1))
      |> patcher.existing()
      |> MapSet.new(&Path.relative_to(&1, root))

    inputs = %{mirror: config.test_mirror, existing_tests: existing}
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
        |> save(facts, ports)

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
        {:refuse, runner_error_code(reason), runner_error(reason)}
    end
  end

  defp baseline_detail(%TestRun{failures: [first | _rest]}),
    do: "#{first.file}:#{first.line} #{first.name}: #{first.text}"

  defp baseline_detail(%TestRun{} = test_run),
    do: Outcome.reason(test_run) || Atom.to_string(test_run.status)

  defp timeout_missing,
    do:
      "the `timeout` binary was not found, so a test run could not be bounded. " <>
        "Fix: install coreutils timeout"

  defp mutants(run, facts, config, sources, planned, ports) do
    Enum.reduce_while(planned, run, fn {mutant, selection}, run ->
      case mutant_outcome(mutant, selection, facts, config, sources, ports) do
        {:ok, outcome} -> {:cont, %{run | outcomes: run.outcomes ++ [outcome]}}
        {:refuse, code, message} -> {:halt, %{run | refusal: {code, message}}}
      end
    end)
  end

  defp mutant_outcome(mutant, {:none, []} = selection, _facts, config, _sources, _ports) do
    looked =
      TestSelection.mirror_path(mutant, config.test_mirror) || "(no test_mirror rule matches)"

    {:ok, outcome(mutant, :no_tests, [], selection, looked)}
  end

  defp mutant_outcome(
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
        {:ok, outcome(mutant, status, killers, selection, Outcome.reason(test_run))}

      {:error, reason} ->
        {:refuse, runner_error_code(reason), runner_error(reason)}

      {:mutant_not_written, posix} ->
        {:refuse, 2,
         "could not write the mutant into #{mutant.file} (#{inspect(posix)}); the original " <>
           "was written back. Fix: make #{mutant.file} writable"}
    end
  end

  defp runner_error_code(:timeout_not_found), do: 2
  defp runner_error_code({:results_not_removed, _path, _posix}), do: 3
  defp runner_error_code({:results_dir_not_created, _dir, _posix}), do: 3

  defp runner_error(:timeout_not_found), do: timeout_missing()

  defp runner_error({:results_not_removed, path, posix}) do
    "COULD NOT MEASURE: the previous results file #{path} could not be removed " <>
      "(#{inspect(posix)}), so a test run's failures could be an earlier run's. " <>
      "Fix: remove #{path} by hand"
  end

  defp runner_error({:results_dir_not_created, dir, posix}) do
    "COULD NOT MEASURE: the results directory #{dir} could not be made " <>
      "(#{inspect(posix)}), so no test run's failures can be read. Fix: make #{dir} " <>
      "(or its parent) a writable directory"
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

  defp test_run(tests, facts, config, %{tests: runner}) do
    runner.run(config.test_command, tests,
      cd: facts.root,
      results_path: build_path(facts, "results.bin"),
      timeout_seconds: config.timeout_seconds
    )
  end

  # A refused run is not saved: DND-5483 and DND-5484 read only finished runs.
  defp save(%Run{refusal: {_code, _message}} = run, _facts, _ports), do: run

  defp save(run, facts, %{patcher: patcher}) do
    path = build_path(facts, "last-run.etf")

    case patcher.save_run(path, :erlang.term_to_binary(run)) do
      :ok -> run
      {:error, posix} -> note(run, "could not save #{path} (#{inspect(posix)})")
    end
  end

  defp build_path(facts, name),
    do:
      Path.join([
        facts.root,
        "_build",
        to_string(Map.get(facts, :env, :dev)),
        "anchor",
        "sabotage",
        name
      ])
end
