defmodule Anchor.Domain.DependencyAnalyzerModuleScopeTest do
  # DND-8063: the owner of a nested `defmodule` whose name is not a plain
  # child (an `Elixir.` head, a module attribute, an Erlang atom), held after
  # module_scope/2's `with ... else` became a `case` and a helper with the
  # same result. A sibling of dependency_analyzer_test.exs, so a sabotage run
  # of the analyzer selects it.
  #
  # Sabotage record:
  #   ../../sabotage_records/dependency_analyzer-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  defp facts(source) do
    ast = Code.string_to_quoted!(source, columns: true)

    {DependencyAnalyzer.defined_modules(ast),
     DependencyAnalyzer.attributed_dependency_lines(ast, :call).by_owner}
  end

  test "an Elixir.-headed nested name is expanded as written, at the top level" do
    assert facts("""
           defmodule Outer do
             defmodule Elixir.Top.Inner do
               def f, do: Dep.call()
             end
           end
           """) == {[Outer, Top.Inner], [{Top.Inner, Dep, 3}]}
  end

  test "a nested name held in a module attribute is the attribute's module" do
    assert facts("""
           defmodule Outer do
             @m Foo.Bar
             defmodule @m do
               def f, do: Dep.call()
             end
           end
           """) == {[Foo.Bar, Outer], [{Foo.Bar, Dep, 4}]}
  end

  test "a __MODULE__-headed name nests under the owner, a defimpl's module inside one" do
    assert facts("""
           defmodule Outer do
             defimpl String.Chars, for: Outer do
               defmodule __MODULE__.Helper do
                 def f, do: Dep.call()
               end
             end
           end
           """) ==
             {[Outer, String.Chars.Outer, String.Chars.Outer.Helper],
              [{String.Chars.Outer.Helper, Dep, 4}]}
  end

  test "a nested Erlang-atom name defines no Elixir module: its code has no owner" do
    assert facts("""
           defmodule Outer do
             defmodule :erl_inner do
               def f, do: Dep.call()
             end
           end
           """) == {[Outer], [{nil, Dep, 3}]}
  end
end
