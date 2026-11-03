defmodule Anchor.Domain.Sabotage.ChangedTestsTest do
  # DND-5484: the tests whose lines a diff touched.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ChangedTests

  @source """
  defmodule ATest do
    use ExUnit.Case

    describe "a" do
      test "first" do
        assert 1 == 1
      end

      # a comment line

      test "second", %{x: x} do
        assert x
      end
    end

    test "top level", do: assert(true)
  end
  """

  defp in_ranges(ranges), do: ChangedTests.in_ranges(@source, "test/a_test.exs", ranges)

  test "1: a range inside a describe's test gives its full name and line" do
    assert in_ranges([{12, 2}]) ==
             {:ok, [%{file: "test/a_test.exs", line: 11, name: "test a second"}]}
  end

  test "2: a range on a line between tests gives none (row 1 is the positive control)" do
    assert in_ranges([{9, 1}]) == {:ok, []}
  end

  test "3: a range spanning two tests gives both" do
    assert {:ok, [%{line: 5}, %{line: 11}]} = in_ranges([{6, 6}])
  end

  test "a top-level one-line test, and a deletion point inside a test" do
    assert in_ranges([{16, 1}]) ==
             {:ok, [%{file: "test/a_test.exs", line: 16, name: "test top level"}]}

    assert {:ok, [%{line: 5}]} = in_ranges([{6, 0}])
    assert in_ranges([{7, 0}]) == {:ok, []}
  end

  test "a file that does not parse is an error naming the line" do
    assert {:error, {_line, _message}} =
             ChangedTests.in_ranges("test \"x\" do", "test/b_test.exs", [{1, 1}])
  end
end
