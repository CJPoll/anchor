defmodule Anchor.Adapters.CallTracerTest do
  # DND-5474: real call tracing of two fixture modules into a real collector.
  # sync: global trace flags. `trace(:all, ...)` and the trace patterns are
  # VM-wide, so no other test may run while they are on.
  # Excluded from the coverage build itself (`--exclude global_tracing`): that
  # run is already traced, and this test would find the tracer taken.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5642): ../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  # Sabotage record (DND-5652): ../../sabotage_records/sabotage-20261103-dnd_5652_first_hit_gate.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Anchor.Adapters.CallTracer
  alias Anchor.Domain.Sabotage.FirstHit
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

  # stop/0 of a first-hit run writes the gate's report line to the standard
  # error; a test that does not read it keeps the suite's output clean.
  defp stop_quietly do
    capture_io(:stderr, fn -> send(self(), {:stopped, CallTracer.stop()}) end)
    assert_received {:stopped, result}
    result
  end

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
      assert stop_quietly() == :ok
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
    assert :erlang.system_flag(:trace_control_word, 0) == 0
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
      stop_quietly()
    end

    send(sink, {:dump, parent})
    assert_receive {:dumped, messages}

    calls =
      for {:trace_ts, _pid, :call, {^a, name, arity}, window, _stamp} <- messages,
          do: {name, arity, window}

    assert calls == [{:f, 0, 0}, {:g, 1, 0}]
  end

  test "stop/0 returns only once every trace message is with the tracer", %{modules: [a, _b]} do
    parent = self()

    sink =
      spawn_link(fn -> receive(do: ({:dump, ^parent} -> send(parent, {:dumped, drain([])}))) end)

    callers = 8
    calls = 500

    assert CallTracer.start(sink, [a], :every_call) == :ok

    try do
      1..callers
      |> Enum.map(fn _i -> Task.async(fn -> for _n <- 1..calls, do: a.f() end) end)
      |> Enum.each(&Task.await/1)
    after
      stop_quietly()
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

  describe "first-hit tracing (DND-5652)" do
    @suite """
    defmodule AnchorFixtures.CallTracerTest.Hot do
      def loop(0), do: :done
      def loop(n), do: loop(n - 1)
    end

    defmodule AnchorFixtures.CallTracerTest.Shared do
      def s, do: :s
    end

    defmodule AnchorFixtures.CallTracerTest.Leak do
      def l, do: :l
    end
    """

    setup do
      modules = for {module, _bin} <- Code.compile_string(@suite), do: module

      on_exit(fn ->
        for module <- modules do
          :code.purge(module)
          :code.delete(module)
        end
      end)

      %{suite: modules}
    end

    # A process a test starts and never stops: it calls Leak.l/0 when asked,
    # and the test blocks on its reply (no clock).
    defp leaked(leak) do
      spawn(fn -> leaked_loop(leak) end)
    end

    defp leaked_loop(leak) do
      receive do
        {:call, from} ->
          send(from, {:called, leak.l()})
          leaked_loop(leak)

        :stop ->
          :ok
      end
    end

    # Three tests: a recursive hot function, a function two tests share
    # (silenced in the first window, traced again in the second), and a
    # process the first test leaves running that calls in the second.
    # `settle/0` makes the tracer handle every message so far before the next
    # step, so each silence is in place when the next window starts: the
    # equality is decided, never left to how fast the gate runs.
    defp run_suite(mode, [hot, shared, leak] = suite) do
      {:ok, manager} = ExUnit.EventManager.start_link()
      {:ok, collector} = CoverageCollector.start_link()
      assert CallTracer.start(collector, suite, mode) == :ok
      process = leaked(leak)

      try do
        ExUnit.EventManager.test_started(manager, exunit_test(1))
        :done = hot.loop(2_000)
        :s = shared.s()
        settle()
        :s = shared.s()
        ExUnit.EventManager.test_finished(manager, exunit_test(1))
        settle()

        ExUnit.EventManager.test_started(manager, exunit_test(2))
        :s = shared.s()
        send(process, {:call, self()})
        assert_receive {:called, :l}
        :done = hot.loop(3)
        settle()
        ExUnit.EventManager.test_finished(manager, exunit_test(2))
        settle()

        ExUnit.EventManager.test_started(manager, exunit_test(3))
        :s = shared.s()
        send(process, {:call, self()})
        assert_receive {:called, :l}
        ExUnit.EventManager.test_finished(manager, exunit_test(3))
      after
        assert stop_quietly() == :ok
        send(process, :stop)
      end

      assert {:ok, state} = CallTracer.collected(collector)
      GenServer.stop(collector)
      ExUnit.EventManager.stop(manager)

      CoverageMap.finalize(state, %{
        commit: nil,
        elixir: "x",
        otp: "x",
        modules_traced: 3,
        suite_exit: 0,
        root: "/p"
      })
    end

    test "FH1: the map's test -> functions sets equal every-call tracing's", %{suite: suite} do
      every_call = run_suite(:every_call, suite)
      first_hit = run_suite(:first_hit, suite)

      expected = %{
        1 => [
          "AnchorFixtures.CallTracerTest.Hot.loop/1",
          "AnchorFixtures.CallTracerTest.Shared.s/0"
        ],
        2 => [
          "AnchorFixtures.CallTracerTest.Hot.loop/1",
          "AnchorFixtures.CallTracerTest.Leak.l/0",
          "AnchorFixtures.CallTracerTest.Shared.s/0"
        ],
        3 => [
          "AnchorFixtures.CallTracerTest.Leak.l/0",
          "AnchorFixtures.CallTracerTest.Shared.s/0"
        ]
      }

      assert Map.new(every_call.tests, &{&1.line, &1.functions}) == expected
      assert first_hit.tests == every_call.tests
      assert first_hit.late_events == 0
    end

    test "FH2: stop/0 clears every flag and pattern and restores the trace control word",
         %{suite: [hot | _rest] = suite} do
      saved = :erlang.system_flag(:trace_control_word, 7)

      try do
        _map = run_suite(:first_hit, suite)
        assert :erlang.system_flag(:trace_control_word, saved) == 7
      after
        :erlang.system_flag(:trace_control_word, saved)
      end

      assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
      assert :erlang.trace_info({hot, :loop, 1}, :traced) == {:traced, false}

      assert :erlang.trace_info({ExUnit.EventManager, :test_started, 2}, :traced) ==
               {:traced, false}
    end

    test "FH3: a function is silenced after the threshold in a window: it sends no more messages there, and traces again in the next",
         %{suite: [hot, shared, leak]} do
      {:ok, manager} = ExUnit.EventManager.start_link()
      parent = self()
      threshold = FirstHit.threshold()

      sink =
        spawn_link(fn ->
          receive(do: ({:dump, ^parent} -> send(parent, {:dumped, drain([])})))
        end)

      assert CallTracer.start(sink, [hot, shared, leak]) == :ok

      try do
        ExUnit.EventManager.test_started(manager, exunit_test(1))
        for _call <- 1..(threshold - 1), do: :s = shared.s()
        # One call short of the threshold: not silenced yet.
        refute silenced?(shared, 1)
        :s = shared.s()
        # Once the threshold's message is with the gate and the gate has handled
        # it, shared.s/0's pattern is silent for window 1.
        assert silenced?(shared, 1)
        for _call <- 1..10, do: :s = shared.s()
        ExUnit.EventManager.test_finished(manager, exunit_test(1))
        :s = shared.s()
      after
        capture_io(:stderr, fn -> CallTracer.stop() end)
      end

      send(sink, {:dump, parent})
      assert_receive {:dumped, messages}

      windows = for {:trace_ts, _pid, :call, {^shared, :s, 0}, w, _stamp} <- messages, do: w
      assert windows == List.duplicate(1, threshold) ++ [2]
    end

    test "FH6: stop/0 reports what the gate did on one line", %{suite: [_hot, shared, _leak]} do
      {:ok, manager} = ExUnit.EventManager.start_link()
      {:ok, collector} = CoverageCollector.start_link()
      assert CallTracer.start(collector, [shared]) == :ok

      try do
        ExUnit.EventManager.test_started(manager, exunit_test(1))
        for _call <- 1..(FirstHit.threshold() + 5), do: :s = shared.s()
        ExUnit.EventManager.test_finished(manager, exunit_test(1))
      after
        report = capture_io(:stderr, fn -> CallTracer.stop() end)

        # How many of the messages after the threshold are dropped depends on
        # when the pattern goes silent, so only the shape is asserted.
        assert report =~
                 ~r/first-hit gate: messages: \d+, forwarded: \d+, dropped: \d+; silences: 1, in trace_pattern: \d+ ms, most in one window: 1\n/
      end
    end
  end

  test "FH4: a gate that dies mid-run is loud: collected/1 says the collector is down, and the trace control word is restored",
       %{modules: [a, _b]} do
    {:ok, collector} = CoverageCollector.start_link()
    Process.unlink(collector)
    saved = :erlang.system_flag(:trace_control_word, 0)

    try do
      assert CallTracer.start(collector, [a]) == :ok
      {:tracer, gate} = :erlang.trace_info(:new_processes, :tracer)
      ref = Process.monitor(gate)
      Process.exit(gate, :kill)
      assert_receive {:DOWN, ^ref, :process, ^gate, :killed}
      2 = a.f()
      assert stop_quietly() == :ok

      assert {:error, {:collector_down, _reason}} = CallTracer.collected(collector)
      assert :erlang.system_flag(:trace_control_word, 0) == 0
    after
      :erlang.system_flag(:trace_control_word, saved)
    end
  end

  test "FH5: the gate counts and silences only on calls stamped inside their window, and drops only after the silence",
       %{modules: [a, _b]} do
    {:ok, gate} = Anchor.Adapters.FirstHitGate.start(self())
    test = exunit_test(1)
    em = ExUnit.EventManager
    threshold = FirstHit.threshold()
    early = {:trace_ts, self(), :call, {a, :f, 0}, 1, {5, 0}}
    inside = {:trace_ts, self(), :call, {a, :f, 0}, 1, {11, 0}}

    try do
      send(gate, {:trace_ts, self(), :call, {em, :test_started, 2}, {test, 1}, {10, 0}})
      # Read the new word before the boundary was stamped: not inside window 1,
      # so it is forwarded and never counted, however many there are.
      for _i <- 1..(threshold + 5), do: send(gate, early)
      _state = :sys.get_state(gate)
      assert :erlang.trace_info({a, :f, 0}, :match_spec) == {:match_spec, false}

      for _i <- 1..(threshold - 1), do: send(gate, inside)
      _state = :sys.get_state(gate)
      assert :erlang.trace_info({a, :f, 0}, :match_spec) == {:match_spec, false}

      send(gate, inside)
      _state = :sys.get_state(gate)

      assert :erlang.trace_info({a, :f, 0}, :match_spec) ==
               {:match_spec, Anchor.Adapters.FirstHitGate.match_spec(1)}

      # In flight when the pattern went silent: dropped.
      send(gate, inside)
      _state = :sys.get_state(gate)

      # The boundary reaches the collector with the test alone, as it reads it.
      assert_received {:trace_ts, _pid, :call, {^em, :test_started, 2}, ^test, {10, 0}}

      assert drain([]) ==
               List.duplicate(early, threshold + 5) ++ List.duplicate(inside, threshold)
    after
      capture_io(:stderr, fn -> :ok = Anchor.Adapters.FirstHitGate.flush(gate) end)
      :erlang.trace_pattern({a, :_, :_}, false, [:local])
    end
  end

  # Every trace message so far delivered to the tracer, then handled by it
  # (a call to it returns after every earlier message). Two events, no clock.
  defp settle do
    {:tracer, tracer} = :erlang.trace_info(:new_processes, :tracer)
    ref = :erlang.trace_delivered(:all)

    receive do
      {:trace_delivered, :all, ^ref} -> :ok
    end

    _state = :sys.get_state(tracer)
    :ok
  end

  # Blocks on two events, never a clock: every trace message of this process
  # delivered to the gate, then a call to the gate, which returns after it
  # handled every earlier message. Then reads `module.s/0`'s pattern.
  defp silenced?(module, window) do
    {:tracer, gate} = :erlang.trace_info(:new_processes, :tracer)
    ref = :erlang.trace_delivered(self())

    receive do
      {:trace_delivered, _pid, ^ref} -> :ok
    end

    _state = :sys.get_state(gate)

    {:match_spec, spec} = :erlang.trace_info({module, :s, 0}, :match_spec)
    spec == Anchor.Adapters.FirstHitGate.match_spec(window)
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
        :ok = stop_quietly()
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
