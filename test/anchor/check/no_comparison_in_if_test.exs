defmodule Anchor.Check.NoComparisonInIfTest do
  # Framework-level tests for the `no_comparison_in_if` check: exercises the
  # thin `Anchor.Check.NoComparisonInIf` shell's `check_file/3` (Credo.Issue
  # mapping) end to end. Pure detection lives in
  # Anchor.Domain.Checks.NoComparisonInIf.
  #
  # Sabotage record: ../../sabotage_records/no_comparison_in_if-20260913-dnd_133_t6_8_no_comparison_in_if.md
  use ExUnit.Case

  alias Anchor.Check.NoComparisonInIf
  alias Credo.SourceFile

  # Row #1
  test "flags `if` with a comparison (message/trigger/line)" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if user.age >= 18 do
          :adult
        end
      end
    end
    """

    issues = run_check(source)

    assert [issue] = issues
    assert issue.message =~ "Avoid direct comparisons in "
    assert issue.message =~ "if"
    assert issue.message =~ " statements"
    assert issue.trigger == "if"
    assert issue.line_no == 3
  end

  # Row #2
  for op <- ["==", "!=", "===", "!==", "<", ">", "<=", ">="] do
    test "flags `if` using the #{op} operator" do
      source = """
      defmodule TestModule do
        def test_function(a, b) do
          if a #{unquote(op)} b do
            :ok
          end
        end
      end
      """

      issues = run_check(source)
      assert length(issues) == 1
    end
  end

  # Row #3
  test "flags a compound `and` condition containing a comparison" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if user.age >= 18 and user.verified? do
          :eligible
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  # Row #4
  test "flags a compound `or` condition containing a comparison" do
    source = """
    defmodule TestModule do
      def test_function(a, b) do
        if a or b > 3 do
          :ok
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  # Row #5
  test "flags a negated comparison" do
    source = """
    defmodule TestModule do
      def test_function(a, b) do
        if not (a == b) do
          :ok
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  # Row #6
  test "flags a comparison nested inside a call's arguments" do
    source = """
    defmodule TestModule do
      def test_function(a, b) do
        if valid?(a == b) do
          :ok
        end
      end

      defp valid?(x), do: x
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  # Row #7
  test "flags `unless` with a comparison, with trigger `unless`" do
    source = """
    defmodule TestModule do
      def test_function(a, b) do
        unless a >= b do
          :ok
        end
      end
    end
    """

    issues = run_check(source)

    assert [issue] = issues
    assert issue.trigger == "unless"
  end

  # Row #8
  test "does not flag `if` with a call-based (non-comparison) condition" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if adult?(user) do
          :adult
        end
      end

      defp adult?(user), do: user.age >= 18
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  # Row #9
  test "does not flag `if` with a plain boolean variable/call condition" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if verified?(user) do
          :ok
        end
      end

      defp verified?(user), do: user.verified?
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  # Row #10
  test "does not flag `if` with a compound condition free of comparisons" do
    source = """
    defmodule TestModule do
      def test_function(u) do
        if active?(u) and verified?(u) do
          :ok
        end
      end

      defp active?(u), do: u.active?
      defp verified?(u), do: u.verified?
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  # Row #11
  test "does not flag `unless` with a comparison-free condition" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        unless adult?(user) do
          :ok
        end
      end

      defp adult?(user), do: user.age >= 18
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  defp run_check(source) do
    rules = [%{"type" => "no_comparison_in_if"}]
    source_file = SourceFile.parse(source, "test.ex")
    NoComparisonInIf.check_file(source_file, rules, [])
  end
end
