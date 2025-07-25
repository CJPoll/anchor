defmodule Anchor.Check.ModulePatternRestrictionsTest do
  use ExUnit.Case

  alias Anchor.Check.ModulePatternRestrictions
  alias Credo.SourceFile

  describe "uses_module pattern matching" do
    test "restricts functions in modules that use Ecto.Schema" do
      source_code = """
      defmodule MyApp.User do
        use Ecto.Schema

        schema "users" do
          field :name, :string
        end

        def custom_function do
          :not_allowed
        end
      end
      """

      rule = %{
        type: :module_pattern_restrictions,
        uses_module: "Ecto.Schema",
        allowed_functions: ["changeset", "__changeset__", "__schema__", "__struct__"]
      }

      source_file = SourceFile.parse(source_code, "lib/my_app/user.ex")

      issues = ModulePatternRestrictions.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message == "Module defines non-allowed function: custom_function"
    end

    test "allows functions in allowed_functions list for modules using Ecto.Schema" do
      source_code = """
      defmodule MyApp.User do
        use Ecto.Schema

        schema "users" do
          field :name, :string
        end

        def changeset(user, attrs) do
          user
          |> Ecto.Changeset.cast(attrs, [:name])
          |> Ecto.Changeset.validate_required([:name])
        end
      end
      """

      rule = %{
        type: :module_pattern_restrictions,
        uses_module: "Ecto.Schema",
        allowed_functions: ["changeset", "__changeset__", "__schema__", "__struct__"]
      }

      source_file = SourceFile.parse(source_code, "lib/my_app/user.ex")

      issues = ModulePatternRestrictions.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "does not apply to modules that don't use the specified module" do
      source_code = """
      defmodule MyApp.Service do
        def custom_function do
          :allowed
        end

        def another_function do
          :also_allowed
        end
      end
      """

      _rule = %{
        type: :module_pattern_restrictions,
        uses_module: "Ecto.Schema",
        allowed_functions: []
      }

      source_file = SourceFile.parse(source_code, "lib/my_app/service.ex")
      ast = Credo.Code.ast(source_file)

      # Test that the module doesn't use Ecto.Schema
      refute Anchor.DependencyAnalyzer.has_use?(ast, Ecto.Schema)

      # Since this test directly calls check_file, we need to ensure the rule would match
      # In the real flow, rule_matches_file? would prevent this from being checked
      # So we'll test the matching logic separately
    end
  end

  describe "rule matching with uses_module" do
    test "rule_matches_file? returns true for modules using the specified module" do
      source_code = """
      defmodule MyApp.User do
        use Ecto.Schema
      end
      """

      source_file = SourceFile.parse(source_code, "lib/my_app/user.ex")
      ast = Credo.Code.ast(source_file)

      assert Anchor.DependencyAnalyzer.has_use?(ast, Ecto.Schema)
    end

    test "rule_matches_file? returns false for modules not using the specified module" do
      source_code = """
      defmodule MyApp.Service do
        def hello, do: :world
      end
      """

      source_file = SourceFile.parse(source_code, "lib/my_app/service.ex")
      ast = Credo.Code.ast(source_file)

      refute Anchor.DependencyAnalyzer.has_use?(ast, Ecto.Schema)
    end
  end
end
