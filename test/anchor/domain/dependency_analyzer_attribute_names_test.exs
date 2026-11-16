defmodule Anchor.Domain.DependencyAnalyzerAttributeNamesTest do
  # A MODULE ATTRIBUTE whose name is a special form or a name a walker clause
  # matches (`@quote`, `@use`, `@import`, ...). Setting one is
  # `{:@, meta, [{name, meta, [value]}]}`: the inner node has the shape of the
  # call `name(value)`. Reading one is `{:@, meta, [{name, meta, context}]}`, the
  # shape of a variable. A walker that read either as the special form crashed
  # (`@quote` read as a quote block with no body) or recorded the wrong thing
  # (`@use Other.Mod` read as `use Other.Mod`). Every such name must read
  # exactly as an attribute with a plain name does.
  #
  # Sabotage record: ../../sabotage_records/dependency_analyzer-20261116-athena_quote_attribute_crash.md (hand runs A, B), ../../sabotage_records/attribute_node-20261116-athena_quote_attribute_crash.md (D, F)
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()
                   |> Enum.map(&String.to_atom/1)

  # The attribute is set from a module, from a keyword list with a `do:` (the
  # shape of a block call's arguments) and from a `fn`, then read in a function.
  # The references after it prove the attribute left the lexical environment
  # alone: `__MODULE__.Sub` (a quote would suppress it), `Mod` (an alias would
  # rewrite it) and `helper(x)`, the imported `Foo.helper/1` (an attribute read
  # as a definition, `@def helper(1)`, would make it a local call).
  defp source(name) do
    """
    defmodule Sample.AttrUser do
      alias Foo.Bar
      import Foo

      @#{name} Other.Mod
      @#{name} [do: Third.Mod]
      @#{name} fn x -> x end
      @#{name} helper(1)

      def run(x) do
        y = Bar.call(@#{name})
        __MODULE__.Sub.go(y)
        Mod.go(helper(x))
      end
    end
    """
  end

  defp ast(source), do: Code.string_to_quoted!(source)

  defp analysis(ast) do
    %{
      module_names: DependencyAnalyzer.extract_module_names(ast),
      defined: DependencyAnalyzer.defined_modules(ast),
      direct: DependencyAnalyzer.extract_direct_dependencies(ast),
      call: DependencyAnalyzer.extract_call_dependencies(ast),
      functions: DependencyAnalyzer.function_references(ast),
      unresolved: DependencyAnalyzer.unresolved_directives(ast),
      graph: DependencyAnalyzer.module_dependencies(ast),
      uses: DependencyAnalyzer.extract_uses(ast)
    }
  end

  describe "an attribute named like a special form or a matched call" do
    test "the plain-named baseline has the expected dependencies (positive control)" do
      assert %{
               module_names: [Sample.AttrUser],
               direct: [Foo, Foo.Bar, Mod, Other.Mod, Sample.AttrUser.Sub, Third.Mod],
               call: [Foo, Foo.Bar, Mod, Sample.AttrUser.Sub],
               unresolved: [],
               uses: []
             } = analysis(ast(source(:value)))
    end

    for name <- @attribute_names do
      test "an attribute named @#{name} analyses exactly as one named @value" do
        name = unquote(name)
        baseline = analysis(ast(source(:value)))

        assert analysis(ast(source(name))) == baseline,
               "an attribute named @#{name} changed the analysis"
      end
    end
  end

  describe "the @quote shapes, as bare AST" do
    test "a read @quote is walked as an attribute read: no crash, no dependency" do
      ast =
        {:defmodule, [line: 1],
         [
           {:__aliases__, [line: 1], [:Sample, :Q]},
           [
             do:
               {:def, [line: 2],
                [{:run, [line: 2], nil}, [do: {:@, [line: 3], [{:quote, [line: 3], nil}]}]]}
           ]
         ]}

      assert DependencyAnalyzer.extract_direct_dependencies(ast) == []
      assert DependencyAnalyzer.extract_uses(ast) == []

      assert DependencyAnalyzer.module_dependencies(ast) == [
               {Sample.Q, %{module: Sample.Q, direct_dependencies: []}}
             ]
    end

    test "a set @quote is walked as an attribute set: its value is a dependency" do
      ast =
        {:defmodule, [line: 1],
         [
           {:__aliases__, [line: 1], [:Sample, :Q]},
           [
             do:
               {:@, [line: 2], [{:quote, [line: 2], [{:__aliases__, [line: 2], [:Other, :Mod]}]}]}
           ]
         ]}

      assert DependencyAnalyzer.extract_direct_dependencies(ast) == [Other.Mod]
      assert DependencyAnalyzer.extract_uses(ast) == []
    end

    test "a set @use is not a use of its value" do
      assert DependencyAnalyzer.extract_uses(ast("@use Other.Mod")) == []
      assert DependencyAnalyzer.extract_uses(ast("use Other.Mod")) == [Other.Mod]
    end
  end
end
