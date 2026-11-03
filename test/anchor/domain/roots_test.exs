defmodule Anchor.Domain.RootsTest do
  # Domain (ADR 002). DND-5447: the roots of a program, over hand-built models
  # (Anchor.Test.EffectsModels). External behaviours' callbacks come in as a
  # map (the runner reads them through Anchor.Adapters.BehaviourSource), so no
  # module is loaded.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.EffectsModels

  alias Anchor.Domain.Roots

  @callbacks %{GenServer => [handle_call: 3, init: 1], App.Port => [run: 1]}

  defp roots(modules, opts \\ []),
    do: modules |> model([], opts) |> Roots.roots(@callbacks)

  test "public functions of a framework-role bucket are roots" do
    roots = roots([{Web.Controller, "framework", [{:show, 2}, {:load, 1, :defp}], []}])

    assert Roots.root?(roots, {Web.Controller, :show, 2})
    # A private function of the same module is not.
    refute Roots.root?(roots, {Web.Controller, :load, 1})
  end

  test "an external behaviour callback is a root, its other public functions are not" do
    roots =
      roots([
        {Store.Server, "adapters", [{:handle_call, 3}, {:fetch, 1}], behaviours: [GenServer]}
      ])

    assert Roots.root?(roots, {Store.Server, :handle_call, 3})
    refute Roots.root?(roots, {Store.Server, :fetch, 1})
  end

  test "a project-behaviour callback is not a root" do
    roots =
      roots([
        {App.Port, "domain", [], []},
        {App.Impl, "adapters", [{:run, 1}], behaviours: [App.Port]}
      ])

    refute Roots.root?(roots, {App.Impl, :run, 1})
  end

  test "architecture.roots selectors add roots" do
    modules = [{Mix.Tasks.Foo, "adapters", [{:run, 1}], []}]

    assert Roots.root?(
             roots(modules, roots: [%{"pattern" => "Mix.Tasks.*"}]),
             {Mix.Tasks.Foo, :run, 1}
           )

    # Positive control: without the selector it is not a root.
    refute Roots.root?(roots(modules), {Mix.Tasks.Foo, :run, 1})
  end

  test "a behaviour the callbacks do not hold gives no root (judged, never skipped)" do
    modules = [{Store.Server, "adapters", [{:handle_call, 3}], behaviours: [GenServer]}]

    refute Roots.root?(modules |> model([]) |> Roots.roots(%{}), {Store.Server, :handle_call, 3})
  end

  test "external_behaviours/1: the behaviours declared that the graph does not hold, once" do
    graph =
      model(
        [
          {App.Port, "domain", [], []},
          {App.Impl, "adapters", [{:run, 1}], behaviours: [App.Port, GenServer]},
          {App.Other, "adapters", [], behaviours: [GenServer, Supervisor]}
        ],
        []
      ).graph

    assert Roots.external_behaviours(graph) == [GenServer, Supervisor]
  end
end
