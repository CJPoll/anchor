defmodule Mix.Tasks.Anchor.SabotageCoverageTest do
  # Framework tests for `mix anchor.sabotage coverage` (DND-5474): argv, the CI
  # refusal and the exit code, the Manager's ports doubled by Hammox (a port
  # with no expectation fails the test if it is called: "nothing traced").
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  @opts [
    tracing: Anchor.TracingMock,
    in_process_tests: Anchor.InProcessTestsMock,
    project_modules: Anchor.ProjectModuleSourceMock,
    coverage_store: Anchor.CoverageStoreMock
  ]

  test "outside CI and without --local: exit 2 with the Fix: line, nothing listed or traced" do
    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["coverage"], [ci: false] ++ @opts)) == {:shutdown, 2}
      end)

    assert stderr =~
             "per-test coverage runs the whole suite serially with call tracing; it belongs in CI. " <>
               "Fix: run it in CI, or pass --local where that load is acceptable."
  end

  test "--local passes the CI check; arguments after -- go to the suite" do
    expect(Anchor.ProjectModuleSourceMock, :list, fn [ebin] ->
      assert ebin =~ ~r{_build/test/lib/anchor/ebin$}
      []
    end)

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(
                 Sabotage.run(
                   ["coverage", "--local", "--", "test/x_test.exs"],
                   [ci: false] ++ @opts
                 )
               ) == {:shutdown, 3}
      end)

    assert stderr =~ "COULD NOT MEASURE: 0 project modules"
  end

  test "an unknown flag is a usage error, exit 2" do
    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["coverage", "--bogus"], @opts)) == {:shutdown, 2}
      end)

    assert stderr =~ "mix anchor.sabotage coverage [--out PATH] [--local]"
  end
end
