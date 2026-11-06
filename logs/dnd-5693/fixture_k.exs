# DND-5693 (throwaway, CI only): QA rows 4 and 6 on a fixture with the real gate. Does
# a suppression shape change the map or the leak list? One mode per VM.
#   elixir logs/dnd-5693/fixture_k.exs <every|shape:k>
Code.require_file("causal_lib.exs", __DIR__)

defmodule Spike.Hot do
  @moduledoc false
  def f(n), do: n + 1
  def g(n), do: n + 2
  def h(n), do: n + 3
end

defmodule Spike.Srv do
  @moduledoc false
  use GenServer
  def init(state), do: {:ok, state}

  def handle_call({:g, times}, _from, state) do
    for n <- 1..times, do: Spike.Hot.g(n)
    {:reply, :ok, state}
  end

  def handle_info({:g_once, flag}, state) do
    Spike.Hot.g(0)
    :atomics.put(flag, 2, 1)
    {:noreply, state}
  end
end

ExUnit.start(autorun: false, max_cases: 1, seed: 0, formatters: [ExUnit.CLIFormatter])

defmodule Spike.KCase do
  use ExUnit.Case, async: false
  alias Spike.Hot

  @hot 10_000

  defp settle(srv) do
    for pid <- [self(), srv] do
      ref = :erlang.trace_delivered(pid)

      receive do
        {:trace_delivered, ^pid, ^ref} -> :ok
      end
    end

    send(:persistent_term.get(:spike_k_gate), {:sync, self()})

    receive do
      :synced -> :ok
    end
  end

  defp wait_flag(flag, slot) do
    if :atomics.get(flag, slot) == 1 do
      :ok
    else
      :erlang.yield()
      wait_flag(flag, slot)
    end
  end

  # A holds a process past its own end; the flags are shared memory, so no message
  # relabels anything.
  test "a hot, leaves a process" do
    for n <- 1..@hot, do: Hot.f(n)
    go = :atomics.new(2, [])
    :persistent_term.put(:spike_k_flag, go)
    srv = :persistent_term.get(:spike_k_srv)

    spawn(fn ->
      Hot.h(0)
      wait_flag(go, 1)
      # QA row 4: f is silenced inside A and again inside B; this is a leak of A's.
      Hot.f(0)
      # A second leak of A's, through the server: its token says A in B's window.
      send(srv, {:g_once, go})
      wait_flag(go, 2)
    end)

    assert :atomics.get(go, 1) == 0
  end

  test "b hot, releases a's process" do
    srv = :persistent_term.get(:spike_k_srv)
    go = :persistent_term.get(:spike_k_flag)
    for n <- 1..@hot, do: Hot.f(n)
    :ok = GenServer.call(srv, {:g, @hot})
    # Every message so far has reached the gate and each suppression is installed,
    # so what follows runs against a silenced f and g: no scheduling decides this.
    settle(srv)
    :atomics.put(go, 1, 1)
    wait_flag(go, 2)
    # The server's message came and went: block until the leak process has run.
    assert :atomics.get(go, 2) == 1
  end

  test "c calls nothing hot" do
    assert Hot.h(1) == 4
  end
end

defmodule Spike.KRun do
  @moduledoc false
  def owner(pid, parents, roots, depth \\ 0)
  def owner(_pid, _parents, _roots, depth) when depth > 64, do: :none

  def owner(pid, parents, roots, depth) do
    case roots do
      %{^pid => {:entry_test, word}} -> {:test, word}
      _other ->
        case parents do
          %{^pid => {parent, _origin}} -> owner(parent, parents, roots, depth + 1)
          _none -> :none
        end
    end
  end
end

mode = hd(System.argv())

{k, shape} =
  case String.split(mode, ":") do
    ["every"] -> {:none, :label_body}
    [shape, k] -> {String.to_integer(k), String.to_existing_atom(shape)}
  end

{:ok, srv} = GenServer.start(Spike.Srv, %{})
:persistent_term.put(:spike_k_srv, srv)
collector = Spike.Collector.start()
gate = Spike.Gate.start(collector, k, shape)
:persistent_term.put(:spike_k_gate, gate)
Spike.Trace.on([Spike.Hot], gate, collector, [:procs])
results = ExUnit.run()
Spike.Trace.off()
stats = Spike.Gate.finish(gate)
state = Spike.Collector.take(collector)

name = fn word -> state.windows[word] && state.windows[word].name end

# The hybrid rule: a test-owned process by its owner; anything else by its label.
{map, leaks} =
  Enum.reduce(state.keys, {MapSet.new(), MapSet.new()}, fn {{{_m, f, a}, pid, word, label}, _count}, {map, leaks} ->
    case Spike.KRun.owner(pid, state.parents, state.roots) do
      {:test, owner} ->
        map = MapSet.put(map, {name.(owner), {f, a}})
        {map, if(word > owner, do: MapSet.put(leaks, {name.(owner), {f, a}}), else: leaks)}

      :none when is_integer(label) ->
        {MapSet.put(map, {name.(label), {f, a}}), leaks}

      :none ->
        {map, leaks}
    end
  end)

canonical = :erlang.term_to_binary({Enum.sort(map), Enum.sort(leaks)})
hash = :crypto.hash(:sha256, canonical) |> Base.encode16() |> binary_part(0, 16)

IO.puts("KFIX mode=#{mode} forwarded_keys=#{map_size(state.keys)} results=#{inspect(results)} canonical=#{hash} messages=#{stats.received} forwarded=#{stats.forwarded} silences=#{stats.silences}")
IO.puts("KFIX mode=#{mode} map=#{inspect(Enum.sort(map), limit: :infinity)}")
IO.puts("KFIX mode=#{mode} leaks=#{inspect(Enum.sort(leaks), limit: :infinity)}")
System.halt(0)
