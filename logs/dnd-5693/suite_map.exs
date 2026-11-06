# DND-5693 Q4/Q5/Q6 (throwaway, CI only): the whole suite, one test at a time, under
# the causal tracer. Writes a pid-free ETF of what each call was, so the compare
# script can read every mechanism's map from one run.
#   MIX_ENV=test mix run logs/dnd-5693/suite_map.exs <every|shape:k> <out.etf> <preload|nopreload> [seed]
Code.require_file("causal_lib.exs", __DIR__)

alias Anchor.Adapters.ProjectModules
alias Anchor.Adapters.SuiteRunner

defmodule Spike.Preload do
  @moduledoc false
  # Q5: every project and dependency module, and the runtime's own.
  @runtime [:kernel, :stdlib, :compiler, :crypto, :elixir, :ex_unit, :logger, :mix, :eex]

  def run do
    build = Path.wildcard(Path.join(Mix.Project.build_path(), "lib/*/ebin/*.beam"))

    runtime =
      for app <- @runtime, dir = :code.lib_dir(app), is_list(dir) do
        Path.wildcard(Path.join(to_string(dir), "ebin/*.beam"))
      end

    modules =
      [build | runtime]
      |> List.flatten()
      |> Enum.map(&(&1 |> Path.basename(".beam") |> String.to_atom()))
      |> Enum.uniq()

    case :code.ensure_modules_loaded(modules) do
      :ok ->
        IO.puts("SUITE preload modules=#{length(modules)} failed=0")

      {:error, failed} ->
        IO.puts("SUITE preload modules=#{length(modules)} failed=#{length(failed)} #{inspect(failed, limit: 20)}")
    end
  end
end

defmodule Spike.Resolve do
  @moduledoc false
  # Turns pids into what a pid means, once the run is over: its owner by spawn
  # ancestry (a test word, a setup_all module, or none) and the origin chain.
  # Nothing here reads an arrival order: parents and roots are sets.
  def rows(state) do
    %{keys: keys, parents: parents, roots: roots} = state

    keys
    |> Enum.group_by(
      fn {{mfa, pid, word, label}, _count} ->
        {mfa, word, label, owner(pid, parents, roots), origin(pid, parents, roots, [])}
      end,
      fn {_key, count} -> count end
    )
    |> Map.new(fn {row, counts} -> {row, Enum.sum(counts)} end)
  end

  def owner(pid, parents, roots), do: owner(pid, parents, roots, 0)

  defp owner(_pid, _parents, _roots, depth) when depth > 128, do: :cycle

  defp owner(pid, parents, roots, depth) do
    case roots do
      %{^pid => {:entry_test, word}} ->
        {:test, word}

      %{^pid => {:entry_module, module}} ->
        {:module, module}

      _other ->
        case parents do
          %{^pid => {parent, _origin}} -> owner(parent, parents, roots, depth + 1)
          _none -> :none
        end
    end
  end

  # The spawn origins from the process up to its owner, at most five, for naming
  # the source of a difference.
  defp origin(pid, parents, roots, acc) do
    cond do
      length(acc) >= 5 ->
        Enum.reverse(acc)

      is_map_key(roots, pid) ->
        Enum.reverse([:root | acc])

      true ->
        case parents do
          %{^pid => {parent, origin}} -> origin(parent, parents, roots, [origin | acc])
          _none -> Enum.reverse([:pre_existing | acc])
        end
    end
  end
end

[mode, out, preload | rest] = System.argv()
seed = List.first(rest, "0")
path = Mix.Project.compile_path()
modules = ProjectModules.list([path])
for module <- modules, do: Code.ensure_loaded(module)
if preload == "preload", do: Spike.Preload.run()

{k, shape} =
  case String.split(mode, ":") do
    ["every"] -> {:none, :label_body}
    [shape, k] -> {String.to_integer(k), String.to_existing_atom(shape)}
  end

collector = Spike.Collector.start()
gate = Spike.Gate.start(collector, k, shape)
Spike.Trace.on(modules, gate, collector, [:procs])
started = System.monotonic_time(:millisecond)

{suite_ms, suite} =
  :timer.tc(fn -> SuiteRunner.run(["--exclude", "global_tracing", "--seed", seed, "--slowest", "3"]) end, :millisecond)

Spike.Trace.off()
stats = Spike.Gate.finish(gate)
wall = System.monotonic_time(:millisecond) - started
state = Spike.Collector.take(collector)

result = %{
  mode: mode,
  rows: Spike.Resolve.rows(state),
  windows: state.windows,
  stats: stats,
  suite: suite,
  suite_ms: suite_ms,
  wall_ms: wall
}

File.write!(out, :erlang.term_to_binary(result))

verdict =
  case suite do
    :passed -> "passed"
    {:failed, message} -> "FAILED #{String.slice(message, 0, 300)}"
  end

IO.puts(
  "SUITE mode=#{mode} out=#{out} preload=#{preload} seed=#{seed} suite=#{verdict} suite_ms=#{suite_ms} wall_ms=#{wall} " <>
    "tests=#{map_size(state.windows)} rows=#{map_size(result.rows)} messages_sent=#{stats.received} " <>
    "forwarded=#{stats.forwarded} dropped=#{stats.dropped} silences=#{stats.silences} " <>
    "trace_pattern_ms=#{div(stats.silence_us, 1000)} proc_events=#{stats.procs}"
)

System.halt(0)
