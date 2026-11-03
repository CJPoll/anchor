defmodule Anchor.Adapters.TestRunnerTest do
  # DND-5473: the bounded test run, against a fake test command that writes
  # the formatter's frames by mode. The time bound is the `timeout` binary's,
  # never a sleep in the test.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.TestRunner
  alias Anchor.Domain.Sabotage.TestRun

  @moduletag :tmp_dir

  @fake Path.expand("../../fixtures/sabotage/fake_test_command.exs", __DIR__)

  defp run(mode, dir, opts \\ []) do
    TestRunner.run(
      ["elixir", @fake, mode],
      Keyword.get(opts, :tests, ["test/calc_test.exs"]),
      cd: dir,
      results_path: Path.join(dir, "out/results.bin"),
      timeout_seconds: Keyword.get(opts, :timeout, 30)
    )
  end

  test "1: pass", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :passed, total: 2, failures: [], exit_code: 0}} =
             run("pass", dir)
  end

  test "2: fail: each failure carries file, line, name and text", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :failed, exit_code: 2, failures: [failure]}} = run("fail", dir)

    assert failure == %{
             file: "test/calc_test.exs",
             line: 4,
             name: "test adds",
             text: "Assertion with == failed"
           }
  end

  test "3: none: no test ran", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :no_tests}} = run("none", dir)
  end

  test "4: a compile error with no frames", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :compile_error, exit_code: 1, output_head: head}} =
             run("compile_error", dir)

    assert head =~ "== Compilation error in file lib/calc.ex =="
  end

  test "5: a run that hangs is killed by the bound and is a timeout", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :timeout, exit_code: 124}} = run("hang", dir, timeout: 1)
  end

  test "a stale results file that cannot be removed is an error, never read", %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "out/results.bin/inside"))

    path = Path.join(dir, "out/results.bin")

    assert {:error, {:results_not_removed, ^path, posix}} = run("pass", dir)
    assert posix in [:eperm, :eisdir]
  end

  test "the test files and both formatters follow the command; a stale results file is deleted first",
       %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "out"))
    stale = :erlang.term_to_binary({:test_failed, "old", 1, "old", "old"})
    File.write!(Path.join(dir, "out/results.bin"), <<byte_size(stale)::32, stale::binary>>)

    assert {:ok, %TestRun{status: :passed, failures: [], output_head: head}} =
             run("args", dir, tests: ["test/a_test.exs", "test/b_test.exs"])

    assert head =~
             "test/a_test.exs test/b_test.exs --formatter Anchor.Sabotage.ExUnitFormatter " <>
               "--formatter ExUnit.CLIFormatter"
  end
end
