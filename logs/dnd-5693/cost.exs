# DND-5693 Q4 (throwaway, CI only): demand_self's body under each tracing variant.
#   MIX_ENV=test mix run logs/dnd-5693/cost.exs <variant>
# Variants: untraced | call_count | every | <shape>:<k>, shape one of label_body,
# pid_word, word. One variant per VM. Prints one COST line.
Code.require_file("causal_lib.exs", __DIR__)

alias Anchor.Adapters.BeamReader
alias Anchor.Adapters.ProjectModules
alias Anchor.Domain.Cfa
alias Anchor.Domain.Demand
alias Anchor.Domain.Graph.Builder

defmodule Spike.Body do
  @moduledoc false
  # demand_self's body, in a process labelled as a test's would be, blocked on
  # its own exit; a body that overruns limit_ms is killed and named.
  def run(path, label?, limit_ms) do
    me = self()

    {pid, ref} =
      spawn_monitor(fn ->
        if label?, do: :seq_trace.set_token(:label, 1)
        {us, _result} = :timer.tc(fn -> demand(path) end)
        send(me, {:body_us, us})
      end)

    receive do
      {:body_us, us} ->
        Process.demonitor(ref, [:flush])
        {:ok, div(us, 1000)}

      {:DOWN, ^ref, _, _, reason} ->
        {{:down, reason}, 0}
    after
      limit_ms ->
        Process.exit(pid, :kill)
        Process.demonitor(ref, [:flush])
        {:overran, limit_ms}
    end
  end

  defp demand(path) do
    graph = Builder.build(BeamReader.read_ebins([{:anchor, path}]), %{})
    Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])
  end
end

path = Mix.Project.compile_path()
modules = ProjectModules.list([path])
for module <- modules, do: Code.ensure_loaded(module)
variant = hd(System.argv())
limit_ms = 600_000

say = fn text -> IO.puts("COST variant=#{variant} " <> text) end

case String.split(variant, ":") do
  ["untraced"] ->
    {status, ms} = Spike.Body.run(path, false, limit_ms)
    say.("status=#{inspect(status)} body_ms=#{ms}")

  ["call_count"] ->
    for module <- modules, do: :erlang.trace_pattern({module, :_, :_}, true, [:call_count])
    {status, ms} = Spike.Body.run(path, false, limit_ms)

    counts =
      for module <- modules,
          {name, arity} <- module.module_info(:functions),
          {:call_count, count} <- [:erlang.trace_info({module, name, arity}, :call_count)],
          count > 0,
          do: count

    :erlang.trace_pattern({:_, :_, :_}, false, [:call_count])
    say.("status=#{inspect(status)} body_ms=#{ms} calls=#{Enum.sum(counts)} functions=#{length(counts)}")

  mode ->
    {k, shape} =
      case mode do
        ["every"] -> {:none, :label_body}
        [shape, k] -> {String.to_integer(k), String.to_existing_atom(shape)}
      end

    collector = Spike.Collector.start()
    gate = Spike.Gate.start(collector, k, shape)
    {pattern_us, :ok} = :timer.tc(fn -> Spike.Trace.on(modules, gate, collector) end)

    # The body runs inside an open window, as a test does: the word is 1 and the
    # label is 1, so the suppression clauses see what they see in a test.
    :erlang.system_flag(:trace_control_word, 1)
    wall_start = System.monotonic_time(:millisecond)
    {status, ms} = Spike.Body.run(path, true, limit_ms)
    Spike.Trace.off()
    stats = Spike.Gate.finish(gate)
    wall = System.monotonic_time(:millisecond) - wall_start
    forwarded_keys = map_size(Spike.Collector.take(collector).keys)

    say.(
      "status=#{inspect(status)} body_ms=#{ms} wall_with_drain_ms=#{wall} " <>
        "messages_sent=#{stats.received} forwarded=#{stats.forwarded} dropped=#{stats.dropped} " <>
        "silences=#{stats.silences} trace_pattern_ms=#{div(stats.silence_us, 1000)} " <>
        "set_patterns_ms=#{div(pattern_us, 1000)} keys=#{forwarded_keys}"
    )
end
