defmodule Anchor.Sabotage.CoverageCollector do
  @moduledoc """
  The tracer of `mix anchor.sabotage coverage` (DND-5474, DND-5691). An OTP
  process module, so **Framework** (ADR 001), and it lives under
  `lib/mix/tasks/`, a Framework path in `.anchor.yml`'s `architecture:` buckets
  (the `Mix.Tasks.Anchor.Sabotage` task starts it). It turns each trace message
  into a `Anchor.Domain.Sabotage.CoverageMap` event.

  It keeps no traced value. A call becomes its `{module, name, arity}`, its pid and
  the label and word the VM read at the call. A window's `%ExUnit.Test{}` becomes
  the test's ref (`%{file, line, name, module}`, from its tags) and whether it ran.
  A spawn event's arguments become the one pid they name, or a refusal
  (`Anchor.Domain.Sabotage.ProcessOwnership.edge/3`).

  A call message in any other shape is an error in the state, never dropped: the
  spec that sent it did not install as the run assumes (COULD NOT MEASURE). Other
  process events (`:spawned`, `:exit`, `:link`, ...) carry nothing the map reads.

  `finish/1` (the call `{:finish}`) replies `{:ok, state}`.
  """

  use GenServer

  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Domain.Sabotage.ProcessOwnership

  @event_manager ExUnit.EventManager
  @on_exit_handler ExUnit.OnExitHandler
  @runner ExUnit.Runner

  @doc "Starts a collector."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @doc "Returns everything recorded."
  @spec finish(pid(), timeout()) :: {:ok, CoverageMap.state()}
  def finish(pid, timeout \\ :infinity), do: GenServer.call(pid, {:finish}, timeout)

  @impl GenServer
  def init(_opts) do
    # A trace message costs the traced process nothing to send, and a queue this
    # long must not be copied on every garbage collection.
    Process.flag(:message_queue_data, :off_heap)
    Process.flag(:priority, :high)
    {:ok, CoverageMap.new()}
  end

  @impl GenServer
  def handle_call({:finish}, _from, map), do: {:reply, {:ok, map}, map}

  @impl GenServer
  def handle_info({:trace, pid, :call, mfa, message}, map),
    do: {:noreply, CoverageMap.attribute(map, [event(pid, mfa, message)])}

  def handle_info({:trace, parent, :spawn, child, mfa}, map),
    do: {:noreply, CoverageMap.attribute(map, [spawn_event(child, parent, mfa)])}

  def handle_info(_other, map), do: {:noreply, map}

  defp event(pid, {@event_manager, :test_started, 2}, {test, word}),
    do: {:test_started, pid, word, test_ref(test), test.module}

  defp event(pid, {@event_manager, :test_finished, 2}, {test, word}),
    do: {:test_finished, pid, word, ran?(test), test.module}

  defp event(pid, {@event_manager, :module_finished, 2}, {module, word}),
    do: {:module_finished, pid, module, word}

  defp event(_pid, {@on_exit_handler, :register, 1}, {:entry, word}), do: {:entry, word}

  defp event(pid, {@runner, :run_setup_all, 4}, {:module, module}),
    do: {:module_started, pid, module}

  defp event(pid, {module, name, arity}, {label, word})
       when is_atom(module) and is_integer(arity) and is_integer(word),
       do: {:call, {module, name, arity}, pid, label, word}

  defp event(_pid, mfa, message), do: {:error, {:unreadable, {mfa, message}}}

  defp spawn_event(child, parent, mfa) do
    case ProcessOwnership.edge(child, parent, mfa) do
      {^child, ^parent, via} -> {:spawn, parent, child, via}
      {:error, reason} -> {:error, reason}
    end
  end

  # A test with a process ends passed (nil) or failed; every other state means
  # ExUnit never started one.
  defp ran?(%{state: nil}), do: true
  defp ran?(%{state: {:failed, _failures}}), do: true
  defp ran?(_test), do: false

  defp test_ref(%{tags: tags} = test) do
    %{
      file: tags |> Map.get(:file, "") |> to_string(),
      line: Map.get(tags, :line, 0),
      name: to_string(Map.get(test, :name, "")),
      module: inspect(Map.get(test, :module))
    }
  end
end
