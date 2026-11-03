# DND-5652: per-window cost of call_count read+restart, and the window-boundary
# race. MIX_ENV=test mix run profile/dnd5652_windows.exs
alias Anchor.Adapters.BeamReader
alias Anchor.Domain.Cfa
alias Anchor.Domain.Demand
alias Anchor.Domain.Graph.Builder

say = fn text -> IO.puts("PROF " <> text) end
modules = Anchor.Adapters.ProjectModules.list([Mix.Project.compile_path()])
for m <- modules, do: Code.ensure_loaded(m)
mfas = for m <- modules, {f, a} <- m.module_info(:functions), do: {m, f, a}
say.("W modules=#{length(modules)} functions=#{length(mfas)}")

for m <- modules, do: :erlang.trace_pattern({m, :_, :_}, true, [:call_count])

read = fn ->
  Enum.reduce(mfas, 0, fn mfa, acc ->
    case :erlang.trace_info(mfa, :call_count) do
      {:call_count, c} when is_integer(c) and c > 0 -> acc + 1
      _ -> acc
    end
  end)
end

restart_all = fn -> for m <- modules, do: :erlang.trace_pattern({m, :_, :_}, :restart, [:call_count]) end
restart_each = fn -> for mfa <- mfas, do: :erlang.trace_pattern(mfa, :restart, [:call_count]) end

n = 200
{t_read, _} = :timer.tc(fn -> for _ <- 1..n, do: read.() end)
{t_rm, _} = :timer.tc(fn -> for _ <- 1..n, do: restart_all.() end)
{t_re, _} = :timer.tc(fn -> for _ <- 1..n, do: restart_each.() end)
say.("W per-window read_all_functions_us=#{div(t_read, n)} restart_per_module_us=#{div(t_rm, n)} restart_per_function_us=#{div(t_re, n)}")
say.("W x2000 windows: read_s=#{Float.round(t_read / n * 2000 / 1.0e6, 1)} restart_module_s=#{Float.round(t_rm / n * 2000 / 1.0e6, 1)}")

# Equality on the demand body: count set from call_count vs a second run.
body = fn ->
  graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
  Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])
end

restart_all.()
{us, _} = :timer.tc(body)
{t1, called} = :timer.tc(read)
say.("W demand body with call_count: ms=#{div(us, 1000)} functions_called=#{called} read_ms=#{div(t1, 1000)}")
