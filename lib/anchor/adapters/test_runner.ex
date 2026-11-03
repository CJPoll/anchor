defmodule Anchor.Adapters.TestRunner do
  @moduledoc """
  Runs a project's tests for one mutant, the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.TestExecution` (DND-5473).

      timeout --kill-after=10 <t> <argv> <test_args> \\
        --formatter Anchor.Sabotage.ExUnitFormatter --formatter ExUnit.CLIFormatter

  run with `System.cmd/3` (no shell) in `opts[:cd]`, with `MIX_ENV=test` and
  `ANCHOR_SABOTAGE_RESULTS=<results_path>`; the results file is deleted
  first (one that cannot be removed is
  `{:error, {:results_not_removed, path, posix}}`, never read; a directory for
  it that cannot be made is `{:error, {:results_dir_not_created, dir, posix}}`).
  The bound is the `timeout` binary's: a mutant that loops forever is stopped
  (exit 124) or, if it ignores that, killed after the grace period (exit 137
  once the bound has passed) and recorded `:timeout`. An exit 137 inside the
  bound is a kill by something else (the kernel's out-of-memory killer, for
  one): `:crashed`, killed by signal 9 (DND-5573).

  The output is collected into an `Anchor.Domain.Sabotage.BoundedOutput`
  (opts `:output_limits`, `{head_bytes, tail_bytes}`, default 32 KiB each):
  a mutant that prints without end cannot grow the VM, and the bytes dropped
  are on the `TestRun`. `opts[:kill_after_seconds]` (default 10) is the
  grace period.

  Two seams let the time bound be tested without a wall clock (DND-5618):
  `opts[:clock]`, a 0-arity function returning milliseconds (default
  `System.monotonic_time(:millisecond)`), read before and after the run; and
  `opts[:command_runner]`, a function with `System.cmd/3`'s arguments and
  result (default `System.cmd/3`), given the `timeout` path, the full argv
  and the command options.
  The frames are read with `:erlang.binary_to_term(bin, [:safe])`; a frame cut
  short by a kill ends the read.
  """

  @behaviour Anchor.Adapters.TestExecution

  alias Anchor.Domain.Sabotage.BoundedOutput
  alias Anchor.Domain.Sabotage.TestRun

  @formatters [
    "--formatter",
    "Anchor.Sabotage.ExUnitFormatter",
    "--formatter",
    "ExUnit.CLIFormatter"
  ]

  @kill_after_seconds 10
  @output_limit 32_768

  @impl Anchor.Adapters.TestExecution
  def run([command | args], test_args, opts) do
    results = Keyword.fetch!(opts, :results_path)

    case System.find_executable("timeout") do
      nil ->
        {:error, :timeout_not_found}

      timeout ->
        with :ok <- fresh(results), do: {:ok, execute(timeout, [command | args], test_args, opts)}
    end
  end

  defp execute(timeout, argv, test_args, opts) do
    results = Keyword.fetch!(opts, :results_path)
    seconds = Keyword.fetch!(opts, :timeout_seconds)
    grace = Keyword.get(opts, :kill_after_seconds, @kill_after_seconds)
    {head, tail} = Keyword.get(opts, :output_limits, {@output_limit, @output_limit})

    full =
      ["--kill-after=#{grace}", Integer.to_string(seconds)] ++ argv ++ test_args ++ @formatters

    clock = Keyword.get(opts, :clock, &monotonic_ms/0)
    command_runner = Keyword.get(opts, :command_runner, &System.cmd/3)
    started = clock.()

    {output, code} =
      command_runner.(timeout, full,
        cd: Keyword.fetch!(opts, :cd),
        env: [
          {"MIX_ENV", "test"},
          {"ANCHOR_SABOTAGE_RESULTS", results},
          {"ANCHOR_SABOTAGE_ROOT", Keyword.fetch!(opts, :cd)}
        ],
        stderr_to_stdout: true,
        into: BoundedOutput.new(head, tail)
      )

    TestRun.from_frames(code, frames(results), BoundedOutput.text(output),
      elapsed_ms: clock.() - started,
      timeout_seconds: seconds,
      dropped_bytes: BoundedOutput.dropped(output)
    )
  end

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  # A results file left by an earlier run must be gone: its frames would be
  # read as this run's.
  defp fresh(results) do
    dir = Path.dirname(results)

    case File.mkdir_p(dir) do
      :ok -> remove_stale(results)
      {:error, posix} -> {:error, {:results_dir_not_created, dir, posix}}
    end
  end

  defp remove_stale(results) do
    case File.rm(results) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, posix} -> {:error, {:results_not_removed, results, posix}}
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
