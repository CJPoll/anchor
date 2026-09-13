defmodule Anchor.Check.NoTupleMatchInHeadTest do
  # Framework-edge characterization for the `no_tuple_match_in_head` check: the
  # 15-row acceptance matrix, exercised through `check_file/3` so the assertions
  # land on the built `%Credo.Issue{}` (message / trigger / line_no). Detection
  # itself is AST-based and lives in the pure Domain module, tested directly in
  # test/anchor/domain/checks/no_tuple_match_in_head_test.exs.
  #
  # Sabotage record:
  #   ../../sabotage_records/no_tuple_match_in_head-20260913-dnd_131_t6_6_no_tuple_match_in_head.md
  use ExUnit.Case, async: true

  alias Anchor.Check.NoTupleMatchInHead
  alias Credo.SourceFile

  defp issues(source_code) do
    rule = %{type: :no_tuple_match_in_head}
    source_file = SourceFile.parse(source_code, "lib/my_app/example.ex")
    NoTupleMatchInHead.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row #1
    test "flags a direct :ok tuple head (message/trigger/line)" do
      source = """
      defmodule MyApp.Example do
        def process({:ok, data}) do
          transform(data)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "pattern matches on :ok/:error tuple"
      assert issue.message =~ "public function head"
      assert issue.trigger == "process"
      assert issue.line_no == 2
    end

    # Row #2
    test "flags a direct :error tuple head, trigger is the function name" do
      source = """
      defmodule MyApp.Example do
        def handle_error({:error, reason}) do
          log(reason)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "pattern matches on :ok/:error tuple"
      assert issue.trigger == "handle_error"
    end

    # Row #3
    test "flags a three-element :error tuple head" do
      source = """
      defmodule MyApp.Example do
        def handle_detailed_error({:error, type, details}) do
          log_error(type, details)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "handle_detailed_error"
    end

    # Row #4 — forward match-assignment: `{:ok, _} = result`
    test "flags a forward match-assignment whose left operand is an :ok tuple" do
      source = """
      defmodule MyApp.Example do
        def process({:ok, _} = result) do
          log_success(result)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "process"
    end

    # Row #5 — reversed match-assignment: `result = {:ok, data}`
    test "flags a reversed match-assignment whose right operand is an :ok tuple" do
      source = """
      defmodule MyApp.Example do
        def process(result = {:ok, data}) do
          use_it(result, data)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "process"
    end

    # Row #6
    test "distinguishes a private function head in the message" do
      source = """
      defmodule MyApp.Example do
        defp handle({:ok, d}) do
          process(d)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "private function head"
      assert issue.trigger == "handle"
    end

    # Row #7
    test "flags a guarded head" do
      source = """
      defmodule MyApp.Example do
        def process({:ok, data}) when is_binary(data) do
          String.upcase(data)
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "process"
    end

    # Row #8
    test "flags each violating clause of a multi-clause function" do
      source = """
      defmodule MyApp.Example do
        def multi({:ok, data}), do: process(data)
        def multi({:error, :not_found}), do: nil
        def multi({:error, reason}), do: {:failed, reason}
        def multi(other), do: other
      end
      """

      issues = issues(source)
      assert length(issues) == 3
      assert Enum.all?(issues, fn issue -> issue.trigger == "multi" end)
    end

    # Row #9 — non ok/error tuple is allowed (positive control alongside)
    test "does not flag a non ok/error tuple head" do
      source = """
      defmodule MyApp.Example do
        def process({:data, value}) do
          transform(value)
        end

        def control({:ok, c}), do: c
      end
      """

      # Only the positive control flags; the {:data, value} head does not.
      assert [issue] = issues(source)
      assert issue.trigger == "control"
    end

    # Row #10 — tuple nested in a list is allowed (positive control alongside)
    test "does not flag an ok tuple nested in a list sub-pattern" do
      source = """
      defmodule MyApp.Example do
        def process([{:ok, d} | rest]) do
          [transform(d) | process(rest)]
        end

        def control({:error, c}), do: c
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "control"
    end

    # Row #11 — tuple nested in a map is allowed (positive control alongside)
    test "does not flag an error tuple nested in a map sub-pattern" do
      source = """
      defmodule MyApp.Example do
        def handle(%{result: {:error, r}}) do
          {:failed, r}
        end

        def control({:ok, c}), do: c
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "control"
    end

    # Row #12 — plain argument is allowed (positive control alongside)
    test "does not flag a plain argument" do
      source = """
      defmodule MyApp.Example do
        def process(data) do
          transform(data)
        end

        def control({:ok, c}), do: c
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "control"
    end

    # Row #13 — a tuple in a body-level `case` is not a head (positive control alongside)
    test "does not flag an ok/error tuple in a body-level case clause" do
      source = """
      defmodule MyApp.Example do
        def handle(result) do
          case result do
            {:ok, value} -> {:success, value}
            {:error, reason} -> {:failure, reason}
          end
        end

        def control({:error, c}), do: c
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "control"
    end

    # Row #14 — mixed head: top-level tuple flags, sibling nested tuple does not suppress it
    test "flags the top-level tuple arg while a sibling nested tuple is allowed" do
      source = """
      defmodule MyApp.Example do
        def f({:ok, a}, %{r: {:error, e}}) do
          {a, e}
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "f"
    end

    # Row #15 — reversed match-assignment in a non-first argument
    test "flags a reversed match-assignment in a later argument position" do
      source = """
      defmodule MyApp.Example do
        def f(x, result = {:error, r}) do
          {x, result, r}
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "f"
    end
  end
end
