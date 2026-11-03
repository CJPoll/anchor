defmodule Anchor.Adapters.TestRunner do
  @moduledoc """
  Runs a project's tests for one mutant, the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.TestExecution` (DND-5473).

      timeout --kill-after=10 <t> <argv> <test_args> \\
        --formatter Anchor.Sabotage.ExUnitFormatter --formatter ExUnit.CLIFormatter

  run with `System.cmd/3` (no shell) in `opts[:cd]`, with `MIX_ENV=test` and
  `ANCHOR_SABOTAGE_RESULTS=<results_path>`; the results file is deleted
  first. The bound is the `timeout` binary's: a mutant that loops forever is
  killed (exit 124, or 137 after the grace period) and recorded `:timeout`.
  The frames are read with `:erlang.binary_to_term(bin, [:safe])`; a frame cut
  short by a kill ends the read.
  """

  @behaviour Anchor.Adapters.TestExecution

  alias Anchor.Domain.Sabotage.TestRun

  @formatters [
    "--formatter",
    "Anchor.Sabotage.ExUnitFormatter",
    "--formatter",
    "ExUnit.CLIFormatter"
  ]

  @impl Anchor.Adapters.TestExecution
  def run([command | args], test_args, opts) do
    results = Keyword.fetch!(opts, :results_path)
    seconds = Keyword.fetch!(opts, :timeout_seconds)

    case System.find_executable("timeout") do
      nil ->
        {:error, :timeout_not_found}

      timeout ->
        _ = File.rm(results)
        :ok = File.mkdir_p(Path.dirname(results))
        argv = ["--kill-after=10", Integer.to_string(seconds), command] ++ args ++ test_args

        {output, code} =
          System.cmd(timeout, argv ++ @formatters,
            cd: Keyword.fetch!(opts, :cd),
            env: [{"MIX_ENV", "test"}, {"ANCHOR_SABOTAGE_RESULTS", results}],
            stderr_to_stdout: true
          )

        {:ok, TestRun.from_frames(code, frames(results), output)}
    end
  end

  defp frames(path) do
    case File.read(path) do
      {:ok, bytes} -> decode(bytes, [])
      {:error, _posix} -> []
    end
  end

  defp decode(<<size::32, frame::binary-size(size), rest::binary>>, acc),
    do: decode(rest, [:erlang.binary_to_term(frame, [:safe]) | acc])

  defp decode(_rest, acc), do: Enum.reverse(acc)
end
