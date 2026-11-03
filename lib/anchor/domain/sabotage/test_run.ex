defmodule Anchor.Domain.Sabotage.TestRun do
  @moduledoc """
  One test run's result (DND-5473), read from the frames
  `Anchor.Sabotage.ExUnitFormatter` wrote, never from parsed test output.
  Pure **Domain**.

  `status`: `:timeout` (exit 124: the `timeout` bound stopped it; or exit 137
  once the bound was reached, which is the KILL that follows the stop signal);
  exit 137 with the bound not reached is `:crashed`, killed by signal 9 (an
  out-of-memory kill, for one), never a timeout (DND-5573). With no
  `{:suite_finished, ...}` frame, `:compile_error` when the output shows a
  compile failure, else `:crashed`; `:no_tests` (none ran); `:failed`;
  `:passed`. `failures` are `%{file, line, name, text}`; `output_head` is the
  output's first 40 lines, for an `invalid` reason; `dropped_bytes` is how
  much of the output the collector did not keep
  (`Anchor.Domain.Sabotage.BoundedOutput`).
  """

  @enforce_keys [:status, :exit_code, :output_head]
  defstruct status: nil, total: 0, failures: [], exit_code: 0, output_head: "", dropped_bytes: 0

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
          output_head: String.t(),
          dropped_bytes: non_neg_integer()
        }

  @compile_markers [
    "== Compilation error",
    "error:",
    "Compilation failed due to warnings"
  ]

  @doc """
  The run from its exit code, the decoded frames and the command's output.

  `opts`: `:elapsed_ms` and `:timeout_seconds` (how long the run took and its
  bound, to tell the KILL after a timeout from a kill by something else), and
  `:dropped_bytes` (output the collector dropped). With no clock reading an
  exit 137 is a crash: a timeout must be proven.
  """
  @spec from_frames(integer(), [tuple()], String.t(), keyword()) :: t()
  def from_frames(exit_code, frames, output, opts \\ []) do
    head = output |> String.split("\n") |> Enum.take(40) |> Enum.join("\n")

    failures =
      for {:test_failed, file, line, name, text} <- frames, do: failure(file, line, name, text)

    finished = Enum.find(frames, &match?({:suite_finished, _total, _failures, _excluded}, &1))

    %__MODULE__{
      status: status(exit_code, finished, failures, output, bound_reached?(opts)),
      total: total(finished),
      failures: failures,
      exit_code: exit_code,
      output_head: head,
      dropped_bytes: Keyword.get(opts, :dropped_bytes, 0)
    }
  end

  defp bound_reached?(opts) do
    with elapsed when is_integer(elapsed) <- Keyword.get(opts, :elapsed_ms),
         seconds when is_integer(seconds) <- Keyword.get(opts, :timeout_seconds) do
      elapsed >= seconds * 1000
    else
      _no_reading -> false
    end
  end

  defp failure(file, line, name, text), do: %{file: file, line: line, name: name, text: text}

  defp status(124, _finished, _failures, _output, _reached), do: :timeout
  defp status(137, _finished, _failures, _output, true), do: :timeout
  defp status(137, _finished, _failures, _output, false), do: :crashed

  defp status(_code, nil, _failures, output, _reached) do
    if Enum.any?(@compile_markers, &String.contains?(output, &1)),
      do: :compile_error,
      else: :crashed
  end

  defp status(_code, {:suite_finished, 0, _failed, _excluded}, _failures, _output, _reached),
    do: :no_tests

  defp status(_code, {:suite_finished, _total, failed, _excluded}, failures, _output, _reached)
       when failed > 0 or failures != [],
       do: :failed

  defp status(_code, _finished, _failures, _output, _reached), do: :passed

  defp total(nil), do: 0
  defp total({:suite_finished, total, _failed, _excluded}), do: total
end
