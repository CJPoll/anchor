defmodule Anchor.Check.NoTransitiveDependencyTest do
  use ExUnit.Case

  alias Anchor.Check.NoTransitiveDependency
  alias Anchor.DependencyAnalyzer
  alias Credo.SourceFile

  describe "transitive dependency analysis" do
    test "finds all transitive dependencies" do
      modules_map = %{
        ModuleA => %{direct_dependencies: [ModuleB]},
        ModuleB => %{direct_dependencies: [ModuleC, ModuleD]},
        ModuleC => %{direct_dependencies: []},
        ModuleD => %{direct_dependencies: []}
      }

      deps = DependencyAnalyzer.find_transitive_dependencies(modules_map, ModuleA)

      assert deps == MapSet.new([ModuleA, ModuleB, ModuleC, ModuleD])
    end

    test "handles circular dependencies" do
      modules_map = %{
        ModuleA => %{direct_dependencies: [ModuleB]},
        ModuleB => %{direct_dependencies: [ModuleA, ModuleC]},
        ModuleC => %{direct_dependencies: []}
      }

      deps = DependencyAnalyzer.find_transitive_dependencies(modules_map, ModuleA)

      # Should find all modules despite the cycle
      assert deps == MapSet.new([ModuleA, ModuleB, ModuleC])
    end

    test "handles missing modules gracefully" do
      modules_map = %{
        ModuleA => %{direct_dependencies: [ModuleB]}
        # ModuleB is referenced but not in the map
      }

      deps = DependencyAnalyzer.find_transitive_dependencies(modules_map, ModuleA)

      # Should find ModuleA and ModuleB (even though ModuleB is not in the map)
      assert deps == MapSet.new([ModuleA, ModuleB])
    end
  end

  describe "check_file" do
    test "returns empty list when no rules match" do
      source_code = """
      defmodule TestModule do
        def test do
          OtherModule.foo()
        end
      end
      """

      rule = %{
        type: :no_transitive_dependency,
        pattern: "NonMatchingPattern",
        forbidden_modules: [ForbiddenModule]
      }

      source_file = SourceFile.parse(source_code, "lib/test_module.ex")

      # Since the pattern doesn't match, check_file shouldn't be called
      # but we can still test it returns empty
      issues = NoTransitiveDependency.check_file(source_file, [rule], [])

      assert issues == []
    end

    test "check_file returns empty list when modules_map is empty" do
      source_code = """
      defmodule TestModule do
        def test do
          OtherModule.foo()
        end
      end
      """

      rule = %{
        type: :no_transitive_dependency,
        forbidden_modules: [ForbiddenModule]
      }

      source_file = SourceFile.parse(source_code, "lib/test_module.ex")

      # With empty modules_map (default from check_file), no transitive deps are found
      issues = NoTransitiveDependency.check_file(source_file, [rule], [])

      assert issues == []
    end
  end

  describe "rule type" do
    test "has correct rule type" do
      assert NoTransitiveDependency.rule_type() == :no_transitive_dependency
    end
  end
end
