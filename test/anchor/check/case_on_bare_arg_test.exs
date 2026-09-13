defmodule Anchor.Check.CaseOnBareArgTest do
  # Acceptance tests for Anchor.Check.CaseOnBareArg (T6.7 / DND-132).
  #
  # Detection now lives in the pure Domain module
  # Anchor.Domain.Checks.CaseOnBareArg; this suite exercises the check's
  # observable contract end-to-end through the thin Framework shell:
  # `check_file/3` takes a real `Credo.SourceFile` and returns
  # `[%Credo.Issue{}]`. These rows match
  # docs/five-bucket-test-matrix.md ("case_on_bare_arg.ex -> check_file/3 -> #1-8").
  #
  # Sabotage record: ../../sabotage_records/case_on_bare_arg-20260913-dnd_132_t6_7_case_on_bare_arg.md
  use ExUnit.Case, async: true

  alias Anchor.Check.CaseOnBareArg
  alias Credo.SourceFile

  defp issues(source) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :case_on_bare_arg}
    CaseOnBareArg.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row 1 — Happy Path
    test "flags case directly on a bare argument" do
      source = """
      defmodule MyApp.Example do
        def process(status) do
          case status do
            :ok -> "Success!"
            :error -> "Failed!"
          end
        end
      end
      """

      assert [issue] = issues(source)

      assert issue.message ==
               "Case statement operates on bare argument `status` in function `process`. Consider using function head pattern matching instead."

      assert issue.trigger == "case"
      assert issue.line_no == 3
    end

    # Row 2 — Positive Control
    test "passes when case is on a transformed value" do
      source = """
      defmodule MyApp.Example do
        def process(data) do
          case validate(data) do
            :ok -> :done
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row 3 — Happy Path
    test "flags bare arg in a guarded function" do
      source = """
      defmodule MyApp.Example do
        def process(status) when is_atom(status) do
          case status do
            :yes -> true
            :no -> false
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "case"
    end

    # Row 4 — Validation (adjudicated fix: a defaulted arg is still bare)
    test "flags case on a defaulted bare argument" do
      source = """
      defmodule MyApp.Example do
        def process(status \\\\ :ok) do
          case status do
            :ok -> :done
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.trigger == "case"
      assert issue.message =~ "bare argument `status`"
    end

    # Row 5 — Control Flow Decisioning
    test "passes when the case scrutinee is a different variable" do
      source = """
      defmodule MyApp.Example do
        def process(a) do
          b = f(a)

          case b do
            :ok -> :done
          end
        end
      end
      """

      assert issues(source) == []
    end

    # Row 6 — Happy Path
    test "flags in a private function" do
      source = """
      defmodule MyApp.Example do
        defp process(x) do
          case x do
            :ok -> :done
          end
        end
      end
      """

      assert [issue] = issues(source)
      assert issue.message =~ "function `process`"
    end

    # Row 7 — High Signal
    test "flags two bare-arg cases in one function" do
      source = """
      defmodule MyApp.Example do
        def process(a, b) do
          case a, do: (:ok -> :continue)
          case b, do: (:fast -> :go)
        end
      end
      """

      issues = issues(source)
      assert length(issues) == 2

      line_nos = issues |> Enum.map(& &1.line_no) |> Enum.sort()
      assert line_nos == [3, 4]
    end

    # Row 8 — Positive Control
    test "passes when there is no case at all" do
      source = """
      defmodule MyApp.Example do
        def process(x), do: x + 1
      end
      """

      assert issues(source) == []
    end
  end

  describe "rule_type/0" do
    test "is :case_on_bare_arg" do
      assert CaseOnBareArg.rule_type() == :case_on_bare_arg
    end
  end
end
