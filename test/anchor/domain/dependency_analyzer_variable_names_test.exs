defmodule Anchor.Domain.DependencyAnalyzerVariableNamesTest do
  # DND-1310: a VARIABLE whose name is a special form or a name a walker clause
  # matches (`quote`, `import`, `case`, ...) is `{name, meta, context_atom}`, not
  # the call `{name, meta, [args]}`. The analyzer crashed on a variable named
  # `quote` (`walk_children(nil)`), which stopped every Anchor check on the file.
  # Every such name must read exactly as a variable with a plain name does.
  #
  # Sabotage record: test/sabotage_records/dependency_analyzer-20260929-dnd_1310_analyzer_quote_crash.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  # Every name the parser accepts as a variable that is also a special form, a
  # directive, a definition macro or a name one of Anchor's walker clauses
  # matches. `__MODULE__`, `fn`, `__aliases__` and `__block__` are absent: the
  # first is always the special form, the others do not parse as variables.
  # `Anchor.Managers.LintVariableNamesTest` runs every check over the same list.
  @variable_names "test/fixtures/special_variable_names.txt"
                  |> File.read!()
                  |> String.split()
                  |> Enum.map(&String.to_atom/1)

  @fragment File.read!("test/fixtures/option_parser_split.txt")

  # A variable named `name`, bound in a function head, rebound from a call and
  # passed on. `__MODULE__.Sub` after it proves the variable left the lexical
  # environment alone (a variable read as `quote` would suppress it).
  defp source(name) do
    """
    defmodule Sample.VarUser do
      alias Foo.Bar

      def run(#{name}) do
        #{name} = Bar.call(#{name})
        __MODULE__.Sub.go(#{name})
      end
    end
    """
  end

  defp ast(source), do: Code.string_to_quoted!(source)

  defp analysis(ast) do
    %{
      module_names: DependencyAnalyzer.extract_module_names(ast),
      direct: DependencyAnalyzer.extract_direct_dependencies(ast),
      call: DependencyAnalyzer.extract_call_dependencies(ast),
      functions: DependencyAnalyzer.function_references(ast),
      unresolved: DependencyAnalyzer.unresolved_directives(ast),
      graph: DependencyAnalyzer.module_dependencies(ast),
      uses: DependencyAnalyzer.extract_uses(ast)
    }
  end

  describe "a variable named like a special form or a matched call" do
    test "the plain-named baseline has the expected dependencies (positive control)" do
      assert analysis(ast(source(:value))) == %{
               module_names: [Sample.VarUser],
               direct: [Foo.Bar, Sample.VarUser.Sub],
               call: [Foo.Bar, Sample.VarUser.Sub],
               functions: %{
                 calls: [{{Foo.Bar, :call, 1}, 5}, {{Sample.VarUser.Sub, :go, 1}, 6}],
                 dynamic: []
               },
               unresolved: [],
               graph: [
                 {Sample.VarUser,
                  %{module: Sample.VarUser, direct_dependencies: [Foo.Bar, Sample.VarUser.Sub]}}
               ],
               uses: []
             }
    end

    for name <- @variable_names do
      test "a variable named #{name} analyses exactly as a variable named value" do
        name = unquote(name)
        baseline = analysis(ast(source(:value)))

        assert analysis(ast(source(name))) == baseline,
               "a variable named #{name} changed the analysis"
      end
    end
  end

  describe "Elixir's own OptionParser.split/1 (a variable named quote), verbatim" do
    test "analyses without crashing and records its real dependencies" do
      ast = ast(@fragment)

      # `Kernel` is the interpolation in the last clause's `raise`: `"#{x}"`
      # parses as a call on `Kernel.to_string/1`. `Enum` is in the clauses
      # after the `quote` variables.
      assert DependencyAnalyzer.extract_module_names(ast) == [OptionParserSplitFragment]
      assert DependencyAnalyzer.extract_direct_dependencies(ast) == [Enum, Kernel, String]
      assert DependencyAnalyzer.extract_call_dependencies(ast) == [Enum, Kernel, String]
      assert DependencyAnalyzer.unresolved_directives(ast) == []

      assert DependencyAnalyzer.module_dependencies(ast) == [
               {OptionParserSplitFragment,
                %{module: OptionParserSplitFragment, direct_dependencies: [Enum, Kernel, String]}}
             ]

      %{calls: calls, dynamic: dynamic} = DependencyAnalyzer.function_references(ast)

      assert Enum.map(calls, fn {mfa, _line} -> mfa end) == [
               {Enum, :reverse, 1},
               {Kernel, :in, 2},
               {Kernel, :is_binary, 1},
               {Kernel, :raise, 1},
               {Kernel, :to_string, 1},
               {String, :trim_leading, 2}
             ]

      assert dynamic == []
    end
  end
end
