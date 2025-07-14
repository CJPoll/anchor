defmodule Anchor.Check.NoTupleMatchInHeadTest do
  use ExUnit.Case

  alias Anchor.Check.NoTupleMatchInHead
  alias Credo.SourceFile

  describe "no tuple match in head check" do
    test "allows functions without tuple pattern matching" do
      source_code = """
      defmodule MyApp.Example do
        def process(data) do
          transform(data)
        end
        
        def handle_result(result) do
          case result do
            {:ok, value} -> {:success, value}
            {:error, reason} -> {:failure, reason}
          end
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "detects direct :ok tuple pattern in function head" do
      source_code = """
      defmodule MyApp.Example do
        def process({:ok, data}) do
          transform(data)
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "pattern matches on :ok/:error tuple"
      assert issue.trigger == "process"
    end

    test "detects direct :error tuple pattern in function head" do
      source_code = """
      defmodule MyApp.Example do
        def handle_error({:error, reason}) do
          Logger.error("Failed: \#{reason}")
          {:error, reason}
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "pattern matches on :ok/:error tuple"
    end

    test "detects :error tuple with additional elements" do
      source_code = """
      defmodule MyApp.Example do
        def handle_detailed_error({:error, type, details}) do
          log_error(type, details)
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 1
    end

    test "allows nested ok/error tuples in complex patterns" do
      source_code = """
      defmodule MyApp.Example do
        def process_response([{:ok, data} | rest]) do
          [transform(data) | process_response(rest)]
        end
        
        def handle_map_result(%{result: {:error, reason}}) do
          {:failed, reason}
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      # These patterns are now allowed
      assert length(issues) == 0
    end

    test "detects pattern matching with assignment" do
      source_code = """
      defmodule MyApp.Example do
        def process({:ok, _} = result) do
          log_success(result)
          result
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      # Assignment patterns are still direct patterns, so they're forbidden
      assert length(issues) == 1
    end

    test "detects in private functions" do
      source_code = """
      defmodule MyApp.Example do
        defp handle_internal({:ok, data}) do
          process(data)
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "private function head"
    end

    test "detects in functions with guards" do
      source_code = """
      defmodule MyApp.Example do
        def process({:ok, data}) when is_binary(data) do
          String.upcase(data)
        end
        
        defp validate({:error, reason}) when not is_nil(reason) do
          log_error(reason)
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 2
    end

    test "allows other tuple patterns that are not ok/error" do
      source_code = """
      defmodule MyApp.Example do
        def process({:data, value}) do
          transform(value)
        end
        
        def handle_event({:event, type, payload}) do
          dispatch(type, payload)
        end
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "detects multiple clauses with ok/error patterns" do
      source_code = """
      defmodule MyApp.Example do
        def multi_clause({:ok, data}), do: process(data)
        def multi_clause({:error, :not_found}), do: nil
        def multi_clause({:error, reason}), do: {:failed, reason}
        def multi_clause(other), do: other
      end
      """

      rule = %{type: :no_tuple_match_in_head}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = NoTupleMatchInHead.check_file(source_file, [rule], [])

      # Should detect 3 issues (first three clauses)
      assert length(issues) == 3
      assert Enum.all?(issues, fn issue -> issue.trigger == "multi_clause" end)
    end
  end
end