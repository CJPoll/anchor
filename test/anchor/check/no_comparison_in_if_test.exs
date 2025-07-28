defmodule Anchor.Check.NoComparisonInIfTest do
  use ExUnit.Case

  alias Anchor.Check.NoComparisonInIf
  alias Credo.SourceFile

  test "does not flag if statements without comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if valid_user?(user) do
          :ok
        end

        if user.active? do
          :active
        end

        if Enum.empty?(list) do
          :empty
        end
      end

      defp valid_user?(user), do: user.age >= 18
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  test "flags if statements with equality comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if user.status == :active do
          :ok
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
    assert issues |> hd() |> Map.get(:message) =~ "Avoid direct comparisons in `if` statements"
  end

  test "flags if statements with inequality comparisons" do
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
    assert length(issues) == 1
  end

  test "flags if statements with strict equality comparisons" do
    source = """
    defmodule TestModule do
      def test_function(value) do
        if value === nil do
          :nil_value
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  test "flags if statements with logical operators containing comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if user.age >= 18 and user.status == :active do
          :eligible
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  test "flags if statements with negated comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if not (user.age < 18) do
          :adult
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  test "flags multiple if statements with comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user, account) do
        if user.age >= 18 do
          :adult
        end

        if account.balance > 0 do
          :has_funds
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 2
  end

  test "does not flag complex expressions without comparisons" do
    source = """
    defmodule TestModule do
      def test_function(user, list) do
        if user.active? and not Enum.empty?(list) do
          :ready
        end

        if valid_user?(user) or admin?(user) do
          :authorized
        end
      end

      defp valid_user?(user), do: user.verified?
      defp admin?(user), do: user.role == :admin
    end
    """

    issues = run_check(source)
    assert issues == []
  end

  test "flags nested comparisons in logical expressions" do
    source = """
    defmodule TestModule do
      def test_function(user) do
        if user.active? or user.status == :pending do
          :eligible
        end
      end
    end
    """

    issues = run_check(source)
    assert length(issues) == 1
  end

  defp run_check(source) do
    rules = [%{"type" => "no_comparison_in_if"}]
    source_file = SourceFile.parse(source, "test.ex")
    NoComparisonInIf.check_file(source_file, rules, [])
  end
end