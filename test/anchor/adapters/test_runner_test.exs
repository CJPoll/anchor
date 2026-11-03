defmodule Anchor.Adapters.TestRunnerTest do
  # DND-5473: the bounded test run, against a fake test command that writes
  # the formatter's frames by mode. The time bound is the `timeout` binary's,
  # never a sleep in the test.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.TestRunner
  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.TestRun

  @moduletag :tmp_dir

  @fake Path.expand("../../fixtures/sabotage/fake_test_command.exs", __DIR__)

  defp run(mode, dir, opts \\ []) do
    TestRunner.run(
      ["elixir", @fake, mode],
      Keyword.get(opts, :tests, ["test/calc_test.exs"]),
      cd: dir,
      results_path: Path.join(dir, "out/results.bin"),
      timeout_seconds: Keyword.get(opts, :timeout, 30),
      kill_after_seconds: Keyword.get(opts, :kill_after, 10),
      output_limits: Keyword.get(opts, :output_limits, {32_768, 32_768})
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

  # The hang rows wait for the real `timeout` binary (1 s, plus the grace
  # period for the stubborn one) beside the VM's start-up: ExUnit's bound
  # must not be the shorter of the two.
  @tag timeout: 20_000
  test "5: a run that hangs is killed by the bound and is a timeout", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :timeout, exit_code: 124}} = run("hang", dir, timeout: 1)
  end

  test "6: a run killed by signal 9 inside the bound is crashed: killed by signal 9, not a timeout",
       %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :crashed, exit_code: 137} = run} = run("killed", dir)
    assert Outcome.reason(run) == "test run crashed: killed by signal 9 (exit 137)"
  end

  # 8 s: the real run is about 2.5 s; with the default 10 s grace period
  # (the option not passed on) it would be 11 s and fail here.
  @tag timeout: 8_000
  test "7: positive control: a run that ignores the stop signal and needs the KILL is a timeout",
       %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :timeout, exit_code: 137}} =
             run("stubborn", dir, timeout: 1, kill_after: 1)
  end

  test "8: the output is bounded: head and tail kept, the dropped bytes counted", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :passed, dropped_bytes: dropped, output_head: head}} =
             run("flood", dir, output_limits: {500, 500})

    assert dropped > 150_000
    assert String.starts_with?(head, "line 1 ")
    assert dropped < 4000 * 52
  end

  test "9: output within the bound drops nothing", %{tmp_dir: dir} do
    assert {:ok, %TestRun{dropped_bytes: 0}} = run("pass", dir)
  end

  test "a stale results file that cannot be removed is an error, never read", %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "out/results.bin/inside"))

    path = Path.join(dir, "out/results.bin")

    assert {:error, {:results_not_removed, ^path, posix}} = run("pass", dir)
    assert posix in [:eperm, :eisdir]
  end

  test "a results directory that cannot be made is an error, never a crash", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "out"), "a file, not a directory")

    out = Path.join(dir, "out")

    assert {:error, {:results_dir_not_created, ^out, posix}} = run("pass", dir)
    assert posix in [:enotdir, :eexist]
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
