# DND-5652 profile 2: first-hit silencing latency, trace_pattern cost, and the
# trace-control-word bitmask hybrid. MIX_ENV=test mix run profile/dnd5652_profile2.exs
alias Anchor.Adapters.BeamReader
alias Anchor.Domain.Cfa
alias Anchor.Domain.Demand
alias Anchor.Domain.Graph.Builder

defmodule Prof2 do
  def say(text), do: IO.puts("PROF2 " <> text)

  def body do
    graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
    Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])
  end

  def timed(limit_ms, sampler) do
    parent = self()
    {pid, ref} = spawn_monitor(fn ->
      {us, _} = :timer.tc(&body/0)
      send(parent, {:body_done, us})
    end)
    wait(pid, ref, System.monotonic_time(:millisecond), limit_ms, sampler)
  end

  defp wait(pid, ref, started, limit_ms, sampler) do
    receive do
      {:body_done, us} -> Process.demonitor(ref, [:flush]); {:ok, div(us, 1000)}
      {:DOWN, ^ref, _, _, reason} -> {{:down, reason}, 0}
    after
      1000 ->
        elapsed = System.monotonic_time(:millisecond) - started
        sampler.()
        if elapsed > limit_ms do
          Process.exit(pid, :kill); Process.demonitor(ref, [:flush]); {:timeout, elapsed}
        else
          wait(pid, ref, started, limit_ms, sampler)
        end
    end
  end

  # tracer that counts, and (silence?) turns a function off on its first message
  def tracer(n, seen, silences, silence_us, silence?) do
    receive do
      {:report, from} ->
        send(from, {:report, n, silences, silence_us})
        tracer(n, seen, silences, silence_us, silence?)

      {:trace_ts, _pid, :call, mfa, _stamp} when silence? ->
        if MapSet.member?(seen, mfa) do
          tracer(n + 1, seen, silences, silence_us, silence?)
        else
          {us, _} = :timer.tc(fn -> :erlang.trace_pattern(mfa, false, [:local]) end)
          tracer(n + 1, MapSet.put(seen, mfa), silences + 1, silence_us + us, silence?)
        end

      _other ->
        tracer(n + 1, seen, silences, silence_us, silence?)
    end
  end

  def run(label, modules, specs, silence?, limit_ms) do
    t = spawn(fn -> tracer(0, MapSet.new(), 0, 0, silence?) end)
    for m <- modules, Code.ensure_loaded?(m), do: :erlang.trace_pattern({m, :_, :_}, true, [:local])
    for {mfa, spec} <- specs, do: :erlang.trace_pattern(mfa, spec, [:local])
    :erlang.system_flag(:trace_control_word, 0)
    :erlang.trace(:all, true, [{:tracer, t}, :call, :arity, :strict_monotonic_timestamp])
    :erlang.trace(t, false, [:all])
    {status, ms} = timed(limit_ms, fn -> :ok end)
    :erlang.trace(:all, false, [:all])
    ref = :erlang.trace_delivered(:all)
    receive do {:trace_delivered, :all, ^ref} -> :ok end
    :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    send(t, {:report, self()})
    receive do
      {:report, n, s, sus} -> say("#{label}: status=#{inspect(status)} body_ms=#{ms} messages=#{n} silences=#{s} silence_total_ms=#{div(sus, 1000)} silence_mean_us=#{if s > 0, do: div(sus, s), else: 0}")
    end
    Process.exit(t, :kill)
  end
end

modules = Anchor.Adapters.ProjectModules.list([Mix.Project.compile_path()])
for m <- modules, do: Code.ensure_loaded(m)
Prof2.say("modules=#{length(modules)} otp=#{:erlang.system_info(:otp_release)} tcw=#{:erlang.system_flag(:trace_control_word, 0)}")

# hot list from call_count
for m <- modules, do: :erlang.trace_pattern({m, :_, :_}, true, [:call_count])
Prof2.timed(120_000, fn -> :ok end)
counts =
  for m <- modules, {f, a} <- m.module_info(:functions),
      {:call_count, c} <- [:erlang.trace_info({m, f, a}, :call_count)], c > 0, do: {{m, f, a}, c}
:erlang.trace_pattern({:_, :_, :_}, false, [:call_count])
sorted = Enum.sort_by(counts, &elem(&1, 1), :desc)
total = counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()

# trace_pattern microbenchmarks (no tracer on: patterns only)
sample = sorted |> Enum.take(200) |> Enum.map(&elem(&1, 0))
{t_on, _} = :timer.tc(fn -> for mfa <- sample, do: :erlang.trace_pattern(mfa, true, [:local]) end)
{t_off, _} = :timer.tc(fn -> for mfa <- sample, do: :erlang.trace_pattern(mfa, false, [:local]) end)
spec = [{:_, [{:"=/=", {:get_tcw}, 7}], [{:message, {:get_tcw}}]}]
{t_spec, _} = :timer.tc(fn -> for mfa <- sample, do: :erlang.trace_pattern(mfa, spec, [:local]) end)
{t_mod, _} = :timer.tc(fn -> for m <- modules, do: :erlang.trace_pattern({m, :_, :_}, true, [:local]) end)
:erlang.trace_pattern({:_, :_, :_}, false, [:local])
Prof2.say("MICRO trace_pattern per single function: enable_us=#{div(t_on, 200)} disable_us=#{div(t_off, 200)} spec_us=#{div(t_spec, 200)}; per whole module enable_us=#{div(t_mod, length(modules))}")

# V9: silence a function on its first message (counter process as the gate)
Prof2.run("V9 first-hit-silence-in-tracer", modules, [], true, 150_000)

# V8: top-N functions deduped per window by a bit in the trace control word
for n <- [30] do
  hot = sorted |> Enum.take(n) |> Enum.map(&elem(&1, 0))
  share = sorted |> Enum.take(n) |> Enum.map(&elem(&1, 1)) |> Enum.sum()
  specs =
    hot
    |> Enum.with_index()
    |> Enum.map(fn {mfa, i} ->
      bit = Bitwise.bsl(1, i)
      {mfa, [{:_, [{:==, {:band, {:get_tcw}, bit}, 0}], [{:set_tcw, {:bor, {:get_tcw}, bit}}]}]}
    end)
  Prof2.say("V8 hot=#{n} share_of_calls=#{Float.round(share / total * 100, 1)}%")
  Prof2.run("V8 tcw-bitmask-top#{n}", modules, specs, false, 150_000)
end
Prof2.say("DONE")
