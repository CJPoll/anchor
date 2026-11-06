defmodule Anchor.Domain.Sabotage.CoverageArgsTest do
  # DND-5691: the map is of the whole suite, so an argument that chooses files is
  # refused, and an argument this cannot place counts as one.
  # Sabotage record: ../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageArgs

  test "filters and their values choose no file" do
    for args <- [
          [],
          ["--exclude", "global_tracing"],
          ["--only", "file:test/x_test.exs", "--include", "slow"],
          ["--seed", "0", "--timeout", "5000"],
          ["--exclude=slow"],
          ["--trace"],
          ["-n", "name"]
        ] do
      assert CoverageArgs.chooses_files(args) == nil, inspect(args)
    end
  end

  test "a path is refused, with or without a line, wherever it stands" do
    assert CoverageArgs.chooses_files(["test/a_test.exs"]) == "test/a_test.exs"
    assert CoverageArgs.chooses_files(["test/a_test.exs:3"]) == "test/a_test.exs:3"

    assert CoverageArgs.chooses_files(["--exclude", "slow", "test/a_test.exs"]) ==
             "test/a_test.exs"
  end

  test "a boolean switch does not swallow the path after it" do
    assert CoverageArgs.chooses_files(["--trace", "test/a_test.exs"]) == "test/a_test.exs"
  end

  test "the switches that choose files are refused" do
    assert CoverageArgs.chooses_files(["--failed"]) == "--failed"
    assert CoverageArgs.chooses_files(["--stale"]) == "--stale"
    assert CoverageArgs.chooses_files(["--partitions", "2"]) == "--partitions"
    assert CoverageArgs.chooses_files(["--partitions=2"]) == "--partitions=2"
  end

  test "an unknown switch's value reads as a path: refused, never handed on" do
    assert CoverageArgs.chooses_files(["--unknown", "value"]) == "value"
  end
end
