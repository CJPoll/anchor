defmodule Anchor.Check.NoDependencyTest do
  # Acceptance tests for Anchor.Check.NoDependency (T6.1 / DND-126).
  #
  # Detection now lives in the pure Domain module Anchor.Domain.Checks.NoDependency;
  # this suite exercises the check's observable contract end-to-end through the thin
  # Framework shell: `check_file/3` takes a real `Credo.SourceFile` and returns
  # `[%Credo.Issue{}]`. These rows assert the *intended* behaviour in
  # docs/five-bucket-test-matrix.md ("no_dependency.ex -> check_file/3 -> #1-8"),
  # which supersedes the T1 characterization pins — in particular row 7 now reports
  # every reference line, so a line-level disable covers only its own line.
  #
  # Sabotage record: ../../sabotage_records/no_dependency-20260913-dnd_126_t6_1_no_dependency.md
  use ExUnit.Case, async: true

  alias Anchor.Check.NoDependency
  alias Credo.SourceFile

  defp issues(source, forbidden_modules) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :no_direct_dependency, forbidden_modules: forbidden_modules}
    NoDependency.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row 1 — Happy Path
    test "flags a direct dependency on a forbidden module" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
      end
      """

      assert [issue] = issues(source, [MyApp.Repo])

      assert issue.message ==
               "Module has forbidden direct dependency on MyApp.Repo" <>
                 ". Fix: do not reference MyApp.Repo from a module this rule selects; reach it through a module the rule allows"

      assert issue.trigger == "MyApp.Repo"
      assert issue.line_no == 2
    end

    # Row 2 — Happy Path
    test "flags a forbidden dep referenced only in a qualified call" do
      source = """
      defmodule W do
        def f do
          Ecto.Query.from(x in "t")
        end
      end
      """

      assert [issue] = issues(source, [Ecto.Query])
      assert issue.trigger == "Ecto.Query"
      assert issue.line_no == 3
    end

    # Row 3 — Happy Path
    test "flags each distinct forbidden module once" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
        def g, do: System.halt()
      end
      """

      issues = issues(source, [MyApp.Repo, System])
      triggers = issues |> Enum.map(& &1.trigger) |> Enum.sort()

      assert length(issues) == 2
      assert triggers == ["MyApp.Repo", "System"]
    end

    # Row 4 — Positive Control
    test "clean module with no forbidden dep returns no issues" do
      source = """
      defmodule W do
        def f, do: Enum.map([], & &1)
      end
      """

      assert issues(source, [MyApp.Repo]) == []
    end

    # Row 5 — Positive Control
    test "forbidden module named but not referenced returns no issues" do
      source = """
      defmodule W do
        def f, do: MyApp.Other.call()
      end
      """

      assert issues(source, [MyApp.Repo]) == []
    end

    # Row 6 — Validation
    test "empty forbidden list flags nothing" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
      end
      """

      assert issues(source, []) == []
    end

    # Row 7 — Control Flow Decisioning: every reference line when a module
    # appears twice (references on lines 2 and 4 -> reported at both).
    test "reports each reference line when a forbidden module appears twice" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)

        def g, do: MyApp.Repo.one(Q)
      end
      """

      assert [first, second] = issues(source, [MyApp.Repo])
      assert {first.line_no, second.line_no} == {2, 4}
    end

    # Row 8 — Rule Selection: a rule that does not select the file never reaches
    # check_file/3 (Base filters by path first), so the check sees no rules and
    # emits nothing. A positive control (row 1) proves the same source DOES flag
    # when the rule is present.
    test "rule not selecting the file yields nothing" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
      end
      """

      source_file = SourceFile.parse(source, "lib/some_module.ex")
      assert NoDependency.check_file(source_file, [], []) == []
    end
  end

  # Every reference site is reported at its own line, so a Credo line-level
  # disable excuses exactly the line under it and never a later reference.
  # `issues_after_disables/2` applies Credo's own comment filter
  # (`Credo.CLI.Filter`) to the check's issues, as `mix credo` does.
  describe "check_file/3 — every reference site, so a disable covers one line" do
    defp issues_after_disables(source, forbidden_modules) do
      source_file = SourceFile.parse(source, "lib/some_module.ex")

      comment_map =
        case Credo.Check.ConfigCommentFinder.find_and_set_in_source_file(source_file) do
          nil -> %{}
          {filename, comments} -> %{filename => comments}
        end

      issues = NoDependency.check_file(source_file, [rule(forbidden_modules)], [])

      Credo.CLI.Filter.valid_issues(issues, %{config_comment_map: comment_map})
    end

    defp rule(forbidden_modules),
      do: %{type: :no_direct_dependency, forbidden_modules: forbidden_modules}

    test "a disable on the first reference does not hide the second" do
      source = """
      defmodule Sample.Web.Thing do
        # credo:disable-for-next-line Anchor.Check.NoDependency
        def f, do: Sample.Repo.all(Q)

        def g, do: Sample.Repo.one(Q)
      end
      """

      assert [issue] = issues_after_disables(source, [Sample.Repo])
      assert issue.line_no == 5
      assert issue.trigger == "Sample.Repo"
    end

    test "a disable on every reference reports nothing" do
      source = """
      defmodule Sample.Web.Thing do
        # credo:disable-for-next-line Anchor.Check.NoDependency
        def f, do: Sample.Repo.all(Q)

        # credo:disable-for-next-line Anchor.Check.NoDependency
        def g, do: Sample.Repo.one(Q)
      end
      """

      assert issues_after_disables(source, [Sample.Repo]) == []
    end

    test "no disable reports every reference, each at its own line" do
      source = """
      defmodule Sample.Web.Thing do
        def f, do: Sample.Repo.all(Q)

        def g, do: Sample.Repo.one(Q)
      end
      """

      assert [first, second] = issues_after_disables(source, [Sample.Repo])
      assert {first.line_no, second.line_no} == {2, 4}
    end

    test "a disable on the first call of a forbidden function does not hide the second" do
      source = """
      defmodule Sample.Web.Thing do
        # credo:disable-for-next-line Anchor.Check.NoDependency
        def f, do: Sample.Repo.all(Q)

        def g, do: Sample.Repo.all(Q)
      end
      """

      source_file = SourceFile.parse(source, "lib/some_module.ex")

      {filename, comments} =
        Credo.Check.ConfigCommentFinder.find_and_set_in_source_file(source_file)

      rule = %{
        type: :no_direct_dependency,
        forbidden_modules: [],
        forbidden_functions: [
          %Anchor.Domain.FunctionRef{module: Sample.Repo, function: :all, arity: :any}
        ]
      }

      issues = NoDependency.check_file(source_file, [rule], [])

      assert [issue] =
               Credo.CLI.Filter.valid_issues(issues, %{
                 config_comment_map: %{filename => comments}
               })

      assert issue.line_no == 5
    end

    test "two references to one module on a single line are one issue" do
      source = """
      defmodule Sample.Web.Thing do
        def f, do: Sample.Repo.all(Sample.Repo.query())
      end
      """

      assert [issue] = issues_after_disables(source, [Sample.Repo])
      assert issue.line_no == 2
    end
  end

  describe "check_file/3 — Erlang-atom forbidden module (Gap B / DND-141, integration)" do
    # End-to-end through the wired Framework shell, no mocks: an Erlang/OTP atom
    # `forbidden_modules` entry flags a bare-atom remote call.
    # Sabotage record: ../../sabotage_records/dependency_analyzer-20260913-dnd_141_gap_b_erlang_atom_targets.md

    # Matrix (no_dependency.ex) row 9 — Happy Path
    test "an atom forbidden module flags a bare-atom remote call at its first line" do
      source = """
      defmodule W do
        def f, do: :telemetry.execute([:a], %{}, %{})
      end
      """

      assert [issue] = issues(source, [:telemetry])

      assert issue.message ==
               "Module has forbidden direct dependency on :telemetry" <>
                 ". Fix: do not reference :telemetry from a module this rule selects; reach it through a module the rule allows"

      assert issue.trigger == ":telemetry"
      assert issue.line_no == 2
    end

    # Reports each reference line for a bare-atom module appearing twice — the
    # atom-path analogue of the alias-path row above (proves every site of a bare
    # atom is found, and that the walk never calls `Module.split/1` on one).
    test "reports each reference line for a bare-atom module referenced twice" do
      source = """
      defmodule W do
        def f, do: :telemetry.execute([:a], %{}, %{})

        def g, do: :telemetry.execute([:b], %{}, %{})
      end
      """

      assert [first, second] = issues(source, [:telemetry])
      assert {first.line_no, second.line_no} == {2, 4}
    end

    # Absence assertion (paired with the row-9 positive control above): an inert
    # `:ok` is never recorded, so an `:ok` rule flags nothing.
    test "an inert :ok atom literal is never flagged" do
      source = """
      defmodule W do
        def f, do: :ok
      end
      """

      assert issues(source, [:ok]) == []
    end

    # Positive control — Elixir alias behavior is unchanged alongside the atom rule.
    test "Elixir Logger behavior is unchanged when an atom rule is also present" do
      source = """
      defmodule W do
        def f, do: Logger.info("x")
      end
      """

      assert [issue] = issues(source, [Logger, :telemetry])
      assert issue.trigger == "Logger"
      assert issue.line_no == 2
    end
  end

  # Gap F (DND-150): detect_violations/4 derives the file's own context from
  # `context.module_names` (threaded by the Manager) and passes it to the Domain
  # detector so `same_context` rules scope their pattern matches. This exercises
  # the Framework edge's context derivation; the Violation → Credo.Issue mapping
  # is Base's job (covered above and in the domain suite). A returned
  # `%Violation{}` maps 1:1 to a Credo issue.
  #
  # Matrix: docs/gap-f-same-context-test-matrix.md
  #   "lib/anchor/check/no_dependency.ex -> detect_violations/4 -> #1-5".
  #
  # Sabotage record:
  #   ../../sabotage_records/no_dependency-20260913-dnd_150_a2_same_context_detection.md
  describe "detect_violations/4 — same_context context derivation (Gap F)" do
    alias Anchor.Check.Source
    alias Anchor.Domain.Violation

    defp same_context_rule do
      %{
        type: :no_direct_dependency,
        forbidden_modules: [],
        forbidden_patterns: ["*.Managers.*"],
        match: :call,
        same_context: true,
        context_depth: 2
      }
    end

    defp detect4(source, rules, module_names) do
      source_file = SourceFile.parse(source, "lib/some_module.ex")
      ast = Source.ast(source_file)
      input = %Anchor.Domain.Detector.Input{ast: ast, rules: rules, module_names: module_names}
      NoDependency.__anchor_detector__().detect(input)
    end

    # Matrix row 1 — Happy Path: file context derived from the file's own module.
    test "derives the file's context from its defining module name" do
      source = """
      defmodule WaltUi.Contacts.Adapters.Foo do
        def f, do: WaltUi.Contacts.Managers.Bar.run(x)
      end
      """

      assert [%Violation{trigger: "WaltUi.Contacts.Managers.Bar"}] =
               detect4(source, [same_context_rule()], ["WaltUi.Contacts.Adapters.Foo"])
    end

    # Matrix row 2 — Control Flow: cross-context dep under the derived context.
    test "does not flag a cross-context dep under the derived file context" do
      source = """
      defmodule WaltUi.Contacts.Adapters.Foo do
        def f, do: WaltUi.Search.Managers.Baz.run(x)
      end
      """

      assert detect4(source, [same_context_rule()], ["WaltUi.Contacts.Adapters.Foo"]) == []
    end

    # Matrix row 3 — Control Flow: a non-same_context rule is unchanged.
    test "a non-same_context rule is unaffected by module_names threading" do
      source = """
      defmodule WaltUi.Contacts.Adapters.Foo do
        def f, do: MyApp.Repo.all(q)
      end
      """

      rule = %{
        type: :no_direct_dependency,
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: [],
        match: :reference
      }

      assert [%Violation{trigger: "MyApp.Repo"}] =
               detect4(source, [rule], ["WaltUi.Contacts.Adapters.Foo"])
    end

    # Matrix row 4 — Control Flow: context derived from the FIRST module.
    test "derives context from the first module when the file defines several" do
      source = """
      defmodule WaltUi.Contacts.Adapters.Foo do
        def f, do: WaltUi.Contacts.Managers.Bar.run(x)
      end

      defmodule WaltUi.Contacts.Adapters.Baz do
        def g, do: :noop
      end
      """

      module_names = ["WaltUi.Contacts.Adapters.Foo", "WaltUi.Contacts.Adapters.Baz"]

      assert [%Violation{trigger: "WaltUi.Contacts.Managers.Bar"}] =
               detect4(source, [same_context_rule()], module_names)
    end

    # Matrix row 5 — Error Handling: no derivable module name ⇒ nil context, no crash.
    test "an empty module_names list yields no scoped issues and does not crash" do
      source = """
      defmodule W do
        def f, do: WaltUi.Contacts.Managers.Bar.run(x)
      end
      """

      assert detect4(source, [same_context_rule()], []) == []
    end
  end

  describe "check_file/3 — alias and import resolution (DND-1266)" do
    # End-to-end through the Credo shell: a multi-alias evaded both match modes
    # before DND-1266, so a forbidden module reached through `alias A.{B, C}`
    # produced no issue at all.
    # Sabotage record: ../../sabotage_records/dependency_analyzer-20260929-dnd_1266_alias_import_resolution.md
    for mode <- [:reference, :call] do
      test "flags a forbidden module reached through a multi-alias (match: #{mode})" do
        source = """
        defmodule W do
          alias MyApp.{Repo, Other}

          def f, do: Repo.all(Q)
        end
        """

        source_file = SourceFile.parse(source, "lib/some_module.ex")

        rule = %{
          type: :no_direct_dependency,
          forbidden_modules: [MyApp.Repo],
          match: unquote(mode)
        }

        # The `alias` line is a site of its own in reference mode; the call is
        # the only site in call mode.
        issues = NoDependency.check_file(source_file, [rule], [])

        assert Enum.map(issues, &{&1.line_no, &1.trigger}) ==
                 Enum.map(
                   unquote(if mode == :reference, do: [2, 4], else: [4]),
                   &{&1, "MyApp.Repo"}
                 )
      end
    end
  end

  describe "rule_type/0" do
    test "is :no_direct_dependency" do
      assert NoDependency.__anchor_detector__().rule_type() == :no_direct_dependency
    end
  end
end
