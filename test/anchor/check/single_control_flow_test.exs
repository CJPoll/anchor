defmodule Anchor.Check.SingleControlFlowTest do
  use ExUnit.Case

  alias Anchor.Check.SingleControlFlow
  alias Credo.SourceFile

  describe "single control flow check" do
    test "allows functions with no control-flow structures" do
      source_code = """
      defmodule MyApp.Example do
        def simple_function(a, b) do
          a + b
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "allows functions with exactly one control-flow structure" do
      source_code = """
      defmodule MyApp.Example do
        def with_if(x) do
          if x > 0 do
            :positive
          else
            :non_positive
          end
        end

        def with_case(value) do
          case value do
            nil -> :empty
            _ -> :has_value
          end
        end

        def with_pipe(list) do
          list
          |> Enum.map(&(&1 * 2))
          |> Enum.sum()
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "detects functions with multiple control-flow structures" do
      source_code = """
      defmodule MyApp.Example do
        def multiple_flows(x, list) do
          result = if x > 0 do
            list
            |> Enum.map(&(&1 * 2))
            |> Enum.sum()
          else
            0
          end
          
          result
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "contains 2 control-flow structures"
      assert issue.trigger == "multiple_flows"
    end

    test "counts pipe chains as one control-flow structure" do
      source_code = """
      defmodule MyApp.Example do
        def long_pipe(list) do
          list
          |> Enum.map(&(&1 * 2))
          |> Enum.filter(&(&1 > 10))
          |> Enum.take(5)
          |> Enum.sum()
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "detects nested control-flow structures" do
      source_code = """
      defmodule MyApp.Example do
        def nested_flows(x, y) do
          case x do
            :a ->
              if y > 0 do
                :positive_a
              else
                :non_positive_a
              end
            :b ->
              :just_b
          end
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "contains 2 control-flow structures"
    end

    test "handles all control-flow types" do
      source_code = """
      defmodule MyApp.Example do
        def with_cond(x) do
          cond do
            x > 10 -> :big
            x > 0 -> :small
            true -> :zero_or_negative
          end
        end

        def with_with(user, params) do
          with {:ok, user} <- validate_user(user),
               {:ok, params} <- validate_params(params) do
            process(user, params)
          end
        end

        def with_unless(x) do
          unless x == nil do
            x * 2
          end
        end

        def with_for(list) do
          for x <- list, x > 0 do
            x * 2
          end
        end

        def with_receive() do
          receive do
            {:msg, data} -> data
          after
            1000 -> :timeout
          end
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      # All functions have exactly one control-flow structure
      assert length(issues) == 0
    end

    test "handles private functions" do
      source_code = """
      defmodule MyApp.Example do
        defp private_with_multiple(x) do
          y = case x do
            nil -> 0
            n -> n
          end
          
          if y > 0 do
            :positive
          else
            :non_positive
          end
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.trigger == "private_with_multiple"
    end

    test "handles functions with guards" do
      source_code = """
      defmodule MyApp.Example do
        def guarded(x) when is_integer(x) do
          if x > 0 do
            :positive
          else
            :non_positive
          end
        end
      end
      """

      rule = %{type: :single_control_flow}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = SingleControlFlow.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end
  end
end
