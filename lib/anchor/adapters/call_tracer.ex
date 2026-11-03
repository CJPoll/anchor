defmodule Anchor.Adapters.CallTracer do
  @moduledoc """
  Call tracing for the per-test coverage map (DND-5474), the **Side Effect**
  adapter (ADR 001) behind `Anchor.Adapters.Tracing`.

  `start/2`, after refusing when a tracer is already on
  (`:erlang.trace_info(:new_processes, :tracer)`):

    1. loads each project module and sets `trace_pattern({m, :_, :_}, true,
       [:local])` on it (a pattern on a module not yet loaded would never
       apply);
    2. sets a `[:global]` pattern on `ExUnit.EventManager.test_started/2` and
       `test_finished/2` whose match spec puts the `%ExUnit.Test{}` argument
       into the trace message;
    3. `trace(:all, true, [:call, :arity, :strict_monotonic_timestamp,
       {:tracer, collector}])`, then turns tracing off for the collector
       itself. `:arity` makes every call message carry its arity, not its
       arguments, so no traced value is ever copied to the collector.

  `stop/0` turns every flag off for all processes, clears every local and
  global pattern, and then waits for `:erlang.trace_delivered(:all)`: trace
  messages reach the tracer later than the calls they describe, so without
  the wait a call (or a `test_finished`) still on its way would miss the
  collector's `finish` and be lost, never counted. Only the test VM the
  command itself runs is traced.
  """

  @behaviour Anchor.Adapters.Tracing

  @event_manager ExUnit.EventManager
  @window_functions [:test_started, :test_finished]
  @test_arg_spec [{[:_, :"$1"], [], [{:message, :"$1"}]}]
  @flags [:call, :arity, :strict_monotonic_timestamp]

  @impl Anchor.Adapters.Tracing
  def start(collector, modules) do
    case :erlang.trace_info(:new_processes, :tracer) do
      {:tracer, []} -> traced(collector, modules)
      {:tracer, _other} -> {:error, :already_tracing}
    end
  end

  @impl Anchor.Adapters.Tracing
  def stop do
    _flags = :erlang.trace(:all, false, [:all])
    _local = :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    _global = :erlang.trace_pattern({:_, :_, :_}, false, [:global])
    ref = :erlang.trace_delivered(:all)

    receive do
      {:trace_delivered, :all, ^ref} -> :ok
    end
  end

  @impl Anchor.Adapters.Tracing
  def collected(collector) do
    {:ok, _state} = GenServer.call(collector, {:finish}, :infinity)
  catch
    :exit, reason -> {:error, {:collector_down, reason}}
  end

  defp traced(collector, modules) do
    for module <- modules, Code.ensure_loaded?(module) do
      :erlang.trace_pattern({module, :_, :_}, true, [:local])
    end

    {:module, @event_manager} = Code.ensure_loaded(@event_manager)

    for name <- @window_functions do
      1 = :erlang.trace_pattern({@event_manager, name, 2}, @test_arg_spec, [:global])
    end

    _count = :erlang.trace(:all, true, [{:tracer, collector} | @flags])
    1 = :erlang.trace(collector, false, [:all])
    :ok
  end
end
