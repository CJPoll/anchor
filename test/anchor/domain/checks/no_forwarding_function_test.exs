defmodule Anchor.Domain.Checks.NoForwardingFunctionTest do
  # DND-5452 (proposal F4, same module): a function that only forwards its
  # arguments to another function of its module is an inert hop. Rows D1-D18
  # and S1 are the QA plan's. Pure Domain.
  #
  # Sabotage record: ../../../sabotage_records/no_forwarding_function-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoForwardingFunction, as: Check

  @shape "inline the hop: make the callers of f/n call g/n directly and delete f/n, or " <>
           "rename g/n to f/n (public if f/n was). Keep a forwarding function only where it " <>
           "crosses a boundary (a behaviour callback marked @impl, another module's public API)."

  defp detect(source, rules \\ [%{}]) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations(rules)
  end

  # A module holding `f`'s definition and a two- and one-arity target `g`.
  defp module(f_source) do
    """
    defmodule App.X do
      #{f_source}

      defp g(a, b), do: {a, b}
      defp g(a), do: a
    end
    """
  end

  defp triggers(source), do: source |> detect() |> Enum.map(& &1.trigger)

  describe "detect_violations/2" do
    test "D1: a function forwarding to a same-module function is one violation" do
      assert [violation] = detect(module("def f(a, b), do: g(a, b)"))
      assert violation.trigger == "f/2"
      assert violation.line == 2
      assert violation.message =~ "f/2 only forwards its arguments unchanged to g/2"
      assert String.ends_with?(violation.message, "Fix: " <> @shape)
    end

    test "D2: a __MODULE__ call is flagged" do
      assert triggers(module("def f(a, b), do: __MODULE__.g(a, b)")) == ["f/2"]
    end

    test "D3: a pipe of the first argument is flagged" do
      assert triggers(module("def f(a, b), do: a |> g(b)")) == ["f/2"]
    end

    test "D4: a defdelegate to __MODULE__ with as: is flagged" do
      assert triggers(module("defdelegate f(a, b), to: __MODULE__, as: :g")) == ["f/2"]
    end

    test "D5: a multi-clause function forwarding in every clause is flagged once" do
      source = """
      defmodule App.X do
        def f(x), do: g(x)
        def f(y), do: g(y)
        defp g(a), do: a
      end
      """

      assert triggers(source) == ["f/1"]
    end

    test "D6: a transformed, reordered, dropped or added argument is not flagged" do
      for body <- ["g(a + 1, b)", "g(b, a)", "g(a)", "g(a, b, [])"] do
        source = """
        defmodule App.X do
          def f(a, b), do: #{body}
          defp g(a, b), do: {a, b}
          defp g(a), do: a
          defp g(a, b, c), do: {a, b, c}
        end
        """

        assert triggers(source) == [], body
      end
    end

    test "D7: a pattern, an underscore name, a repeated name, a default or a guard is not flagged" do
      # Each body passes the head's own names, so only the head disqualifies.
      for {head, call} <- [
            {"f(%{} = a, b)", "g(a, b)"},
            {"f(a, _b)", "g(a, _b)"},
            {"f(a, a)", "g(a, a)"},
            {"f(a, b \\\\ 1)", "g(a, b)"},
            {"f(a, b) when is_integer(a)", "g(a, b)"},
            # Whole-MR critic on a1b22c4: a head named like the detector's own
            # "not a variable" marker is still a pattern or a default.
            {"f(%{} = error)", "g(error)"},
            {"f(error \\\\ nil)", "g(error)"}
          ] do
        assert triggers(module("def #{head}, do: #{call}")) == [], head
      end
    end

    # Whole-MR critic on a1b22c4: a call argument that is not a variable
    # never matches a head variable, whatever that variable is named.
    test "D7: a non-variable call argument never matches a head variable of any name" do
      assert triggers(
               module("def f(not_a_variable), do: g(not_a_variable + 1)\n  defp g(a), do: a")
             ) ==
               []

      assert triggers(module("def f(error), do: g(error)\n  defp g(a), do: a")) == ["f/1"],
             "positive control: a variable named error still forwards"
    end

    test "D8: a body of two expressions is not flagged" do
      source =
        module("""
        def f(a, b) do
            Logger.debug(a)
            g(a, b)
          end
        """)

      assert triggers(source) == []
    end

    test "D9: an imported target is not flagged" do
      source = """
      defmodule App.X do
        import Enum
        def f(a, b), do: map(a, b)
      end
      """

      assert triggers(source) == []
    end

    test "D10: a remote target is not flagged (the graph rule's)" do
      assert triggers(module("def f(a, b), do: Other.g(a, b)")) == []
    end

    test "D11: a call to itself is not flagged" do
      assert triggers(module("def f(a), do: f(a)")) == []
    end

    test "D12: a function marked @impl is not flagged; @impl false is" do
      assert triggers(module("@impl true\n  def f(a, b), do: g(a, b)")) == []
      assert triggers(module("@impl GenServer\n  def f(a, b), do: g(a, b)")) == []
      # Positive control: the same function, @impl false or unmarked.
      assert triggers(module("@impl false\n  def f(a, b), do: g(a, b)")) == ["f/2"]
      assert triggers(module("def f(a, b), do: g(a, b)")) == ["f/2"]
    end

    test "D13: a function marked @deprecated is not flagged" do
      assert triggers(module(~s|@deprecated "use g/2"\n  def f(a, b), do: g(a, b)|)) == []
    end

    test "D14: nested modules: the outer function's target in the inner module is not its own" do
      source = """
      defmodule App.Outer do
        def f(a), do: g(a)

        defmodule Inner do
          def h(a), do: g(a)
          defp g(a), do: a
        end
      end
      """

      assert [%{trigger: "h/1", line: 5}] = detect(source)
    end

    test "D15: clauses forwarding to different targets are not flagged" do
      source = """
      defmodule App.X do
        def f(x), do: g(x)
        def f(y), do: h(y)
        defp g(a), do: a
        defp h(a), do: a
      end
      """

      assert triggers(source) == []
    end

    test "D16: forwarding inside quote is not flagged" do
      source = """
      defmodule App.X do
        defmacro m do
          quote do
            defmodule Generated do
              def f(a, b), do: g(a, b)
              defp g(a, b), do: {a, b}
            end
          end
        end
      end
      """

      assert triggers(source) == []
    end

    test "D17: a defdelegate to another module is not flagged" do
      assert triggers(module("defdelegate f(a), to: Other")) == []
      assert triggers(module("defdelegate f(a), to: Other, as: :g")) == []
    end

    test "D18: no rules, no violations" do
      assert detect(module("def f(a, b), do: g(a, b)"), []) == []
    end

    test "a target with a default argument counts at every arity it makes" do
      source = """
      defmodule App.X do
        def f(a), do: g(a)
        defp g(a, b \\\\ 1), do: {a, b}
      end
      """

      assert triggers(source) == ["f/1"]
    end

    test "a public function forwarding to a private one, zero arity included" do
      source = """
      defmodule App.X do
        def f, do: g()
        defp g, do: :ok
      end
      """

      assert triggers(source) == ["f/0"]
    end

    test "a defimpl body is skipped (protocol callbacks)" do
      source = """
      defimpl String.Chars, for: App.X do
        def to_string(a), do: render(a)
        defp render(a), do: inspect(a)
      end
      """

      assert triggers(source) == []
    end

    test "a body with rescue is not a single forwarding expression" do
      source =
        module("""
        def f(a, b) do
            g(a, b)
          rescue
            _ -> :error
          end
        """)

      assert triggers(source) == []
    end
  end

  describe "shape/1" do
    test "S1: the exact conforming shape" do
      assert Check.shape(%{}) == @shape
    end
  end
end
