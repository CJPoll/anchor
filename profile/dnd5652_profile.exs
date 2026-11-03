# DND-5652 profiling harness (temporary; CI only, never a desktop).
# MIX_ENV=test mix run profile/dnd5652_profile.exs
alias Anchor.Adapters.BeamReader
alias Anchor.Adapters.CallTracer
alias Anchor.Domain.Cfa
alias Anchor.Domain.Demand
alias Anchor.Domain.Graph.Builder
alias Anchor.Sabotage.CoverageCollector

defmodule Prof do
  def say(text), do: IO.puts("PROF " <> text)

  def body do
    graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
    demand = Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])
    {map_size(demand.summaries), demand.bound_hit}
  end

  # Runs body in its own process; returns {:ok, micros} or {:timeout, micros}.
  def timed(limit_ms, sampler \\ fn -> :ok end) do
    parent = self()
    {pid, ref} = spawn_monitor(fn ->
      {us, _} = :timer.tc(&body/0)
      send(parent, {:body_done, us})
    end)

    started = System.monotonic_time(:millisecond)
    wait(pid, ref, started, limit_ms, sampler)
  end

  defp wait(pid, ref, started, limit_ms, sampler) do
    receive do
      {:body_done, us} ->
        Process.demonitor(ref, [:flush])
        {:ok, us}

      {:DOWN, ^ref, _, _, reason} ->
        {{:down, reason}, 0}
    after
      1000 ->
        elapsed = System.monotonic_time(:millisecond) - started
        sampler.()

        if elapsed > limit_ms do
          Process.exit(pid, :kill)
          Process.demonitor(ref, [:flush])
          {:timeout, elapsed * 1000}
        else
          wait(pid, ref, started, limit_ms, sampler)
        end
    end
  end

  def ms(us) when is_integer(us), do: div(us, 1000)

  def counter(n, last_report) do
    receive do
      {:report, from} ->
        send(from, {:count, n})
        counter(n, last_report)

      _other ->
        counter(n + 1, last_report)
    end
  end

  def count_variant(label, flags, modules, limit_ms) do
    counter = spawn(fn -> counter(0, 0) end)
    for m <- modules, Code.ensure_loaded?(m), do: :erlang.trace_pattern({m, :_, :_}, true, [:local])
    :erlang.trace(:all, true, [{:tracer, counter} | flags])
    :erlang.trace(counter, false, [:all])

    sampler = fn ->
      {:message_queue_len, q} = Process.info(counter, :message_queue_len)
      say("#{label} sample queue_len=#{q}")
    end

    {status, us} = timed(limit_ms, sampler)
    :erlang.trace(:all, false, [:all])
    ref = :erlang.trace_delivered(:all)
    receive do {:trace_delivered, :all, ^ref} -> :ok end
    :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    {:message_queue_len, q} = Process.info(counter, :message_queue_len)
    drain_start = System.monotonic_time(:millisecond)
    send(counter, {:report, self()})
    receive do {:count, n} -> say("#{label}: status=#{inspect(status)} body_ms=#{ms(us)} messages=#{n} queue_at_body_end=#{q} drain_ms=#{System.monotonic_time(:millisecond) - drain_start}") end
    Process.exit(counter, :kill)
  end
end

{:ok, _} = Application.ensure_all_started(:ex_unit)
modules = Anchor.Adapters.ProjectModules.list([Mix.Project.compile_path()])
Prof.say("modules=#{length(modules)} schedulers=#{System.schedulers_online()} otp=#{:erlang.system_info(:otp_release)}")

# V0: untraced, cold then warm
{:ok, us0} = Prof.timed(120_000)
{:ok, us1} = Prof.timed(120_000)
Prof.say("V0 untraced cold_ms=#{Prof.ms(us0)} warm_ms=#{Prof.ms(us1)}")

# V6: call_count only (no messages): total call volume and its distribution
for m <- modules, Code.ensure_loaded?(m), do: :erlang.trace_pattern({m, :_, :_}, true, [:call_count])
{:ok, us6} = Prof.timed(120_000)
counts =
  for m <- modules, Code.ensure_loaded?(m), {f, a} <- m.module_info(:functions),
      {:call_count, c} <- [:erlang.trace_info({m, f, a}, :call_count)], c > 0, do: {{m, f, a}, c}
:erlang.trace_pattern({:_, :_, :_}, false, [:call_count])
total = counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()
sorted = Enum.sort_by(counts, &elem(&1, 1), :desc)
Prof.say("V6 call_count body_ms=#{Prof.ms(us6)} total_calls=#{total} distinct_functions=#{length(counts)}")
for n <- [1, 5, 10, 25, 50, 100, 200, 400] do
  share = sorted |> Enum.take(n) |> Enum.map(&elem(&1, 1)) |> Enum.sum()
  Prof.say("V6 top#{n}_share=#{Float.round(share / total * 100, 2)}%")
end
for {{m, f, a}, c} <- Enum.take(sorted, 15), do: Prof.say("V6 hot #{inspect(m)}.#{f}/#{a} calls=#{c}")

# V4: counting tracer process, no timestamp
Prof.count_variant("V4 plain-trace-no-stamp", [:call, :arity], modules, 200_000)
# V2: counting tracer process with strict_monotonic_timestamp (the real flags)
Prof.count_variant("V2 plain-trace-strict-stamp", [:call, :arity, :strict_monotonic_timestamp], modules, 200_000)

# V1: the real every-call tracer and collector, with a test window open
{:ok, collector} = CoverageCollector.start_link()
{:ok, mgr} = ExUnit.EventManager.start_link()
:ok = CallTracer.start(collector, modules)
test = %ExUnit.Test{name: :"test prof", module: Prof, tags: %{file: "prof.exs", line: 1}}
ExUnit.EventManager.test_started(mgr, test)
sampler = fn ->
  {:message_queue_len, q} = Process.info(collector, :message_queue_len)
  Prof.say("V1 sample collector_queue_len=#{q}")
end
{status, us} = Prof.timed(240_000, sampler)
ExUnit.EventManager.test_finished(mgr, test)
:ok = CallTracer.stop()
{:message_queue_len, q} = Process.info(collector, :message_queue_len)
t0 = System.monotonic_time(:millisecond)
{:ok, st} = CallTracer.collected(collector)
Prof.say("V1 real-collector: status=#{inspect(status)} body_ms=#{Prof.ms(us)} queue_at_body_end=#{q} drain_ms=#{System.monotonic_time(:millisecond) - t0} arrived=#{st.arrived} outside=#{st.outside_windows} late=#{st.late_events}")
Prof.say("DONE")
