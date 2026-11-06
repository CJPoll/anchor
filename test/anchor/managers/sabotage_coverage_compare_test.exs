defmodule Anchor.Managers.SabotageCoverageCompareTest do
  # Manager tests for `Anchor.Managers.Sabotage.coverage_compare/2` (DND-5692): the
  # store doubled by Hammox `expect/3`, so each file is proven read, and read from the
  # path it was given. The verdicts themselves are CoverageCompareTest's.
  # Sabotage record: ../../sabotage_records/coverage_compare-20261106-dnd_5692_repeatability_check.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.CoverageStoreMock
  alias Anchor.Managers.Sabotage

  setup :verify_on_exit!

  @opts [coverage_store: CoverageStoreMock]
  @facts %{first: "/tmp/one.etf", second: "/tmp/two.etf"}
  @map %{
    version: 2,
    commit: String.duplicate("a", 40),
    elixir: "1.19.4",
    otp: "28",
    tests: [
      %{file: "test/a_test.exs", line: 3, name: "test one", module: "ATest", functions: ["A.f/0"]}
    ],
    leaks: [],
    ambient: [],
    modules_traced: 1,
    suite_exit: 0,
    counters: %{call_rows: 1, credited_by_label: 0, spawns: 1}
  }

  defp reads(first, second) do
    expect(CoverageStoreMock, :read, 2, fn
      "/tmp/one.etf" -> first
      "/tmp/two.etf" -> second
    end)
  end

  test "reads both paths: equal maps are exit 0, and the line names each path" do
    reads({:ok, @map}, {:ok, @map})

    assert {0, [line]} = Sabotage.coverage_compare(@facts, @opts)
    assert line =~ "identical: /tmp/one.etf and /tmp/two.etf"
  end

  test "the second map's read decides as well as the first's: a difference is exit 1" do
    reads({:ok, @map}, {:ok, %{@map | ambient: ["C.boot/0"]}})

    assert {1, lines} = Sabotage.coverage_compare(@facts, @opts)
    assert "differs: ambient C.boot/0: only in the second build (/tmp/two.etf)" in lines
  end

  # No expectation on the store: a read fails this.
  test "one path given twice is exit 3, nothing read, even spelled two ways" do
    facts = %{first: "/tmp/one.etf", second: "/tmp/./x/../one.etf"}

    assert {3, lines} = Sabotage.coverage_compare(facts, @opts)
    assert "/tmp/one.etf was given as both builds, and a file always equals itself" in lines
  end

  test "a second file that cannot be read is exit 3, naming its path" do
    reads({:ok, @map}, {:error, :enoent})

    assert {3, lines} = Sabotage.coverage_compare(@facts, @opts)
    assert "second build (/tmp/two.etf): no file, so that build wrote no map" in lines
  end
end
