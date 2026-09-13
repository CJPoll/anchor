defmodule Anchor.Domain.Checks.NoDiscardingArrowInWithTest do
  # Pure Domain detection for the `no_discarding_arrow_in_with` check: bare AST
  # in, `[%Violation{}]` out. No Credo types, no IO. The Framework mapping to
  # `Credo.Issue` is exercised in
  # test/anchor/check/no_discarding_arrow_in_with_test.exs.
  #
  # Sabotage record: ../../../sabotage_records/no_discarding_arrow_in_with-20260913-dnd_134_t6_9_no_discarding_arrow_in_with.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDiscardingArrowInWith
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  describe "detect_violations/1" do
    # Row #1
    test "flags `_ <- expr` discarding clause" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with _ <- some_function() do
              :ok
            end
          end
        end
        """)

      assert [%Violation{} = violation] = NoDiscardingArrowInWith.detect_violations(ast)

      assert violation.message ==
               "Unnecessary arrow (<-) in with clause. Pattern `_` only discards the value. " <>
                 "Remove the arrow and pattern to simplify"

      assert violation.trigger == "_"
      assert violation.line == 3
    end

    # Row #2
    test "flags `_result <- expr` (underscore-prefixed var)" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with _result <- some_function() do
              :ok
            end
          end
        end
        """)

      assert [violation] = NoDiscardingArrowInWith.detect_violations(ast)
      assert violation.trigger == "_result"
    end

    # Row #3
    test "flags a discarding clause with a guard" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with _x when is_nil(_x) <- some_function() do
              :ok
            end
          end
        end
        """)

      assert [violation] = NoDiscardingArrowInWith.detect_violations(ast)
      assert violation.trigger == "_x"
    end

    # Row #4
    test "passes meaningful pattern `{:ok, value} <-`" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with {:ok, value} <- some_function() do
              value
            end
          end
        end
        """)

      assert NoDiscardingArrowInWith.detect_violations(ast) == []
    end

    # Row #5
    test "passes `{:ok, _} <-` (structural match, not bare discard)" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with {:ok, _} <- some_function() do
              :ok
            end
          end
        end
        """)

      assert NoDiscardingArrowInWith.detect_violations(ast) == []
    end

    # Row #6
    test "passes a normal bound var `value <- expr`" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with value <- some_function() do
              value
            end
          end
        end
        """)

      assert NoDiscardingArrowInWith.detect_violations(ast) == []
    end

    # Row #7
    test "flags only the discarding clause in a multi-clause `with`" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with {:ok, v} <- a(),
                 _ <- b(v) do
              v
            end
          end
        end
        """)

      assert [violation] = NoDiscardingArrowInWith.detect_violations(ast)
      assert violation.line == 4
    end

    # Row #8
    test "`with` with no arrow clauses (all bare exprs) passes" do
      ast =
        ast("""
        defmodule Test do
          def f do
            with true, do: :ok
          end
        end
        """)

      assert NoDiscardingArrowInWith.detect_violations(ast) == []
    end
  end
end
