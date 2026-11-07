defmodule Anchor.Domain.GraphRules.ModuleOneComponentTest do
  # Domain (ADR 002). DND-5463: module split proposals as violations, over hand-built
  # models (Anchor.Test.PlacementModels).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  # and ../../../sabotage_records/placement-20261107-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.GraphRules.ModuleOneComponent
  alias Anchor.Domain.Placement

  @rule %{type: :module_one_component, id: "one", paths: ["lib/**/*.ex"]}

  @modules [
    {W, "framework", [{:run, 0}], []},
    {M, "domain", [{:a, 0}, {:b, 0}, {:p, 0, :defp}], []},
    {N, "domain", [{:c, 0}, {:d, 0}], []}
  ]

  @calls [
    {{W, :run, 0}, {M, :a, 0}},
    {{W, :run, 0}, {M, :b, 0}},
    {{W, :run, 0}, {N, :c, 0}},
    {{M, :a, 0}, {M, :p, 0}, :local},
    {{M, :b, 0}, {M, :p, 0}, :local},
    {{N, :c, 0}, {N, :d, 0}, :local}
  ]

  test "one violation per proposal: a split at the module, a shared helper at the function" do
    model = model(@modules, @calls)
    violations = ModuleOneComponent.check(model, @rule)
    proposals = model |> Placement.build() |> Placement.proposals(model, :module_one_component)

    assert Enum.map(violations, &{&1.trigger, &1.filename, &1.key}) == [
             {"M.p/0", "lib/domain/M.ex", "one|function|M.p/0|M.P"},
             {"M", "lib/domain/M.ex", "one|module|M|a/0;b/0"}
           ]

    for {violation, proposal} <- Enum.zip(violations, proposals) do
      assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
    end

    assert Enum.map(violations, & &1.message) == [
             "M.p/0 is a private helper of 2 unrelated groups of M. Fix: extract M.p/0 into " <>
               "M.P (2 unrelated groups of M call it: component a/0; component b/0)",
             "M holds 2 unrelated groups of public functions. Fix: split M into M: M.a/0 | " <>
               "M.B: M.b/0; no owned type: rename M.B (no call, own-struct use or behaviour " <>
               "links these 2 groups of public functions)"
           ]
  end

  test "the selector limits the subjects" do
    model = model(@modules, @calls)
    assert ModuleOneComponent.check(model, %{@rule | paths: ["lib/framework/*.ex"]}) == []
    assert length(ModuleOneComponent.check(model, %{@rule | paths: ["lib/domain/M.ex"]})) == 2
  end

  test "shape/1, needs/0 and narrows?/2" do
    assert ModuleOneComponent.shape(@rule) =~ "one causal component"
    assert :placement in ModuleOneComponent.needs()
    refute ModuleOneComponent.narrows?("a", "b")
  end
end
