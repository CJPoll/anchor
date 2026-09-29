defmodule Anchor.Check.BaseTest do
  # Framework (DND-1265): which Anchor check reports a failure that is not
  # specific to one check (a missing or invalid config, an unparseable file),
  # so Credo shows it once per run rather than once per enabled Anchor check,
  # and never zero times.
  #
  # Sabotage record: ../../sabotage_records/base-20260929-dnd_1265_anchor_fail_closed.md
  use Credo.Test.Case, async: true

  alias Anchor.Check.Base
  alias Anchor.Check.MustUseModule
  alias Anchor.Check.NoDependency

  describe "shared_failure_reporter?/2" do
    test "the first enabled Anchor check in the run is the reporter" do
      exec =
        exec_with_checks([
          {Credo.Check.Readability.ModuleNames, []},
          {NoDependency, []},
          {MustUseModule, []}
        ])

      assert Base.shared_failure_reporter?(exec, NoDependency)
      refute Base.shared_failure_reporter?(exec, MustUseModule)
    end

    # Credo never runs a `false` check, so the next enabled Anchor check reports.
    test "a check disabled with `false` params is skipped" do
      exec = exec_with_checks([{NoDependency, false}, {MustUseModule, []}])

      assert Base.shared_failure_reporter?(exec, MustUseModule)
    end

    test "a check in Credo's older `{module}` notation counts as enabled" do
      exec = exec_with_checks([{NoDependency}, {MustUseModule, []}])

      assert Base.shared_failure_reporter?(exec, NoDependency)
      refute Base.shared_failure_reporter?(exec, MustUseModule)
    end

    test "a check the run does not list reports (nobody else will)" do
      exec = exec_with_checks([{MustUseModule, []}])

      assert Base.shared_failure_reporter?(exec, NoDependency)
    end

    test "an execution with no check list reports" do
      assert Base.shared_failure_reporter?(Credo.Execution.build(), NoDependency)
    end

    test "--checks / --ignore-checks filtering is honoured (the list the runner iterates)" do
      exec = %{
        exec_with_checks([{NoDependency, []}, {MustUseModule, []}])
        | ignore_checks: ["NoDependency"]
      }

      assert Base.shared_failure_reporter?(exec, MustUseModule)
    end

    test "--checks (only_checks) filtering is honoured" do
      exec = %{
        exec_with_checks([{NoDependency, []}, {MustUseModule, []}])
        | only_checks: ["MustUseModule"]
      }

      assert Base.shared_failure_reporter?(exec, MustUseModule)
    end

    # A shape Credo.Execution.checks/1 does not accept must not raise: a raise
    # inside a check is rescued by Credo's runner, and the check would then
    # report nothing at all.
    test "an execution whose check list has an unexpected shape reports" do
      exec = %{Credo.Execution.build() | checks: [{NoDependency, []}]}

      assert Base.shared_failure_reporter?(exec, NoDependency)
    end
  end

  describe "check_file/3 on an unparseable file" do
    test "returns an issue on that file instead of no issues" do
      broken = Credo.SourceFile.parse("defmodule Broken do\n  def go(\nend\n", "lib/broken.ex")

      rule = %{
        type: :no_direct_dependency,
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: []
      }

      assert [issue] = NoDependency.check_file(broken, [rule], [])
      assert issue.filename == "lib/broken.ex"
      assert issue.message =~ "could not parse"
      assert issue.message =~ "Fix:"
    end
  end

  defp exec_with_checks(checks) do
    %{Credo.Execution.build() | checks: %{enabled: checks, disabled: []}}
  end
end
