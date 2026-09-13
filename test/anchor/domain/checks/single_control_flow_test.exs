defmodule Anchor.Domain.Checks.SingleControlFlowTest do
  # Pure Domain detection for the `single_control_flow` check: (bare AST, rules)
  # in, `[%Violation{}]` out. No Credo types, no IO. The Framework mapping to
  # `Credo.Issue` is exercised in test/anchor/check/single_control_flow_test.exs.
  #
  # Sabotage record: ../../../sabotage_records/single_control_flow-20260913-dnd_130_t6_5_single_control_flow.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.SingleControlFlow
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp rule, do: %{type: :single_control_flow}

  describe "detect_violations/2" do
    # Row #1
    test "flags a clause with two control-flow structures (message/trigger/line)" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            if x do
              case x do
                _ -> 1
              end
            end
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])

      assert violation.message ==
               "Function clause `f` contains 2 control-flow structures (maximum allowed: 1). " <>
                 "Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive. Favor extracting pipe chains to helpers before extracting other structures."

      assert violation.trigger == "f"
      assert violation.line == 2
    end

    # Row #2
    test "single `case` clause passes" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            case validate(x) do
              :ok -> :ok
              _ -> :error
            end
          end
        end
        """)

      assert SingleControlFlow.detect_violations(ast, [rule()]) == []
    end

    # Row #3
    test "a single pipe chain counts as one (passes)" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            x |> a() |> b() |> c()
          end
        end
        """)

      assert SingleControlFlow.detect_violations(ast, [rule()]) == []
    end

    # Row #4
    test "pipe chain plus a `case` flags (count 2)" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            y = x |> a() |> b()

            case y do
              _ -> y
            end
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.message =~ "contains 2 control-flow structures"
    end

    # Row #5
    test "two separate pipe chains flag (count 2)" do
      ast =
        ast("""
        defmodule S do
          def f(x, y) do
            a = x |> one() |> two()
            b = y |> three() |> four()
            {a, b}
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.message =~ "contains 2 control-flow structures"
    end

    # Row #6
    test "`with` + `if` flags" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            with {:ok, v} <- validate(x) do
              if v do
                :ok
              end
            end
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.message =~ "contains 2 control-flow structures"
    end

    # Row #7
    test "`for` + `unless` flags (cond/receive also count as structures)" do
      ast =
        ast("""
        defmodule S do
          def f(list) do
            unless Enum.empty?(list) do
              for x <- list do
                x * 2
              end
            end
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.message =~ "contains 2 control-flow structures"
    end

    # Row #8
    test "clause with guard is analyzed" do
      ast =
        ast("""
        defmodule S do
          def f(x) when is_integer(x) do
            if x do
              case x do
                _ -> 1
              end
            end
          end
        end
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.trigger == "f"
    end

    # Row #9
    test "function with zero control-flow structures passes" do
      ast =
        ast("""
        defmodule S do
          def f(x) do
            x + 1
          end
        end
        """)

      assert SingleControlFlow.detect_violations(ast, [rule()]) == []
    end

    # Row #10
    test "each violating clause reported at its own def line" do
      ast =
        ast("""
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
        """)

      assert [%Violation{} = violation] = SingleControlFlow.detect_violations(ast, [rule()])
      assert violation.line == 6
    end
  end
end
