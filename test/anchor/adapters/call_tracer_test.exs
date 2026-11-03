defmodule Anchor.Adapters.CallTracerTest do
  # DND-5474: real call tracing of two fixture modules into a real collector.
  # sync: global trace flags. `trace(:all, ...)` and the trace patterns are
  # VM-wide, so no other test may run while they are on.
  # Excluded from the coverage build itself (`--exclude global_tracing`): that
  # run is already traced, and this test would find the tracer taken.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
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
