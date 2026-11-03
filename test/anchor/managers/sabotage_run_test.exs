defmodule Anchor.Managers.SabotageRunTest do
  # Manager tests for `Anchor.Managers.Sabotage.run/2` and `restore/2`
  # (DND-5473), every adapter doubled by Hammox `expect/3`, which
  # self-verifies: a call the test does not expect fails it, so "no write" is
  # proven by not expecting one. Each double reports its call to the test
  # process, so the order of calls is asserted, not assumed.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  # Sabotage record (DND-5617): ../../sabotage_records/sabotage-20261103-dnd_5617_sabotage_cfa_batch.md
  # Sabotage record (DND-5624): ../../sabotage_records/sabotage-20261103-dnd_5624_sabotage_defimpl.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.GitWorktreeMock
  alias Anchor.Managers.Sabotage
  alias Anchor.SourceMutationMock
  alias Anchor.TestExecutionMock

  setup :verify_on_exit!

  # The run lock is taken and released on every run: stubbed here, and
  # asserted (with expect/3, which a stub never satisfies) in its own describe.
  setup do
    stub(SourceMutationMock, :take_lock, fn "/repo" -> :ok end)
    stub(SourceMutationMock, :release_lock, fn "/repo" -> :ok end)
    :ok
  end

  @root "/repo"
  @file_path "/repo/lib/calc.ex"
  @facts %{root: @root, env: :test, base: "origin/main", max: nil, only: [], dry_run: false}
  @opts [
    config_loader: ConfigLoaderMock,
    change_source: ChangeSourceMock,
    source_mutation: SourceMutationMock,
    git_worktree: GitWorktreeMock,
    test_execution: TestExecutionMock
  ]
  @source "defmodule Calc do\n  def add(a, b) do\n    a + b\n  end\nend\n"
  @diff "diff --git a/lib/calc.ex b/lib/calc.ex\nindex 1..2 100644\n--- a/lib/calc.ex\n+++ b/lib/calc.ex\n@@ -3 +3 @@\n-old\n+new\n"
  @killer %{file: "test/calc_test.exs", line: 4, name: "test adds", text: "Assertion failed"}

  defp mutants do
    {:ok, %{mutants: mutants}} = Mutator.generate(@source, "lib/calc.ex", {Calc, :add, 2})
    Enum.sort_by(mutants, & &1.id)
  end

  defp mutated(mutant), do: Patch.apply_range(@source, mutant.range, mutant.replacement)

  defp test_run(status, failures \\ []),
    do:
      {:ok, %TestRun{status: status, total: 2, failures: failures, exit_code: 0, output_head: ""}}

  defp call(name, result) do
    send(self(), {:call, name})
    result
  end

  defp calls(acc \\ []) do
    receive do
      {:call, name} -> calls([name | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp expect_journal({:ok, _entry} = result) do
    expect(SourceMutationMock, :read_journal, fn @root -> call(:read_journal, result) end)
    expect(SourceMutationMock, :owner_alive?, fn _owner -> false end)
  end

  defp expect_journal(result),
    do: expect(SourceMutationMock, :read_journal, fn @root -> call(:read_journal, result) end)

  defp expect_config(sabotage \\ %SabotageConfig{}) do
    expect(ConfigLoaderMock, :load_in, fn @root ->
      call(:config, {:ok, %Anchor.Config{rules: [], sabotage: sabotage}})
    end)
  end

  defp expect_ignored(answer \\ true),
    do:
      expect(GitWorktreeMock, :ignored?, fn @root, ".anchor/sabotage/in-flight.json" ->
        {:ok, answer}
      end)

  defp expect_scope(reads \\ 2) do
    expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" ->
      call(:scope, {:ok, "abc"})
    end)

    expect(ChangeSourceMock, :diff, fn @root, "abc" -> {:ok, @diff} end)
    expect(ChangeSourceMock, :untracked, fn @root -> {:ok, []} end)
    expect(ChangeSourceMock, :read, reads, fn @root, "lib/calc.ex" -> {:ok, @source} end)
    expect(ChangeSourceMock, :show, fn @root, "abc", "lib/calc.ex" -> {:ok, @source} end)
  end

  defp expect_clean(dirty \\ []),
    do: expect(GitWorktreeMock, :dirty_paths, fn @root, ["lib/calc.ex"] -> {:ok, dirty} end)

  defp expect_tests_exist(exist?) do
    expect(SourceMutationMock, :existing, fn ["/repo/test/calc_test.exs"] = paths ->
      if exist?, do: paths, else: []
    end)
  end

  defp expect_until_selection(opts \\ []) do
    expect_journal(:none)
    expect_config(Keyword.get(opts, :config, %SabotageConfig{}))
    expect_ignored()
    expect_scope()
    expect_clean()
    expect_tests_exist(Keyword.get(opts, :tests?, true))
  end

  defp expect_baseline(result) do
    expect(TestExecutionMock, :run, fn ["mix", "test", "--max-cases", "2"],
                                       ["test/calc_test.exs"],
                                       opts ->
      assert opts[:cd] == @root
      assert opts[:timeout_seconds] == 300
      assert opts[:results_path] == "/repo/_build/test/anchor/sabotage/results.bin"
      call(:baseline, result)
    end)
  end

  # The patcher for N applied mutants: every call reported, the restore's
  # sha256 the original's unless `restored_sha` says otherwise.
  defp expect_patcher(n, restored_sha \\ Journal.sha256(@source)) do
    expect(SourceMutationMock, :write_journal, n, fn @root, %Journal{} = entry ->
      call({:write_journal, entry.mutant_id}, :ok)
    end)

    expect(SourceMutationMock, :write_file, 2 * n, fn @file_path, bytes ->
      call({:write_file, if(bytes == @source, do: :original, else: :mutated)}, :ok)
    end)

    expect(SourceMutationMock, :touch_ahead, 2 * n, fn @file_path -> call(:touch_ahead, :ok) end)

    expect(SourceMutationMock, :sha256_file, n, fn @file_path ->
      call(:sha256_file, {:ok, restored_sha})
    end)
  end

  defp expect_delete_journal(n \\ 1),
    do: expect(SourceMutationMock, :delete_journal, n, fn @root -> call(:delete_journal, :ok) end)

  defp expect_save do
    expect(SourceMutationMock, :save_run, fn "/repo/_build/test/anchor/sabotage/last-run.etf",
                                             bytes ->
      assert %Anchor.Domain.Sabotage.Run{} = :erlang.binary_to_term(bytes)
      :ok
    end)
  end

  defp leftover do
    [mutant | _rest] = mutants()
    Journal.entry("lib/calc.ex", mutant.id, @source, mutated(mutant))
  end

  describe "run/2: a leftover journal" do
    test "1: the mutant still in place is restored and the journal deleted before any scope call" do
      entry = leftover()
      expect_journal({:ok, entry})

      expect(SourceMutationMock, :sha256_file, 2, fn @file_path ->
        sha = if calls_seen(:write_file), do: entry.original_sha, else: entry.mutated_sha
        call(:sha256_file, {:ok, sha})
      end)

      expect(SourceMutationMock, :write_file, fn @file_path, @source -> call(:write_file, :ok) end)

      expect(SourceMutationMock, :touch_ahead, fn @file_path -> call(:touch_ahead, :ok) end)
      expect_delete_journal()
      expect_config(nil)

      run = Sabotage.run(@facts, @opts)

      assert calls() == [
               :read_journal,
               :sha256_file,
               :write_file,
               :touch_ahead,
               :sha256_file,
               :delete_journal,
               :config
             ]

      assert run.notes == ["restored leftover mutant #{entry.mutant_id} in lib/calc.ex"]
      assert Report.render(run) =~ "restored leftover mutant #{entry.mutant_id} in lib/calc.ex\n"
      assert {3, "COULD NOT MEASURE: .anchor.yml has no sabotage: section." <> _} = run.refusal
    end

    test "2: a file already back to the original only loses the journal: no write" do
      entry = leftover()
      expect_journal({:ok, entry})
      expect(SourceMutationMock, :sha256_file, fn @file_path -> {:ok, entry.original_sha} end)
      expect_delete_journal()
      expect_config(nil)

      run = Sabotage.run(@facts, @opts)

      assert [note] = run.notes
      assert note =~ "lib/calc.ex was already restored"
    end

    test "3: a file that matches neither hash refuses the run, exit 2: no write, no test run" do
      entry = leftover()
      expect_journal({:ok, entry})

      expect(SourceMutationMock, :sha256_file, fn @file_path ->
        {:ok, Journal.sha256("edited")}
      end)

      run = Sabotage.run(@facts, @opts)

      assert Report.exit_code(run) == 2
      assert {2, message} = run.refusal
      assert message =~ "lib/calc.ex changed since mutant"

      assert message =~
               "Fix: git diff lib/calc.ex, restore it by hand, then delete .anchor/sabotage/in-flight.json"
    end

    test "a recovery restore that does not reproduce the original keeps the journal, exit 2" do
      entry = leftover()
      expect_journal({:ok, entry})

      expect(SourceMutationMock, :sha256_file, 2, fn @file_path ->
        if calls_seen(:write_file),
          do: {:ok, Journal.sha256("still wrong")},
          else: {:ok, entry.mutated_sha}
      end)

      expect(SourceMutationMock, :write_file, fn @file_path, @source -> call(:write_file, :ok) end)

      expect(SourceMutationMock, :touch_ahead, fn @file_path -> :ok end)

      assert %{refusal: {2, message}, notes: []} = Sabotage.run(@facts, @opts)

      assert message =~
               "the restore of lib/calc.ex did not reproduce the original; the journal is kept"
    end

    test "a recovery restore whose write fails keeps the journal, exit 2" do
      entry = leftover()
      expect_journal({:ok, entry})
      expect(SourceMutationMock, :sha256_file, fn @file_path -> {:ok, entry.mutated_sha} end)
      expect(SourceMutationMock, :write_file, fn @file_path, @source -> {:error, :eacces} end)

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "the journal is kept. Fix: mix anchor.sabotage restore"
    end

    test "a leftover journal whose file cannot be read refuses the run, exit 2: no write" do
      entry = leftover()
      expect_journal({:ok, entry})
      expect(SourceMutationMock, :sha256_file, fn @file_path -> {:error, :enoent} end)

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)

      assert message =~
               "lib/calc.ex changed since mutant #{entry.mutant_id} was applied (it cannot be read (:enoent))"
    end

    test "a discard whose journal cannot be deleted refuses the run, exit 2" do
      entry = leftover()
      expect_journal({:ok, entry})
      expect(SourceMutationMock, :sha256_file, fn @file_path -> {:ok, entry.original_sha} end)
      expect(SourceMutationMock, :delete_journal, fn @root -> {:error, :eacces} end)

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "could not delete .anchor/sabotage/in-flight.json (:eacces)"
    end

    test "a journal whose owner is a live run is not a leftover: exit 2, nothing touched" do
      entry = %{leftover() | owner: %{os_pid: 4242, started: "777"}}

      expect(SourceMutationMock, :read_journal, fn @root -> {:ok, entry} end)

      expect(SourceMutationMock, :owner_alive?, fn %{os_pid: 4242, started: "777"} -> true end)

      assert %{refusal: {2, message}, notes: []} = Sabotage.run(@facts, @opts)
      assert message =~ "another sabotage run (OS pid 4242) is applying mutant #{entry.mutant_id}"
      assert message =~ "nothing was touched. Fix: let that run finish, then rerun"
    end

    test "a journal that cannot be decoded refuses the run, exit 2" do
      expect_journal({:error, :corrupt_journal})

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ ".anchor/sabotage/in-flight.json cannot be read"
    end
  end

  describe "run/2: refusals" do
    test "4: a journal path git does not ignore refuses the run, exit 2; no test runs" do
      expect_journal(:none)
      expect_config()
      expect_ignored(false)

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "Fix: add .anchor/sabotage/in-flight.json to .gitignore"
    end

    test "5: a dirty target file refuses the run, exit 2, naming it; no write" do
      expect_journal(:none)
      expect_config()
      expect_ignored()
      expect_scope(1)
      expect_clean(["lib/calc.ex"])

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "uncommitted changes in lib/calc.ex"
      assert message =~ "Fix: commit (or stash) lib/calc.ex, then rerun"
    end

    test "6: a failing baseline is COULD NOT MEASURE, exit 3; no mutant written" do
      expect_until_selection()
      expect_baseline(test_run(:failed, [@killer]))

      run = Sabotage.run(@facts, @opts)

      assert Report.exit_code(run) == 3

      assert {3,
              "COULD NOT MEASURE: the selected tests fail with no mutant applied " <>
                "(test/calc_test.exs:4 test adds: Assertion failed). Fix: make them pass first"} =
               run.refusal
    end

    test "a missing sabotage: section is exit 3 with the README Fix" do
      expect_journal(:none)
      expect_config(nil)

      assert %{refusal: {3, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "Fix: add a sabotage: section (see README, Sabotage)"
    end

    test "a missing `timeout` binary refuses the run, exit 2" do
      expect_until_selection()
      expect_baseline({:error, :timeout_not_found})

      assert %{refusal: {2, message}} = Sabotage.run(@facts, @opts)
      assert message =~ "Fix: install coreutils timeout"
    end

    test "--only with an id the run does not have refuses, exit 2" do
      expect_journal(:none)
      expect_config()
      expect_ignored()
      expect_scope()
      expect_clean()

      assert %{refusal: {2, message}} = Sabotage.run(%{@facts | only: ["000000000000"]}, @opts)
      assert message =~ "--only names a mutant this run does not have: 000000000000"
    end
  end

  describe "run/2: the mutants" do
    test "7: per mutant: journal, mutant, touch, tests, original, touch, sha, delete; killed then survived, exit 1" do
      [first, second] = mutants()
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(2)
      expect_delete_journal(2)
      expect_save()

      expect(TestExecutionMock, :run, 2, fn _argv, ["test/calc_test.exs"], _opts ->
        if calls_seen({:write_journal, second.id}),
          do: call(:tests, test_run(:passed)),
          else: call(:tests, test_run(:failed, [@killer]))
      end)

      run = Sabotage.run(@facts, @opts)

      per_mutant = fn id ->
        [
          {:write_journal, id},
          {:write_file, :mutated},
          :touch_ahead,
          :tests,
          {:write_file, :original},
          :touch_ahead,
          :sha256_file,
          :delete_journal
        ]
      end

      assert calls() ==
               [:read_journal, :config, :scope, :baseline] ++
                 per_mutant.(first.id) ++ per_mutant.(second.id)

      assert Enum.map(run.outcomes, &{&1.mutant.id, &1.status}) == [
               {first.id, :killed},
               {second.id, :survived}
             ]

      assert hd(run.outcomes).killers == [{"test/calc_test.exs", 4, "test adds"}]
      assert hd(run.outcomes).selection == {:mirror, ["test/calc_test.exs"]}
      assert run.baseline == :passed
      assert Report.exit_code(run) == 1
    end

    test "8: a test run that raises still restores the file and deletes the journal; the error is reported" do
      [first, second] = mutants()
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(2)
      expect_delete_journal(2)
      expect_save()

      expect(TestExecutionMock, :run, 2, fn _argv, _tests, _opts ->
        if calls_seen({:write_journal, second.id}),
          do: test_run(:failed, [@killer]),
          else: raise("runner exploded")
      end)

      run = Sabotage.run(@facts, @opts)

      assert [
               {:write_journal, _},
               {:write_file, :mutated},
               :touch_ahead,
               {:write_file, :original},
               :touch_ahead,
               :sha256_file,
               :delete_journal | _rest
             ] =
               Enum.drop(calls(), 4)

      assert [
               %{status: :crashed, reason: "the test run raised: runner exploded"},
               %{status: :killed}
             ] =
               run.outcomes

      assert hd(run.outcomes).mutant.id == first.id
    end

    test "9: a restore whose hash differs stops the run, exit 2: the journal is kept, no further mutant" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(1, Journal.sha256("not the original"))
      expect(TestExecutionMock, :run, fn _argv, _tests, _opts -> test_run(:failed, [@killer]) end)

      run = Sabotage.run(@facts, @opts)

      refute :delete_journal in calls()
      assert run.outcomes == []

      assert run.refusal ==
               {2,
                "the restore of lib/calc.ex did not reproduce the original; the journal is kept. " <>
                  "Fix: mix anchor.sabotage restore"}
    end

    test "a journal already there (another run) refuses before any mutant is written, exit 2" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect(SourceMutationMock, :write_journal, fn @root, _entry -> {:error, :eexist} end)

      run = Sabotage.run(@facts, @opts)

      assert run.outcomes == []
      assert {2, message} = run.refusal
      assert message =~ "another sabotage run is applying a mutant"

      assert message =~
               "Fix: let that run finish, or, if none is running, run mix anchor.sabotage restore"
    end

    test "a journal that cannot be written refuses before any mutant is written, exit 2" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect(SourceMutationMock, :write_journal, fn @root, _entry -> {:error, :enospc} end)

      assert %{refusal: {2, message}, outcomes: []} = Sabotage.run(@facts, @opts)

      assert message =~
               "could not write .anchor/sabotage/in-flight.json (:enospc); no mutant was written"
    end

    test "a mutant that cannot be written is restored, and the run stops, exit 2" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect(SourceMutationMock, :write_journal, fn @root, _entry -> :ok end)

      expect(SourceMutationMock, :write_file, 2, fn @file_path, bytes ->
        if bytes == @source, do: call(:restored, :ok), else: {:error, :eacces}
      end)

      expect(SourceMutationMock, :touch_ahead, fn @file_path -> :ok end)

      expect(SourceMutationMock, :sha256_file, fn @file_path -> {:ok, Journal.sha256(@source)} end)

      expect_delete_journal()

      run = Sabotage.run(@facts, @opts)

      assert :restored in calls()
      assert {2, message} = run.refusal

      assert message =~
               "could not write the mutant into lib/calc.ex (:eacces); the original was written back"
    end

    test "a restore whose journal cannot be deleted stops the run, exit 2" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(1)
      expect(SourceMutationMock, :delete_journal, fn @root -> {:error, :eacces} end)
      expect(TestExecutionMock, :run, fn _argv, _tests, _opts -> test_run(:failed, [@killer]) end)

      assert %{refusal: {2, message}, outcomes: []} = Sabotage.run(@facts, @opts)

      assert message =~
               "the original is back, but .anchor/sabotage/in-flight.json could not be deleted"
    end

    test "a stale results file the runner cannot remove is COULD NOT MEASURE, exit 3" do
      expect_until_selection()
      expect_baseline({:error, {:results_not_removed, "/repo/_build/x/results.bin", :eisdir}})

      assert %{refusal: {3, message}} = Sabotage.run(@facts, @opts)

      assert message =~
               "COULD NOT MEASURE: the previous results file /repo/_build/x/results.bin could not be removed"
    end

    test "a results directory the runner cannot make is COULD NOT MEASURE, exit 3" do
      expect_until_selection()
      expect_baseline({:error, {:results_dir_not_created, "/repo/_build/x", :enotdir}})

      assert %{refusal: {3, message}} = Sabotage.run(@facts, @opts)

      assert message =~
               "COULD NOT MEASURE: the results directory /repo/_build/x could not be made (:enotdir)"
    end

    test "10: a mutant with no test selected is no_tests, and nothing is written for it" do
      expect_until_selection(tests?: false)
      expect_save()

      run = Sabotage.run(@facts, @opts)

      assert Enum.map(run.outcomes, &{&1.status, &1.reason, &1.selection}) ==
               List.duplicate({:no_tests, "test/calc_test.exs", {:none, []}}, 2)

      assert run.baseline == :none
      # Mutants were made and none could be measured: COULD NOT MEASURE.
      assert Report.exit_code(run) == 3
    end

    test "a crashed test run is crashed, and with nothing else measured the run is exit 3" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(2)
      expect_delete_journal(2)
      expect_save()

      expect(TestExecutionMock, :run, 2, fn _argv, _tests, _opts ->
        {:ok, %TestRun{status: :crashed, exit_code: 1, output_head: "boom"}}
      end)

      run = Sabotage.run(@facts, @opts)

      assert Enum.map(run.outcomes, & &1.status) == [:crashed, :crashed]
      assert Report.exit_code(run) == 3
    end

    test "a compile error is invalid, and with a killed mutant beside it the run is exit 0" do
      [first, second] = mutants()
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(2)
      expect_delete_journal(2)
      expect_save()

      expect(TestExecutionMock, :run, 2, fn _argv, _tests, _opts ->
        if calls_seen({:write_journal, second.id}),
          do: test_run(:failed, [@killer]),
          else: {:ok, %TestRun{status: :compile_error, exit_code: 1, output_head: "error: x"}}
      end)

      run = Sabotage.run(@facts, @opts)

      assert Enum.map(run.outcomes, &{&1.mutant.id, &1.status}) ==
               [{first.id, :invalid}, {second.id, :killed}]

      assert Report.exit_code(run) == 0
    end

    test "zero changed functions from a good diff read: exit 0, loud, no baseline, no write" do
      expect_journal(:none)
      expect_config()
      expect_ignored()

      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, "abc"} end)
      expect(ChangeSourceMock, :diff, fn @root, "abc" -> {:ok, ""} end)
      expect(ChangeSourceMock, :untracked, fn @root -> {:ok, []} end)
      expect(GitWorktreeMock, :dirty_paths, fn @root, [] -> {:ok, []} end)
      expect(SourceMutationMock, :existing, fn [] -> [] end)
      expect_save()

      run = Sabotage.run(@facts, @opts)

      assert run.refusal == nil
      assert run.changed_functions == 0
      assert run.outcomes == []
      assert Report.exit_code(run) == 0
      assert Report.render(run) =~ "sabotage: 0 changed functions in origin/main..HEAD"
    end

    test "a diff that could not be read stays exit 3, never the empty scope" do
      expect_journal(:none)
      expect_config()
      expect_ignored()

      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" ->
        {:error, {:no_merge_base, "origin/main"}}
      end)

      run = Sabotage.run(@facts, @opts)

      assert {3, "COULD NOT MEASURE" <> _rest} = run.refusal
      assert Report.exit_code(run) == 3
      refute Report.render(run) =~ "0 changed functions"
    end

    test "11: --dry-run writes nothing and runs no test; the plan is returned" do
      expect_until_selection()

      run = Sabotage.run(%{@facts | dry_run: true}, @opts)

      assert run.dry_run
      assert length(run.planned) == 2
      assert Report.exit_code(run) == 0
      assert Report.render(run) =~ "2 mutants planned; nothing applied"
    end

    test "the cap: --max 1 runs one mutant and lists the other as not run" do
      expect_until_selection()
      expect_baseline(test_run(:passed))
      expect_patcher(1)
      expect_delete_journal()
      expect_save()
      expect(TestExecutionMock, :run, fn _argv, _tests, _opts -> test_run(:failed, [@killer]) end)

      run = Sabotage.run(%{@facts | max: 1}, @opts)

      assert [%{status: :killed}] = run.outcomes
      assert [_one] = run.not_run
      assert Report.render(run) =~ "not run (cap): 1 mutants; rerun with --max all (CI)"
    end
  end

  describe "the run lock" do
    test "is taken before anything else and released after the run" do
      expect(SourceMutationMock, :take_lock, fn @root -> call(:take_lock, :ok) end)
      expect_journal(:none)

      expect(ConfigLoaderMock, :load_in, fn @root ->
        call(:config, {:ok, %Anchor.Config{rules: [], sabotage: nil}})
      end)

      expect(SourceMutationMock, :release_lock, fn @root -> call(:release_lock, :ok) end)

      assert %{refusal: {3, _message}} = Sabotage.run(@facts, @opts)
      assert calls() == [:take_lock, :read_journal, :config, :release_lock]
    end

    test "held by a live run: exit 2, nothing touched, the lock left alone" do
      expect(SourceMutationMock, :take_lock, 2, fn @root ->
        {:error, {:held, %{os_pid: 4242, started: "777"}}}
      end)

      expect(SourceMutationMock, :release_lock, 0, fn @root -> :ok end)

      for run <- [Sabotage.run(@facts, @opts), Sabotage.restore(%{root: @root}, @opts)] do
        assert %{refusal: {2, message}, notes: []} = run

        assert message ==
                 "another sabotage run (OS pid 4242) is running in this project; nothing was " <>
                   "touched. Fix: let that run finish, then rerun"
      end
    end

    test "held by a run that names no pid, or not takeable: exit 2, nothing touched" do
      expect(SourceMutationMock, :take_lock, fn @root -> {:error, {:held, nil}} end)
      assert %{refusal: {2, held}} = Sabotage.run(@facts, @opts)
      assert held =~ "another sabotage run holds _build/anchor-sabotage.lock; nothing was touched"

      expect(SourceMutationMock, :take_lock, fn @root ->
        {:error, {:stuck, "_build/anchor-sabotage.lock.takeover"}}
      end)

      assert %{refusal: {2, stuck}} = Sabotage.run(@facts, @opts)

      assert stuck ==
               "a run was killed while taking over _build/anchor-sabotage.lock, and left " <>
                 "_build/anchor-sabotage.lock.takeover; nothing was touched. Fix: check no " <>
                 "sabotage run is going, delete _build/anchor-sabotage.lock.takeover, then rerun"

      expect(SourceMutationMock, :take_lock, fn @root -> {:error, :eacces} end)
      assert %{refusal: {2, eacces}} = Sabotage.run(@facts, @opts)

      assert eacces ==
               "could not take the run lock _build/anchor-sabotage.lock (:eacces); nothing was " <>
                 "touched. Fix: make _build/ writable"
    end

    test "a host with no /proc refuses the run and the restore, exit 2, with a Fix:: nothing touched" do
      expect(SourceMutationMock, :take_lock, 2, fn @root -> {:error, :no_proc} end)
      expect(SourceMutationMock, :release_lock, 0, fn @root -> :ok end)

      for run <- [Sabotage.run(@facts, @opts), Sabotage.restore(%{root: @root}, @opts)] do
        assert %{refusal: {2, message}, notes: []} = run

        assert message ==
                 "this host has no /proc, so the run lock cannot tell a live sabotage run from " <>
                   "a dead one and would protect nothing; nothing was touched. " <>
                   "Fix: run mix anchor.sabotage on Linux (a dev machine or CI)"

        assert Report.exit_code(run) == 2
      end
    end

    test "a lock that cannot be released is said in the notes" do
      expect_journal(:none)
      expect(SourceMutationMock, :release_lock, fn @root -> {:error, :eacces} end)

      run = Sabotage.restore(%{root: @root}, @opts)

      assert run.notes == [
               "nothing to restore",
               "could not remove the run lock _build/anchor-sabotage.lock (:eacces); the next " <>
                 "run takes it over once this one has exited"
             ]
    end

    test "restore takes it too; a raise inside the run still releases it" do
      expect(SourceMutationMock, :take_lock, fn @root -> call(:take_lock, :ok) end)
      expect_journal(:none)
      expect(SourceMutationMock, :release_lock, fn @root -> call(:release_lock, :ok) end)

      Sabotage.restore(%{root: @root}, @opts)
      assert calls() == [:take_lock, :read_journal, :release_lock]

      expect(SourceMutationMock, :take_lock, fn @root -> :ok end)
      expect(SourceMutationMock, :read_journal, fn @root -> raise "boom" end)
      expect(SourceMutationMock, :release_lock, fn @root -> call(:release_lock, :ok) end)

      assert_raise RuntimeError, "boom", fn -> Sabotage.run(@facts, @opts) end
      assert calls() == [:release_lock]
    end
  end

  describe "restore/2" do
    test "1: a journal whose file holds the mutant: the original is written back, the journal deleted, exit 0" do
      entry = leftover()
      expect_journal({:ok, entry})

      expect(SourceMutationMock, :sha256_file, 2, fn @file_path ->
        if calls_seen(:write_file), do: {:ok, entry.original_sha}, else: {:ok, entry.mutated_sha}
      end)

      expect(SourceMutationMock, :write_file, fn @file_path, @source -> call(:write_file, :ok) end)

      expect(SourceMutationMock, :touch_ahead, fn @file_path -> :ok end)
      expect_delete_journal()

      run = Sabotage.restore(%{root: @root}, @opts)

      assert Report.exit_code(run) == 0
      assert run.notes == ["restored leftover mutant #{entry.mutant_id} in lib/calc.ex"]
    end

    test "2: no journal: exit 0, nothing to restore" do
      expect_journal(:none)

      run = Sabotage.restore(%{root: @root}, @opts)

      assert Report.exit_code(run) == 0
      assert Report.render(run) == "nothing to restore"
    end
  end

  # Whether a call was reported, without consuming the mailbox.
  defp calls_seen(name) do
    {:messages, messages} = Process.info(self(), :messages)
    {:call, name} in messages
  end

  describe "run/2: changed functions that yield no mutant (DND-5617)" do
    # The scope reads `source` (line 3 changed) and the generator yields no
    # mutant: no baseline, no test run, no write; exit 0, said loudly.
    defp expect_barren_run(source) do
      expect_journal(:none)
      expect_config()
      expect_ignored()
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, "abc"} end)
      expect(ChangeSourceMock, :diff, fn @root, "abc" -> {:ok, @diff} end)
      expect(ChangeSourceMock, :untracked, fn @root -> {:ok, []} end)
      expect(ChangeSourceMock, :read, 2, fn @root, "lib/calc.ex" -> {:ok, source} end)
      expect(ChangeSourceMock, :show, fn @root, "abc", "lib/calc.ex" -> {:ok, source} end)
      expect_clean()
      expect(SourceMutationMock, :existing, fn [] -> [] end)
      expect_save()
    end

    test "M1: only a function in a defimpl whose for: is not a literal: exit 0, its own reason and the count" do
      source =
        "defimpl String.Chars, for: target do\n  def to_string(c) do\n    c.a\n  end\nend\n"

      expect_barren_run(source)

      run = Sabotage.run(@facts, @opts)

      assert run.refusal == nil
      assert {run.changed_functions, run.generated, run.outcomes} == {1, 0, []}
      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "sabotage: no mutant from nil.to_string/1 (lib/calc.ex): defimpl target not a " <>
                 "literal: its for: is not a module name the source spells"

      refute text =~ "a macro made it"

      assert text =~
               "sabotage: no mutants generated from 1 changed functions: nothing was measured"
    end

    test "M2: only skipped edits: exit 0, the line names the skip rule, then the count" do
      source = "defmodule Calc do\n  def add(_a, _b) do\n    x = :ok\n    x\n  end\nend\n"
      expect_barren_run(source)

      run = Sabotage.run(@facts, @opts)

      assert {run.changed_functions, run.generated, run.outcomes} == {1, 0, []}
      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "sabotage: no mutant from Calc.add/2 (lib/calc.ex): skipped: delete_statement: " <>
                 "orphans variable `x` bound at line 3 and used at line 4"

      assert text =~
               "sabotage: no mutants generated from 1 changed functions: nothing was measured"
    end

    test "M4: a function inside defimpl P, for: T yields mutants (DND-5624): planned, no reason line" do
      source =
        "defimpl String.Chars, for: Calc do\n  def to_string(c) do\n    c.a\n  end\nend\n"

      expect_journal(:none)
      expect_config()
      expect_ignored()
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, "abc"} end)
      expect(ChangeSourceMock, :diff, fn @root, "abc" -> {:ok, @diff} end)
      expect(ChangeSourceMock, :untracked, fn @root -> {:ok, []} end)
      expect(ChangeSourceMock, :read, 2, fn @root, "lib/calc.ex" -> {:ok, source} end)
      expect(ChangeSourceMock, :show, fn @root, "abc", "lib/calc.ex" -> {:ok, source} end)
      expect_clean()
      expect_tests_exist(true)

      run = Sabotage.run(%{@facts | dry_run: true}, @opts)

      assert {run.changed_functions, run.generated, run.no_mutant, run.errors} == {1, 1, [], []}

      assert [
               {%{module: String.Chars.Calc, function: {:to_string, 1}, range: {{2, _}, _}},
                selection}
             ] =
               run.planned

      assert selection == {:mirror, ["test/calc_test.exs"]}
      text = Report.render(run)
      refute text =~ "sabotage: no mutant from"
      assert text =~ "1 mutants planned; nothing applied"
    end

    test "M3: positive control: a function with mutants prints no such line" do
      expect_until_selection()

      run = Sabotage.run(%{@facts | dry_run: true}, @opts)

      assert {run.changed_functions, run.generated, run.no_mutant} == {1, 2, []}
      text = Report.render(run)
      refute text =~ "no mutants generated"
      refute text =~ "sabotage: no mutant from"
    end
  end
end
