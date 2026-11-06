defmodule Anchor.Adapters.CallTracerTest do
  # DND-5474: real call tracing of two fixture modules into a real collector.
  # sync: global trace flags. `trace(:all, ...)` and the trace patterns are
  # VM-wide, so no other test may run while they are on.
  # Excluded from the coverage build itself (`--exclude global_tracing`): that
  # run is already traced, and this test would find the tracer taken.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5642): ../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  # Sabotage record (DND-5690): ../../sabotage_records/sabotage-20261106-dnd_5690_preload.md
  # Sabotage record (DND-5691): ../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: false

  alias Anchor.Adapters.CallTracer
  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Domain.Sabotage.LabelSpec
  alias Anchor.Domain.Sabotage.ProcessOwnership
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

  # A test's process as ExUnit runs one: spawned by the runner in the window, it
  # registers (which sets its label), then does its work; the caller waits for it.
  defp in_test_process(fun) do
    {pid, ref} =
      spawn_monitor(fn ->
        ExUnit.OnExitHandler.register(self())
        fun.()
      end)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> :normal = reason
    end

    :ets.delete(ExUnit.Server, pid)
    :ok
  end

  test "1: windows, labels and project calls reach the collector; stop clears all",
       %{modules: [a, b]} do
    {:ok, manager} = ExUnit.EventManager.start_link()
    {:ok, collector} = CoverageCollector.start_link()

    assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
    assert CallTracer.start(collector, [a, b]) == :ok

    try do
      assert CallTracer.start(collector, [a]) == {:error, :already_tracing}

      ExUnit.EventManager.test_started(manager, exunit_test(1))
      in_test_process(fn -> 2 = a.f() end)
      ExUnit.EventManager.test_finished(manager, exunit_test(1))

      ExUnit.EventManager.test_started(manager, exunit_test(2))
      in_test_process(fn -> :h = b.h() end)
      ExUnit.EventManager.test_finished(manager, exunit_test(2))
    after
      assert CallTracer.stop() == :ok
    end

    assert {:ok, state} = CallTracer.collected(collector)

    assert {:ok, map} =
             CoverageMap.finalize(state, %{
               commit: nil,
               elixir: "x",
               otp: "x",
               modules_traced: 2,
               suite_exit: 0,
               total: 2,
               root: "/p"
             })

    assert Map.new(map.tests, &{&1.line, &1.functions}) == %{
             1 => [
               "AnchorFixtures.CallTracerTest.A.f/0",
               "AnchorFixtures.CallTracerTest.A.g/1"
             ],
             2 => ["AnchorFixtures.CallTracerTest.B.h/0"]
           }

    assert map.leaks == []
    assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
    assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}

    assert :erlang.trace_info({ExUnit.EventManager, :test_started, 2}, :traced) ==
             {:traced, false}

    assert :erlang.trace_info(self(), :flags) == {:flags, []}
  end

  describe "start/2: the patterns" do
    test "1: a private ExUnit function that is gone is refused, naming it; nothing is traced",
         %{modules: [a, _b]} do
      gone = {ExUnit.Runner, :no_such_function, 9}
      {:ok, collector} = CoverageCollector.start_link()
      [first | rest] = LabelSpec.patterns()
      patterns = [first, {gone, [{:_, [], [{:message, false}]}], [:local]} | rest]

      try do
        assert CallTracer.start(collector, [a], patterns) == {:error, {:pattern_missing, gone}}
        assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
        assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}

        assert :erlang.trace_info({ExUnit.EventManager, :test_started, 2}, :traced) ==
                 {:traced, false}
      after
        CallTracer.stop()
      end
    end

    test "2: all six patterns install on this Elixir", %{modules: [a, _b]} do
      {:ok, collector} = CoverageCollector.start_link()

      try do
        assert CallTracer.start(collector, [a]) == :ok

        for {mfa, _spec, flags} <- LabelSpec.patterns() do
          assert :erlang.trace_info(mfa, :traced) == {:traced, hd(flags)}, inspect(mfa)
        end
      after
        CallTracer.stop()
      end
    end
  end

  # The value the spike did not assert: the pid read from a real spawn event is the
  # caller's own, through every start path, with the supervisor as the parent.
  describe "the owner pid in a real Task spawn event" do
    defp spawn_events(traced, fun) do
      parent = self()

      sink =
        spawn_link(fn ->
          receive(do: ({:dump, ^parent} -> send(parent, {:dumped, drain([])})))
        end)

      :erlang.trace(traced, true, [:procs, {:tracer, sink}])

      try do
        fun.()
      after
        :erlang.trace(traced, false, [:all])
        ref = :erlang.trace_delivered(traced)

        receive do
          {:trace_delivered, ^traced, ^ref} -> :ok
        end
      end

      send(sink, {:dump, parent})
      assert_receive {:dumped, messages}
      for {:trace, ^traced, :spawn, child, mfa} <- messages, do: {child, mfa}
    end

    setup do
      sup = start_supervised!(Task.Supervisor)
      %{sup: sup}
    end

    # Each started task waits for the go, so a spawn event's arguments are read
    # with the task still alive and no timing matters.
    test "6: Task.Supervisor.start_child/3 is the noreply shape", %{sup: sup} do
      me = self()

      assert [{child, {Task.Supervised, :noreply, _args} = mfa}] =
               spawn_events(sup, fn ->
                 {:ok, _pid} = Task.Supervisor.start_child(sup, fn -> :ok end)
               end)

      assert ProcessOwnership.edge(child, sup, mfa) == {child, sup, me}
    end

    test "8: Task.Supervisor.start_child/5 is the reply shape", %{sup: sup} do
      me = self()

      assert [{child, {Task.Supervised, :reply, _args} = mfa}] =
               spawn_events(sup, fn ->
                 {:ok, _pid} =
                   Task.Supervisor.start_child(sup, Kernel, :is_atom, [:x], restart: :temporary)
               end)

      assert ProcessOwnership.edge(child, sup, mfa) == {child, sup, me}
    end

    test "9: Task.Supervisor.async_nolink/2 is the reply shape", %{sup: sup} do
      me = self()

      assert [{child, {Task.Supervised, :reply, _args} = mfa}] =
               spawn_events(sup, fn ->
                 Task.await(Task.Supervisor.async_nolink(sup, fn -> :ok end))
               end)

      assert ProcessOwnership.edge(child, sup, mfa) == {child, sup, me}
    end

    test "Task.async is the reply shape, with this process both parent and owner" do
      me = self()

      assert [{child, {Task.Supervised, :reply, _args} = mfa}] =
               spawn_events(me, fn -> Task.await(Task.async(fn -> :ok end)) end)

      assert ProcessOwnership.edge(child, me, mfa) == {child, me, me}
    end
  end

  # DND-5690: this filtered on Code.ensure_loaded?/1, so a project module that
  # could not load was left untraced with nothing said, and the map read as if
  # it had never been called.
  test "a project module that cannot load refuses by name, and nothing is traced",
       %{modules: [a, b]} do
    missing = [AnchorFixtures.CallTracerTest.NoBeamB, AnchorFixtures.CallTracerTest.NoBeamA]
    {:ok, collector} = CoverageCollector.start_link()

    try do
      assert CallTracer.start(collector, [a | missing] ++ [b]) ==
               {:error, {:not_loadable, Enum.sort(missing)}}

      assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
      assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}

      assert :erlang.trace_info({ExUnit.EventManager, :test_started, 2}, :traced) ==
               {:traced, false}
    after
      CallTracer.stop()
    end
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

    calls =
      for {:trace, _pid, :call, {^a, name, arity}, {:none, 0}} <- messages, do: {name, arity}

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

    # Asked at once: stop/0 already waited, so every call is there, ahead of the
    # dump. The queue also holds the tasks' spawn and exit events.
    send(sink, {:dump, parent})
    assert_receive {:dumped, messages}

    assert Enum.count(messages, &match?({:trace, _pid, :call, _mfa, _word}, &1)) ==
             callers * calls * 2
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
end
