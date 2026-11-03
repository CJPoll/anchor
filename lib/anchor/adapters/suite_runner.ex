defmodule Anchor.Adapters.SuiteRunner do
  @moduledoc """
  Runs a project's suite in this VM for the coverage map (DND-5474), the
  **Side Effect** adapter (ADR 001) behind `Anchor.Adapters.InProcessTests`.

  `Mix.Task.run("test", args ++ ["--max-cases", "1", "--raise"])`: a switch
  given twice takes its last value, so `--max-cases 1` comes last (the
  Manager also refuses test arguments that set it), and `--raise` makes a failing suite raise here instead of setting the VM's
  exit status at exit, so the status is this function's to report.
  """

  @behaviour Anchor.Adapters.InProcessTests

  @impl Anchor.Adapters.InProcessTests
  def run(args) do
    Mix.Task.run("test", args ++ ["--max-cases", "1", "--raise"])
    :passed
  rescue
    error -> {:failed, Exception.message(error)}
  end
end
