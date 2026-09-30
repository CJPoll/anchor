defmodule Anchor.Managers.LintAnalysisCrashTest do
  # DND-1310: an exception while analysing one file must become one fail-closed
  # issue on that file, naming the check and carrying a `Fix:` line. Before, it
  # escaped the check: Credo's runner (`Credo.Check.Runner.run_check/3`) rescues
  # it, warns "Error while running <check>", and then either re-raises (aborting
  # the whole run, every file and every check) or, with `crash_on_error: false`,
  # returns no issues at all for that check, which reads as a pass.
  #
  # The exception is injected by a check whose detection raises on one file. The
  # config loader is a Hammox mock (`expect/3`); the rest is real.
  #
  # Sabotage record: test/sabotage_records/lint-20260929-dnd_1310_analyzer_quote_crash.md
  use Credo.Test.Case, async: true

  import Hammox

  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Lint
  alias Anchor.Managers.LintAnalysisCrashTest.RaisingCheck
  alias Credo.SourceFile

  setup :verify_on_exit!

  defmodule RaisingCheck do
    @moduledoc false
    use Anchor.Check.Base, category: :design

    @doc false
    def rule_type, do: :single_control_flow

    # Raises on `lib/boom.ex`; detects as the real check does everywhere else.
    @doc false
    def detect_violations(%{filename: "lib/boom.ex"}, _ast, _rules, _context),
      do: raise(ArgumentError, "injected by the test")

    def detect_violations(_source_file, ast, rules, _context),
      do: Anchor.Domain.Checks.SingleControlFlow.detect_violations(ast, rules)
  end

  @rule %{type: :single_control_flow, paths: ["lib/**/*.ex"], recursive: true}

  @clean """
  defmodule MyApp.Clean do
    def go(x), do: x
  end
  """

  @flagged """
  defmodule MyApp.Flagged do
    def go(x) do
      if x, do: 1
      case x, do: (_ -> 2)
    end
  end
  """

  test "an exception on one file is one fail-closed violation on that file; the others are checked" do
    boom = SourceFile.parse(@clean, "lib/boom.ex")
    flagged = SourceFile.parse(@flagged, "lib/flagged.ex")
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [@rule]}} end)

    assert {:ok, [{^boom, [crash]}, {^flagged, [flag]}]} =
             Lint.run(RaisingCheck, [boom, flagged], [], config_loader: ConfigLoaderMock)

    assert %Violation{kind: :fail_closed, filename: nil, line: nil} = crash
    assert crash.trigger == inspect(RaisingCheck)

    assert crash.message =~
             "Anchor check #{inspect(RaisingCheck)} crashed on this file, so it checked no " <>
               "Anchor rule against it: ArgumentError: injected by the test"

    assert crash.message =~ "Fix: "

    # Positive control: the next file was still checked.
    assert %Violation{kind: :rule, trigger: "go"} = flag
  end

  test "the Framework entry reports it as one Credo issue on that file, at higher priority" do
    boom = SourceFile.parse(@clean, "lib/boom.ex")

    assert [issue] = RaisingCheck.check_file(boom, [@rule], [])
    assert issue.filename == "lib/boom.ex"
    assert issue.trigger == inspect(RaisingCheck)
    assert issue.message =~ "ArgumentError: injected by the test"
    assert issue.message =~ "Fix: "
    assert issue.priority == Credo.Priority.to_integer(:higher)
  end
end
