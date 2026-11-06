# DND-5693 Q6 (throwaway, CI only): can a tracer read $callers of a Task under a
# supervisor, for ownership? A match spec cannot read a process dictionary, so the
# reader is the tracer, reading another process with Process.info/2.
#   elixir logs/dnd-5693/callers_probe.exs
defmodule Spike.CallersFix do
  @moduledoc false
  def mark(tag), do: :erlang.phash2(tag)
end

defmodule Spike.CallersTracer do
  @moduledoc false
  # Reads the dictionary at the two moments a tracer can: the spawned event and the
  # process's first traced call.
  def loop(counts, seen) do
    receive do
      {:take, from} ->
        send(from, {:taken, counts})

      {:trace, child, :spawned, _parent, _mfa} ->
        loop(tally(counts, {:at_spawned, read(child)}), seen)

      {:trace, pid, :call, {Spike.CallersFix, :mark, _args}} ->
        if MapSet.member?(seen, pid),
          do: loop(counts, seen),
          else: loop(tally(counts, {:at_first_call, read(pid)}), MapSet.put(seen, pid))

      _other ->
        loop(counts, seen)
    end
  end

  defp tally(counts, key), do: Map.update(counts, key, 1, &(&1 + 1))

  defp read(pid) do
    case Process.info(pid, :dictionary) do
      nil ->
        :process_already_dead

      {:dictionary, dictionary} ->
        if List.keymember?(dictionary, :"$callers", 0), do: :has_callers, else: :no_callers_yet
    end
  end
end

run = fn name, task ->
  {:ok, sup} = Task.Supervisor.start_link()
  tracer = spawn(fn -> Spike.CallersTracer.loop(%{}, MapSet.new()) end)
  1 = :erlang.trace_pattern({Spike.CallersFix, :mark, 1}, true, [:global])
  :erlang.trace(sup, true, [:call, :procs, :set_on_spawn, {:tracer, tracer}])

  for n <- 1..500 do
    {:ok, pid} = Task.Supervisor.start_child(sup, fn -> task.(n) end)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
  end

  :erlang.trace(sup, false, [:all])
  delivered = :erlang.trace_delivered(:all)

  receive do
    {:trace_delivered, :all, ^delivered} -> :ok
  end

  send(tracer, {:take, self()})

  counts =
    receive do
      {:taken, counts} -> counts
    end

  IO.puts("CALLERS #{name} tasks=500 #{inspect(Enum.sort(counts))}")
end

for round <- 1..3 do
  run.("short task round #{round}", fn n -> Spike.CallersFix.mark(n) end)
end

IO.puts("CALLERS DONE")
