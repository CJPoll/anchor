defmodule Anchor.Domain.Checks.ModulePatternRestrictionsTest do
  # Pure Domain detection for the `module_pattern_restrictions` check:
  # (bare AST, rules) in, `[%Violation{}]` out. No Credo types, no IO. The
  # Framework mapping to `Credo.Issue` (and the full 9-row acceptance matrix) is
  # exercised in test/anchor/check/module_pattern_restrictions_test.exs.
  #
  # Sabotage record:
  # ../../../sabotage_records/module_pattern_restrictions-20260913-dnd_129_t6_4_module_pattern_restrictions.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.ModulePatternRestrictions
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp uses_rule(allowed), do: %{uses_module: "Ecto.Schema", allowed_functions: allowed}

  describe "detect_violations/2 — function checking" do
    test "flags a non-allowed function (message/trigger/line)" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def custom, do: :x
        end
        """)

      assert [%Violation{} = violation] =
               ModulePatternRestrictions.detect_violations(ast, [uses_rule(["changeset"])])

      assert violation.message == "Module defines non-allowed function: custom"
      assert violation.trigger == "custom"
      assert violation.line == 3
    end

    test "passes when only allowed functions are defined" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def changeset(u, a), do: {u, a}
        end
        """)

      assert ModulePatternRestrictions.detect_violations(ast, [uses_rule(["changeset"])]) == []
    end

    test "flags a private function too" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          defp helper, do: :x
        end
        """)

      assert [%Violation{trigger: "helper"}] =
               ModulePatternRestrictions.detect_violations(ast, [uses_rule([])])
    end

    test "empty allowed list flags every defined function" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def a, do: 1
          def b(x), do: x
        end
        """)

      triggers =
        ast
        |> ModulePatternRestrictions.detect_violations([uses_rule([])])
        |> Enum.map(& &1.trigger)
        |> Enum.sort()

      assert triggers == ["a", "b"]
    end

    test "nil allowed_functions is treated as empty and flags every function" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def a, do: 1
        end
        """)

      assert [%Violation{trigger: "a"}] =
               ModulePatternRestrictions.detect_violations(ast, [
                 %{uses_module: "Ecto.Schema", allowed_functions: nil}
               ])
    end

    test "multi-clause function is reported once (name deduped)" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def foo(1), do: :one
          def foo(_), do: :other
        end
        """)

      assert [%Violation{trigger: "foo"}] =
               ModulePatternRestrictions.detect_violations(ast, [uses_rule([])])
    end
  end

  describe "detect_violations/2 — allowed_functions glob" do
    test "`with_*` allows every `with_`-prefixed function" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def with_status(x), do: x
          def new, do: :n
        end
        """)

      assert ModulePatternRestrictions.detect_violations(ast, [uses_rule(["new", "with_*"])]) ==
               []
    end

    test "`with_*` still flags a non-matching function" do
      ast =
        ast("""
        defmodule S do
          use Ecto.Schema
          def with_status(x), do: x
          def delete(x), do: x
        end
        """)

      assert [%Violation{trigger: "delete"}] =
               ModulePatternRestrictions.detect_violations(ast, [uses_rule(["with_*"])])
    end
  end

  describe "detect_violations/2 — selection" do
    test "uses_module rule not matching the file yields nothing" do
      ast =
        ast("""
        defmodule S do
          def custom, do: :x
        end
        """)

      assert ModulePatternRestrictions.detect_violations(ast, [uses_rule([])]) == []
    end

    test "pattern rule matching a module name selects the file" do
      ast =
        ast("""
        defmodule MyApp.Schemas.User do
          def custom, do: :x
        end
        """)

      rule = %{pattern: "*.Schemas.*", allowed_functions: []}

      assert [%Violation{trigger: "custom"}] =
               ModulePatternRestrictions.detect_violations(ast, [rule])
    end

    test "pattern rule not matching any module name yields nothing" do
      ast =
        ast("""
        defmodule MyApp.Service do
          def custom, do: :x
        end
        """)

      rule = %{pattern: "*.Schemas.*", allowed_functions: []}

      assert ModulePatternRestrictions.detect_violations(ast, [rule]) == []
    end

    test "empty rule list flags nothing" do
      ast =
        ast("""
        defmodule S do
          def custom, do: :x
        end
        """)

      assert ModulePatternRestrictions.detect_violations(ast, []) == []
    end
  end
end
