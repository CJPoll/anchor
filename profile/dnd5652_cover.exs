# DND-5652: native function coverage (+JPcover function) measurement.
# ERL_FLAGS="+JPcover function" MIX_ENV=test mix run profile/dnd5652_cover.exs
alias Anchor.Adapters.BeamReader
alias Anchor.Domain.Cfa
alias Anchor.Domain.Demand
alias Anchor.Domain.Graph.Builder

say = fn text -> IO.puts("PROF " <> text) end
exports = :code.module_info(:exports) |> Enum.filter(fn {n, _} -> n |> Atom.to_string() |> String.contains?("coverage") end)
say.("C code coverage exports=#{inspect(exports)}")
say.("C coverage_support=#{inspect(:code.coverage_support())}")
say.("C mode before=#{inspect(try do :code.get_coverage_mode() rescue e -> e end)}")
say.("C set_mode=#{inspect(try do :code.set_coverage_mode(:function) rescue e -> e end)}")

modules = Anchor.Adapters.ProjectModules.list([Mix.Project.compile_path()])
for m <- modules, do: Code.ensure_loaded(m)

sets =
  for m <- modules,
      {:ok, _} <- [{:ok, nil}] do
    try do
      cov = :code.get_coverage(:function, m)
      {m, cov}
    rescue
      e -> {m, {:error, e}}
    end
  end

[{m1, c1} | _] = sets
say.("C sample #{inspect(m1)} -> #{inspect(Enum.take(List.wrap(c1), 3))}")

body = fn ->
  graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
  Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])
end

{us0, _} = :timer.tc(body)
{us1, _} = :timer.tc(body)
say.("C demand body with native coverage: cold_ms=#{div(us0, 1000)} warm_ms=#{div(us1, 1000)}")

reset_all = fn -> for m <- modules, do: :code.reset_coverage(m) end
covered = fn ->
  for m <- modules, {{f, a}, true} <- List.wrap(:code.get_coverage(:function, m)), into: MapSet.new(), do: {m, f, a}
end

n = 200
{t_reset, _} = :timer.tc(fn -> for _ <- 1..n, do: reset_all.() end)
{t_get, _} = :timer.tc(fn -> for _ <- 1..n, do: covered.() end)
say.("C per-window reset_us=#{div(t_reset, n)} get_us=#{div(t_get, n)} x2000 windows s=#{Float.round((t_reset + t_get) / n * 2000 / 1.0e6, 1)}")

reset_all.()
{us2, _} = :timer.tc(body)
set = covered.()
say.("C body with reset: ms=#{div(us2, 1000)} covered_functions=#{MapSet.size(set)}")
