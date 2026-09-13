defmodule Anchor.Domain.Checks.NoTupleMatchInHeadTest do
  # Pure Domain detection for the `no_tuple_match_in_head` check: (bare AST,
  # rules) in, `[%Violation{}]` out. No Credo types, no IO. The Framework mapping
  # to `Credo.Issue` (and the full 15-row acceptance matrix) is exercised in
  # test/anchor/check/no_tuple_match_in_head_test.exs.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_tuple_match_in_head-20260913-dnd_131_t6_6_no_tuple_match_in_head.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoTupleMatchInHead
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp rule, do: %{type: :no_tuple_match_in_head}

  defp detect(source), do: NoTupleMatchInHead.detect_violations(ast(source), [rule()])

  describe "detect_violations/2" do
    test "flags a direct :ok tuple head (message/trigger/line)" do
      violations =
        detect("""
        defmodule S do
          def process({:ok, data}) do
            transform(data)
          end
        end
        """)

      assert [%Violation{} = violation] = violations

      assert violation.message ==
               "Function `process` pattern matches on :ok/:error tuple in its " <>
                 "public function head. Consider having the calling function use a " <>
                 "case statement on the value instead."

      assert violation.trigger == "process"
      assert violation.line == 2
    end

    test "reports a private head as `private function head`" do
      violations =
        detect("""
        defmodule S do
          defp handle({:error, reason}) do
            reason
          end
        end
        """)

      assert [%Violation{} = violation] = violations
      assert violation.message =~ "private function head"
      assert violation.trigger == "handle"
    end

    test "flags a forward match-assignment (`{:ok, _} = result`)" do
      violations =
        detect("""
        defmodule S do
          def process({:ok, _} = result) do
            result
          end
        end
        """)

      assert [%Violation{trigger: "process"}] = violations
    end

    test "flags a reversed match-assignment (`result = {:ok, data}`)" do
      violations =
        detect("""
        defmodule S do
          def process(result = {:ok, data}) do
            {result, data}
          end
        end
        """)

      assert [%Violation{trigger: "process"}] = violations
    end

    test "flags each violating clause of a multi-clause function" do
      violations =
        detect("""
        defmodule S do
          def multi({:ok, data}), do: data
          def multi({:error, :not_found}), do: nil
          def multi({:error, reason}), do: reason
          def multi(other), do: other
        end
        """)

      assert length(violations) == 3
      assert Enum.all?(violations, &(&1.trigger == "multi"))
    end

    test "flags a guarded head" do
      violations =
        detect("""
        defmodule S do
          def process({:ok, data}) when is_binary(data) do
            data
          end
        end
        """)

      assert [%Violation{trigger: "process"}] = violations
    end

    test "flags a top-level tuple arg while a sibling nested tuple is allowed" do
      # Positive control: the same clause with a plain first arg produces nothing,
      # so the single violation below comes from the top-level {:ok, a}, not the
      # nested {:error, e}.
      assert detect("""
             defmodule S do
               def f(a, %{r: {:error, e}}), do: {a, e}
             end
             """) == []

      violations =
        detect("""
        defmodule S do
          def f({:ok, a}, %{r: {:error, e}}), do: {a, e}
        end
        """)

      assert [%Violation{trigger: "f"}] = violations
    end

    test "does not flag a non ok/error tuple, a nested tuple, or a plain arg" do
      # Positive control proving detection is live for this AST shape.
      assert [%Violation{trigger: "control"}] =
               detect("""
               defmodule S do
                 def control({:ok, c}), do: c
               end
               """)

      assert detect("""
             defmodule S do
               def a({:data, value}), do: value
               def b([{:ok, d} | rest]), do: {d, rest}
               def c(%{result: {:error, r}}), do: r
               def d(plain), do: plain
             end
             """) == []
    end

    test "does not flag an ok/error tuple in a body-level case" do
      assert detect("""
             defmodule S do
               def handle(result) do
                 case result do
                   {:ok, v} -> v
                   {:error, r} -> r
                 end
               end
             end
             """) == []
    end
  end
end
