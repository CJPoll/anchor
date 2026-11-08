defmodule Mix.Tasks.Anchor.SabotageRunTest do
  # Framework tests for `mix anchor.sabotage run` and `restore` (DND-5473):
  # argv handling, rendering and the exit code, the Manager's ports doubled by
  # Hammox.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  # Sabotage record (DND-5617): ../../sabotage_records/sabotage-20261103-dnd_5617_sabotage_cfa_batch.md
  # Sabotage record (DND-5635): ../../sabotage_records/sabotage-20261103-dnd_5630_graph_hardening.md
  # Sabotage record (DND-5490): ../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.GitWorktreeMock
  alias Anchor.RecordStoreMock
  alias Anchor.SourceMutationMock
  alias Anchor.TestExecutionMock
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  setup do
    stub(SourceMutationMock, :take_lock, fn _root -> :ok end)
    stub(SourceMutationMock, :release_lock, fn _root -> :ok end)
    # DND-6070: no mirror directory holds a sibling of the mirror file.
    stub(SourceMutationMock, :files_in, fn _dirs -> [] end)
    :ok
  end

  @opts [source_mutation: SourceMutationMock]

  test "1: a bad --max, an unknown flag or a stray argument is a usage error, exit 2, with Fix:" do
    for argv <- [
          ["run", "--max", "0"],
          ["run", "--max", "-3"],
          ["run", "--max", "lots"],
          ["run", "--bogus"],
          ["run", "extra"],
          ["restore", "now"]
        ] do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2}, inspect(argv)
        end)

      assert stderr =~ "mix anchor.sabotage run [--base REF] [--max N|all]", inspect(argv)
      assert stderr =~ "Fix: ", inspect(argv)
    end
  end

  test "restore with no journal prints `nothing to restore` and exits 0" do
    root = File.cwd!()
    expect(SourceMutationMock, :read_journal, fn ^root -> :none end)

    assert capture_io(fn -> assert Sabotage.run(["restore"], @opts) == :ok end) ==
             "nothing to restore\n"
  end

  test "DND-5484: the record flags are accepted (the run goes on to its first step)" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5484_records.md
    root = File.cwd!()
    expect(SourceMutationMock, :read_journal, fn ^root -> {:error, :corrupt_journal} end)

    argv = ["run", "--no-record", "--domain", "d", "--ticket", "DND-1", "--slot", "s"]

    output =
      capture_io(fn -> assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2} end)

    assert output =~ ".anchor/sabotage/in-flight.json cannot be read"
  end

  test "DND-5485: replay_facts/1 maps --max and --records; a glob outside the project is usage" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
    assert {:ok, %{max: :all, records: ["a/*/records", "b"]}} =
             Sabotage.replay_facts(["--max", "all", "--records", "a/*/records", "--records", "b"])

    assert {:ok, %{max: nil, records: [], build_path: build_path}} = Sabotage.replay_facts([])
    assert build_path == Mix.Project.build_path()

    for argv <- [
          ["--max", "0"],
          ["--records", "../x"],
          ["--records", "/abs"],
          ["extra"],
          ["--bogus"]
        ] do
      assert Sabotage.replay_facts(argv) == :usage, inspect(argv)
    end
  end

  test "DND-5485: replay with a bad flag is a usage error, exit 2, naming the replay form" do
    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["replay", "--records", "../x"], @opts)) == {:shutdown, 2}
      end)

    assert stderr =~ "mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]..."
  end

  describe "DND-5485: replay's rendering and exit code" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
    @replay_source "defmodule Calc do\n  def add(a, b) do\n    a + b\n  end\nend\n"
    @replay_opts [
      config_loader: ConfigLoaderMock,
      change_source: ChangeSourceMock,
      source_mutation: SourceMutationMock,
      git_worktree: GitWorktreeMock,
      test_execution: TestExecutionMock,
      record_store: RecordStoreMock
    ]

    defp expect_replay_records(paths_and_text) do
      expect(SourceMutationMock, :read_journal, fn _root -> :none end)

      expect(ConfigLoaderMock, :load_in, fn _root ->
        {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
      end)

      expect(GitWorktreeMock, :ignored?, fn _root, _path -> {:ok, true} end)
      expect(RecordStoreMock, :list, fn _root, _glob -> Map.keys(paths_and_text) end)

      expect(RecordStoreMock, :read, map_size(paths_and_text), fn _root, path ->
        {:ok, Map.fetch!(paths_and_text, path)}
      end)
    end

    # One killed row; the killer passes at the baseline, then ends as given.
    defp expect_one_row(under_mutant) do
      {:ok, %{mutants: [mutant | _rest]}} =
        Mutator.generate(@replay_source, "lib/calc.ex", {Calc, :add, 2})

      row =
        Enum.join(
          [
            mutant.id,
            "lib/calc.ex",
            "Calc.add/2",
            to_string(mutant.operator),
            "killed",
            "test/calc_test.exs:4 test adds"
          ],
          "\t"
        )

      expect_replay_records(%{
        "test/sabotage_records/a.md" =>
          "```anchor-kills\n# id\tfile\tmfa\toperator\tstatus\tkillers\n#{row}\n```\n"
      })

      expect(SourceMutationMock, :symlinked, fn _root, _paths -> [] end)
      expect(ChangeSourceMock, :read, fn _root, "lib/calc.ex" -> {:ok, @replay_source} end)
      expect(SourceMutationMock, :existing, fn paths -> paths end)
      expect(GitWorktreeMock, :dirty_paths, fn _root, _paths -> {:ok, []} end)
      expect(SourceMutationMock, :write_journal, fn _root, _entry -> :ok end)
      expect(SourceMutationMock, :write_file, 2, fn _path, _bytes -> :ok end)
      expect(SourceMutationMock, :touch_ahead, 2, fn _path -> :ok end)

      expect(SourceMutationMock, :sha256_file, fn _path ->
        {:ok, Journal.sha256(@replay_source)}
      end)

      expect(SourceMutationMock, :delete_journal, fn _root -> :ok end)

      TestExecutionMock
      |> expect(:run, fn _argv, _args, _opts -> {:ok, replay_run(:passed, [])} end)
      |> expect(:run, fn _argv, _args, _opts -> {:ok, under_mutant} end)
    end

    defp replay_run(status, failures) do
      %TestRun{status: status, total: 1, failures: failures, exit_code: 0, output_head: ""}
    end

    test "every row still killed: exit 0, and the row is printed" do
      failure = %{file: "test/calc_test.exs", line: 4, name: "test adds", text: "failed"}
      expect_one_row(replay_run(:failed, [failure]))

      out = capture_io(fn -> assert Sabotage.run(["replay"], @replay_opts) == :ok end)

      assert out =~ "still killed "
      assert out =~ "1 replayed, 1 still killed, 0 LOST POWER"
    end

    test "a row lost power: exit 1, and the row is printed" do
      expect_one_row(replay_run(:passed, []))

      out =
        capture_io(fn ->
          assert catch_exit(Sabotage.run(["replay"], @replay_opts)) == {:shutdown, 1}
        end)

      assert out =~ "LOST POWER "
      assert out =~ "no longer failed by: test/calc_test.exs:4 test adds"
    end

    test "no rows: exit 3, COULD NOT MEASURE is printed" do
      expect_replay_records(%{"test/sabotage_records/a.md" => "# a hand record\n"})

      out =
        capture_io(fn ->
          assert catch_exit(Sabotage.run(["replay"], @replay_opts)) == {:shutdown, 3}
        end)

      assert out =~ "COULD NOT MEASURE: anchor.sabotage replay found no killed or timeout row"
    end
  end

  test "DND-5483: run_facts/1 maps --print-survivor-lines; off by default" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
    assert {:ok, %{print_survivor_lines: true}} = Sabotage.run_facts(["--print-survivor-lines"])
    assert {:ok, %{print_survivor_lines: false}} = Sabotage.run_facts([])
  end

  test "DND-5484: run_facts/1 maps the record flags; without --no-record a record is written" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5484_records.md
    argv = ["--no-record", "--domain", "d", "--ticket", "DND-1", "--slot", "s"]
    assert {:ok, facts} = Sabotage.run_facts(argv)
    assert %{no_record: true, domain: "d", ticket: "DND-1", slot: "s"} = facts
    assert facts.command == "mix anchor.sabotage run " <> Enum.join(argv, " ")

    assert {:ok, %{no_record: false, domain: nil, now: %DateTime{}}} = Sabotage.run_facts([])
    assert Sabotage.run_facts(["--no-such-flag"]) == :usage
  end

  test "DND-5490: run_facts/1 maps --scope, --shard and --report; a scan writes no record" do
    # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
    assert {:ok, %{scope: :diff, shard: nil, report: nil, no_record: false}} =
             Sabotage.run_facts([])

    assert {:ok, %{scope: :all, shard: {3, 7}, report: "scan.md", no_record: true}} =
             Sabotage.run_facts(["--scope", "all", "--shard", "3/7", "--report", "scan.md"])

    assert {:ok, %{scope: :all, no_record: true}} = Sabotage.run_facts(["--scope", "all"])
    assert {:ok, %{scope: :diff, no_record: true}} = Sabotage.run_facts(["--report", "r.md"])
    assert {:ok, %{shard: {:auto, %Date{}}}} = Sabotage.run_facts(["--shard", "auto"])

    for bad <- [
          ["--shard", "7/7"],
          ["--shard", "-1/7"],
          ["--shard", "1/0"],
          ["--shard", "a/7"],
          ["--shard", "3"],
          ["--scope", "everything"]
        ] do
      assert Sabotage.run_facts(bad) == :usage, inspect(bad)
    end
  end

  test "a refused run prints its message and exits with its code" do
    root = File.cwd!()
    expect(SourceMutationMock, :read_journal, fn ^root -> {:error, :corrupt_journal} end)

    output =
      capture_io(fn ->
        assert catch_exit(Sabotage.run(["run", "--max", "all"], @opts)) == {:shutdown, 2}
      end)

    assert output =~ ".anchor/sabotage/in-flight.json cannot be read"
  end

  test "a host with no /proc: the run and the restore print the Fix: and exit 2" do
    root = File.cwd!()
    expect(SourceMutationMock, :take_lock, 2, fn ^root -> {:error, :no_proc} end)

    for argv <- [["run", "--max", "all"], ["restore"]] do
      output =
        capture_io(fn ->
          assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2}
        end)

      assert output =~ "this host has no /proc"
      assert output =~ "Fix: run mix anchor.sabotage on Linux (a dev machine or CI)"
    end
  end

  # A run whose one changed function yields no mutant: it reaches the save of
  # the last run without applying anything. Returns the output; `save_run`
  # is the double's body.
  defp no_mutant_run(save_run) do
    root = File.cwd!()
    source = "defmodule Calc do\n  def add(_a, _b) do\n    x = :ok\n    x\n  end\nend\n"

    diff =
      "diff --git a/lib/calc.ex b/lib/calc.ex\n--- a/lib/calc.ex\n+++ b/lib/calc.ex\n@@ -3 +3 @@\n-old\n+new\n"

    expect(SourceMutationMock, :read_journal, fn ^root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn ^root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn ^root, _journal -> {:ok, true} end)
    expect(ChangeSourceMock, :merge_base, fn ^root, "origin/main" -> {:ok, "abc"} end)
    expect(ChangeSourceMock, :diff, fn ^root, "abc" -> {:ok, diff} end)
    expect(ChangeSourceMock, :untracked, fn ^root -> {:ok, []} end)
    expect(ChangeSourceMock, :read, 2, fn ^root, "lib/calc.ex" -> {:ok, source} end)
    expect(ChangeSourceMock, :show, fn ^root, "abc", "lib/calc.ex" -> {:ok, source} end)
    expect(GitWorktreeMock, :dirty_paths, fn ^root, ["lib/calc.ex"] -> {:ok, []} end)
    expect(SourceMutationMock, :existing, fn [] -> [] end)
    expect(SourceMutationMock, :save_run, save_run)
    # DND-5483: the survivors list, empty here and on the base.
    expect(Anchor.BaselineStoreMock, :read, fn ^root, ".anchor/sabotage/survivors.txt" ->
      {:ok, []}
    end)

    expect(Anchor.GitBaseMock, :show, fn ^root, "origin/main", ".anchor/sabotage/survivors.txt" ->
      {:ok, []}
    end)

    opts = [
      config_loader: ConfigLoaderMock,
      change_source: ChangeSourceMock,
      source_mutation: SourceMutationMock,
      git_worktree: GitWorktreeMock,
      test_execution: TestExecutionMock,
      baseline_store: Anchor.BaselineStoreMock,
      git_base: Anchor.GitBaseMock
    ]

    capture_io(fn -> assert Sabotage.run(["run"], opts) == :ok end)
  end

  test "DND-5617: changed functions that yield no mutant print a line each and the count, exit 0" do
    output = no_mutant_run(fn _path, _bytes -> :ok end)

    assert output =~
             "sabotage: no mutant from Calc.add/2 (lib/calc.ex): skipped: delete_statement: " <>
               "orphans variable `x` bound at line 3 and used at line 4\n"

    assert output =~
             "sabotage: no mutants generated from 1 changed functions: nothing was measured"
  end

  # DND-5635: a project built somewhere other than <root>/_build/<env>
  # (MIX_BUILD_PATH) saves its last run under its own build path, as the task
  # gathers it from Mix. sync: MIX_BUILD_PATH is the VM's OS environment.
  test "the last run is saved under Mix's build path, as MIX_BUILD_PATH sets it" do
    build = Path.join(System.tmp_dir!(), "anchor-build-#{System.unique_integer([:positive])}")
    previous = System.get_env("MIX_BUILD_PATH")

    on_exit(fn ->
      if previous,
        do: System.put_env("MIX_BUILD_PATH", previous),
        else: System.delete_env("MIX_BUILD_PATH")
    end)

    System.put_env("MIX_BUILD_PATH", build)

    no_mutant_run(fn path, _bytes ->
      send(self(), {:saved, path})
      :ok
    end)

    assert_received {:saved, path}
    assert path == Path.join(build, "anchor/sabotage/last-run.etf")
  end
end
