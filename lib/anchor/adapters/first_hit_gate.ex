defmodule Anchor.Adapters.FirstHitGate do
  @moduledoc """
  The tracer process of the first-hit coverage tracing (DND-5652), part of
  the **Side Effect** adapter `Anchor.Adapters.CallTracer` (ADR 001). It
  receives every trace message and, by `Anchor.Domain.Sabotage.FirstHit`,
  forwards it unchanged to the collector, drops it (the function was
  silenced for the message's own window while it was in flight), or forwards
  it and silences the function by setting its local trace pattern to stay
  quiet while the trace control word is that window. A
  `test_started`/`test_finished` message carries `{test, word}`: the gate
  reads the word as the window the boundary opened and forwards the message
  to the collector with the test alone, as the collector reads it. Only this
  process changes a pattern after `CallTracer.start/3`.

  The gate is the only process every trace message passes through, so it
  does the least a message can ask: a dropped message costs one map lookup
  and a counter. What a run did is counted (messages received, forwarded and
  dropped, silences, the time spent in `:erlang.trace_pattern/3`, the most
  silences in one window) and written on one line to the standard error at
  `flush/1`, so a slow Coverage map run says where its time went.

  `flush/1` returns once every message that reached the gate before it has
  been handled, and stops the gate; `CallTracer.stop/0` calls it after the
  trace delivery wait, so the collector holds every message before
  `collected/1` asks for it.

  The gate is linked to the collector. A gate that dies mid-run would leave
  every later trace message undelivered, and the collector would hand back a
  smaller map that looks whole; the link takes the collector down with it,
  so `collected/1` answers `{:error, {:collector_down, reason}}`, as when the
  collector itself dies. A gate's normal stop (`flush/1`) leaves the
  collector running.
  """

  use GenServer

  alias Anchor.Domain.Sabotage.FirstHit

  @event_manager ExUnit.EventManager
  @window_functions [:test_started, :test_finished]
  @received 1
  @forwarded 2
  @dropped 3

  @doc "Starts a gate forwarding to `collector`, linked to it."
  @spec start(pid()) :: {:ok, pid()}
  def start(collector), do: GenServer.start(__MODULE__, collector)

  @doc """
  Waits until every message the gate has received is handled, then stops
  it. A gate already gone is `:ok` here: its link has taken the collector
  down, which `collected/1` reports.
  """
  @spec flush(pid()) :: :ok
  def flush(gate) do
    GenServer.call(gate, :flush, :infinity)
  catch
    :exit, _gone -> :ok
  end

  @doc """
  The local match spec of a traced function: a call message carrying the
  window (the trace control word), sent unless the word is `silent`.
  """
  @spec match_spec(non_neg_integer() | nil) :: :ets.match_spec()
  def match_spec(nil), do: [{:_, [], [{:message, {:get_tcw}}]}]
  def match_spec(silent), do: [{:_, [{:"=/=", {:get_tcw}, silent}], [{:message, {:get_tcw}}]}]

  @doc """
  The global match spec of `test_started/2` and `test_finished/2`: it adds one
  to the trace control word, inside the call, and puts the test and the new
  word in the message.
  """
  @spec window_spec() :: :ets.match_spec()
  def window_spec do
    [
      {[:_, :"$1"], [], [{:set_tcw, {:+, {:get_tcw}, 1}}, {:message, {{:"$1", {:get_tcw}}}}]}
    ]
  end

  @impl GenServer
  def init(collector) do
    true = Process.link(collector)

    {:ok,
     %{
       collector: collector,
       seen: FirstHit.new(),
       counters: :counters.new(3, [:atomics]),
       silences: %{},
       silence_us: 0
     }}
  end

  @impl GenServer
  def handle_call(:flush, _from, state) do
    IO.puts(:stderr, report(state))
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {:trace_ts, pid, :call, {@event_manager, name, 2}, {test, word}, stamp},
        state
      )
      when name in @window_functions and is_integer(word) do
    :counters.add(state.counters, @received, 1)
    forward(state, {:trace_ts, pid, :call, {@event_manager, name, 2}, test, stamp})
    {:noreply, %{state | seen: FirstHit.boundary(state.seen, word, stamp)}}
  end

  def handle_info({:trace_ts, _pid, :call, {m, f, a}, window, stamp} = message, state)
      when is_integer(window) and is_integer(a) do
    :counters.add(state.counters, @received, 1)
    mfa = {m, f, a}

    case FirstHit.decide(state.seen, mfa, window, stamp) do
      {:drop, seen} ->
        :counters.add(state.counters, @dropped, 1)
        {:noreply, %{state | seen: seen}}

      {:forward, seen} ->
        forward(state, message)
        {:noreply, %{state | seen: seen}}

      {:silence, seen} ->
        forward(state, message)
        {:noreply, silence(%{state | seen: seen}, mfa, window)}
    end
  end

  def handle_info(message, state) do
    send(state.collector, message)
    {:noreply, state}
  end

  defp forward(state, message) do
    :counters.add(state.counters, @forwarded, 1)
    send(state.collector, message)
  end

  defp silence(state, mfa, window) do
    {us, _count} =
      :timer.tc(fn -> :erlang.trace_pattern(mfa, match_spec(window), [:local]) end)

    %{
      state
      | silence_us: state.silence_us + us,
        silences: Map.update(state.silences, window, 1, &(&1 + 1))
    }
  end

  defp report(state) do
    total = state.silences |> Map.values() |> Enum.sum()
    worst = state.silences |> Map.values() |> Enum.max(fn -> 0 end)

    "anchor.sabotage coverage: first-hit gate: messages: #{:counters.get(state.counters, @received)}, " <>
      "forwarded: #{:counters.get(state.counters, @forwarded)}, " <>
      "dropped: #{:counters.get(state.counters, @dropped)}; " <>
      "silences: #{total}, in trace_pattern: #{div(state.silence_us, 1000)} ms, " <>
      "most in one window: #{worst}"
  end
end
