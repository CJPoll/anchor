defmodule Mix.Tasks.Anchor.SabotageRunTest do
  # Framework tests for `mix anchor.sabotage run` and `restore` (DND-5473):
  # argv handling, rendering and the exit code, the Manager's ports doubled by
  # Hammox.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.SourceMutationMock
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
end
