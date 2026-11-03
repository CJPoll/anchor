defmodule Anchor.Domain.Graph.SourceFactsTest do
  # Domain (ADR 002): pure function over source text. QA plan rows 1-5 (DND-5438).
  #
  # Sabotage record: ../../../sabotage_records/source_facts-20261103-dnd_5438.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.SourceFacts

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

    test "a module named by an atom keeps its name; a computed name is skipped" do
      text = """
      defmodule :erl_style do
      end

      defmodule unquote(name) do
        defmodule Inner do
        end
      end
      """

      assert %{defmodules: ["erl_style", "Inner"]} = SourceFacts.from_source("a.ex", text)
    end

    # Row 5
    test "unparseable text is an error, never empty facts" do
      assert {:error, :unparseable} = SourceFacts.from_source("a.ex", "defmodule A do")
    end
  end
end
