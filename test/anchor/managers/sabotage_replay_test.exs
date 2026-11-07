defmodule Anchor.Managers.SabotageReplayTest do
  # DND-5485: `Anchor.Managers.Sabotage.replay/2`, every adapter doubled by
  # Hammox `expect/3` (a call the test does not expect fails it, so "no write"
  # is proven by not expecting one). Each double reports its call to the test
  # process, so the order of calls is asserted.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.GitWorktreeMock
  alias Anchor.Managers.Sabotage
  alias Anchor.RecordStoreMock
  alias Anchor.SourceMutationMock
  alias Anchor.TestExecutionMock

  setup :verify_on_exit!

  setup do
    stub(SourceMutationMock, :take_lock, fn "/repo" -> :ok end)
    stub(SourceMutationMock, :release_lock, fn "/repo" -> :ok end)
    :ok
  end

  @root "/repo"
  @file_path "/repo/lib/calc.ex"
  @facts %{root: @root, build_path: "/builds/repo-test", max: :all, records: []}
  @opts [
    config_loader: ConfigLoaderMock,
    change_source: ChangeSourceMock,
    source_mutation: SourceMutationMock,
    git_worktree: GitWorktreeMock,
    test_execution: TestExecutionMock,
    record_store: RecordStoreMock
  ]
  @source "defmodule Calc do\n  def add(a, b) do\n    a + b\n  end\nend\n"
  @killer "test/calc_test.exs:4 test adds"
  @args ["test/calc_test.exs", "--only", "test:test adds"]

  defp mutants do
    {:ok, %{mutants: mutants}} = Mutator.generate(@source, "lib/calc.ex", {Calc, :add, 2})
    Enum.sort_by(mutants, & &1.id)
  end

  defp record(mutants) do
    rows =
      Enum.map(mutants, fn m ->
        Enum.join(
          [m.id, "lib/calc.ex", "Calc.add/2", to_string(m.operator), "killed", @killer],
          "\t"
        )
      end)

    Enum.join(
      ["# r", "```anchor-kills", "# id\tfile\tmfa\toperator\tstatus\tkillers" | rows] ++
        ["```", ""],
      "\n"
    )
  end

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

  defp test_run(status, failures \\ []),
    do:
      {:ok, %TestRun{status: status, total: 1, failures: failures, exit_code: 0, output_head: ""}}

  @failure %{file: "test/calc_test.exs", line: 4, name: "test adds", text: "Assertion failed"}

  defp expect_until_plan(records, config \\ %SabotageConfig{}) do
    expect(SourceMutationMock, :read_journal, fn @root -> call(:read_journal, :none) end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      call(:config, {:ok, %Anchor.Config{rules: [], sabotage: config}})
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, ".anchor/sabotage/in-flight.json" ->
      {:ok, true}
    end)

    expect(RecordStoreMock, :list, fn @root, "test/sabotage_records" -> Map.keys(records) end)

    expect(RecordStoreMock, :read, map_size(records), fn @root, path ->
      {:ok, Map.fetch!(records, path)}
    end)

    expect(SourceMutationMock, :symlinked, fn @root, ["lib/calc.ex", "test/calc_test.exs"] ->
      []
    end)

    expect(ChangeSourceMock, :read, fn @root, "lib/calc.ex" -> {:ok, @source} end)

    expect(SourceMutationMock, :existing, fn ["/repo/test/calc_test.exs"] = paths -> paths end)
  end

  defp expect_clean,
    do: expect(GitWorktreeMock, :dirty_paths, fn @root, ["lib/calc.ex"] -> {:ok, []} end)

  defp expect_patcher(n) do
    expect(SourceMutationMock, :write_journal, n, fn @root, %Journal{} = entry ->
      call({:write_journal, entry.mutant_id}, :ok)
    end)

    expect(SourceMutationMock, :write_file, 2 * n, fn @file_path, bytes ->
      call({:write_file, if(bytes == @source, do: :original, else: :mutated)}, :ok)
    end)

    expect(SourceMutationMock, :touch_ahead, 2 * n, fn @file_path -> call(:touch_ahead, :ok) end)

    expect(SourceMutationMock, :sha256_file, n, fn @file_path ->
      call(:sha256_file, {:ok, Journal.sha256(@source)})
    end)

    expect(SourceMutationMock, :delete_journal, n, fn @root -> call(:delete_journal, :ok) end)
  end

  defp record_with_timeout(killed, timed) do
    Enum.join(
      [
        "# r",
        "```anchor-kills",
        "# id\tfile\tmfa\toperator\tstatus\tkillers",
        row_line(killed, "killed", @killer),
        row_line(timed, "timeout", "(timeout)"),
        "```",
        ""
      ],
      "\n"
    )
  end

  defp row_line(mutant, status, killer) do
    Enum.join(
      [mutant.id, "lib/calc.ex", "Calc.add/2", to_string(mutant.operator), status, killer],
      "\t"
    )
  end

  test "a row killed by the time bound alone runs its killer file whole, baseline included" do
    [killed, timed | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record_with_timeout(killed, timed)})
    expect_clean()
    expect_patcher(2)

    # In order: the named baseline, the by-file baseline, then each mutant.
    # An argument list other than these fails the test.
    TestExecutionMock
    |> expect(:run, fn _argv, @args, _opts -> call(:named_baseline, test_run(:passed)) end)
    |> expect(:run, fn _argv, ["test/calc_test.exs"], _opts ->
      call(:file_baseline, test_run(:passed))
    end)
    |> expect(:run, fn _argv, @args, _opts -> call(:named, test_run(:failed, [@failure])) end)
    |> expect(:run, fn _argv, ["test/calc_test.exs"], _opts ->
      call(:file, test_run(:failed, [@failure]))
    end)

    result = Sabotage.replay(@facts, @opts)

    assert result.refusal == nil
    assert Replay.exit_code(result) == 0

    assert [{%{by_file: false}, :still_killed}, {%{by_file: true}, :still_killed}] =
             result.results

    assert Enum.filter(calls(), &(&1 in [:named_baseline, :file_baseline, :named, :file])) ==
             [:named_baseline, :file_baseline, :named, :file]

    assert Replay.render(result) =~
             "still killed #{timed.id} Calc.add/2 #{timed.operator} " <>
               "(killer run by file: the record names no test)"
  end

  test "a killer file run whole that fails with no mutant: exit 3, main is red; nothing is written" do
    [killed, timed | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record_with_timeout(killed, timed)})
    expect_clean()

    TestExecutionMock
    |> expect(:run, fn _argv, @args, _opts -> call(:named_baseline, test_run(:passed)) end)
    |> expect(:run, fn _argv, ["test/calc_test.exs"], _opts ->
      call(:file_baseline, test_run(:failed, [@failure]))
    end)

    assert %{refusal: {3, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "main is red"
    # No write_journal or write_file is expected: Hammox fails any such call.
    assert :file_baseline in calls()
  end

  test "git cannot say what is dirty: exit 3, before any test runs" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    reason = {:git_failed, ["status"], 128, "fatal"}
    expect(GitWorktreeMock, :dirty_paths, fn @root, ["lib/calc.ex"] -> {:error, reason} end)

    assert %{refusal: {3, message}} = Sabotage.replay(@facts, @opts)

    assert message ==
             "COULD NOT MEASURE: git could not say which files are dirty (#{inspect(reason)})"
  end

  test "the baseline ends any other way (a timeout): exit 3, naming it, not read as a pass" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()
    expect(TestExecutionMock, :run, fn _argv, @args, _opts -> test_run(:timeout) end)

    assert %{refusal: {3, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "the recorded killers did not pass with no mutant applied (timeout)"
  end

  test "the baseline cannot start: the run ends on the refusal's own code and message" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()
    expect(TestExecutionMock, :run, fn _argv, @args, _opts -> {:error, :timeout_not_found} end)

    assert %{refusal: {2, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "the `timeout` binary was not found"
  end

  test "a row's test run cannot start: the file is restored, and the run ends on the refusal" do
    [first, second | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first, second])})
    expect_clean()
    expect_patcher(1)

    TestExecutionMock
    |> expect(:run, fn _argv, @args, _opts -> test_run(:passed) end)
    |> expect(:run, fn _argv, @args, _opts ->
      {:error, {:results_not_removed, "/x/results.bin", :eisdir}}
    end)

    result = Sabotage.replay(@facts, @opts)

    assert {3, message} = result.refusal
    assert message =~ "COULD NOT MEASURE: the previous results file /x/results.bin"
    assert result.results == []
    assert {:write_file, :original} in calls()
  end

  test "a record that cannot be read at all is named by its path and error; alone, exit 3" do
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, ".anchor/sabotage/in-flight.json" ->
      {:ok, true}
    end)

    expect(RecordStoreMock, :list, fn @root, "test/sabotage_records" ->
      ["test/sabotage_records/a.md"]
    end)

    expect(RecordStoreMock, :read, fn @root, "test/sabotage_records/a.md" -> {:error, :eacces} end)

    result = Sabotage.replay(@facts, @opts)

    assert result.unreadable == ["test/sabotage_records/a.md (:eacces)"]
    assert Replay.exit_code(result) == 3
  end

  test "1: the killers fail with no mutant: exit 3, main is red; nothing is written" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()

    expect(TestExecutionMock, :run, fn _argv, @args, _opts ->
      call(:baseline, test_run(:failed, [@failure]))
    end)

    result = Sabotage.replay(@facts, @opts)

    assert {3, message} = result.refusal
    assert message =~ "COULD NOT MEASURE: the recorded killers fail with no mutant applied"
    assert message =~ "main is red"
    assert Replay.exit_code(result) == 3
    # No write_journal or write_file is expected: Hammox fails any such call.
    assert calls() == [:read_journal, :config, :baseline]
  end

  test "every named killer gone (the baseline ran no test): exit 3, said as drift, not a red main" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()
    expect(TestExecutionMock, :run, fn _argv, @args, _opts -> test_run(:no_tests) end)

    assert %{refusal: {3, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "every test the rows name is gone (renamed or deleted)"
    refute message =~ "main is red"
  end

  test "2: one row whose killers fail under the mutant: journal, write, run, restore, as run; still killed" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()
    expect_patcher(1)

    expect(TestExecutionMock, :run, 2, fn _argv, @args, opts ->
      assert opts[:results_path] == "/builds/repo-test/anchor/sabotage/results.bin"

      if :baseline in calls_so_far(),
        do: call(:tests, test_run(:failed, [@failure])),
        else: call(:baseline, test_run(:passed))
    end)

    result = Sabotage.replay(@facts, @opts)

    assert result.refusal == nil
    assert [{%{row: %{id: id}}, :still_killed}] = result.results
    assert id == first.id
    assert Replay.exit_code(result) == 0

    assert Enum.drop_while(calls(), &(&1 != :baseline)) == [
             :baseline,
             {:write_journal, first.id},
             {:write_file, :mutated},
             :touch_ahead,
             :tests,
             {:write_file, :original},
             :touch_ahead,
             :sha256_file,
             :delete_journal
           ]
  end

  test "3: the killers pass under the mutant: exit 1, LOST POWER naming the record and each killer" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect_clean()
    expect_patcher(1)
    expect(TestExecutionMock, :run, 2, fn _argv, @args, _opts -> test_run(:passed) end)

    result = Sabotage.replay(@facts, @opts)

    assert Replay.exit_code(result) == 1
    text = Replay.render(result)

    assert text =~
             "LOST POWER #{first.id} Calc.add/2 #{first.operator} (test/sabotage_records/a.md)"

    assert text =~ "no longer failed by: #{@killer}"
  end

  test "4: cap 1 with 3 replayable rows: 1 replayed, 2 not replayed (cap)" do
    [first, second] = mutants()

    expect_until_plan(%{
      "test/sabotage_records/a.md" => record([first, second]),
      "test/sabotage_records/b.md" => record([first])
    })

    expect_clean()
    expect_patcher(1)

    expect(TestExecutionMock, :run, 2, fn _argv, @args, _opts ->
      if :baseline in calls_so_far(),
        do: test_run(:failed, [@failure]),
        else: call(:baseline, test_run(:passed))
    end)

    result = Sabotage.replay(%{@facts | max: 1}, @opts)

    assert [{_item, :still_killed}] = result.results
    assert length(result.not_replayed) == 2
    assert Replay.render(result) =~ "not replayed (cap)"
    assert Replay.exit_code(result) == 0
  end

  describe "the start-up refusals stop the replay with their own code" do
    test "a journal that cannot be read: exit 2, before the config is read" do
      expect(SourceMutationMock, :read_journal, fn @root -> {:error, :corrupt_journal} end)

      result = Sabotage.replay(@facts, @opts)

      assert {2, message} = result.refusal
      assert message =~ ".anchor/sabotage/in-flight.json cannot be read (:corrupt_journal)"
      assert Replay.exit_code(result) == 2
    end

    test "a leftover mutant is restored first and said; the replay then goes on" do
      entry = %Journal{
        file: "lib/calc.ex",
        mutant_id: "aaaaaaaaaaaa",
        original: @source,
        original_sha: Journal.sha256(@source),
        mutated_sha: "mutated",
        owner: %{os_pid: 4242, started: "777"}
      }

      expect(SourceMutationMock, :read_journal, fn @root -> {:ok, entry} end)
      expect(SourceMutationMock, :owner_alive?, fn %{os_pid: 4242} -> false end)

      SourceMutationMock
      |> expect(:sha256_file, fn @file_path -> {:ok, "mutated"} end)
      |> expect(:sha256_file, fn @file_path -> {:ok, Journal.sha256(@source)} end)

      expect(SourceMutationMock, :write_file, fn @file_path, @source -> :ok end)
      expect(SourceMutationMock, :touch_ahead, fn @file_path -> :ok end)
      expect(SourceMutationMock, :delete_journal, fn @root -> :ok end)

      expect(ConfigLoaderMock, :load_in, fn @root ->
        {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
      end)

      expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)
      expect(RecordStoreMock, :list, fn @root, _glob -> [] end)

      result = Sabotage.replay(@facts, @opts)

      assert result.notes == ["restored leftover mutant aaaaaaaaaaaa in lib/calc.ex"]
      assert Replay.render(result) =~ "restored leftover mutant aaaaaaaaaaaa in lib/calc.ex\n"
    end

    test "another run's live journal: exit 2, nothing touched" do
      entry = %Journal{
        file: "lib/calc.ex",
        mutant_id: "aaaaaaaaaaaa",
        original: @source,
        original_sha: Journal.sha256(@source),
        mutated_sha: "mutated",
        owner: %{os_pid: 4242, started: "777"}
      }

      expect(SourceMutationMock, :read_journal, fn @root -> {:ok, entry} end)
      expect(SourceMutationMock, :owner_alive?, fn %{os_pid: 4242} -> true end)

      assert %{refusal: {2, message}} = Sabotage.replay(@facts, @opts)
      assert message =~ "another sabotage run (OS pid 4242)"
    end

    test "no sabotage: section: exit 3, before the journal check or any record" do
      expect(SourceMutationMock, :read_journal, fn @root -> :none end)

      expect(ConfigLoaderMock, :load_in, fn @root ->
        {:ok, %Anchor.Config{rules: [], sabotage: nil}}
      end)

      result = Sabotage.replay(@facts, @opts)

      assert {3, message} = result.refusal
      assert message =~ "COULD NOT MEASURE: .anchor.yml has no sabotage: section"
      assert Replay.exit_code(result) == 3
    end

    test "the journal not git-ignored: exit 2, before any record is read" do
      expect(SourceMutationMock, :read_journal, fn @root -> :none end)

      expect(ConfigLoaderMock, :load_in, fn @root ->
        {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
      end)

      expect(GitWorktreeMock, :ignored?, fn @root, ".anchor/sabotage/in-flight.json" ->
        {:ok, false}
      end)

      result = Sabotage.replay(@facts, @opts)

      assert {2, message} = result.refusal
      assert message =~ ".anchor/sabotage/in-flight.json is not git-ignored"
      assert Replay.exit_code(result) == 2
    end
  end

  test "no --max: the cap is the config's max_mutants" do
    [first, second] = mutants()

    expect_until_plan(
      %{"test/sabotage_records/a.md" => record([first, second])},
      %SabotageConfig{max_mutants: 1}
    )

    expect_clean()
    expect_patcher(1)

    expect(TestExecutionMock, :run, 2, fn _argv, @args, _opts ->
      if :baseline in calls_so_far(),
        do: test_run(:failed, [@failure]),
        else: call(:baseline, test_run(:passed))
    end)

    result = Sabotage.replay(%{@facts | max: nil}, @opts)

    assert [{_item, :still_killed}] = result.results
    assert length(result.not_replayed) == 1
  end

  test "zero rows: exit 3, naming the directories searched; a malformed kill map is named" do
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)

    expect(RecordStoreMock, :list, fn @root, "test/sabotage_records" ->
      ["test/sabotage_records/hand.md", "test/sabotage_records/bad.md"]
    end)

    expect(RecordStoreMock, :read, 2, fn
      @root, "test/sabotage_records/hand.md" -> {:ok, "# a hand record, no kill map\n"}
      @root, "test/sabotage_records/bad.md" -> {:ok, "```anchor-kills\nx\n```\n"}
    end)

    result = Sabotage.replay(@facts, @opts)

    assert Replay.exit_code(result) == 3
    text = Replay.render(result)
    assert text =~ "could not read kill map in test/sabotage_records/bad.md:2"
    assert text =~ "found no killed or timeout row in 2 records under test/sabotage_records"
  end

  test "a record that cannot be read beside rows still killed: exit 3, never green" do
    [first | _rest] = mutants()

    expect_until_plan(%{
      "test/sabotage_records/a.md" => record([first]),
      "test/sabotage_records/bad.md" => "```anchor-kills\nx\n```\n"
    })

    expect_clean()
    expect_patcher(1)

    expect(TestExecutionMock, :run, 2, fn _argv, @args, _opts ->
      if :baseline in calls_so_far(),
        do: test_run(:failed, [@failure]),
        else: call(:baseline, test_run(:passed))
    end)

    result = Sabotage.replay(@facts, @opts)

    assert [{_item, :still_killed}] = result.results
    assert Replay.exit_code(result) == 3
    text = Replay.render(result)
    assert text =~ "could not read kill map in test/sabotage_records/bad.md:2"
    assert text =~ "COULD NOT MEASURE: 1 records could not be read (above)"
  end

  test "a row file or killer file with a symlink on its path is drifted: never read, written or run" do
    [first | _rest] = mutants()
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)

    expect(RecordStoreMock, :list, fn @root, "test/sabotage_records" ->
      ["test/sabotage_records/a.md"]
    end)

    expect(RecordStoreMock, :read, fn @root, _path -> {:ok, record([first])} end)

    expect(SourceMutationMock, :symlinked, fn @root, ["lib/calc.ex", "test/calc_test.exs"] ->
      ["lib/calc.ex"]
    end)

    expect(SourceMutationMock, :existing, fn paths -> paths end)

    result = Sabotage.replay(@facts, @opts)

    assert [{_item, :symlink}] = result.drifted
    assert Replay.exit_code(result) == 3
    assert Replay.render(result) =~ "drifted (a symlink on the file's path: never followed)"
  end

  test "the run lock is taken before anything else and released after; held, exit 2, nothing touched" do
    expect(SourceMutationMock, :take_lock, fn @root -> call(:take_lock, :ok) end)
    expect(SourceMutationMock, :release_lock, fn @root -> call(:release_lock, :ok) end)
    expect(SourceMutationMock, :read_journal, fn @root -> call(:read_journal, :none) end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)
    expect(RecordStoreMock, :list, fn @root, _glob -> [] end)

    Sabotage.replay(@facts, @opts)
    assert calls() == [:take_lock, :read_journal, :release_lock]

    expect(SourceMutationMock, :take_lock, fn @root ->
      {:error, {:held, %{os_pid: 4242, started: "777"}}}
    end)

    assert %{refusal: {2, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "another sabotage run (OS pid 4242) is running in this project"
  end

  test "--records names the directory globs read instead of the configured one" do
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)
    expect(RecordStoreMock, :list, fn @root, "apps/*/records" -> [] end)

    result = Sabotage.replay(%{@facts | records: ["apps/*/records"]}, @opts)
    assert result.searched == ["apps/*/records"]
    assert Replay.exit_code(result) == 3
  end

  test "DND-6031: with no --records, records.dir and records.outside_apps_dir are both read" do
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    records = %{
      %SabotageConfig{}.records
      | dir: "apps/{app}/test/sabotage_records",
        outside_apps_dir: "tools/sabotage_records"
    }

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{records: records}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, _path -> {:ok, true} end)
    expect(RecordStoreMock, :list, fn @root, "apps/*/test/sabotage_records" -> [] end)
    expect(RecordStoreMock, :list, fn @root, "tools/sabotage_records" -> [] end)

    result = Sabotage.replay(@facts, @opts)
    assert result.searched == ["apps/*/test/sabotage_records", "tools/sabotage_records"]
    assert Replay.exit_code(result) == 3
  end

  test "a replayable row's file with uncommitted changes refuses, exit 2, before any test runs" do
    [first | _rest] = mutants()
    expect_until_plan(%{"test/sabotage_records/a.md" => record([first])})
    expect(GitWorktreeMock, :dirty_paths, fn @root, ["lib/calc.ex"] -> {:ok, ["lib/calc.ex"]} end)

    assert %{refusal: {2, message}} = Sabotage.replay(@facts, @opts)
    assert message =~ "uncommitted changes in lib/calc.ex"
  end

  defp calls_so_far do
    {:messages, messages} = Process.info(self(), :messages)
    for {:call, name} <- messages, do: name
  end
end
