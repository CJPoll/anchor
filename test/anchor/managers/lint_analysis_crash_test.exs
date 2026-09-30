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
  # Sabotage records:
  #   ../../sabotage_records/lint-20260929-dnd_1310_analyzer_quote_crash.md
  #   ../../sabotage_records/base-20260929-dnd_1310_analyzer_quote_crash.md (check_file/3)
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

    # Raises on `lib/boom.ex`, throws on `lib/throw.ex`; detects as the real
    # check does everywhere else.
    @doc false
    def detect_violations(%{filename: "lib/boom.ex"}, _ast, _rules, _context),
      do: raise(ArgumentError, "injected by the test")

    def detect_violations(%{filename: "lib/throw.ex"}, _ast, _rules, _context),
      do: throw(:injected_by_the_test)

    def detect_violations(_source_file, ast, rules, _context),
      do: Anchor.Domain.Checks.SingleControlFlow.detect_violations(ast, rules)
  end

  # The real analyzer, except that it raises on a file defining `Boom`: in the
  # per-file facts (`FactsCrashAnalyzer`) or in the module-graph nodes
  # (`GraphCrashAnalyzer`).
  defmodule FactsCrashAnalyzer do
    @moduledoc false
    alias Anchor.Domain.DependencyAnalyzer

    def extract_module_names(ast) do
      names = DependencyAnalyzer.extract_module_names(ast)
      if Boom in names, do: raise(ArgumentError, "facts crash injected"), else: names
    end

    defdelegate extract_uses(ast), to: DependencyAnalyzer
    defdelegate module_dependencies(ast), to: DependencyAnalyzer
  end

  defmodule GraphCrashAnalyzer do
    @moduledoc false
    alias Anchor.Domain.DependencyAnalyzer

    defdelegate extract_module_names(ast), to: DependencyAnalyzer
    defdelegate extract_uses(ast), to: DependencyAnalyzer

    def module_dependencies(ast) do
      nodes = DependencyAnalyzer.module_dependencies(ast)

      if List.keymember?(nodes, Boom, 0),
        do: raise(ArgumentError, "graph crash injected"),
        else: nodes
    end
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

  test "a throw from a check is reported the same way" do
    thrower = SourceFile.parse(@clean, "lib/throw.ex")
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [@rule]}} end)

    assert {:ok, [{^thrower, [crash]}]} =
             Lint.run(RaisingCheck, [thrower], [], config_loader: ConfigLoaderMock)

    assert %Violation{kind: :fail_closed} = crash
    assert crash.message =~ "against it: throw: :injected_by_the_test"
  end

  describe "a crash deriving a file's facts (shared by every check)" do
    @boom """
    defmodule Boom do
      def go(x), do: x
    end
    """

    test "the shared-failure reporter reports it once, naming Anchor; the next file is checked" do
      boom = SourceFile.parse(@boom, "lib/boom_facts.ex")
      flagged = SourceFile.parse(@flagged, "lib/flagged.ex")
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [@rule]}} end)

      assert {:ok, [{^boom, [crash]}, {^flagged, [flag]}]} =
               Lint.run(Anchor.Check.SingleControlFlow, [boom, flagged], [],
                 config_loader: ConfigLoaderMock,
                 analyzer: FactsCrashAnalyzer
               )

      assert %Violation{kind: :fail_closed, trigger: "Anchor"} = crash

      assert crash.message =~
               "Anchor crashed analysing this file, so no Anchor rule was checked against it: " <>
                 "ArgumentError: facts crash injected"

      assert %Violation{kind: :rule, trigger: "go"} = flag
    end

    test "every other check stays quiet about it" do
      boom = SourceFile.parse(@boom, "lib/boom_facts.ex")
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [@rule]}} end)

      assert {:ok, [{^boom, []}]} =
               Lint.run(Anchor.Check.SingleControlFlow, [boom], [],
                 config_loader: ConfigLoaderMock,
                 analyzer: FactsCrashAnalyzer,
                 report_shared_failures: false
               )
    end

    test "the file counts toward a pattern rule's floor as an unparsed file does" do
      boom = SourceFile.parse(@boom, "lib/boom_facts.ex")
      rule = %{type: :single_control_flow, pattern: "Boom"}
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      # No `{:config, [floor violation]}` entry: the crash is the report.
      assert {:ok, [{^boom, [%Violation{kind: :fail_closed, trigger: "Anchor"}]}]} =
               Lint.run(Anchor.Check.SingleControlFlow, [boom], [],
                 config_loader: ConfigLoaderMock,
                 analyzer: FactsCrashAnalyzer
               )
    end
  end

  describe "a crash building a file's module-graph nodes" do
    @boom_graph """
    defmodule Boom do
      def go, do: Forbidden.Mod.call()
    end
    """

    @other """
    defmodule MyApp.Other do
      def go, do: Forbidden.Mod.call()
    end
    """

    test "the graph check reports it on that file; the other file is still checked" do
      boom = SourceFile.parse(@boom_graph, "lib/boom_graph.ex")
      other = SourceFile.parse(@other, "lib/other.ex")

      rule = %{
        type: :no_transitive_dependency,
        paths: ["lib/**/*.ex"],
        recursive: true,
        forbidden_modules: [Forbidden.Mod]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^boom, [crash]}, {^other, [flag]}]} =
               Lint.run(Anchor.Check.NoTransitiveDependency, [boom, other], [],
                 config_loader: ConfigLoaderMock,
                 analyzer: GraphCrashAnalyzer
               )

      assert %Violation{kind: :fail_closed, trigger: "Anchor.Check.NoTransitiveDependency"} =
               crash

      assert crash.message =~ "ArgumentError: graph crash injected"
      assert %Violation{kind: :rule, trigger: "Forbidden.Mod"} = flag
    end
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
