defmodule Anchor.Managers.SabotageCoverageTest do
  # Manager tests for `Anchor.Managers.Sabotage.coverage/2` (DND-5474): every
  # port doubled by Hammox `expect/3`, so a call the test does not expect
  # fails it ("nothing traced" is proven by expecting no `start`). Each double
  # reports its call to the test process, so the order is asserted.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5642): ../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  # Sabotage record (DND-5690): ../../sabotage_records/sabotage-20261106-dnd_5690_preload.md
  # Sabotage record (DND-5691): ../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
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

  defp pid, do: spawn(fn -> :ok end)

  defp state(extra \\ []) do
    [runner, t] = [pid(), pid()]

    CoverageMap.attribute(
      CoverageMap.new(),
      [
        {:test_started, runner, 1, @t1, ATest},
        {:spawn, runner, t, nil},
        {:entry, 1},
        {:call, {A, :f, 0}, t, 1, 1},
        {:test_finished, runner, 2, true, ATest}
      ] ++ Enum.map(extra, &resolve(&1, t))
    )
  end

  defp resolve({:call, mfa, :test_process, label, word}, t), do: {:call, mfa, t, label, word}
  defp resolve(event, _t), do: event

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
    expect_traced({:passed, 1})
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

  test "a path in the test args is refused, exit 2, before tracing: the map is of the whole suite" do
    for args <- [
          ["test/a_test.exs"],
          ["test/a_test.exs:3"],
          ["--exclude", "slow", "test/a_test.exs"]
        ] do
      assert {2, [message]} = Sabotage.coverage(facts(%{test_args: args}), @opts), inspect(args)
      assert message =~ "per-test coverage maps the whole suite"
      assert message =~ "Fix: "
    end

    assert calls() == []
  end

  test "filters still pass through, to the suite unchanged" do
    expect_modules()
    expect_traced({:passed, 1})
    expect(CoverageStoreMock, :write, fn _path, _map -> :ok end)

    assert {0, [_summary]} = Sabotage.coverage(facts(%{test_args: ["--exclude", "slow"]}), @opts)
  end

  test "MIX_ENV other than test: exit 2, nothing listed or traced" do
    assert {2, [message]} = Sabotage.coverage(facts(%{env: :dev}), @opts)
    assert message =~ "Fix: MIX_ENV=test mix anchor.sabotage coverage"
    assert calls() == []
  end

  test "2: tracing starts before the suite and stops after it; the finalized map is written" do
    state = state()
    expect_modules()
    expect_traced({:passed, 1}, state)

    expect(CoverageStoreMock, :write, fn "/repo/cov.etf", map ->
      send(self(), {:written, map})
      call(:write, :ok)
    end)

    assert {0, [summary]} = Sabotage.coverage(facts(), @opts)
    assert calls() == [:modules, :start, :suite, :stop, :collected, :write]

    assert_received {:written, map}

    assert {:ok, map} ==
             CoverageMap.finalize(state, %{
               commit: "abc123",
               elixir: "1.19.4",
               otp: "28",
               modules_traced: 2,
               suite_exit: 0,
               total: 1,
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
    expect_traced({:passed, 0}, CoverageMap.new())

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: tests: 0, modules_traced: 2; no map was written"
    refute message =~ "The suite failed"
    refute :write in calls()
  end

  # DND-5690: test_helper.exs raises before any test when a module of the closure
  # cannot load. The suite's message is the only place that name is, so a
  # zero-test exit 3 must carry it.
  test "a suite that failed before any test: exit 3 carrying the suite's message" do
    message = "1 module(s) of :anchor's closure failed to load:\n  Dep: :nofile\nFix: repair it"
    expect_modules()
    expect_traced({:failed, message, nil}, CoverageMap.new())

    assert {3, [refusal]} = Sabotage.coverage(facts(), @opts)
    assert refusal =~ "COULD NOT MEASURE: tests: 0, modules_traced: 2; no map was written"
    assert refusal =~ "The suite failed before any test ran: #{message}"
    refute :write in calls()
  end

  test "5: a failed suite still writes the map, marked, and exits 1" do
    expect_modules()
    expect_traced({:failed, "1 of 1 test(s) failed", 1})

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

  # DND-5690: no expectation on the suite, the collector or the store, so
  # Hammox fails this if the run goes on past the refusal.
  test "a project module that cannot load: exit 3 naming it, the suite never runs" do
    collector = self()
    expect_modules()

    expect(TracingMock, :start, fn ^collector, _modules ->
      {:error, {:not_loadable, [A, B]}}
    end)

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)

    assert message =~
             "COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls " <>
               "cannot be traced: A, B; no map was written."

    assert message =~ "Fix: "
  end

  test "a collector that stopped: exit 3, nothing written" do
    collector = self()
    expect_modules()
    expect(TracingMock, :start, fn ^collector, _modules -> :ok end)
    expect(InProcessTestsMock, :run, fn _args -> {:passed, 0} end)
    expect(TracingMock, :stop, fn -> :ok end)

    expect(TracingMock, :collected, fn ^collector ->
      {:error, {:collector_down, :killed}}
    end)

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: the coverage collector stopped (:killed)"
  end

  test "a map that cannot be written: exit 2 with a Fix:" do
    expect_modules()
    expect_traced({:passed, 1})
    expect(CoverageStoreMock, :write, fn _path, _map -> {:error, :eacces} end)

    assert {2, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "could not write /repo/cov.etf (:eacces). Fix: pass --out a writable path"
  end

  # DND-5691: no expectation on the suite or the store: the run stops at the refusal.
  test "an ExUnit function that cannot be traced: exit 3 naming it, the suite never runs" do
    collector = self()
    mfa = {ExUnit.Runner, :run_setup_all, 4}
    expect_modules()
    expect(TracingMock, :start, fn ^collector, _modules -> {:error, {:pattern_missing, mfa}} end)

    assert {3, [message]} = Sabotage.coverage(facts(), @opts)
    assert message =~ "COULD NOT MEASURE: {ExUnit.Runner, :run_setup_all, 4} could not be traced"
    assert message =~ "Fix: "
  end

  describe "a leak fails the run (DND-5691)" do
    defp leaked_state, do: state([{:call, {B, :g, 0}, :test_process, :none, 2}])

    defp expect_written do
      expect(CoverageStoreMock, :write, fn "/repo/cov.etf", map ->
        send(self(), {:written, map})
        :ok
      end)
    end

    test "1: a leak with a passing suite: exit 1, the pair, a Fix: line, the map written" do
      expect_modules()
      expect_traced({:passed, 1}, leaked_state())
      expect_written()

      assert {1, [summary, leak, fix]} = Sabotage.coverage(facts(), @opts)
      assert summary =~ "leaks: 1"
      assert leak =~ "leak: test/a_test.exs:3 test one left a process that called B.g/0"
      assert fix =~ "Fix: make the process end inside its test"

      assert_received {:written, map}
      assert [%{functions: ["A.f/0", "B.g/0"]}] = map.tests
      assert [%{function: "B.g/0"}] = map.leaks
    end

    test "a leak and a failed suite: exit 1, naming both" do
      expect_modules()
      expect_traced({:failed, "1 of 1 test(s) failed", 1}, leaked_state())
      expect_written()

      assert {1, [_summary, _leak, _fix, failed]} = Sabotage.coverage(facts(), @opts)
      assert failed =~ "the suite failed (1 of 1 test(s) failed)"
    end

    test "3: ambient calls alone never fail" do
      expect_modules()
      ambient = {:call, {C, :body, 0}, pid(), :none, 0}
      expect_traced({:passed, 1}, state([ambient]))
      expect_written()

      assert {0, [summary]} = Sabotage.coverage(facts(), @opts)
      assert summary =~ "ambient: 1"
      assert_received {:written, %{ambient: ["C.body/0"], leaks: []}}
    end
  end

  describe "a smaller map never looks whole (DND-5691)" do
    defp expect_refused(suite, state) do
      expect_modules()
      expect_traced(suite, state)
      assert {3, [message]} = Sabotage.coverage(facts(), @opts)
      message
    end

    test "4: fewer windows than total: exit 3, no map" do
      message = expect_refused({:passed, 10}, state())
      assert message =~ "COULD NOT MEASURE: 1 test windows opened, but ExUnit counted 10 tests"
      assert message =~ "no map was written"
      assert message =~ "Fix: "
    end

    test "8: excluded and skipped tests count as windows: exit 0" do
      runner = pid()

      not_run =
        for word <- [3, 5] do
          [
            {:test_started, runner, word, %{@t1 | line: word}, ATest},
            {:test_finished, runner, word + 1, false, ATest}
          ]
        end

      expect_modules()
      expect_traced({:passed, 3}, CoverageMap.attribute(state(), List.flatten(not_run)))
      expect(CoverageStoreMock, :write, fn _path, _map -> :ok end)

      assert {0, [summary]} = Sabotage.coverage(facts(), @opts)
      assert summary =~ "tests: 1,"
    end

    test "9: a test that ran with no entry message is refused, naming the test" do
      runner = pid()

      state =
        CoverageMap.attribute(CoverageMap.new(), [
          {:test_started, runner, 1, @t1, ATest},
          {:test_finished, runner, 2, true, ATest}
        ])

      message = expect_refused({:passed, 1}, state)
      assert message =~ "/repo/test/a_test.exs:3 test one ran with no entry message"
    end

    test "10: an excluded test with no entry message is fine" do
      runner = pid()

      excluded = [
        {:test_started, runner, 3, %{@t1 | line: 8}, ATest},
        {:test_finished, runner, 4, false, ATest}
      ]

      expect_modules()
      expect_traced({:passed, 2}, CoverageMap.attribute(state(), excluded))
      expect(CoverageStoreMock, :write, fn _path, _map -> :ok end)

      assert {0, [_summary]} = Sabotage.coverage(facts(), @opts)
    end

    test "11: a bad label or a Task shape is refused, naming it, no map" do
      message = expect_refused({:passed, 1}, state([{:call, {A, :f, 0}, pid(), {:x}, 1}]))
      assert message =~ "COULD NOT MEASURE: a call carries the seq_trace label {:x}"
      assert message =~ "Fix: "

      shape = {Task.Supervised, :noreply, [:x]}
      message = expect_refused({:passed, 1}, state([{:error, {:task_shape, shape}}]))
      assert message =~ "a Task was spawned in a shape this does not know"
      assert message =~ "Fix: "
    end

    test "an unreadable trace message and an unfinished module are refused too" do
      message = expect_refused({:passed, 1}, state([{:error, {:unreadable, {A, :nope}}}]))
      assert message =~ "a trace message could not be read"

      message = expect_refused({:passed, 1}, state([{:module_started, pid(), ATest}]))
      assert message =~ "ATest started but never reported finishing"
    end
  end
end
