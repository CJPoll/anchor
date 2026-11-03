defmodule Anchor.Domain.Sabotage.TestRun do
  @moduledoc """
  One test run's result (DND-5473), read from the frames
  `Anchor.Sabotage.ExUnitFormatter` wrote, never from parsed test output.
  Pure **Domain**.

  `status`: `:timeout` (exit 124 or 137: the `timeout` bound killed it);
  with no `{:suite_finished, ...}` frame, `:compile_error` when the output
  shows a compile failure, else `:crashed`; `:no_tests` (none ran);
  `:failed`; `:passed`. `failures` are `%{file, line, name, text}`;
  `output_head` is the output's first 40 lines, for an `invalid` reason.
  """

  @enforce_keys [:status, :exit_code, :output_head]
  defstruct status: nil, total: 0, failures: [], exit_code: 0, output_head: ""

  @type status :: :passed | :failed | :timeout | :compile_error | :crashed | :no_tests
  @type failure :: %{
          file: String.t(),
          line: non_neg_integer(),
          name: String.t(),
          text: String.t()
        }
  @type t :: %__MODULE__{
          status: status(),
          total: non_neg_integer(),
          failures: [failure()],
          exit_code: integer(),
          output_head: String.t()
        }

  @compile_markers [
    "== Compilation error",
    "error:",
    "Compilation failed due to warnings"
  ]

  @doc "The run from its exit code, the decoded frames and the command's output."
  @spec from_frames(integer(), [tuple()], String.t()) :: t()
  def from_frames(exit_code, frames, output) do
    head = output |> String.split("\n") |> Enum.take(40) |> Enum.join("\n")

    failures =
      for {:test_failed, file, line, name, text} <- frames, do: failure(file, line, name, text)

    finished = Enum.find(frames, &match?({:suite_finished, _total, _failures, _excluded}, &1))

    %__MODULE__{
      status: status(exit_code, finished, failures, output),
      total: total(finished),
      failures: failures,
      exit_code: exit_code,
      output_head: head
    }
  end

  defp failure(file, line, name, text), do: %{file: file, line: line, name: name, text: text}

  defp status(code, _finished, _failures, _output) when code in [124, 137], do: :timeout

  defp status(_code, nil, _failures, output) do
    if Enum.any?(@compile_markers, &String.contains?(output, &1)),
      do: :compile_error,
      else: :crashed
  end

  defp status(_code, {:suite_finished, 0, _failed, _excluded}, _failures, _output), do: :no_tests

  defp status(_code, {:suite_finished, _total, failed, _excluded}, failures, _output)
       when failed > 0 or failures != [],
       do: :failed

  defp status(_code, _finished, _failures, _output), do: :passed

  defp total(nil), do: 0
  defp total({:suite_finished, total, _failed, _excluded}), do: total
end
