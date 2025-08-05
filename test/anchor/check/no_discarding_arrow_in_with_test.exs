defmodule Anchor.Check.NoDiscardingArrowInWithTest do
  use ExUnit.Case

  alias Anchor.Check.NoDiscardingArrowInWith
  alias Credo.SourceFile

  # Helper function to check if issues are found
  defp assert_issue(source_code) do
    source = SourceFile.parse(source_code, "lib/test.ex")
    issues = NoDiscardingArrowInWith.check_file(source, [], [])
    assert length(issues) > 0, "Expected to find issues but found none"
    issues
  end

  defp assert_no_issue(source_code) do
    source = SourceFile.parse(source_code, "lib/test.ex")
    issues = NoDiscardingArrowInWith.check_file(source, [], [])
    assert issues == [], "Expected no issues but found: #{inspect(issues)}"
  end

  describe "single underscore pattern - should trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function() do
            :ok
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with _ when x > 0 <- some_function() do
            :ok
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with _ when x > 0 <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function() do
            :ok
          else
            other -> {:else, other}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end
  end

  describe "variable starting with underscore - should trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with _result <- some_function() do
            :ok
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with _result when x > 0 <- some_function() do
            :ok
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with _result <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with _result when x > 0 <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with _result <- some_function() do
            :ok
          else
            other -> {:else, other}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert Enum.any?(issues, &(&1.message =~ "Unnecessary arrow"))
    end

    test "various underscore variable names" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ignored <- func1(),
               _unused <- func2(),
               _temp <- func3() do
            :ok
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 3
    end
  end

  describe "multiple violations in one with - should trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, value} <- get_value(),
               _ <- log_something(),
               _ignored <- another_function() do
            use_value(value)
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2  # Should find 2 violations
    end

    test "with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {:ok, value} <- get_value(),
               _ when x > 0 <- log_something(),
               _ignored when x > 1 <- another_function() do
            use_value(value)
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, value} <- get_value(),
               _ <- log_something(),
               _ignored <- another_function() do
            use_value(value)
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end

    test "with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {:ok, value} <- get_value(),
               _ when x > 0 <- log_something(),
               _ignored when x > 1 <- another_function() do
            use_value(value)
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, value} <- get_value(),
               _ <- log_something(),
               _ignored <- another_function() do
            use_value(value)
          else
            {:error, reason} -> {:failed, reason}
            other -> {:unexpected, other}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end
  end

  describe "no left-arrow - should NOT trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with some_function() do
            :ok
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with some_function() do
            :ok
          else
            false -> :failed
            nil -> :not_found
          end
        end
      end
      """
      assert_no_issue(source_code)
    end
  end

  describe "meaningful pattern match with underscore inside - should NOT trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, _} <- some_function() do
            :ok
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {:ok, _} when x > 0 <- some_function() do
            :ok
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, _} <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {:ok, _} when x > 0 <- some_function() do
            :ok
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, _} <- some_function() do
            :ok
          else
            {:error, reason} -> {:failed, reason}
            other -> {:unexpected, other}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end
  end

  describe "variable without underscore prefix - should NOT trigger" do
    test "base case" do
      source_code = """
      defmodule Test do
        def test_func do
          with result <- some_function() do
            result
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with result when x > 0 <- some_function() do
            result
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with result <- some_function() do
            result
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with result when x > 0 <- some_function() do
            result
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with result <- some_function() do
            result
          else
            nil -> :not_found
            other -> other
          end
        end
      end
      """
      assert_no_issue(source_code)
    end
  end

  describe "complex patterns - should NOT trigger" do
    test "list pattern" do
      source_code = """
      defmodule Test do
        def test_func do
          with [_, _, third] <- get_list() do
            third
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "tuple pattern with guard" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {_, second} when x > 0 <- get_tuple() do
            second
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "map pattern with rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          with %{key: _, value: v} <- get_map() do
            v
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "multiple underscores with guard and rescue" do
      source_code = """
      defmodule Test do
        def test_func do
          x = 5
          with {_, _, third} when x > 0 <- get_triple() do
            third
          rescue
            e -> {:error, e}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "struct pattern with else" do
      source_code = """
      defmodule Test do
        def test_func do
          with %MyStruct{id: _, data: data} <- get_struct() do
            data
          else
            nil -> :not_found
            other -> {:invalid, other}
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "error tuple patterns" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:error, _, _} <- some_function() do
            :ok
          end
        end
      end
      """
      assert_no_issue(source_code)
    end
  end

  describe "nested with expressions" do
    test "should detect violation in inner with" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, conn} <- get_connection() do
            with _ <- validate(conn) do
              :ok
            end
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 1
    end

    test "nested with variations" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, conn} <- get_connection() do
            x = 5
            with _ when x > 0 <- validate(conn) do
              :ok
            rescue
              e -> {:validation_error, e}
            end
          else
            {:error, reason} -> {:connection_failed, reason}
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 1
    end

    test "multiple nested violations" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, data} <- get_data() do
            with _ <- log_data(data) do
              with _result <- process_data(data) do
                :ok
              end
            end
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end
  end

  describe "edge cases" do
    test "with in function with multiple clauses" do
      source_code = """
      defmodule Test do
        def test_func(true) do
          with _ <- some_function() do
            :ok
          end
        end

        def test_func(false) do
          with _ignored <- another_function() do
            :error
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 2
    end

    test "with catch and after" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function() do
            :ok
          catch
            :throw, value -> {:caught, value}
          after
            cleanup()
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 1
    end

    test "multiple function-level keywords" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function() do
            :ok
          rescue
            e in RuntimeError -> {:runtime_error, e}
            e -> {:error, e}
          catch
            :exit, reason -> {:exit, reason}
            :throw, value -> {:caught, value}
          else
            {:error, _} -> :expected_error
            other -> {:unexpected, other}
          after
            cleanup()
          end
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 1
    end

    test "underscore in rescue/catch patterns should not trigger" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, value} <- some_function() do
            value
          rescue
            %SpecificError{message: _} = e -> {:specific, e}
            _ -> :generic_error
          catch
            :throw, _ -> :caught_throw
          end
        end
      end
      """
      assert_no_issue(source_code)
    end

    test "single line with expression" do
      source_code = """
      defmodule Test do
        def test_func do
          with _ <- some_function(), do: :ok
        end
      end
      """
      issues = assert_issue(source_code)
      assert length(issues) == 1
    end

    test "pattern matching in with body should not affect check" do
      source_code = """
      defmodule Test do
        def test_func do
          with {:ok, data} <- get_data() do
            _ = Logger.debug("Got data")
            process(data)
          end
        end
      end
      """
      assert_no_issue(source_code)
    end
  end
end