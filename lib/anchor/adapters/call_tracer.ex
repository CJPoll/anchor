defmodule Anchor.Adapters.CallTracer do
  @moduledoc """
  Call tracing for the per-test coverage map (DND-5474), the **Side Effect**
  adapter (ADR 001) behind `Anchor.Adapters.Tracing`.

  `start/2` is `start/3` with `:first_hit`, the mode the coverage map is
  built with (DND-5652). After refusing when a tracer is already on
  (`:erlang.trace_info(:new_processes, :tracer)`), `start/3`:

    1. loads each project module and sets a local trace pattern on it (a
       pattern on a module not yet loaded would never apply);
    2. sets a `[:global]` pattern on `ExUnit.EventManager.test_started/2` and
       `test_finished/2` whose match spec puts the `%ExUnit.Test{}` argument
       into the trace message;
    3. `trace(:all, true, [:call, :arity, :strict_monotonic_timestamp,
       {:tracer, tracer}])`, then turns tracing off for the tracer and the
       collector themselves. `:arity` makes every call message carry its
       arity, not its arguments, so no traced value is ever copied.

  The two modes:

    * `:every_call` (DND-5474): the collector is the tracer, and the project
      patterns are `true`: one message per call.
    * `:first_hit` (DND-5652): one message per function per test window, the
      same sets. The window number is the VM's trace control word, saved and
      set to 0 here: the `test_started`/`test_finished` match spec adds one
      to it inside the traced call, so it moves before the test runs. Every
      project call message carries the word (`Anchor.Adapters.FirstHitGate.match_spec/1`),
      and the tracer is an `Anchor.Adapters.FirstHitGate`, which forwards
      each message to the collector and silences a function for the rest of
      the window it first called in. Nothing has to switch it back on: the
      next window's number no longer matches. A call from a process a test
      left running is still traced in each later window it calls in, by the
      first caller there.

  `stop/0` turns every flag off for all processes and then waits for
  `:erlang.trace_delivered(:all)`: trace messages reach the tracer later than
  the calls they describe, so without the wait a call (or a `test_finished`)
  still on its way would miss the collector's `finish` and be lost, never
  counted. A gate is then flushed (every message it holds forwarded) and
  stopped, and the trace control word restored. The gate and the saved word
  are kept in the starting process's dictionary, so `stop/0` is called from
  the process that called `start/3` (the Manager does both). A gate that
  died mid-run took the collector down with it (they are linked), so
  `collected/1` reports `{:error, {:collector_down, reason}}`, never a
  smaller map that looks whole. Every local and global
  pattern is cleared last, so a message the gate still held cannot set one
  again. Only the test VM the command itself runs is traced.
  """

  @behaviour Anchor.Adapters.Tracing

  alias Anchor.Adapters.FirstHitGate

  @event_manager ExUnit.EventManager
  @window_functions [:test_started, :test_finished]
  @test_arg_spec [{[:_, :"$1"], [], [{:message, :"$1"}]}]
  @flags [:call, :arity, :strict_monotonic_timestamp]
  # The first-hit run's gate and the trace control word the VM had before
  # it, kept by the process that started tracing for its stop/0.
  @first_hit_key {__MODULE__, :first_hit}

  @impl Anchor.Adapters.Tracing
  def start(collector, modules), do: start(collector, modules, :first_hit)

  @doc "`start/2` in a given mode: `:first_hit` (the default) or `:every_call`."
  @spec start(pid(), [module()], :first_hit | :every_call) :: :ok | {:error, :already_tracing}
  def start(collector, modules, mode) when mode in [:first_hit, :every_call] do
    case :erlang.trace_info(:new_processes, :tracer) do
      {:tracer, []} -> traced(collector, modules, mode)
      {:tracer, _other} -> {:error, :already_tracing}
    end
  end

  @impl Anchor.Adapters.Tracing
  def stop, do: stop(fn -> :erlang.trace_delivered(:all) end)

  @doc false
  # `delivered` asks for the delivery notice (`:erlang.trace_delivered(:all)`
  # in `stop/0`); a test passes its own to see the wait happen (the race
  # itself cannot be forced from a test).
  @spec stop((-> reference())) :: :ok
  def stop(delivered) do
    first_hit = Process.delete(@first_hit_key)
    _flags = :erlang.trace(:all, false, [:all])
    ref = delivered.()

    receive do
      {:trace_delivered, :all, ^ref} -> :ok
    end

    # The patterns are cleared after the gate's flush: a message it still
    # held would otherwise set its function's pattern again.
    :ok = flush_gate(first_hit)
    _local = :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    _global = :erlang.trace_pattern({:_, :_, :_}, false, [:global])
    :ok
  end

  @impl Anchor.Adapters.Tracing
  def collected(collector) do
    {:ok, _state} = GenServer.call(collector, {:finish}, :infinity)
  catch
    :exit, reason -> {:error, {:collector_down, reason}}
  end

  defp traced(collector, modules, mode) do
    {tracer, local_spec, window_spec} = mode_setup(collector, mode)

    for module <- modules, Code.ensure_loaded?(module) do
      :erlang.trace_pattern({module, :_, :_}, local_spec, [:local])
    end

    {:module, @event_manager} = Code.ensure_loaded(@event_manager)

    for name <- @window_functions do
      1 = :erlang.trace_pattern({@event_manager, name, 2}, window_spec, [:global])
    end

    _count = :erlang.trace(:all, true, [{:tracer, tracer} | @flags])
    1 = :erlang.trace(collector, false, [:all])
    untrace_gate(tracer, collector)
    :ok
  end

  defp mode_setup(collector, :every_call), do: {collector, true, @test_arg_spec}

  defp mode_setup(collector, :first_hit) do
    saved_tcw = :erlang.system_flag(:trace_control_word, 0)
    {:ok, gate} = FirstHitGate.start(collector)
    nil = Process.put(@first_hit_key, {gate, saved_tcw})
    {gate, FirstHitGate.match_spec(nil), FirstHitGate.window_spec()}
  end

  defp untrace_gate(collector, collector), do: :ok
  defp untrace_gate(gate, _collector), do: 1 = :erlang.trace(gate, false, [:all])

  # A gate that died has taken the collector down with it (its link), so
  # collected/1 reports it; the trace control word is restored either way.
  defp flush_gate({gate, saved_tcw}) do
    :ok = FirstHitGate.flush(gate)
    _ours = :erlang.system_flag(:trace_control_word, saved_tcw)
    :ok
  end

  defp flush_gate(nil), do: :ok
end
