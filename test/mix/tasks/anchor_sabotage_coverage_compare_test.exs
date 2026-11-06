defmodule Mix.Tasks.Anchor.SabotageCoverageCompareTest do
  # Framework tests for `mix anchor.sabotage coverage-compare` (DND-5692): argv,
  # rendering and the exit code, the store doubled by Hammox.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/coverage_compare-20261106-dnd_5692_repeatability_check.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.CoverageStoreMock
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  @opts [coverage_store: CoverageStoreMock]

  test "a failure's lines go to stderr, and its code is the exit" do
    expect(CoverageStoreMock, :read, 2, fn _path -> {:error, :enoent} end)
    argv = ["coverage-compare", "one.etf", "two.etf"]

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 3}
      end)

    assert stderr =~ "COULD NOT MEASURE"
    assert stderr =~ "first build (one.etf): no file"
  end

  for argv <- [[], ["one.etf"], ["one.etf", "two.etf", "three.etf"]] do
    test "#{length(argv)} paths is usage: exit 2, nothing read" do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(["coverage-compare" | unquote(argv)], @opts)) ==
                   {:shutdown, 2}
        end)

      assert stderr =~ "mix anchor.sabotage coverage-compare FIRST SECOND"
      assert stderr =~ "Fix: "
    end
  end
end
