defmodule Anchor.DependencyAnalyzerTest do
  use ExUnit.Case, async: true

  alias Anchor.DependencyAnalyzer

  describe "extract_module_name/1" do
    test "extracts module name from AST" do
      ast =
        quote do
          defmodule MyApp.Test do
            def hello, do: :world
          end
        end

      assert DependencyAnalyzer.extract_module_name(ast) == MyApp.Test
    end

    test "returns nil for non-module AST" do
      ast =
        quote do
          def hello, do: :world
        end

      assert DependencyAnalyzer.extract_module_name(ast) == nil
    end
  end

  describe "extract_direct_dependencies/1" do
    test "extracts module aliases" do
      ast =
        quote do
          defmodule Test do
            def test do
              MyApp.Repo.all(Query)
              SomeModule.function()
            end
          end
        end

      deps = DependencyAnalyzer.extract_direct_dependencies(ast)
      assert MyApp.Repo in deps
      assert Query in deps
      assert SomeModule in deps
    end

    test "extracts qualified function calls" do
      ast =
        quote do
          defmodule Test do
            def test do
              Enum.map([1, 2, 3], &(&1 * 2))
            end
          end
        end

      deps = DependencyAnalyzer.extract_direct_dependencies(ast)
      assert Enum in deps
    end
  end

  describe "extract_uses/1" do
    test "extracts use declarations" do
      ast =
        quote do
          defmodule Test do
            use MyApp.Web, :controller
            use Phoenix.LiveView

            def test, do: :ok
          end
        end

      uses = DependencyAnalyzer.extract_uses(ast)
      assert MyApp.Web in uses
      assert Phoenix.LiveView in uses
    end

    test "returns empty list when no uses" do
      ast =
        quote do
          defmodule Test do
            def test, do: :ok
          end
        end

      uses = DependencyAnalyzer.extract_uses(ast)
      assert uses == []
    end
  end
end
