defmodule Anchor.Adapters.InProcessTests do
  @moduledoc """
  Behaviour for running a project's test suite in this VM, so its calls can be
  traced (DND-5474), the **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.SuiteRunner`, doubled in tests as
  `Anchor.InProcessTestsMock`.

  `run(args)` runs the suite with `--max-cases 1` last, so it wins (one test at a time)
  and returns `:passed`, or `{:failed, message}` (a failed test, a test file
  that does not compile, a suite that ran nothing).
  """

  @callback run(args :: [String.t()]) :: :passed | {:failed, String.t()}
end
