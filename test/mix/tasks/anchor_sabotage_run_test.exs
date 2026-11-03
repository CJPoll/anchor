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
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.GitWorktreeMock
  alias Anchor.SourceMutationMock
  alias Anchor.TestExecutionMock
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  setup do
    stub(SourceMutationMock, :take_lock, fn _root -> :ok end)
    stub(SourceMutationMock, :release_lock, fn _root -> :ok end)
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

    opts = [
      config_loader: ConfigLoaderMock,
      change_source: ChangeSourceMock,
      source_mutation: SourceMutationMock,
      git_worktree: GitWorktreeMock,
      test_execution: TestExecutionMock
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
