defmodule Anchor.Adapters.CallTracerTest do
  # DND-5474: real call tracing of two fixture modules into a real collector.
  # sync: global trace flags. `trace(:all, ...)` and the trace patterns are
  # VM-wide, so no other test may run while they are on.
  # Excluded from the coverage build itself (`--exclude global_tracing`): that
  # run is already traced, and this test would find the tracer taken.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5642): ../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  use ExUnit.Case, async: false

  alias Anchor.Adapters.CallTracer
  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Sabotage.CoverageCollector

  @moduletag :global_tracing

  @fixtures """
  defmodule AnchorFixtures.CallTracerTest.A do
    def f, do: g(1)
    defp g(x), do: x + 1
  end

  defmodule AnchorFixtures.CallTracerTest.B do
    def h, do: :h
  end
  """

  setup_all do
    modules = for {module, _bin} <- Code.compile_string(@fixtures), do: module

    on_exit(fn ->
      for module <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end)

    %{modules: modules}
  end

  defp exunit_test(line),
    do: %ExUnit.Test{
      name: :"test #{line}",
      module: FixtureTest,
      tags: %{file: "/p/test/f_test.exs", line: line}
    }

  test "1: window events and project calls reach the collector in stamp order; stop clears all",
       %{modules: [a, b]} do
    {:ok, manager} = ExUnit.EventManager.start_link()
    {:ok, collector} = CoverageCollector.start_link()

    assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
    assert CallTracer.start(collector, [a, b]) == :ok

    try do
      assert CallTracer.start(collector, [a]) == {:error, :already_tracing}

      ExUnit.EventManager.test_started(manager, exunit_test(1))
      2 = a.f()
      ExUnit.EventManager.test_finished(manager, exunit_test(1))

      ExUnit.EventManager.test_started(manager, exunit_test(2))
      :h = b.h()
      ExUnit.EventManager.test_finished(manager, exunit_test(2))
    after
      assert CallTracer.stop() == :ok
    end

    assert {:ok, state} = CallTracer.collected(collector)

    map =
      CoverageMap.finalize(state, %{
        commit: nil,
        elixir: "x",
        otp: "x",
        modules_traced: 2,
        suite_exit: 0,
        root: "/p"
      })

    assert Map.new(map.tests, &{&1.line, &1.functions}) == %{
             1 => [
               "AnchorFixtures.CallTracerTest.A.f/0",
               "AnchorFixtures.CallTracerTest.A.g/1"
             ],
             2 => ["AnchorFixtures.CallTracerTest.B.h/0"]
           }

    assert map.late_events == 0
    assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
    assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}

    assert :erlang.trace_info({ExUnit.EventManager, :test_started, 2}, :traced) ==
             {:traced, false}

    assert :erlang.trace_info(self(), :flags) == {:flags, []}
  end

  test "a call's message carries its arity, never its arguments", %{modules: [a, _b]} do
    parent = self()

    sink =
      spawn_link(fn ->
        receive do
          {:dump, ^parent} -> :ok
        end

        send(parent, {:dumped, drain([])})
      end)

    assert CallTracer.start(sink, [a]) == :ok

    try do
      2 = a.f()
    after
      CallTracer.stop()
    end

    send(sink, {:dump, parent})
    assert_receive {:dumped, messages}

    calls = for {:trace_ts, _pid, :call, {^a, name, arity}, _stamp} <- messages, do: {name, arity}
    assert calls == [f: 0, g: 1]
  end

  test "stop/0 returns only once every trace message is with the tracer", %{modules: [a, _b]} do
    parent = self()

    sink =
      spawn_link(fn -> receive(do: ({:dump, ^parent} -> send(parent, {:dumped, drain([])}))) end)

    callers = 8
    calls = 500

    assert CallTracer.start(sink, [a]) == :ok

    try do
      1..callers
      |> Enum.map(fn _i -> Task.async(fn -> for _n <- 1..calls, do: a.f() end) end)
      |> Enum.each(&Task.await/1)
    after
      CallTracer.stop()
    end

    # Read at once, with no other message sent first: stop/0 already waited.
    {:message_queue_len, queued} = Process.info(sink, :message_queue_len)
    assert queued == callers * calls * 2

    send(sink, {:dump, parent})
    assert_receive {:dumped, _messages}
  end

  test "stop/0 asks for trace delivery and returns only once it is notified" do
    parent = self()
    ref = make_ref()

    stopper =
      spawn_link(fn ->
        :ok = CallTracer.stop(fn -> send(parent, {:asked, self()}) && ref end)
        send(parent, :returned)
      end)

    assert_receive {:asked, ^stopper}
    # Not yet notified: stop has not returned.
    refute_received :returned

    send(stopper, {:trace_delivered, :all, ref})
    assert_receive :returned
  end

  defp drain(acc) do
    receive do
      message -> drain([message | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  test "collected/1 on a collector that is gone is an error, not a crash" do
    {:ok, collector} = CoverageCollector.start_link()
    GenServer.stop(collector)

    assert {:error, {:collector_down, _reason}} = CallTracer.collected(collector)
  end

  describe "window leaks through real tracing (DND-5642)" do
    # Each call is made by a process that answers a message, so the window it
    # falls in is set by when the test asks, never by timing.
    defp worker(fun) do
      spawn_link(fn -> serve(fun) end)
    end

    defp serve(fun) do
      receive do
        {:run, from} ->
          send(from, {:ran, self(), fun.()})
          serve(fun)
      end
    end

    defp run_in(worker) do
      send(worker, {:run, self()})

      # Blocks until the worker has made its call: bounded by the test's own
      # timeout, never by a receive deadline.
      receive do
        {:ran, ^worker, _result} -> :ok
      end
    end

    defp traced_windows(modules, steps) do
      {:ok, manager} = ExUnit.EventManager.start_link()
      {:ok, collector} = CoverageCollector.start_link()
      :ok = CallTracer.start(collector, modules)

      try do
        for {line, step} <- steps do
          ExUnit.EventManager.test_started(manager, exunit_test(line))
          step.()
          ExUnit.EventManager.test_finished(manager, exunit_test(line))
        end
      after
        :ok = CallTracer.stop()
      end

      {:ok, state} = CallTracer.collected(collector)

      CoverageMap.finalize(state, %{
        commit: nil,
        elixir: "x",
        otp: "x",
        modules_traced: 2,
        suite_exit: 0,
        root: "/p"
      })
    end

    test "LT1: a process the first test left running, called in the next window, warns", %{
      modules: [_a, b]
    } do
      leaker = worker(&b.h/0)

      map = traced_windows([b], [{1, fn -> run_in(leaker) end}, {2, fn -> run_in(leaker) end}])

      assert [%{from: [%{line: 1}], to: %{line: 2}, calls: 1}] = map.window_leaks
      assert [warning] = CoverageMap.leak_warnings(map)
      assert warning =~ "test/f_test.exs:1 test 1 -> test/f_test.exs:2 test 2 (1 calls)"

      assert Map.new(map.tests, &{&1.line, &1.functions})[2] == [
               "AnchorFixtures.CallTracerTest.B.h/0"
             ]
    end

    test "LT2: positive control: a clean pair, a new process per window, warns of nothing", %{
      modules: [_a, b]
    } do
      first = worker(&b.h/0)
      second = worker(&b.h/0)

      map = traced_windows([b], [{1, fn -> run_in(first) end}, {2, fn -> run_in(second) end}])

      assert map.window_leaks == []
      assert CoverageMap.leak_warnings(map) == []
    end
  end
end
