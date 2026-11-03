defmodule Anchor.Managers.SabotageRunTest do
  # Manager tests for `Anchor.Managers.Sabotage.run/2` and `restore/2`
  # (DND-5473), every adapter doubled by Hammox `expect/3`, which
  # self-verifies: a call the test does not expect fails it, so "no write" is
  # proven by not expecting one. Each double reports its call to the test
  # process, so the order of calls is asserted, not assumed.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
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
               %{status: :invalid, reason: "the test run raised: runner exploded"},
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

    test "10: a mutant with no test selected is no_tests, and nothing is written for it" do
      expect_until_selection(tests?: false)
      expect_save()

      run = Sabotage.run(@facts, @opts)

      assert Enum.map(run.outcomes, &{&1.status, &1.reason, &1.selection}) ==
               List.duplicate({:no_tests, "test/calc_test.exs", {:none, []}}, 2)

      assert run.baseline == :none
      assert Report.exit_code(run) == 1
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
end
