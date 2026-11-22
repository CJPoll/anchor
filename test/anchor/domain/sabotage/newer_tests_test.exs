defmodule Anchor.Domain.Sabotage.NewerTestsTest do
  # DND-7453: which new survivors a test added after a committed record may
  # kill, built from the records' own rows and plain git facts, no test run.
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.NewerTests

  defp outcome(id, selected \\ ["test/calc_test.exs"], function \\ {:add, 2}) do
    %{
      mutant: %Mutant{
        id: id,
        file: "lib/calc.ex",
        module: Calc,
        function: function,
        operator: :return_input,
        variant: 0,
        target: "",
        range: {{1, 1}, {1, 2}},
        original: "",
        replacement: "",
        patch: ""
      },
      status: :survived,
      killers: [],
      selection: {:mirror, selected},
      reason: nil
    }
  end

  defp record(overrides \\ %{}) do
    Map.merge(
      %{
        path: "test/sabotage_records/calc-20261101-first.md",
        commit: "0123456789abcdef0123456789abcdef01234567",
        mfas: ["Calc.add/2"],
        changed: ["test/extra_test.exs"]
      },
      overrides
    )
  end

  @branch ["test/extra_test.exs", "test/calc_test.exs"]

  describe "find/3" do
    test "a branch test changed since a record that lists the function, and not selected" do
      assert %{"aaa" => [found]} = NewerTests.find([outcome("aaa")], [record()], @branch)

      assert found == %{
               record: "test/sabotage_records/calc-20261101-first.md",
               commit: "0123456789abcdef0123456789abcdef01234567",
               tests: ["test/extra_test.exs"]
             }
    end

    test "a test file the mutant's selection already runs is no news" do
      assert NewerTests.find([outcome("aaa", ["test/extra_test.exs"])], [record()], @branch) ==
               %{}
    end

    test "a selection ref with a line counts as its file" do
      assert NewerTests.find(
               [outcome("aaa", ["test/extra_test.exs:12"])],
               [record()],
               @branch
             ) == %{}
    end

    test "a record that does not list the mutant's function says nothing" do
      assert NewerTests.find([outcome("aaa")], [record(%{mfas: ["Calc.sub/2"]})], @branch) ==
               %{}
    end

    test "a test the branch did not change (a file changed on main) is not named" do
      assert NewerTests.find([outcome("aaa")], [record()], ["test/calc_test.exs"]) == %{}
    end

    test "a changed file that is not a test file, or an unsafe path, is not named" do
      rec = record(%{changed: ["lib/calc.ex", "--opt_test.exs", "/abs/x_test.exs"]})

      assert NewerTests.find([outcome("aaa")], [rec], ["lib/calc.ex", "--opt_test.exs"]) == %{}
    end

    test "every record that lists the function and has newer tests is named, in record order" do
      older =
        record(%{path: "test/sabotage_records/calc-20261001-a.md", changed: ["test/a_test.exs"]})

      newer = record()

      assert %{"aaa" => [first, second]} =
               NewerTests.find(
                 [outcome("aaa")],
                 [older, newer],
                 ["test/a_test.exs", "test/extra_test.exs"]
               )

      assert first.tests == ["test/a_test.exs"]
      assert second.tests == ["test/extra_test.exs"]
    end

    test "tests are sorted and listed once" do
      rec = record(%{changed: ["test/z_test.exs", "test/b_test.exs", "test/b_test.exs"]})

      assert %{"aaa" => [%{tests: ["test/b_test.exs", "test/z_test.exs"]}]} =
               NewerTests.find([outcome("aaa")], [rec], ["test/z_test.exs", "test/b_test.exs"])
    end

    test "no records, or no survivors, is an empty map" do
      assert NewerTests.find([outcome("aaa")], [], @branch) == %{}
      assert NewerTests.find([], [record()], @branch) == %{}
    end
  end

  describe "note/2" do
    test "names the record, its short commit, the tests and a Fix line" do
      [found] = NewerTests.find([outcome("aaa")], [record()], @branch)["aaa"]

      assert NewerTests.note(found, outcome("aaa")) == [
               "  Note: a test added after record test/sabotage_records/calc-20261101-first.md " <>
                 "(0123456789ab) may kill this mutant, and this run did not select it: " <>
                 "test/extra_test.exs",
               "  Fix: fold that test into a test file this run selects (test/calc_test.exs), " <>
                 "then re-run: a run selects only the files a record's kill map and the " <>
                 "function's mirror name"
             ]
    end

    test "more than five tests are cut with a count" do
      tests = for n <- 1..7, do: "test/t#{n}_test.exs"
      found = %{record: "r.md", commit: "abc", tests: tests}

      [line | _] = NewerTests.note(found, outcome("aaa"))
      assert line =~ "test/t5_test.exs and 2 more"
      refute line =~ "test/t6_test.exs"
    end
  end
end
