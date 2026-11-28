defmodule Anchor.Test.TransitiveGraphFixtures do
  @moduledoc """
  A generated module dependency graph about the size of a large umbrella
  (DND-8208): 1,200 Domain modules, 3,500 service modules and 300 adapters,
  5,000 nodes in all, with cycles, shared dead ends, modules absent from the map
  (`Enum`, `MyApp.Repo`) and many forbidden modules reachable from one module.

  It is the same graph on every run: the edges come from a fixed linear
  congruential sequence, not from `:rand`, so no seed or algorithm version can
  change it. Each Domain module also gets a source file whose functions name its
  dependencies, one per line, so a violation's line is meaningful.
  """

  @domain 1_200
  @services 3_500
  @adapters 300

  @doc """
  `{modules_map, sources}`: the graph as `Anchor.Managers.Lint` builds it (each
  module mapped to `%{direct_dependencies: [module]}`), and one
  `{module, source}` per Domain module. `service_fanout` bounds a service's
  dependencies on other services (fewer than `service_fanout`); a larger one
  makes a denser graph, where each module reaches far more.
  """
  @spec graph(pos_integer()) :: {map(), [{module(), String.t()}]}
  def graph(service_fanout \\ 3) do
    {domain, seed} = nodes(@domain, 7, &domain_deps/2)
    {services, seed} = nodes(@services, seed, &service_deps(&1, &2, service_fanout))
    {adapters, _seed} = nodes(@adapters, seed, &adapter_deps/2)

    modules_map =
      [domain, services, adapters]
      |> Enum.concat()
      |> Map.new(fn {module, deps} -> {module, %{direct_dependencies: deps}} end)

    {modules_map, Enum.map(domain, fn {module, deps} -> {module, source(module, deps)} end)}
  end

  @doc "The `no_transitive_dependency` rules the fixture is checked against."
  @spec rules() :: [map()]
  def rules do
    [
      %{
        type: :no_transitive_dependency,
        forbidden_modules: [MyApp.Repo, MyApp.Mailer],
        forbidden_patterns: ["MyApp.Adapters.*"]
      },
      %{
        type: :no_transitive_dependency,
        forbidden_modules: [MyApp.Services.S1, MyApp.Services.S2]
      }
    ]
  end

  @doc "The modules the Domain sources define, in order."
  @spec domain_modules() :: [module()]
  def domain_modules, do: Enum.map(1..@domain, &domain/1)

  defp nodes(count, seed, deps_fun) do
    Enum.map_reduce(1..count, seed, fn index, seed -> deps_fun.(index, seed) end)
  end

  # A Domain module depends on up to two earlier Domain modules (or, now and
  # then, a later one: a cycle), and sometimes on a service.
  defp domain_deps(index, seed) do
    {count, seed} = pick(seed, 3)
    {domain_targets, seed} = picks(count, seed, fn seed -> domain_target(index, seed) end)
    {roll, seed} = pick(seed, 4)
    {service, seed} = pick(seed, @services)
    deps = domain_targets ++ if(roll == 0, do: [service(service + 1)], else: [])
    {{domain(index), Enum.uniq(deps -- [domain(index)])}, seed}
  end

  defp domain_target(index, seed) do
    {roll, seed} = pick(seed, 10)
    {offset, seed} = pick(seed, 40)
    target = if roll == 0, do: min(index + offset + 1, @domain), else: max(index - offset - 1, 1)
    {domain(target), seed}
  end

  # A service depends on up to two services in a window below it (a layered
  # graph with shared subtrees), sometimes on one just above it (a cycle), and
  # now and then on an adapter or an external module.
  defp service_deps(index, seed, fanout) do
    {count, seed} = pick(seed, fanout)
    {targets, seed} = picks(count, seed, fn seed -> service_target(index, seed) end)
    {roll, seed} = pick(seed, 8)
    {adapter, seed} = pick(seed, @adapters)
    extra = Enum.at([[adapter(adapter + 1)], [Enum]], roll, [])
    {{service(index), Enum.uniq((targets ++ extra) -- [service(index)])}, seed}
  end

  defp service_target(index, seed) do
    {roll, seed} = pick(seed, 12)
    {offset, seed} = pick(seed, 60)
    target = if roll == 0, do: min(index + 1, @services), else: max(index - offset - 1, 1)
    {service(target), seed}
  end

  defp adapter_deps(index, seed) do
    {roll, seed} = pick(seed, 3)
    deps = Enum.at([[MyApp.Repo], [MyApp.Repo, MyApp.Mailer], [Enum]], roll)
    {{adapter(index), deps}, seed}
  end

  defp picks(count, seed, fun) do
    Enum.map_reduce(List.duplicate(nil, count), seed, fn nil, seed -> fun.(seed) end)
  end

  # A number in 0..(bound - 1), and the next state of the sequence.
  defp pick(seed, bound) do
    next = rem(seed * 1_103_515_245 + 12_345, 2_147_483_648)
    {div(next, 65_536) |> rem(bound), next}
  end

  defp source(module, deps) do
    functions =
      deps
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {dep, index} -> "  def f#{index}, do: #{inspect(dep)}.call()" end)

    "defmodule #{inspect(module)} do\n#{functions}\nend\n"
  end

  defp domain(index), do: Module.concat(MyApp.Domain, "D#{index}")
  defp service(index), do: Module.concat(MyApp.Services, "S#{index}")
  defp adapter(index), do: Module.concat(MyApp.Adapters, "A#{index}")
end
