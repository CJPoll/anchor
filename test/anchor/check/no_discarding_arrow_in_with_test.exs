defmodule Anchor.Check.NoDiscardingArrowInWithTest do
  # Acceptance tests for Anchor.Check.NoDiscardingArrowInWith (T6.9 / DND-134).
  #
  # Detection now lives in the pure Domain module
  # Anchor.Domain.Checks.NoDiscardingArrowInWith; this suite exercises the
  # check's observable contract end-to-end through the thin Framework shell:
  # `check_file/3` takes a real `Credo.SourceFile` and returns
  # `[%Credo.Issue{}]`. These rows match docs/five-bucket-test-matrix.md
  # ("no_discarding_arrow_in_with.ex -> check_file/3 -> #1-8").
  #
  # Sabotage record: ../../sabotage_records/no_discarding_arrow_in_with-20260913-dnd_134_t6_9_no_discarding_arrow_in_with.md
  use ExUnit.Case, async: true

  alias Anchor.Check.NoDiscardingArrowInWith
  alias Credo.SourceFile

  defp issues(source) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :no_discarding_arrow_in_with}
    NoDiscardingArrowInWith.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row 1 — Happy Path
    test "flags `_ <- expr` discarding clause" do
      source = """
      defmodule MyApp.Example do
        def f do
          with _ <- some_function() do
            :ok
          end
        end
      end
      """

      assert [issue] = issues(source)

      assert issue.message ==
               "Unnecessary arrow (<-) in with clause. Pattern `_` only discards the value. " <>
                 "Remove the arrow and pattern to simplify"

      assert issue.trigger == "_"
      assert issue.line_no == 3
    end

    # Row 2 — Happy Path
    test "flags `_result <- expr` (underscore-prefixed var)" do
      source = """
      defmodule MyApp.Example do
        def f do
          with _result <- some_function() do
            :ok
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "_result"
    end

    # Row 3 — Validation
    test "flags a discarding clause with a guard" do
      source = """
      defmodule MyApp.Example do
        def f do
          with _x when is_nil(_x) <- some_function() do
            :ok
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "_x"
    end

    # Row 4 — Positive Control
    test "passes meaningful pattern `{:ok, value} <-`" do
      source = """
      defmodule MyApp.Example do
        def f do
          with {:ok, value} <- some_function() do
            value
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row 5 — Positive Control
    test "passes `{:ok, _} <-` (structural match, not bare discard)" do
      source = """
      defmodule MyApp.Example do
        def f do
          with {:ok, _} <- some_function() do
            :ok
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row 6 — Positive Control
    test "passes a normal bound var `value <- expr`" do
      source = """
      defmodule MyApp.Example do
        def f do
          with value <- some_function() do
            value
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row 7 — High Signal
    test "flags only the discarding clause in a multi-clause `with`" do
      source = """
      defmodule MyApp.Example do
        def f do
          with {:ok, v} <- a(),
               _ <- b(v) do
            v
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.line_no == 4
    end

    # Row 8 — Positive Control
    test "`with` with no arrow clauses (all bare exprs) passes" do
      source = """
      defmodule MyApp.Example do
        def f do
          with true, do: :ok
        end
      end
      """

      assert issues(source) == []
    end
  end

  describe "rule_type/0" do
    test "is :no_discarding_arrow_in_with" do
      assert NoDiscardingArrowInWith.rule_type() == :no_discarding_arrow_in_with
    end
  end
end
