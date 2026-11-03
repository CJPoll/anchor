defmodule Anchor.Managers.SabotageCoverageTest do
  # Manager tests for `Anchor.Managers.Sabotage.coverage/2` (DND-5474): every
  # port doubled by Hammox `expect/3`, so a call the test does not expect
  # fails it ("nothing traced" is proven by expecting no `start`). Each double
  # reports its call to the test process, so the order is asserted.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.CoverageStoreMock
  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.GitWorktreeMock
  alias Anchor.InProcessTestsMock
  alias Anchor.Managers.Sabotage
  alias Anchor.ProjectModuleSourceMock
  alias Anchor.TracingMock

  setup :verify_on_exit!

  @opts [
    tracing: TracingMock,
    in_process_tests: InProcessTestsMock,
    project_modules: ProjectModuleSourceMock,
    coverage_store: CoverageStoreMock,
    git_worktree: GitWorktreeMock
  ]
  @t1 %{file: "/repo/test/a_test.exs", line: 3, name: "test one", module: "ATest"}

  defp facts(overrides \\ %{}) do
    Map.merge(
      %{
        root: "/repo",
        env: :test,
        ci: true,
        local: false,
        ebin_dirs: ["/repo/_build/test/lib/app/ebin"],
        out: "/repo/cov.etf",
        collector: self(),
        elixir: "1.19.4",
        otp: "28",
        test_args: ["--exclude", "slow"]
      },
      overrides
    )
  end

  defp call(name, result) do
    send(self(), {:call, name})
    result
  end

  defp calls(acc \\ []) do
    receive do
      {:call, name} -> calls([name | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp state do
    CoverageMap.attribute(CoverageMap.new(), [
      {:window_open, 1, @t1},
      {:call, 2, {A, :f, 0}},
      {:window_close, 3, @t1}
    ])
  end

  defp expect_modules(modules \\ [A, B]) do
    expect(ProjectModuleSourceMock, :list, fn ["/repo/_build/test/lib/app/ebin"] ->
      call(:modules, modules)
    end)
  end

  defp expect_traced(suite_result, state \\ state()) do
    collector = self()
    expect(TracingMock, :start, fn ^collector, [A, B] -> call(:start, :ok) end)

    expect(InProcessTestsMock, :run, fn ["--exclude", "slow"] ->
      call(:suite, suite_result)
    end)

    expect(TracingMock, :stop, fn -> call(:stop, :ok) end)
    expect(TracingMock, :collected, fn ^collector -> call(:collected, {:ok, state}) end)
    expect(GitWorktreeMock, :head_sha, fn "/repo" -> {:ok, "abc123"} end)
  end

  test "1: outside CI and without --local: exit 2 with its Fix:, nothing traced" do
    assert {2, [message]} = Sabotage.coverage(facts(%{ci: false}), @opts)

    assert message ==
             "per-test coverage runs the whole suite serially with call tracing; it belongs " <>
               "in CI. Fix: run it in CI, or pass --local where that load is acceptable."

    assert calls() == []
  end

  test "--local outside CI runs" do
    expect_modules()
    expect_traced(:passed)
    expect(CoverageStoreMock, :write, fn "/repo/cov.etf", _map -> :ok end)

    assert {0, [_summary]} = Sabotage.coverage(facts(%{ci: false, local: true}), @opts)
  end

  test "a --max-cases in the test args is refused, exit 2: tests must never overlap" do
    for args <- [["--max-cases", "4"], ["--max-cases=4"], ["test/a_test.exs", "--max-cases", "1"]] do
      assert {2, [message]} = Sabotage.coverage(facts(%{test_args: args}), @opts), inspect(args)

      assert message =~
               "per-test coverage runs one test at a time, so the test arguments may not " <>
                 "set --max-cases"
    end

    assert calls() == []
  end

  test "MIX_ENV other than test: exit 2, nothing listed or traced" do
    assert {2, [message]} = Sabotage.coverage(facts(%{env: :dev}), @opts)
    assert message =~ "Fix: MIX_ENV=test mix anchor.sabotage coverage"
    assert calls() == []
  end

  test "2: tracing starts before the suite and stops after it; the finalized map is written" do
    expect_modules()
    expect_traced(:passed)

    expect(CoverageStoreMock, :write, fn "/repo/cov.etf", map ->
      send(self(), {:written, map})
      call(:write, :ok)
    end)

    assert {0, [summary]} = Sabotage.coverage(facts(), @opts)
    assert calls() == [:modules, :start, :suite, :stop, :collected, :write]

    assert_received {:written, map}

    assert map ==
             CoverageMap.finalize(state(), %{
               commit: "abc123",
               elixir: "1.19.4",
               otp: "28",
               modules_traced: 2,
               suite_exit: 0,
               root: "/repo"
             })

    assert [%{file: "test/a_test.exs", functions: ["A.f/0"]}] = map.tests
    assert summary =~ "tests: 1, modules_traced: 2"
  end

  test "3: a suite that raises still stops tracing" do
    collector = self()
    expect_modules()
    expect(TracingMock, :start, fn ^collector, [A, B] -> :ok end)
    expect(InProcessTestsMock, :run, fn _args -> raise "boom" end)
    expect(TracingMock, :stop, fn -> call(:stop, :ok) end)

    assert_raise RuntimeError, "boom", fn -> Sabotage.coverage(facts(), @opts) end
    assert calls() == [:modules, :stop]
  end

  test "4: zero project modules: exit 3 COULD NOT MEASURE, nothing traced or written" do
    expect_modules([])

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: 0 project modules"
    assert calls() == [:modules]
  end

  test "zero tests traced: exit 3, no map written" do
    expect_modules()
    expect_traced(:passed, CoverageMap.new())

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: tests: 0, modules_traced: 2; no map was written"
    refute :write in calls()
  end

  test "5: a failed suite still writes the map, marked, and exits 1" do
    expect_modules()
    expect_traced({:failed, "\"mix test\" failed"})

    expect(CoverageStoreMock, :write, fn "/repo/cov.etf", %{suite_exit: 1} ->
      call(:write, :ok)
    end)

    assert {1, [_summary, message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "Fix: make the suite green first"
    assert :write in calls()
  end

  test "another tracer already on: exit 2, the suite never runs" do
    collector = self()
    expect_modules()
    expect(TracingMock, :start, fn ^collector, _modules -> {:error, :already_tracing} end)

    assert {2, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "Fix: run without other tracers"
  end

  test "a collector that stopped: exit 3, nothing written" do
    collector = self()
    expect_modules()
    expect(TracingMock, :start, fn ^collector, _modules -> :ok end)
    expect(InProcessTestsMock, :run, fn _args -> :passed end)
    expect(TracingMock, :stop, fn -> :ok end)

    expect(TracingMock, :collected, fn ^collector ->
      {:error, {:collector_down, :killed}}
    end)

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: the coverage collector stopped (:killed)"
  end

  test "a map that cannot be written: exit 2 with a Fix:" do
    expect_modules()
    expect_traced(:passed)
    expect(CoverageStoreMock, :write, fn _path, _map -> {:error, :eacces} end)

    assert {2, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "could not write /repo/cov.etf (:eacces). Fix: pass --out a writable path"
  end
end
