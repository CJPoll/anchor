defmodule Anchor.Domain.Checks.MustUseModuleTest do
  # Pure Domain detection for the `must_use_module` check: (bare AST, rules) in,
  # `[%Violation{}]` out. No Credo types, no IO. The Framework mapping to
  # `Credo.Issue` is exercised in test/anchor/check/must_use_module_test.exs.
  #
  # Sabotage record: ../../../sabotage_records/must_use_module-20260913-dnd_128_t6_3_must_use_module.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.MustUseModule
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp rule(required_modules), do: %{type: :must_use_module, required_modules: required_modules}

  describe "detect_violations/2" do
    test "flags a module missing a required use (message/trigger/line)" do
      ast =
        ast("""
        defmodule S do
          def f, do: :ok
        end
        """)

      assert [%Violation{} = violation] =
               MustUseModule.detect_violations(ast, [rule([MyApp.Schema])])

      assert violation.message == "Module must use MyApp.Schema"
      assert violation.trigger == "MyApp.Schema"
      assert violation.line == 1
    end

    test "passes when the required module is used" do
      ast =
        ast("""
        defmodule S do
          use MyApp.Schema
          def f, do: :ok
        end
        """)

      assert MustUseModule.detect_violations(ast, [rule([MyApp.Schema])]) == []
    end

    test "flags each missing required module separately" do
      ast =
        ast("""
        defmodule S do
          def f, do: :ok
        end
        """)

      violations = MustUseModule.detect_violations(ast, [rule([MyApp.Schema, MyApp.Base])])
      triggers = violations |> Enum.map(& &1.trigger) |> Enum.sort()

      assert length(violations) == 2
      assert triggers == ["MyApp.Base", "MyApp.Schema"]
    end

    test "one of two required modules present flags only the missing one" do
      ast =
        ast("""
        defmodule S do
          use MyApp.Schema
          def f, do: :ok
        end
        """)

      assert [%Violation{} = violation] =
               MustUseModule.detect_violations(ast, [rule([MyApp.Schema, MyApp.Base])])

      assert violation.trigger == "MyApp.Base"
    end

    test "`use ModName, opts` still counts as a use" do
      ast =
        ast("""
        defmodule S do
          use MyApp.Schema, :controller
          def f, do: :ok
        end
        """)

      assert MustUseModule.detect_violations(ast, [rule([MyApp.Schema])]) == []
    end

    test "empty required list flags nothing" do
      ast =
        ast("""
        defmodule S do
          def f, do: :ok
        end
        """)

      assert MustUseModule.detect_violations(ast, [rule([])]) == []
    end

    test "nil required_modules is treated as empty and flags nothing" do
      ast =
        ast("""
        defmodule S do
          def f, do: :ok
        end
        """)

      assert MustUseModule.detect_violations(ast, [
               %{type: :must_use_module, required_modules: nil}
             ]) ==
               []
    end

    test "no matching rules (empty rule list) flags nothing" do
      ast =
        ast("""
        defmodule S do
          def f, do: :ok
        end
        """)

      assert MustUseModule.detect_violations(ast, []) == []
    end
  end
end
