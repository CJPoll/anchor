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

  # DND-1290: whether this run saw the whole configured file set. A rule that
  # selects zero files is only a finding when it had every file to select from;
  # `mix credo lib/a.ex`, stdin and a watch-mode rerun hand a check a subset.
  # Sabotage record: ../../sabotage_records/base-20260929-dnd_1290_empty_relation_list.md
  describe "whole_file_set?/2" do
    test "an execution with no CLI options (a direct call) is the whole set" do
      assert Base.whole_file_set?(Credo.Execution.build(), [])
    end

    test "a run over the working directory is the whole set" do
      assert Base.whole_file_set?(exec_with_cli(File.cwd!(), %{}), [])
    end

    test "explicit files on the command line are a subset" do
      refute Base.whole_file_set?(exec_with_cli(File.cwd!(), %{files_included: ["lib/a.ex"]}), [])
    end

    test "a subdirectory path is a subset" do
      refute Base.whole_file_set?(exec_with_cli(Path.join(File.cwd!(), "lib"), %{}), [])
    end

    test "a --working-dir run over that directory is the whole set" do
      dir = Path.join(File.cwd!(), "lib")
      assert Base.whole_file_set?(exec_with_cli(dir, %{working_dir: dir}), [])
    end

    test "reading from stdin is a subset" do
      exec = %{exec_with_cli(File.cwd!(), %{}) | read_from_stdin: true}
      refute Base.whole_file_set?(exec, [])
    end

    test "a watch-mode rerun is a subset" do
      params = Credo.Check.Params.put_rerun_files_that_changed([], ["lib/a.ex"])
      refute Base.whole_file_set?(exec_with_cli(File.cwd!(), %{}), params)
    end
  end

  # DND-1290: the rule types some enabled Anchor check reads, or `:unknown`.
  describe "enabled_rule_types/1" do
    test "names the rule types of the enabled Anchor checks" do
      exec =
        exec_with_checks([
          {Credo.Check.Readability.ModuleNames, []},
          {NoDependency, []},
          {MustUseModule, false}
        ])

      assert Base.enabled_rule_types(exec) == {:ok, [:no_direct_dependency]}
    end

    test "an execution with no check list is unknown" do
      assert Base.enabled_rule_types(Credo.Execution.build()) == :unknown
    end

    test "--checks or --ignore-checks filtering makes it unknown (a deliberate subset)" do
      base = exec_with_checks([{NoDependency, []}, {MustUseModule, []}])

      assert Base.enabled_rule_types(%{base | only_checks: ["NoDependency"]}) == :unknown
      assert Base.enabled_rule_types(%{base | ignore_checks: ["NoDependency"]}) == :unknown
      assert Base.enabled_rule_types(%{base | only_checks_tags: [:x]}) == :unknown
      assert Base.enabled_rule_types(%{base | ignore_checks_tags: [:x]}) == :unknown
    end

    test "a check list of an unexpected shape is unknown" do
      exec = %{Credo.Execution.build() | checks: [{NoDependency, []}]}

      assert Base.enabled_rule_types(exec) == :unknown
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

  defp exec_with_cli(path, switches) do
    %{Credo.Execution.build() | cli_options: %Credo.CLI.Options{path: path, switches: switches}}
  end
end
