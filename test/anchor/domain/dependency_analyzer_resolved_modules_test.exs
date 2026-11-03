defmodule Anchor.Domain.DependencyAnalyzerResolvedModulesTest do
  # DND-5451: `resolved_modules/1` exposes the analyzer's one alias resolver
  # per node position, so an AST rule asks what one name node means instead of
  # writing a second resolver. Pure Domain; sources are parsed with columns, as
  # `Credo.Code.ast/1` parses every file.
  #
  # Sabotage record: ../../sabotage_records/dependency_analyzer-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  defp resolved(source) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> DependencyAnalyzer.resolved_modules()
  end

  # The module the name at `{line, column}` resolves to.
  defp at(source, line, column), do: Map.get(resolved(source), {line, column})

  test "an alias resolves through an `alias` directive" do
    source = """
    defmodule App.X do
      alias App.Calc
      def f(a), do: Calc.add(a, 1)
    end
    """

    assert at(source, 3, 17) == App.Calc
  end

  test "`alias ..., as:` and a multi-alias resolve" do
    source = """
    defmodule App.X do
      alias App.Math.Calc, as: C
      alias App.{Turn, Run}
      def f(a), do: {C.add(a), %Turn{}, Run}
    end
    """

    assert at(source, 4, 18) == App.Math.Calc
    assert at(source, 4, 29) == App.Turn
    assert at(source, 4, 37) == App.Run
  end

  test "an unaliased name is itself" do
    assert at("defmodule A do\n  def f, do: Other.Mod.g()\nend\n", 2, 14) == Other.Mod
  end

  test "a bare `__MODULE__` and `%__MODULE__{}` name the enclosing module" do
    source = """
    defmodule App.Outer do
      defmodule Inner do
        def f, do: {__MODULE__, %__MODULE__{}}
      end
    end
    """

    assert at(source, 3, 17) == App.Outer.Inner
    assert at(source, 3, 30) == App.Outer.Inner
  end

  test "a `__MODULE__` callee names the enclosing module" do
    assert at("defmodule App.X do\n  def f(a), do: __MODULE__.g(a)\nend\n", 2, 17) == App.X
  end

  test "a literal defmodule name resolves to the module its body is, nested too" do
    source = """
    defmodule App.Outer do
      defmodule Inner do
      end
    end
    """

    assert at(source, 1, 11) == App.Outer
    assert at(source, 2, 13) == App.Outer.Inner
  end

  test "a nested module's automatic alias resolves in the enclosing module" do
    source = """
    defmodule App.Outer do
      defmodule Inner do
        defstruct [:a]
      end

      def f, do: %Inner{}
    end
    """

    assert at(source, 6, 15) == App.Outer.Inner
  end

  test "`__MODULE__` inside a quote is not recorded (it names the macro's caller)" do
    source = """
    defmodule App.X do
      defmacro m do
        quote do
          __MODULE__
        end
      end

      def f, do: __MODULE__
    end
    """

    assert at(source, 4, 7) == nil
    # Positive control: the same name outside the quote is recorded.
    assert at(source, 8, 14) == App.X
  end

  test "a name bound by an unresolvable directive is not recorded" do
    source = """
    defmodule App.X do
      alias @target, as: T
      def f, do: T.g()
    end
    """

    assert at(source, 3, 14) == nil
  end
end
