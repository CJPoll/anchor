defmodule Anchor.Domain.Sabotage.OutcomeTest do
  # DND-5473: a test run's status, read from the formatter's frames, and the
  # mutant status it gives. A mutant that does not compile is never killed.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.TestRun

  @f1 %{file: "test/x_test.exs", line: 4, name: "test adds", text: "Assertion with == failed"}
  @f2 %{file: "test/x_test.exs", line: 9, name: "test subs", text: "boom"}

  defp run(status, extra \\ []),
    do: struct!(TestRun, Keyword.merge([status: status, exit_code: 0, output_head: ""], extra))

  describe "classify/1" do
    test "1: failed with 2 failures is killed by those two tests" do
      assert Outcome.classify(run(:failed, total: 3, failures: [@f1, @f2])) ==
               {:killed,
                [{"test/x_test.exs", 4, "test adds"}, {"test/x_test.exs", 9, "test subs"}]}
    end

    test "2: passed is survived" do
      assert Outcome.classify(run(:passed, total: 4)) == {:survived, []}
    end

    test "3: timeout counts as killed, by (timeout)" do
      assert Outcome.classify(run(:timeout)) == {:timeout, ["(timeout)"]}
    end

    test "4: a compile error is invalid, never killed, with the compiler's first error line" do
      output = "Compiling 1 file (.ex)\n    error: undefined variable \"y\"\n  more\n"

      assert Outcome.classify(run(:compile_error, exit_code: 1, output_head: output)) ==
               {:invalid, []}

      assert Outcome.reason(run(:compile_error, exit_code: 1, output_head: output)) ==
               "did not compile: error: undefined variable \"y\""
    end

    test "4: a warnings-as-errors failure names the first warning" do
      output =
        "Compiling 1 file (.ex)\n     warning: variable \"y\" is unused\n\n" <>
          "Compilation failed due to warnings while using the --warnings-as-errors option\n"

      assert Outcome.reason(run(:compile_error, exit_code: 1, output_head: output)) ==
               "did not compile: warning: variable \"y\" is unused"
    end

    test "5: a crashed run is invalid" do
      assert Outcome.classify(run(:crashed, exit_code: 1)) == {:invalid, []}
      assert Outcome.reason(run(:crashed, exit_code: 1)) == "test run crashed (exit 1)"
    end

    test "6: a run in which no test ran is invalid" do
      assert Outcome.classify(run(:no_tests, total: 0)) == {:invalid, []}
      assert Outcome.reason(run(:no_tests, total: 0)) == "no test ran"
    end

    test "only an invalid run has a reason" do
      for status <- [:failed, :passed, :timeout], do: assert(Outcome.reason(run(status)) == nil)
    end
  end

  describe "TestRun.from_frames/3" do
    @finished {:suite_finished, 2, 1, 0}
    @failed {:test_failed, "test/x_test.exs", 4, "test adds", "Assertion with == failed"}

    test "exit 124 or 137 is a timeout, whatever the frames say" do
      for code <- [124, 137],
          do: assert(%TestRun{status: :timeout} = TestRun.from_frames(code, [], "x"))
    end

    test "frames with failures are failed, with each failure" do
      assert %TestRun{status: :failed, total: 2, failures: [@f1]} =
               TestRun.from_frames(2, [{:suite_started}, @failed, @finished], "")
    end

    test "a finished suite with no failure is passed; zero tests is no_tests" do
      assert %TestRun{status: :passed, total: 3} =
               TestRun.from_frames(0, [{:suite_started}, {:suite_finished, 3, 0, 0}], "")

      assert %TestRun{status: :no_tests} =
               TestRun.from_frames(0, [{:suite_started}, {:suite_finished, 0, 0, 2}], "")
    end

    test "no suite_finished frame: a compile error when the output says so, else crashed" do
      assert %TestRun{status: :compile_error} =
               TestRun.from_frames(1, [], "== Compilation error in file lib/x.ex ==\n")

      assert %TestRun{status: :compile_error} =
               TestRun.from_frames(1, [], "    error: undefined function y/0\n")

      assert %TestRun{status: :compile_error} =
               TestRun.from_frames(
                 1,
                 [],
                 "Compilation failed due to warnings while using the --warnings-as-errors option\n"
               )

      assert %TestRun{status: :crashed} =
               TestRun.from_frames(1, [{:suite_started}], "** (RuntimeError) boom\n")
    end

    test "a finished suite is read by its frames even when the exit code is non-zero" do
      assert %TestRun{status: :passed} =
               TestRun.from_frames(1, [{:suite_finished, 1, 0, 0}], "")
    end

    test "output_head keeps the first 40 lines" do
      output = Enum.map_join(1..50, "\n", &"line #{&1}")
      run = TestRun.from_frames(0, [{:suite_finished, 1, 0, 0}], output)

      assert run.output_head |> String.split("\n") |> length() == 40
      assert String.starts_with?(run.output_head, "line 1\n")
    end
  end
end
