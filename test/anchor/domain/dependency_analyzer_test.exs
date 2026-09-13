defmodule Anchor.Domain.DependencyAnalyzerTest do
  # Functional unit tests for the pure Domain analyzer (T5 / DND-125).
  #
  # These assert the INTENDED behavior from docs/five-bucket-test-matrix.md
  # (dependency_analyzer.ex rows), not the pre-T5 buggy behavior:
  #
  #   * extract_module_names/1 (plural, pre-order DFS, fully qualified) — rows 1–12
  #   * extract_direct_dependencies/1 (__MODULE__ resolution, quote opacity) — rows 1–10
  #   * extract_uses/1 — rows 1–4
  #   * find_transitive_dependencies/3 — rows 1–7
  #
  # Inputs are bare ASTs produced by `Code.string_to_quoted!/1` — the same shape
  # `Anchor.Check.Source.ast/1` hands the Domain in production (post-BUG-1: the
  # `{:ok, ast}` tuple is unwrapped exactly once at the Framework edge).
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  defp ast(src), do: Code.string_to_quoted!(src)

  describe "extract_module_names/1" do
    # Row 1
    test "single module -> one-element list" do
      src = """
      defmodule MyApp.Test do
        def hello, do: :world
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [MyApp.Test]
    end

    # Row 2
    test "non-module AST -> []" do
      assert DependencyAnalyzer.extract_module_names(ast("def hello, do: :world")) == []
    end

    # Row 3
    test "two sibling top-level modules, source order" do
      src = """
      defmodule A do
      end

      defmodule B do
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A, B]
    end

    # Row 4
    test "nested siblings are fully qualified, in source order" do
      src = """
      defmodule A do
        defmodule B do
        end

        defmodule C do
        end
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A, A.B, A.C]
    end

    # Row 5
    test "pre-order DFS keeps a subtree contiguous" do
      src = """
      defmodule A do
        defmodule D do
        end

        defmodule C do
          defmodule E do
          end
        end
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A, A.D, A.C, A.C.E]
    end

    # Row 6
    test "deeper DFS — full pre-order traversal (not breadth-first)" do
      src = """
      defmodule A do
        defmodule D do
          defmodule F do
          end
        end

        defmodule C do
          defmodule E do
          end
        end
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A, A.D, A.D.F, A.C, A.C.E]
    end

    # Row 7
    test "defimpl/defprotocol not emitted as module nodes" do
      src = """
      defmodule A do
        defimpl String.Chars, for: A do
          def to_string(_), do: "a"
        end
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A]
    end

    # Row 8
    test "unknown/unnamed module (non-literal name) contributes no name" do
      src = """
      defmodule :undefined_thing do
        def f, do: 1
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == []
    end

    # Row 9
    test "macro/quote — dynamic defmodule unquote(x) name is skipped, no crash" do
      src = """
      defmodule unquote(x) do
        def f, do: 1
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == []
    end

    # Row 10
    test "macro/quote — variable/expression module name is skipped, no crash" do
      src = """
      defmodule mod_name do
        def f, do: 1
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == []
    end

    # Row 11
    test "macro/quote — pure DSL file with zero literal defmodule -> []" do
      src = """
      defcontext Sales do
        defaggregate Order
        defentity LineItem
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == []
    end

    # Row 12
    test "literal modules alongside a dynamic one — only literals emitted" do
      src = """
      defmodule A do
      end

      defmodule unquote(x) do
      end
      """

      assert DependencyAnalyzer.extract_module_names(ast(src)) == [A]
    end
  end

  describe "extract_direct_dependencies/1" do
    # Row 1
    test "extracts module aliases" do
      src = """
      defmodule Test do
        def test do
          MyApp.Repo.all(Query)
          SomeModule.function()
        end
      end
      """

      deps = DependencyAnalyzer.extract_direct_dependencies(ast(src))
      assert MyApp.Repo in deps
      assert Query in deps
      assert SomeModule in deps
    end

    # Row 2
    test "extracts qualified function calls" do
      src = """
      defmodule Test do
        def test, do: Enum.map([1, 2, 3], &(&1 * 2))
      end
      """

      assert Enum in DependencyAnalyzer.extract_direct_dependencies(ast(src))
    end

    # Row 3
    test "result is sorted and de-duplicated (and excludes the module's own name)" do
      src = """
      defmodule Foo do
        def f do
          Enum.map([], & &1)
          Enum.count([])
          A.x()
        end
      end
      """

      assert DependencyAnalyzer.extract_direct_dependencies(ast(src)) == [A, Enum]
    end

    # Row 4
    test "no external references -> []" do
      assert DependencyAnalyzer.extract_direct_dependencies(ast("def f, do: 1")) == []
    end

    # Row 5 (BUG 3 — decision #1: resolve)
    test "__MODULE__.Sub in ordinary code resolves to the enclosing submodule" do
      src = """
      defmodule Enclosing do
        def f, do: __MODULE__.Sub.f()
      end
      """

      deps = DependencyAnalyzer.extract_direct_dependencies(ast(src))
      assert Enclosing.Sub in deps
    end

    # Row 6 (BUG 3 — no crash, no spurious dep)
    test "@attr.Sub does not crash and is not a spurious module dep" do
      src = """
      defmodule A do
        def f, do: @config.Sub
      end
      """

      assert DependencyAnalyzer.extract_direct_dependencies(ast(src)) == []
    end

    # Row 7 (BUG 3 — runtime access is not a static dep)
    test "var.Sub (runtime access) does not crash and is not a static dep" do
      src = """
      defmodule A do
        def f(conn), do: conn.Sub
      end
      """

      assert DependencyAnalyzer.extract_direct_dependencies(ast(src)) == []
    end

    # Row 8 (quote opacity — the non-negotiable suppression)
    test "__MODULE__ inside quote is opaque, not resolved to the enclosing module" do
      src = """
      defmodule Enclosing do
        def f do
          quote do
            __MODULE__.Sub.g()
          end
        end
      end
      """

      deps = DependencyAnalyzer.extract_direct_dependencies(ast(src))
      refute Enclosing.Sub in deps
      assert deps == []
    end

    # Row 9 (quote opacity for struct form)
    test "%__MODULE__{} inside quote is opaque" do
      src = """
      defmodule Enclosing do
        def f do
          quote do
            %__MODULE__{}
          end
        end
      end
      """

      deps = DependencyAnalyzer.extract_direct_dependencies(ast(src))
      refute Enclosing in deps
    end

    # Row 10 (positive control — ordinary deps unaffected by the quote rule)
    test "ordinary literal-aliased deps outside any quote are recorded as normal" do
      src = """
      defmodule Foo do
        def f, do: MyApp.Repo.all()
      end
      """

      assert MyApp.Repo in DependencyAnalyzer.extract_direct_dependencies(ast(src))
    end
  end

  describe "extract_uses/1" do
    # Row 1
    test "extracts use declarations" do
      src = """
      defmodule Test do
        use MyApp.Web, :controller
        use Phoenix.LiveView

        def test, do: :ok
      end
      """

      uses = DependencyAnalyzer.extract_uses(ast(src))
      assert MyApp.Web in uses
      assert Phoenix.LiveView in uses
    end

    # Row 2
    test "no uses -> []" do
      src = """
      defmodule Test do
        def test, do: :ok
      end
      """

      assert DependencyAnalyzer.extract_uses(ast(src)) == []
    end

    # Row 3
    test "use Mod, opts records the module, not the opts" do
      src = """
      defmodule Test do
        use MyApp.Schema, foo: 1
      end
      """

      assert DependencyAnalyzer.extract_uses(ast(src)) == [MyApp.Schema]
    end

    # Row 4
    test "result sorted and de-duplicated" do
      src = """
      defmodule Test do
        use Foo
        use Foo
      end
      """

      assert DependencyAnalyzer.extract_uses(ast(src)) == [Foo]
    end
  end

  describe "find_transitive_dependencies/3" do
    # Row 1
    test "reaches a module through one hop" do
      map = %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [Repo]}}

      visited = DependencyAnalyzer.find_transitive_dependencies(map, A)

      assert MapSet.member?(visited, A)
      assert MapSet.member?(visited, B)
      assert MapSet.member?(visited, Repo)
    end

    # Row 2
    test "reaches through two hops" do
      map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [C]},
        C => %{direct_dependencies: [Repo]}
      }

      assert MapSet.member?(DependencyAnalyzer.find_transitive_dependencies(map, A), Repo)
    end

    # Row 3
    test "does not reach an unrelated module" do
      map = %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [C]}}

      refute MapSet.member?(DependencyAnalyzer.find_transitive_dependencies(map, A), Repo)
    end

    # Row 4
    test "terminates on a cycle" do
      map = %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [A]}}

      assert DependencyAnalyzer.find_transitive_dependencies(map, A) == MapSet.new([A, B])
    end

    # Row 5
    test "start module absent from map -> just the start" do
      assert DependencyAnalyzer.find_transitive_dependencies(%{}, A) == MapSet.new([A])
    end

    # Row 6
    test "direct dependency included" do
      map = %{A => %{direct_dependencies: [Repo]}}

      assert MapSet.member?(DependencyAnalyzer.find_transitive_dependencies(map, A), Repo)
    end

    # Row 7
    test "pre-seeded visited short-circuits" do
      map = %{A => %{direct_dependencies: [B]}}
      seeded = MapSet.new([A])

      assert DependencyAnalyzer.find_transitive_dependencies(map, A, seeded) == seeded
    end
  end
end
