defmodule Anchor.Check.ModulePatternRestrictionsTest do
  # Acceptance tests for Anchor.Check.ModulePatternRestrictions (T6.4 / DND-129).
  #
  # Detection now lives in the pure Domain module
  # Anchor.Domain.Checks.ModulePatternRestrictions; this suite exercises the
  # check's observable contract end-to-end through the thin Framework shell:
  # `check_file/3` takes a real `Credo.SourceFile` and returns `[%Credo.Issue{}]`.
  # These rows assert docs/five-bucket-test-matrix.md
  # ("module_pattern_restrictions.ex -> check_file/3 -> #1-9"), including the
  # adjudicated fixes: `allowed_functions` glob support (rows 5-6), multi-clause
  # name dedup (row 8), and module-based rule selection (row 9). Selection is
  # exercised via SPARSE rule maps (no `:paths` key), the only way
  # `pattern`/`uses_module` selection is observable — see the matrix note on the
  # pre-existing `paths: []` selection shadow.
  #
  # Sabotage record:
  # ../../sabotage_records/module_pattern_restrictions-20260913-dnd_129_t6_4_module_pattern_restrictions.md
  use ExUnit.Case, async: true

  alias Anchor.Check.ModulePatternRestrictions
  alias Credo.SourceFile

  defp issues(source, rule) do
    source_file = SourceFile.parse(source, "lib/my_app/user.ex")
    ModulePatternRestrictions.check_file(source_file, [rule], [])
  end

  defp uses_rule(allowed) do
    %{type: :module_pattern_restrictions, uses_module: "Ecto.Schema", allowed_functions: allowed}
  end

  describe "check_file/3" do
    # Row 1 — Happy Path
    test "flags a non-allowed public function (message/trigger/line 7)" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema

        schema "users" do
          field :name, :string
        end
        def custom_function, do: :not_allowed
      end
      """

      rule = uses_rule(["changeset", "__changeset__", "__schema__", "__struct__"])

      assert [issue] = issues(source, rule)
      assert issue.message == "Module defines non-allowed function: custom_function"
      assert issue.trigger == "custom_function"
      assert issue.line_no == 7
    end

    # Row 2 — Positive Control
    test "passes when only allowed functions are defined" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema

        def changeset(user, attrs) do
          {user, attrs}
        end
      end
      """

      rule = uses_rule(["changeset", "__changeset__", "__schema__", "__struct__"])

      assert issues(source, rule) == []
    end

    # Row 3 — Validation
    test "flags a non-allowed private function too" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        defp helper, do: :x
      end
      """

      assert [issue] = issues(source, uses_rule([]))
      assert issue.trigger == "helper"
    end

    # Row 4 — Happy Path
    test "empty allowed list flags every defined function" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        def a, do: 1
        def b(x), do: x
      end
      """

      issues = issues(source, uses_rule([]))
      triggers = issues |> Enum.map(& &1.trigger) |> Enum.sort()

      assert length(issues) == 2
      assert triggers == ["a", "b"]
    end

    # Row 5 — Happy Path (glob allow)
    test "glob/prefix allow pattern honored (`with_*`)" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        def with_status(x), do: x
        def new, do: :n
      end
      """

      assert issues(source, uses_rule(["new", "with_*"])) == []
    end

    # Row 6 — Control Flow Decisioning (glob still flags non-match)
    test "prefix pattern still flags a non-matching function" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        def with_status(x), do: x
        def delete(x), do: x
      end
      """

      assert [issue] = issues(source, uses_rule(["with_*"]))
      assert issue.trigger == "delete"
    end

    # Row 7 — High Signal (reported at definition line 5)
    test "function reported at its definition line" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        def changeset(u, a), do: {u, a}

        def custom, do: :x
      end
      """

      assert [issue] = issues(source, uses_rule(["changeset"]))
      assert issue.trigger == "custom"
      assert issue.line_no == 5
    end

    # Row 8 — Control Flow Decisioning (multi-clause deduped)
    test "multi-clause non-allowed function reported once" do
      source = """
      defmodule MyApp.User do
        use Ecto.Schema
        def foo(1), do: :one
        def foo(_), do: :other
      end
      """

      assert [issue] = issues(source, uses_rule([]))
      assert issue.trigger == "foo"
    end

    # Row 9 — Rule Selection (uses_module does not match -> nothing).
    # Positive control: row 1 proves the same shape DOES flag when selected.
    test "rule not selecting the file (uses_module) yields nothing" do
      source = """
      defmodule MyApp.Service do
        def custom_function, do: :x
      end
      """

      assert issues(source, uses_rule([])) == []
    end
  end

  describe "rule_type/0" do
    test "is :module_pattern_restrictions" do
      assert ModulePatternRestrictions.rule_type() == :module_pattern_restrictions
    end
  end
end
