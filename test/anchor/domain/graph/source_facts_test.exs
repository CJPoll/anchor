defmodule Anchor.Domain.Graph.SourceFactsTest do
  # Domain (ADR 002): pure function over source text. QA plan rows 1-5 (DND-5438).
  #
  # Sabotage record: ../../../sabotage_records/source_facts-20261103-dnd_5438.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.SourceFacts

  # The DND-1310 table every AST walker runs over (CLAUDE.md).
  @variable_names "test/fixtures/special_variable_names.txt"
                  |> File.read!()
                  |> String.split()

  describe "from_source/2" do
    # Row 1
    test "a top-level module is a literal defmodule" do
      assert %{defmodules: ["A.B"], uses: %{"A.B" => []}} =
               SourceFacts.from_source("a.ex", "defmodule A.B do end")
    end

    # Row 2
    test "nested modules are qualified through nesting, in source order" do
      text = """
      defmodule A do
        defmodule B do
        end
      end

      defmodule C do
      end
      """

      assert %{defmodules: ["A", "A.B", "C"]} = SourceFacts.from_source("a.ex", text)
    end

    # Row 3
    test "a literal use is scoped to its own module's body" do
      text = """
      defmodule A do
        use GenServer

        defmodule B do
          use Agent, restart: :temporary
        end
      end
      """

      assert %{uses: uses} = SourceFacts.from_source("a.ex", text)
      assert uses["A"] == ["GenServer"]
      assert uses["A.B"] == ["Agent"]
    end

    # Row 4 (with its positive control: the literal defmodule beside it is found)
    test "a module a macro emits is not a literal defmodule" do
      text = """
      defmodule A do
        MyDSL.defthing :x
      end
      """

      assert %{defmodules: ["A"]} = SourceFacts.from_source("a.ex", text)
    end

    # Row 4b: a defmodule (and a use) inside a quote is macro output.
    test "a defmodule or use inside a quote is macro output, not a literal of this file" do
      text = """
      defmodule Mac do
        defmacro __using__(_opts) do
          quote do
            use Agent
            defmodule Generated do
            end
          end
        end
      end
      """

      assert %{defmodules: ["Mac"], uses: %{"Mac" => []}} = SourceFacts.from_source("a.ex", text)
    end

    test "a module named by an atom keeps its name" do
      assert %{defmodules: ["erl_style"], nonliteral_defmodule?: false} =
               SourceFacts.from_source("a.ex", "defmodule :erl_style do\nend\n")
    end

    # Kernel names `Elixir.X` and an atom absolutely, nested or not (checked:
    # compiling this text gives InnerAbs, :inner_atom, TopAbs.Rel, TopAbs).
    test "an Elixir.-prefixed or atom name is absolute, never qualified by the enclosing module" do
      text = """
      defmodule Elixir.TopAbs do
        use Elixir.GenServer

        defmodule Elixir.InnerAbs do
        end

        defmodule :inner_atom do
        end

        defmodule Rel do
        end
      end
      """

      assert SourceFacts.from_source("a.ex", text) == %{
               defmodules: ["TopAbs", "InnerAbs", "inner_atom", "TopAbs.Rel"],
               uses: %{
                 "TopAbs" => ["GenServer"],
                 "InnerAbs" => [],
                 "inner_atom" => [],
                 "TopAbs.Rel" => []
               },
               nonliteral_defmodule?: false
             }
    end

    # Kernel expands a file-level alias in a top-level module's name (checked:
    # `alias Foo.Accounts` then `defmodule Accounts.User` compiles to
    # Foo.Accounts.User; `alias Foo.Bar, as: Acc` then `defmodule Acc.User` to
    # Foo.Bar.User; `use Inj`, whose __using__ aliases Foo.Wee, then
    # `defmodule Wee.Y` to Foo.Wee.Y). The text alone does not show that name.
    @file_level_aliasers [
      "alias Foo.Accounts",
      "alias Foo.Bar, as: Accounts",
      "require Foo.Bar, as: Accounts",
      "import Foo.Bar",
      "use Foo.Injector"
    ]

    test "a relative top-level name after a file-level alias, require, import or use is not collected; the file says so" do
      for aliaser <- @file_level_aliasers do
        text = """
        #{aliaser}

        defmodule Accounts.User do
          use Agent

          defmodule Inner do
          end
        end

        defmodule Elixir.Absolute do
        end
        """

        assert SourceFacts.from_source("a.ex", text) ==
                 %{
                   defmodules: ["Absolute"],
                   uses: %{"Absolute" => []},
                   nonliteral_defmodule?: true
                 },
               "after #{inspect(aliaser)}"
      end
    end

    # Checked: an alias after the module, or inside a module, leaves a module
    # name as written (`defmodule P1 do alias Foo.Accounts; defmodule
    # Accounts.User` compiles to P1.Accounts.User).
    test "an alias after a top-level module, or inside a module, leaves its literal name" do
      text = """
      defmodule Accounts.User do
      end

      defmodule P1 do
        alias Foo.Accounts

        defmodule Accounts.Inner do
        end
      end

      alias Foo.Accounts
      """

      assert SourceFacts.from_source("a.ex", text) ==
               %{
                 defmodules: ["Accounts.User", "P1", "P1.Accounts.Inner"],
                 uses: %{"Accounts.User" => [], "P1" => [], "P1.Accounts.Inner" => []},
                 nonliteral_defmodule?: false
               }
    end

    test "__MODULE__ at the head of a nested name resolves to the enclosing module" do
      text = """
      defmodule A do
        defmodule __MODULE__.Child do
          use Agent
        end
      end
      """

      assert SourceFacts.from_source("a.ex", text) ==
               %{
                 defmodules: ["A", "A.Child"],
                 uses: %{"A" => [], "A.Child" => ["Agent"]},
                 nonliteral_defmodule?: false
               }
    end

    test "a computed name, and every module inside it, is not collected; the file says so" do
      text = """
      defmodule A do
        defmodule unquote(name) do
          use Agent

          defmodule Inner do
          end
        end
      end
      """

      assert SourceFacts.from_source("a.ex", text) ==
               %{defmodules: ["A"], uses: %{"A" => []}, nonliteral_defmodule?: true}
    end

    # DND-1310's table: a variable named like a special form (`quote`,
    # `defmodule`, `use`, ...) is a variable, never the form.
    test "a variable named like a special form is read as a variable" do
      for name <- @variable_names do
        text = """
        defmodule Sample.VarUser do
          use Plain.Base

          def run(#{name}) do
            #{name} = Bar.call(#{name})
            #{name}
          end
        end
        """

        assert SourceFacts.from_source("a.ex", text) ==
                 %{
                   defmodules: ["Sample.VarUser"],
                   uses: %{"Sample.VarUser" => ["Plain.Base"]},
                   nonliteral_defmodule?: false
                 },
               "variable #{name}"
      end
    end

    # Row 5
    test "unparseable text is an error, never empty facts" do
      assert {:error, :unparseable} = SourceFacts.from_source("a.ex", "defmodule A do")
    end
  end
end
