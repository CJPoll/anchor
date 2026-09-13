defmodule Anchor.Check.SingleControlFlowTest do
  # Framework contract for Anchor.Check.SingleControlFlow: real `Credo.SourceFile`
  # in, `[%Credo.Issue{}]` out via `check_file/3`. Detection lives in the Domain
  # (Anchor.Domain.Checks.SingleControlFlow, tested in
  # test/anchor/domain/checks/single_control_flow_test.exs); these rows verify
  # the thin shell delegates and that violations are mapped to issues with the
  # right message/trigger/line_no.
  #
  # Covers docs/five-bucket-test-matrix.md → single_control_flow.ex → check_file/3
  # rows #1-10 (adjudicated contract).
  #
  # Sabotage record: ../../sabotage_records/single_control_flow-20260913-dnd_130_t6_5_single_control_flow.md
  use ExUnit.Case, async: true

  alias Anchor.Check.SingleControlFlow
  alias Credo.SourceFile

  defp issues(source) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :single_control_flow}
    SingleControlFlow.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row #1
    test "flags a clause with two control-flow structures" do
      source = """
      defmodule S do
        def f(x) do
          if x do
            case x do
              _ -> 1
            end
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "contains 2 control-flow structures (maximum allowed: 1)"
      assert issue.trigger == "f"
      assert issue.line_no == 2
    end

    # Row #2
    test "single `case` clause passes" do
      source = """
      defmodule S do
        def f(x) do
          case validate(x) do
            :ok -> :ok
            _ -> :error
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row #3
    test "a single pipe chain counts as one (passes)" do
      source = """
      defmodule S do
        def f(x) do
          x |> a() |> b() |> c()
        end
      end
      """

      assert issues(source) == []
    end

    # Row #4
    test "pipe chain plus a `case` flags (count 2)" do
      source = """
      defmodule S do
        def f(x) do
          y = x |> a() |> b()

          case y do
            _ -> y
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "contains 2 control-flow structures"
    end

    # Row #5
    test "two separate pipe chains flag (count 2)" do
      source = """
      defmodule S do
        def f(x, y) do
          a = x |> one() |> two()
          b = y |> three() |> four()
          {a, b}
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "contains 2 control-flow structures"
    end

    # Row #6
    test "`with` + `if` flags" do
      source = """
      defmodule S do
        def f(x) do
          with {:ok, v} <- validate(x) do
            if v do
              :ok
            end
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "contains 2 control-flow structures"
    end

    # Row #7
    test "`for` + `unless` flags (cond/receive also count as structures)" do
      source = """
      defmodule S do
        def f(list) do
          unless Enum.empty?(list) do
            for x <- list do
              x * 2
            end
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "contains 2 control-flow structures"
    end

    # Row #8
    test "clause with guard is analyzed" do
      source = """
      defmodule S do
        def f(x) when is_integer(x) do
          if x do
            case x do
              _ -> 1
            end
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "f"
    end

    # Row #9
    test "function with zero control-flow structures passes" do
      source = """
      defmodule S do
        def f(x) do
          x + 1
        end
      end
      """

      assert issues(source) == []
    end

    # Row #10
    test "each violating clause reported at its own def line" do
      source = """
      defmodule S do
        def ok(x) do
          x + 1
        end

        def bad(x) do
          if x do
            case x do
              _ -> 1
            end
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.line_no == 6
    end
  end

  describe "rule_type/0" do
    test "is :single_control_flow" do
      assert SingleControlFlow.rule_type() == :single_control_flow
    end
  end
end
