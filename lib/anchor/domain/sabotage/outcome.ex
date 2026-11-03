defmodule Anchor.Domain.Sabotage.Outcome do
  @moduledoc """
  A mutant's status from its test run (DND-5473). Pure **Domain**.

  | Test run | Status | Killers |
  |---|---|---|
  | `:failed` | `:killed` | each failed test, `{file, line, name}` |
  | `:passed` | `:survived` | none |
  | `:timeout` | `:timeout` (counts as killed) | `["(timeout)"]` |
  | `:compile_error`, `:crashed`, `:no_tests` | `:invalid` | none |

  A mutant that does not compile is `:invalid`, never killed and never
  survived: its tests said nothing about it. `reason/1` says why, quoting
  the compiler's first error line (or warning, under warnings-as-errors).
  """

  alias Anchor.Domain.Sabotage.TestRun

  @type status :: :killed | :survived | :timeout | :invalid | :no_tests
  @type killer :: {String.t(), non_neg_integer(), String.t()} | String.t()

  @spec classify(TestRun.t()) :: {status(), [killer()]}
  def classify(%TestRun{status: :failed, failures: failures}),
    do: {:killed, Enum.map(failures, &{&1.file, &1.line, &1.name})}

  def classify(%TestRun{status: :passed}), do: {:survived, []}
  def classify(%TestRun{status: :timeout}), do: {:timeout, ["(timeout)"]}
  def classify(%TestRun{}), do: {:invalid, []}

  @doc "Why an invalid run is invalid; `nil` for any other."
  @spec reason(TestRun.t()) :: String.t() | nil
  def reason(%TestRun{status: :compile_error, output_head: output}),
    do: "did not compile: " <> first_error_line(output)

  def reason(%TestRun{status: :crashed, exit_code: code}), do: "test run crashed (exit #{code})"
  def reason(%TestRun{status: :no_tests}), do: "no test ran"
  def reason(%TestRun{}), do: nil

  defp first_error_line(output) do
    lines = output |> String.split("\n") |> Enum.map(&String.trim/1)

    Enum.find(lines, &String.starts_with?(&1, ["error:", "** ("])) ||
      Enum.find(lines, &String.starts_with?(&1, ["warning:", "== Compilation error"])) ||
      "(no error line in the first 40 lines of output)"
  end
end
