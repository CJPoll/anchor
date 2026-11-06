defmodule Anchor.Adapters.CallTracer do
  @moduledoc """
  Call tracing for the per-test coverage map (DND-5474; causal attribution,
  DND-5691), the **Side Effect** adapter (ADR 001) behind
  `Anchor.Adapters.Tracing`.

  `start/2`, after refusing when a tracer is already on
  (`:erlang.trace_info(:new_processes, :tracer)`):

    1. loads each project module, refusing with `{:error, {:not_loadable,
       modules}}` before any pattern or flag is set when one cannot load
       (DND-5690: tracing around it would read as a module never called), and
       sets `Anchor.Domain.Sabotage.LabelSpec.call_spec/0` as a `[:local]`
       pattern on each;
    2. sets the window word to 0 and installs `LabelSpec.patterns/0`. Each must
       match exactly one function: three of them are private to ExUnit, so one
       that has moved refuses with `{:error, {:pattern_missing, mfa}}`, nothing
       left traced;
    3. `trace(:all, true, [:call, :arity, :procs, {:tracer, collector}])`, then
       turns tracing off for the collector itself. `:arity` makes every call
       message carry its arity, not its arguments, so no traced argument is ever
       copied to the collector; `:procs` adds spawn events, whose arguments the
       collector reduces to one pid. There is no timestamp flag: nothing reads
       time.

  `stop/0` turns every flag off for all processes, clears every local and
  global pattern, and then waits for `:erlang.trace_delivered(:all)`: trace
  messages reach the tracer later than the calls they describe, so without
  the wait a call (or a `test_finished`) still on its way would miss the
  collector's `finish` and be lost, never counted. Only the test VM the
  command itself runs is traced.
  """

  @behaviour Anchor.Adapters.Tracing

  alias Anchor.Domain.Sabotage.LabelSpec

  @flags [:call, :arity, :procs]

  @impl Anchor.Adapters.Tracing
  def start(collector, modules), do: start(collector, modules, LabelSpec.patterns())

  @doc false
  # `patterns` is `LabelSpec.patterns/0`; a test passes a list holding a function
  # that does not exist, to see the refusal an Elixir upgrade would cause.
  @spec start(pid(), [module()], [LabelSpec.pattern()]) ::
          :ok
          | {:error, :already_tracing}
          | {:error, {:not_loadable, [module()]}}
          | {:error, {:pattern_missing, mfa()}}
  def start(collector, modules, patterns) do
    case :erlang.trace_info(:new_processes, :tracer) do
      {:tracer, []} -> loaded_then_traced(collector, modules, patterns)
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
    _flags = :erlang.trace(:all, false, [:all])
    :ok = clear_patterns()
    ref = delivered.()

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

  defp loaded_then_traced(collector, modules, patterns) do
    case Enum.reject(modules, &Code.ensure_loaded?/1) do
      [] -> patterned_then_traced(collector, modules, patterns)
      not_loadable -> {:error, {:not_loadable, Enum.sort(not_loadable)}}
    end
  end

  defp patterned_then_traced(collector, modules, patterns) do
    for module <- modules do
      :erlang.trace_pattern({module, :_, :_}, LabelSpec.call_spec(), [:local])
    end

    :erlang.system_flag(:trace_control_word, 0)

    case Enum.find(patterns, &(install(&1) != 1)) do
      nil ->
        traced(collector)

      {mfa, _spec, _flags} ->
        clear_patterns()
        {:error, {:pattern_missing, mfa}}
    end
  end

  defp install({{module, _name, _arity} = mfa, spec, flags}) do
    _loaded = Code.ensure_loaded(module)
    :erlang.trace_pattern(mfa, spec, flags)
  end

  defp traced(collector) do
    _count = :erlang.trace(:all, true, [{:tracer, collector} | @flags])
    1 = :erlang.trace(collector, false, [:all])
    :ok
  end

  defp clear_patterns do
    _local = :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    _global = :erlang.trace_pattern({:_, :_, :_}, false, [:global])
    :ok
  end
end
