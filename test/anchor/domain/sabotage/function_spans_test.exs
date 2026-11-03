defmodule Anchor.Domain.Sabotage.FunctionSpansTest do
  # Domain tests for the def-clause line spans of a source file (DND-5472).
  # Sabotage record: test/sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.FunctionSpans
  alias Anchor.Domain.Sabotage.Span

  defp spans!(source) do
    {:ok, spans} = FunctionSpans.spans(source, "lib/m.ex")
    spans
  end

  defp summary(spans) do
    Enum.map(
      spans,
      &{&1.module, &1.name, &1.arity, &1.kind, &1.first..&1.last//1, &1.excluded_macro}
    )
  end

  describe "spans/2" do
    test "P1: a do-block def spans from its def line to its end line" do
      source = """
      defmodule M do
        def f(x) do
          y = x + 1
          y * 2
        end
      end
      """

      assert summary(spans!(source)) == [{M, :f, 1, :def, 2..5, false}]
    end

    test "P2: a keyword def spans its one line" do
      source = """
      defmodule M do
        @moduledoc false
        @doc false
        # one
        # two
        # three
        def f(x), do: x
      end
      """

      assert summary(spans!(source)) == [{M, :f, 1, :def, 7..7, false}]
    end

    test "P3: a keyword def whose body is a heredoc ends on the heredoc's closing line" do
      source = ~S'''
      defmodule M do
        def f(_x),
          do: """
          a
          b
          """

        def g, do: :ok
      end
      '''

      assert summary(spans!(source)) == [
               {M, :f, 1, :def, 2..6, false},
               {M, :g, 0, :def, 8..8, false}
             ]
    end

    test "P4: a multi-clause function is one span per clause, with one identity" do
      source = """
      defmodule M do
        def f(:a), do: 1

        def f(_other) do
          2
        end
      end
      """

      assert summary(spans!(source)) == [
               {M, :f, 1, :def, 2..2, false},
               {M, :f, 1, :def, 4..6, false}
             ]
    end

    test "P5: a guarded head names the function and its arity" do
      source = """
      defmodule M do
        def f(x) when is_integer(x) and x > 0 do
          x
        end
      end
      """

      assert summary(spans!(source)) == [{M, :f, 1, :def, 2..4, false}]
    end

    test "P6: nested modules qualify the inner module's name" do
      source = """
      defmodule A do
        def outer, do: 1

        defmodule B do
          def g(x), do: x
        end

        defmodule Elixir.C do
          def h, do: 3
        end
      end
      """

      assert summary(spans!(source)) == [
               {A, :outer, 0, :def, 2..2, false},
               {A.B, :g, 1, :def, 5..5, false},
               {C, :h, 0, :def, 9..9, false}
             ]
    end

    test "P7: defimpl names the protocol and the type, with or without for: inside a module" do
      source = """
      defimpl String.Chars, for: A do
        def to_string(_a), do: "a"
      end

      defmodule B do
        defstruct []

        defimpl Inspect do
          def inspect(_b, _opts), do: "b"
        end
      end
      """

      assert summary(spans!(source)) == [
               {String.Chars.A, :to_string, 1, :def, 2..2, false},
               {Inspect.B, :inspect, 2, :def, 9..9, false}
             ]
    end

    test "P8: macros and functions defined inside quote are marked excluded_macro" do
      source = """
      defmodule M do
        defmacro m(x) do
          quote do
            def generated(y), do: unquote(x) + y
          end
        end

        defmacrop p, do: :ok

        def real, do: 1
      end
      """

      assert summary(spans!(source)) == [
               {M, :m, 1, :defmacro, 2..6, true},
               {M, :generated, 1, :def, 4..4, true},
               {M, :p, 0, :defmacrop, 8..8, true},
               {M, :real, 0, :def, 10..10, false}
             ]
    end

    test "P9: a default argument still counts once; the function is the full arity" do
      source = """
      defmodule M do
        def f(a, b \\\\ 1), do: a + b
      end
      """

      assert summary(spans!(source)) == [{M, :f, 2, :def, 2..2, false}]
    end

    test "P10: defp is kind :defp" do
      source = """
      defmodule M do
        defp f, do: 1
      end
      """

      assert [%Span{kind: :defp, name: :f, arity: 0}] = spans!(source)
    end

    test "P11: unparseable source is {:error, {line, reason}}" do
      source = """
      defmodule M do
        def f(
      end
      """

      assert {:error, {line, reason}} = FunctionSpans.spans(source, "lib/m.ex")
      assert line == 2
      assert is_binary(reason) and reason != ""
    end

    test "P12: a name built by unquote outside quote cannot be named, and is marked excluded_macro" do
      source = """
      defmodule M do
        for name <- [:a, :b] do
          def unquote(name)(), do: unquote(name)
        end
      end
      """

      assert [%Span{excluded_macro: true, first: 3, last: 3}] = spans!(source)
    end
  end
end
