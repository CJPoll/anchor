defmodule Anchor.Check.NoDependencyTest do
  # Acceptance tests for Anchor.Check.NoDependency (T6.1 / DND-126).
  #
  # Detection now lives in the pure Domain module Anchor.Domain.Checks.NoDependency;
  # this suite exercises the check's observable contract end-to-end through the thin
  # Framework shell: `check_file/3` takes a real `Credo.SourceFile` and returns
  # `[%Credo.Issue{}]`. These rows assert the *intended* behaviour in
  # docs/five-bucket-test-matrix.md ("no_dependency.ex -> check_file/3 -> #1-8"),
  # which supersedes the T1 characterization pins — in particular row 7 now reports
  # the FIRST reference line, not the last.
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
      assert issue.message == "Module has forbidden direct dependency on MyApp.Repo"
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

    # Row 7 — Control Flow Decisioning: FIRST reference line when a module
    # appears twice (references on lines 2 and 4 -> reported at line 2).
    test "reports the first reference line when a forbidden module appears twice" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)

        def g, do: MyApp.Repo.one(Q)
      end
      """

      assert [issue] = issues(source, [MyApp.Repo])
      assert issue.line_no == 2
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

  describe "rule_type/0" do
    test "is :no_direct_dependency" do
      assert NoDependency.rule_type() == :no_direct_dependency
    end
  end
end
