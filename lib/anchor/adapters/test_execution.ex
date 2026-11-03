defmodule Anchor.Adapters.TestExecution do
  @moduledoc """
  Behaviour for running a project's tests under a time bound (DND-5473), the
  **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.TestRunner`, doubled in tests as `Anchor.TestExecutionMock`.

  `run(argv, test_args, opts)` runs `argv ++ test_args` plus Anchor's ExUnit
  formatter in `opts[:cd]`, killed after `opts[:timeout_seconds]`, and returns
  the `Anchor.Domain.Sabotage.TestRun` read from `opts[:results_path]`.
  `{:error, :timeout_not_found}` when the `timeout` binary is missing: a run
  is never unbounded.
  """

  alias Anchor.Domain.Sabotage.TestRun

  @callback run(argv :: [String.t(), ...], test_args :: [String.t()], opts :: keyword()) ::
              {:ok, TestRun.t()} | {:error, :timeout_not_found}
end
