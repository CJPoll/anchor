defmodule Anchor.Adapters.SuiteRunner do
  @moduledoc """
  Runs a project's suite in this VM for the coverage map (DND-5474), the
  **Side Effect** adapter (ADR 001) behind `Anchor.Adapters.InProcessTests`.

  `Mix.Task.run("test", ["--max-cases", "1", "--raise" | args])`: Mix reads
  the first `--max-cases`, so one test runs at a time whatever `args` say,
  and `--raise` makes a failing suite raise here instead of setting the VM's
  exit status at exit, so the status is this function's to report.
  """

  @behaviour Anchor.Adapters.InProcessTests

  @impl Anchor.Adapters.InProcessTests
  def run(args) do
    Mix.Task.run("test", ["--max-cases", "1", "--raise" | args])
    :passed
  rescue
    error -> {:failed, Exception.message(error)}
  end
end
