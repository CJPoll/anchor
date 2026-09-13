defmodule Anchor.Domain.Checks.NoDependencyTest do
  # Pure Domain detection for the `no_direct_dependency` check:
  # (bare AST, already-selected rules) in, `[%Violation{}]` out. No Credo types,
  # no IO. Rule SELECTION is the Manager's job; the Framework mapping to
  # `Credo.Issue` is Base's job and is exercised via `Anchor.Check.NoDependency`
  # in test/anchor/check/no_dependency_test.exs.
  #
  # This suite covers Gap A (`forbidden_patterns`) and Gap A' (`match` mode) added
  # in DND-142; the pre-existing exact-`forbidden_modules` behavior and the
  # Gap-B Erlang-atom path are exercised end-to-end in the Framework suite.
  #
  # Matrix: docs/phase-d-gap-test-matrix.md
  #   "lib/anchor/domain/checks/no_dependency.ex -> detect_violations/2 -> #1-10".
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_dependency-20260913-dnd_142_gap_a_forbidden_patterns_match.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp detect(source, rule), do: NoDependency.detect_violations(ast(source), [rule])

  describe "detect_violations/2 — forbidden_patterns and match (Gap A + A')" do
    # Matrix row 1 — Happy Path: a pattern flags a matching dependency.
    test "forbidden_patterns flags a matching dependency" do
      source = """
      defmodule W do
        def f do
          WaltUi.Contacts.Adapters.Repositories.Repository.all(q)
        end
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}

      assert [%Violation{} = violation] = detect(source, rule)

      assert violation.message ==
               "Module has forbidden direct dependency on WaltUi.Contacts.Adapters.Repositories.Repository"

      assert violation.trigger == "WaltUi.Contacts.Adapters.Repositories.Repository"
      assert violation.line == 3
    end

    # Matrix row 2 — Positive Control: a Domain-only file passes the pattern rule.
    test "a Domain-only file passes the pattern rule" do
      source = """
      defmodule W do
        def f, do: WaltUi.Contacts.Domain.Foo.call(q)
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}

      assert detect(source, rule) == []
    end

    # Matrix row 3 — Validation: the pattern is dot-bounded (no substring match).
    test "the pattern is dot-bounded — AdaptersHelper does not match *.Adapters.*" do
      source = """
      defmodule W do
        def f, do: Foo.AdaptersHelper.call(q)
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}

      assert detect(source, rule) == []
    end

    # Matrix row 4 — Happy Path: forbidden_modules and forbidden_patterns both fire.
    test "forbidden_modules and forbidden_patterns both fire" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(q)
        def g, do: X.Adapters.Y.call(q)
      end
      """

      rule = %{
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: ["*.Adapters.*"],
        match: :reference
      }

      violations = detect(source, rule)

      assert length(violations) == 2

      triggers = violations |> Enum.map(& &1.trigger) |> MapSet.new()
      assert triggers == MapSet.new(["MyApp.Repo", "X.Adapters.Y"])
    end

    # Matrix row 5 — Control Flow Decisioning: a pattern-matched module is
    # reported once, at its first reference line.
    test "a pattern-matched module referenced twice is reported once at the first line" do
      source = """
      defmodule W do
        def f, do: X.Adapters.Y.a(q)
        def g, do: :noop
        def h, do: X.Adapters.Y.b(q)
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}

      assert [%Violation{} = violation] = detect(source, rule)
      assert violation.trigger == "X.Adapters.Y"
      assert violation.line == 2
    end

    # Matrix row 6 — Happy Path: match: :reference (default) flags an inert
    # reference (an alias held as a map value, never called).
    test "match: :reference flags an inert alias held as a map value" do
      source = """
      defmodule W do
        @config %{a: Foo.Adapters.L}
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}

      assert [%Violation{} = violation] = detect(source, rule)
      assert violation.trigger == "Foo.Adapters.L"
      assert violation.line == 2
    end

    # Matrix row 7 — Validation (router carve-out): match: :call passes the same
    # inert map value.
    test "match: :call passes an inert alias held as a map value" do
      source = """
      defmodule W do
        @config %{a: Foo.Adapters.L}
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :call}

      assert detect(source, rule) == []
    end

    # Matrix row 8 — Happy Path: match: :call flags a real call.
    test "match: :call flags a real call on the forbidden pattern" do
      source = """
      defmodule W do
        def f, do: Foo.Adapters.L.enrich(x)
      end
      """

      rule = %{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :call}

      assert [%Violation{} = violation] = detect(source, rule)
      assert violation.trigger == "Foo.Adapters.L"
      assert violation.line == 2
    end

    # Matrix row 9 — Happy Path (B): an Erlang-atom forbidden_modules entry flags
    # a bare-atom remote call.
    test "an Erlang-atom forbidden_modules entry flags a remote atom call" do
      source = """
      defmodule W do
        def f, do: :telemetry.execute(a, b, c)
      end
      """

      rule = %{forbidden_modules: [:telemetry], forbidden_patterns: [], match: :reference}

      assert [%Violation{} = violation] = detect(source, rule)
      assert violation.trigger == ":telemetry"
      assert violation.line == 2
    end

    # Matrix row 10 — Positive Control: a clean file under both selectors passes.
    test "a clean file passes under both selectors" do
      source = """
      defmodule W do
        def f, do: Enum.map([1], & &1)
      end
      """

      rule = %{
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: ["*.Adapters.*"],
        match: :reference
      }

      assert detect(source, rule) == []
    end
  end
end
