defmodule Anchor.Check.CaseOnBareArgTest do
  use ExUnit.Case

  alias Anchor.Check.CaseOnBareArg
  alias Credo.SourceFile

  describe "case on bare arg check" do
    test "detects case statement on bare function argument" do
      source_code = """
      defmodule MyApp.Example do
        def process(status) do
          case status do
            :ok -> "Success!"
            :error -> "Failed!"
            _ -> "Unknown"
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "Case statement operates on bare argument `status`"
      assert issue.message =~ "Consider using function head pattern matching"
    end

    test "allows case statement on function call result" do
      source_code = """
      defmodule MyApp.Example do
        def process(data) do
          case validate(data) do
            {:ok, result} -> result
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "allows case statement on expression" do
      source_code = """
      defmodule MyApp.Example do
        def process(x, y) do
          case x + y do
            0 -> :zero
            n when n > 0 -> :positive
            _ -> :negative
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 0
    end

    test "detects multiple violations in same function" do
      source_code = """
      defmodule MyApp.Example do
        def process(status, mode) do
          result = case status do
            :ok -> :continue
            :error -> :stop
          end
          
          case mode do
            :fast -> do_fast(result)
            :slow -> do_slow(result)
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 2
      assert Enum.any?(issues, &(&1.message =~ "bare argument `status`"))
      assert Enum.any?(issues, &(&1.message =~ "bare argument `mode`"))
    end

    test "detects in private functions" do
      source_code = """
      defmodule MyApp.Example do
        defp handle_internal(response) do
          case response do
            {:ok, data} -> process_data(data)
            {:error, _} -> nil
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 1
      issue = List.first(issues)
      assert issue.message =~ "bare argument `response`"
    end

    test "detects in functions with guards" do
      source_code = """
      defmodule MyApp.Example do
        def process(value) when is_atom(value) do
          case value do
            :yes -> true
            :no -> false
            _ -> nil
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 1
    end

    test "allows case on local variables" do
      source_code = """
      defmodule MyApp.Example do
        def process(data) do
          result = transform(data)
          
          case result do
            {:ok, value} -> value
            {:error, _} -> nil
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      # result is a local variable, not a function argument
      assert length(issues) == 0
    end

    test "detects nested case statements" do
      source_code = """
      defmodule MyApp.Example do
        def process(outer, inner) do
          case outer do
            :a ->
              case inner do
                :x -> :ax
                :y -> :ay
              end
            :b ->
              :b_result
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      assert length(issues) == 2
      assert Enum.any?(issues, &(&1.message =~ "bare argument `outer`"))
      assert Enum.any?(issues, &(&1.message =~ "bare argument `inner`"))
    end

    test "handles destructured arguments correctly" do
      source_code = """
      defmodule MyApp.Example do
        def process({:ok, _data} = result) do
          # This should not trigger since result is pattern matched in the function head
          case result do
            {:ok, value} -> value
            _ -> nil
          end
        end

        def handle(%{status: status}) do
          # status is extracted from a map pattern, not a bare arg
          case status do
            :active -> true
            :inactive -> false
          end
        end
      end
      """

      rule = %{type: :case_on_bare_arg}
      source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
      issues = CaseOnBareArg.check_file(source_file, [rule], [])

      # Neither should trigger - they're not simple bare arguments
      assert length(issues) == 0
    end
  end
end