defmodule Anchor.Domain.Sabotage.Outcome do
  @moduledoc """
  A mutant's status from its test run (DND-5473). Pure **Domain**.

  | Test run | Status | Killers |
  |---|---|---|
  | `:failed` | `:killed` | each failed test, `{file, line, name}` |
  | `:failed`, every failure a test timeout | `:timeout` | `"(test timeout) file:line name"` each |
  | `:passed` | `:survived` | none |
  | `:timeout` | `:timeout` (counts as killed) | `["(timeout)"]` |
  | `:compile_error` | `:invalid` | none |
  | `:crashed` | `:crashed` | none |
  | `:no_tests` (the tests ran none) | `:no_tests` | none |

  A per-test timeout (DND-5653) is a failure whose text starts
  `** (ExUnit.TimeoutError)`: ExUnit stopped the test at its bound, and no
  assertion failed. A run whose every failure is one is a `:timeout` kill,
  never `:killed`, so a kill that rests on time alone is never counted as an
  assertion's. A run that also failed an assertion is `:killed`, by those
  tests only.

  A mutant that does not compile is `:invalid`, never killed and never
  survived: its tests said nothing about it. `reason/1` says why, quoting
  the compiler's first error line (or warning, under warnings-as-errors).

  `:crashed` and `:no_tests` are the unmeasured mutants (DND-5570): the
  tests could have killed them and did not get to say. `Report` fails a run
  that holds one beside a measured mutant, like a survivor; an `:invalid`
  mutant is a different thing (a mutation that is not valid code) and, beside
  a measured mutant, never changes the exit code.
  """

  alias Anchor.Domain.Sabotage.TestRun

  @type status :: :killed | :survived | :timeout | :invalid | :crashed | :no_tests
  @type killer :: {String.t(), non_neg_integer(), String.t()} | String.t()

  @spec classify(TestRun.t()) :: {status(), [killer()]}
  def classify(%TestRun{status: :failed, failures: failures}) do
    {timeouts, asserted} = Enum.split_with(failures, &test_timeout?/1)
    failed(timeouts, asserted)
  end

  def classify(%TestRun{status: :passed}), do: {:survived, []}
  def classify(%TestRun{status: :timeout}), do: {:timeout, ["(timeout)"]}
  def classify(%TestRun{status: :crashed}), do: {:crashed, []}
  def classify(%TestRun{status: :no_tests}), do: {:no_tests, []}
  def classify(%TestRun{}), do: {:invalid, []}

  @doc "Why an invalid, crashed or no-test run is unmeasured or invalid; `nil` for any other."
  @spec reason(TestRun.t()) :: String.t() | nil
  def reason(%TestRun{status: :compile_error, output_head: output}),
    do: "did not compile: " <> first_error_line(output)

  def reason(%TestRun{status: :crashed} = run),
    do: crash_text(run) <> dropped_note(run.dropped_bytes)

  def reason(%TestRun{status: :no_tests}), do: "no test ran"
  def reason(%TestRun{}), do: nil

  # A run ExUnit counted as failed with no failure frame stays `:killed`, as
  # before DND-5653: only a failure frame can say the kill was a timeout.
  defp failed([_ | _] = timeouts, []),
    do: {:timeout, Enum.map(timeouts, &"(test timeout) #{&1.file}:#{&1.line} #{&1.name}")}

  defp failed(_timeouts, asserted),
    do: {:killed, Enum.map(asserted, &{&1.file, &1.line, &1.name})}

  defp test_timeout?(%{text: text}), do: String.starts_with?(text, "** (ExUnit.TimeoutError)")

  defp crash_text(%TestRun{exit_code: 137}), do: "test run crashed: killed by signal 9 (exit 137)"
  defp crash_text(%TestRun{exit_code: code}), do: "test run crashed (exit #{code})"

  defp dropped_note(0), do: ""
  defp dropped_note(bytes), do: "; #{bytes} bytes of its output were dropped"

  defp first_error_line(output) do
    # Mix's "mtime ... was set to the future" warning follows every touch
    # ahead; it is never why a mutant did not compile.
    lines =
      output
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&String.starts_with?(&1, "warning: mtime"))

    Enum.find(lines, &String.starts_with?(&1, ["error:", "** ("])) ||
      Enum.find(lines, &String.starts_with?(&1, ["warning:", "== Compilation error"])) ||
      "(no error line in the first 40 lines of output)"
  end
end
