defmodule Anchor.Domain.GraphRules.NoInertHopTest do
  # Domain (ADR 002). DND-5461: inert hops as violations. The models are hand-built
  # (Anchor.Test.PlacementModels); each function's Core comes from fixture modules
  # compiled in the test (AnchorFixtures.NoInertHopTest.*).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Anchor.Test.PlacementModels

  alias Anchor.Domain.GraphRules.NoInertHop
  alias Anchor.Domain.Placement
  alias AnchorFixtures.NoInertHopTest, as: F

  @source """
  defmodule AnchorFixtures.NoInertHopTest.Web do
    def show(xs), do: AnchorFixtures.NoInertHopTest.Totals.sum(xs)
    def list(xs), do: AnchorFixtures.NoInertHopTest.Totals.sum(xs)
    def run(conn, params), do: AnchorFixtures.NoInertHopTest.Invoices.show(conn, params)
  end

  defmodule AnchorFixtures.NoInertHopTest.Totals do
    def sum(xs), do: AnchorFixtures.NoInertHopTest.Math.sum(xs)
  end

  defmodule AnchorFixtures.NoInertHopTest.Math do
    def sum(xs), do: Enum.sum(xs)
    def pair(a, b), do: {a, b}
  end

  defmodule AnchorFixtures.NoInertHopTest.Defaults do
    def k(a, b \\\\ 1), do: AnchorFixtures.NoInertHopTest.Math.pair(a, b)
  end

  defmodule AnchorFixtures.NoInertHopTest.Invoices do
    def show(conn, params), do: AnchorFixtures.NoInertHopTest.Query.show(conn, params)
    def list(user), do: AnchorFixtures.NoInertHopTest.Query.list(user)
  end

  defmodule AnchorFixtures.NoInertHopTest.Query do
    def show(conn, params), do: {conn, params}
    def list(user), do: [user]
  end

  defmodule AnchorFixtures.NoInertHopTest.Http do
    def get(url), do: Req.get(url)
  end
  """

  @rule %{type: :no_inert_hop, id: "hops", paths: ["lib/**/*.ex"]}

  setup_all do
    %{binaries: Map.new(compile_unloaded(@source))}
  end

  # The hand-built model, each function given the Core of its fixture.
  defp model_with_core(modules, calls, binaries) do
    model = model(modules, calls)

    Enum.reduce(modules, model, fn {module, _bucket, functions, _opts}, model ->
      Enum.reduce(functions, model, fn name_arity, model ->
        core = core_fun!(Map.fetch!(binaries, module), name_arity)
        put_in(model.graph.modules[module].functions[name_arity].core, core)
      end)
    end)
  end

  defp modules(opts \\ []) do
    [
      {F.Web, "framework", [{:show, 1}, {:list, 1}, {:run, 2}], []},
      {F.Totals, "domain", [{:sum, 1}], []},
      {F.Math, "domain", [{:sum, 1}, {:pair, 2}], []},
      {F.Invoices, "managers", [{:show, 2}, {:list, 1}], Keyword.get(opts, :invoices, [])},
      {F.Query, "managers", [{:show, 2}, {:list, 1}], []},
      {F.Http, "adapters", [{:get, 1}], []}
    ]
  end

  @calls [
    {{F.Web, :show, 1}, {F.Totals, :sum, 1}},
    {{F.Web, :list, 1}, {F.Totals, :sum, 1}},
    {{F.Web, :run, 2}, {F.Invoices, :show, 2}},
    {{F.Totals, :sum, 1}, {F.Math, :sum, 1}},
    {{F.Invoices, :show, 2}, {F.Query, :show, 2}},
    {{F.Invoices, :list, 1}, {F.Query, :list, 1}}
  ]

  test "an inert forwarder is one violation naming both callers; its Fix is the render", %{
    binaries: binaries
  } do
    model = model_with_core(modules(invoices: [interface: true]), @calls, binaries)

    assert [violation] = NoInertHop.check(model, @rule)
    [proposal] = model |> Placement.build() |> Placement.proposals(model, :no_inert_hop)

    assert violation.trigger == "AnchorFixtures.NoInertHopTest.Totals.sum/1"
    assert violation.filename == "lib/domain/Totals.ex"

    assert violation.key ==
             "hops|function|AnchorFixtures.NoInertHopTest.Totals.sum/1|" <>
               "AnchorFixtures.NoInertHopTest.Math.sum/1"

    assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))

    assert Placement.render(proposal) ==
             "inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers " <>
               "(AnchorFixtures.NoInertHopTest.Web.list/1, AnchorFixtures.NoInertHopTest.Web.show/1) " <>
               "call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without " <>
               "crossing a bucket, context, app, aggregate, interface or callback boundary)"
  end

  test "legal forwarders are not reported: bucket, interface and dependency crossings", %{
    binaries: binaries
  } do
    model = model_with_core(modules(invoices: [interface: true]), @calls, binaries)
    triggers = model |> NoInertHop.check(@rule) |> Enum.map(& &1.trigger)

    # Web.run/2 crosses into managers, Invoices.* is an interface forwarding to its
    # interior, Http.get/1 wraps a dependency: none is reported.
    assert triggers == ["AnchorFixtures.NoInertHopTest.Totals.sum/1"]

    # Positive control: the same Invoices, no interface, forwards inertly.
    plain = model_with_core(modules(), @calls, binaries)

    assert plain |> NoInertHop.check(@rule) |> Enum.map(& &1.trigger) == [
             "AnchorFixtures.NoInertHopTest.Invoices.list/1",
             "AnchorFixtures.NoInertHopTest.Invoices.show/2",
             "AnchorFixtures.NoInertHopTest.Totals.sum/1"
           ]
  end

  test "a forwarder no call names is still inert: dynamic callers only", %{binaries: binaries} do
    calls = Enum.reject(@calls, &match?({_from, {F.Totals, :sum, 1}}, &1))
    calls = calls ++ [{{F.Web, :show, 1}, {:dynamic, :sum, 1, :variable}}]
    model = model_with_core(modules(invoices: [interface: true]), calls, binaries)

    assert [violation] = NoInertHop.check(model, @rule)
    assert violation.message =~ "its callers (dynamic callers only)"
  end

  test "a function with a default argument is no forwarder", %{binaries: binaries} do
    modules = [
      {F.Web, "framework", [{:show, 1}], []},
      {F.Defaults, "domain", [{:k, 1}, {:k, 2}], []},
      {F.Math, "domain", [{:sum, 1}, {:pair, 2}], []}
    ]

    calls = [
      {{F.Web, :show, 1}, {F.Defaults, :k, 1}},
      {{F.Defaults, :k, 1}, {F.Defaults, :k, 2}},
      {{F.Defaults, :k, 2}, {F.Math, :pair, 2}}
    ]

    model = model_with_core(modules, calls, binaries)
    # The compiler's clause for k/1: `super` into k/2, marked a default.
    default =
      {[line: 1], [{:x0, [generated: true], :elixir_def}], [],
       {:super, [super: {:def, :k}, default: true], [{:x0, [generated: true], :elixir_def}, 1]}}

    with_default = put_in(model.graph.modules[F.Defaults].functions[{:k, 1}].clauses, [default])

    assert NoInertHop.check(with_default, @rule) == []
    # Positive control: without the default clause, k/2 is an inert forwarder.
    assert [%{trigger: "AnchorFixtures.NoInertHopTest.Defaults.k/2"}] =
             NoInertHop.check(model, @rule)
  end

  test "a generated module's forwarder is not judged", %{binaries: binaries} do
    model = model_with_core(modules(invoices: [interface: true]), @calls, binaries)
    generated = put_in(model.graph.modules[F.Totals].generated?, true)

    assert NoInertHop.check(generated, @rule) == []
    assert [_violation] = NoInertHop.check(model, @rule)
  end

  test "the selector limits the subjects", %{binaries: binaries} do
    model = model_with_core(modules(invoices: [interface: true]), @calls, binaries)
    rule = %{@rule | paths: ["lib/managers/**/*.ex"]}

    assert NoInertHop.check(model, rule) == []
  end

  test "shape/1, needs/0 and narrows?/2" do
    assert NoInertHop.shape(@rule) =~ "only forwards to another module"
    assert :placement in NoInertHop.needs()
    refute NoInertHop.narrows?("a", "b")
  end
end
