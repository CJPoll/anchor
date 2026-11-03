defmodule Anchor.Adapters.TestRunnerTest do
  # DND-5473: the bounded test run, against a fake test command that has the
  # real Anchor.Sabotage.ExUnitFormatter write its frames by mode (DND-5572).
  # The time bound is the `timeout` binary's, never a sleep in the test, and
  # no row waits for it (DND-5625).
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  # Sabotage record (DND-5618): ../../sabotage_records/sabotage-20261103-dnd_5617_sabotage_cfa_batch.md
  # Sabotage record (DND-5625): ../../sabotage_records/sabotage-20261103-dnd_5624_sabotage_defimpl.md
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

    assert %{file: "test/calc_test.exs", line: 4, name: "test adds", text: text} = failure
    assert text =~ "** (ExUnit.AssertionError)"
    assert text =~ "Assertion with == failed"
  end

  test "3: none: no test ran", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :no_tests}} = run("none", dir)
  end

  test "4: a compile error with no frames", %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :compile_error, exit_code: 1, output_head: head}} =
             run("compile_error", dir)

    assert head =~ "== Compilation error in file lib/calc.ex =="
  end

  # DND-5625: the argv contract with coreutils `timeout`. The real binary
  # runs the adapter's real argv (`--kill-after=<grace> <bound> <command>
  # ...`) around a command that exits at once, so nothing hangs and no time is
  # measured: `timeout` accepts the flag and the bound, runs the command, and
  # passes its exit code through. An argv `timeout` refuses exits 125 (a bad
  # flag or bound) or 126/127 (a "command" that is really a flag). The bound
  # and the KILL themselves are proven by the injected-clock rows K1-K5.
  defp contract(command, dir),
    do:
      TestRunner.run([command], ["test/calc_test.exs"],
        cd: dir,
        results_path: Path.join(dir, "out/results.bin"),
        timeout_seconds: 30,
        kill_after_seconds: 1
      )

  test "5: C1: coreutils timeout accepts the argv and passes exit 0 through", %{tmp_dir: dir} do
    assert {:ok, %TestRun{exit_code: 0, output_head: ""}} = contract("true", dir)
  end

  test "6: a run killed by signal 9 inside the bound is crashed: killed by signal 9, not a timeout",
       %{tmp_dir: dir} do
    assert {:ok, %TestRun{status: :crashed, exit_code: 137} = run} = run("killed", dir)
    assert Outcome.reason(run) == "test run crashed: killed by signal 9 (exit 137)"
  end

  test "7: C2: coreutils timeout passes a non-zero exit through unchanged", %{tmp_dir: dir} do
    assert {:ok, %TestRun{exit_code: 1, output_head: ""}} = contract("false", dir)
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

  describe "the time bound with an injected clock and command runner (DND-5618)" do
    # No real timeout, no sleep: the command runner is a fake that reports
    # its call and returns a canned exit; the clock returns the readings the
    # test queued, in order. The command named is never run.
    @argv ["anchor-fake-never-run", "test"]

    defp tick(readings), do: Enum.each(readings, &send(self(), {:clock, &1}))

    defp clock do
      receive do
        {:clock, ms} -> ms
      after
        0 -> flunk("the clock was read more often than the test queued readings")
      end
    end

    defp fake_runner(code) do
      test = self()

      fn executable, args, cmd_opts ->
        send(test, {:cmd, executable, args, cmd_opts})
        {Enum.into(["canned output\n"], Keyword.fetch!(cmd_opts, :into)), code}
      end
    end

    defp run_fake(code, dir, opts) do
      TestRunner.run(
        @argv,
        ["test/calc_test.exs"],
        [
          cd: dir,
          results_path: Path.join(dir, "out/results.bin"),
          timeout_seconds: 30,
          clock: &clock/0,
          command_runner: fake_runner(code)
        ] ++ opts
      )
    end

    test "K1: --kill-after and the bound lead the argv given to `timeout`", %{tmp_dir: dir} do
      tick([1_000, 1_500])

      assert {:ok, %TestRun{}} = run_fake(0, dir, kill_after_seconds: 7)

      assert_received {:cmd, timeout, args, cmd_opts}
      assert Path.basename(timeout) == "timeout"

      assert args ==
               ["--kill-after=7", "30", "anchor-fake-never-run", "test", "test/calc_test.exs"] ++
                 ~w(--formatter Anchor.Sabotage.ExUnitFormatter --formatter ExUnit.CLIFormatter)

      assert cmd_opts[:cd] == dir
      assert {"MIX_ENV", "test"} in cmd_opts[:env]
    end

    test "DND-5484: the project root reaches the formatter as ANCHOR_SABOTAGE_ROOT",
         %{tmp_dir: dir} do
      # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5484_records.md
      tick([0, 10])

      assert {:ok, %TestRun{}} = run_fake(0, dir, [])
      assert_received {:cmd, _timeout, _args, cmd_opts}
      assert {"ANCHOR_SABOTAGE_ROOT", dir} in cmd_opts[:env]
    end

    test "K2: with no grace period given, --kill-after is 10", %{tmp_dir: dir} do
      tick([0, 10])

      assert {:ok, %TestRun{}} = run_fake(0, dir, [])
      assert_received {:cmd, _timeout, ["--kill-after=10", "30" | _rest], _cmd_opts}
    end

    test "K3: exit 124 is a timeout, whatever the clock says", %{tmp_dir: dir} do
      tick([0, 5])

      assert {:ok, %TestRun{status: :timeout, exit_code: 124} = run} = run_fake(124, dir, [])
      assert Outcome.classify(run) == {:timeout, ["(timeout)"]}
    end

    test "K4: exit 137 with the measured time at the bound is a timeout (the KILL after the grace)",
         %{tmp_dir: dir} do
      tick([2_000, 32_000])

      assert {:ok, %TestRun{status: :timeout, exit_code: 137} = run} = run_fake(137, dir, [])
      assert Outcome.classify(run) == {:timeout, ["(timeout)"]}
    end

    test "K5: exit 137 one millisecond below the bound is a crash, killed by signal 9",
         %{tmp_dir: dir} do
      tick([2_000, 31_999])

      assert {:ok, %TestRun{status: :crashed, exit_code: 137} = run} = run_fake(137, dir, [])
      assert Outcome.reason(run) == "test run crashed: killed by signal 9 (exit 137)"
    end
  end
end
