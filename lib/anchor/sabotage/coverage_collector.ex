defmodule Anchor.Sabotage.CoverageCollector do
  @moduledoc """
  The process that receives call trace messages while
  `mix anchor.sabotage coverage` runs the suite (DND-5474). An OTP process
  module, so **Framework** (ADR 001): it turns each trace message into a
  `Anchor.Domain.Sabotage.CoverageMap` event and hands them to
  `CoverageMap.attribute/2` in batches.

  It keeps no trace argument: a call becomes its `{module, name, arity}`, and
  the `%ExUnit.Test{}` that `ExUnit.EventManager.test_started/2` and
  `test_finished/2` are called with becomes the test's ref
  (`%{file, line, name, module}`, from its tags). It reads both message shapes
  a tracer sends: `{:trace_ts, pid, :call, {m, f, args}, stamp}` and, under
  the `arity` flag with a match-spec message, `{:trace_ts, pid, :call,
  {m, f, arity}, message, stamp}`.

  `finish/1` (the call `{:finish}`) attributes what is buffered and replies
  `{:ok, state}`, the drained `CoverageMap` state.
  """

  use GenServer

  alias Anchor.Domain.Sabotage.CoverageMap

  @batch 1_000
  @event_manager ExUnit.EventManager

  @doc "Starts a collector; `slack:` is `CoverageMap.new/1`'s reorder slack."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @doc "Attributes every buffered event and returns the drained state."
  @spec finish(pid(), timeout()) :: {:ok, CoverageMap.state()}
  def finish(pid, timeout \\ :infinity), do: GenServer.call(pid, {:finish}, timeout)

  @impl GenServer
  def init(opts),
    do: {:ok, %{map: CoverageMap.new(Keyword.take(opts, [:slack])), batch: [], count: 0}}

  @impl GenServer
  def handle_call({:finish}, _from, state) do
    map = state |> flush() |> Map.fetch!(:map) |> CoverageMap.drain()
    {:reply, {:ok, map}, %{state | map: map}}
  end

  @impl GenServer
  def handle_info({:trace_ts, _pid, :call, {module, name, args}, stamp}, state),
    do: {:noreply, add(state, event(module, name, args, nil, stamp))}

  def handle_info({:trace_ts, _pid, :call, {module, name, arity}, message, stamp}, state),
    do: {:noreply, add(state, event(module, name, arity, message, stamp))}

  def handle_info(_other, state), do: {:noreply, state}

  defp event(@event_manager, :test_started, args, message, stamp),
    do: {:window_open, stamp, test_ref(test_arg(args, message))}

  defp event(@event_manager, :test_finished, args, message, stamp),
    do: {:window_close, stamp, test_ref(test_arg(args, message))}

  defp event(module, name, args, _message, stamp) when is_list(args),
    do: {:call, stamp, {module, name, length(args)}}

  defp event(module, name, arity, _message, stamp), do: {:call, stamp, {module, name, arity}}

  defp test_arg([_manager, test], _message), do: test
  defp test_arg(_arity, message), do: message

  defp test_ref(%{tags: tags} = test) do
    %{
      file: tags |> Map.get(:file, "") |> to_string(),
      line: Map.get(tags, :line, 0),
      name: to_string(Map.get(test, :name, "")),
      module: inspect(Map.get(test, :module))
    }
  end

  defp add(state, event) do
    state = %{state | batch: [event | state.batch], count: state.count + 1}
    if state.count >= @batch, do: flush(state), else: state
  end

  defp flush(%{batch: []} = state), do: state

  defp flush(state) do
    map = CoverageMap.attribute(state.map, Enum.reverse(state.batch))
    %{state | map: map, batch: [], count: 0}
  end
end
