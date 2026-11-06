defmodule Anchor.Domain.GraphRules.ReachableFromRootTest do
  # Domain (ADR 002). DND-5448: F5 over hand-built models.
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.GraphRules.ReachableFromRoot
  alias Anchor.Domain.Placement

  @rule %{type: :reachable_from_root, id: "reach", paths: ["lib/**"]}
  @root {W, "framework", [{:a, 0}], []}

  defp check(modules, calls), do: modules |> model(calls) |> ReachableFromRoot.check(@rule)

  test "an uncalled public function is one violation, and its Fix is the rendered proposal" do
    model =
      model([@root, {M, "domain", [{:dead, 0}, {:used, 0}], []}], [{{W, :a, 0}, {M, :used, 0}}])

    assert [violation] = ReachableFromRoot.check(model, @rule)

    assert [proposal] =
             model |> Placement.build() |> Placement.proposals(model, :reachable_from_root)

    assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
    assert violation.key == "reach|function|M.dead/0|delete"
    assert violation.filename == "lib/domain/M.ex"
    assert violation.line == 10
    assert violation.rule_id == "reach"
    assert violation.trigger == "M.dead/0"
    assert violation.kind == :rule
  end

  test "a called function passes" do
    assert check([@root, {M, "domain", [{:used, 0}], []}], [{{W, :a, 0}, {M, :used, 0}}]) == []
  end

  test "a captured function passes" do
    calls = [{{W, :a, 0}, {M, :used, 1}, :capture}]
    assert check([@root, {M, "domain", [{:used, 1}], []}], calls) == []
  end

  test "generated functions are not reported" do
    assert check([@root, {M, "domain", [{:dead, 0}], generated: true}], []) == []
  end

  test "lost precision fails closed, naming the site, with no finding" do
    modules = [@root, {M, "domain", [{:dead, 0}], []}]

    assert [issue] = check(modules, [{{W, :a, 0}, {:dynamic, nil, 2, :call}, :apply}])
    assert issue.kind == :fail_closed
    assert issue.message =~ "reachability is imprecise: lib/framework/W.ex:7 calls an unknown"
    assert issue.message =~ "Fix:"
    # Positive control: the same model, no computed name, reports the dead function.
    assert [%{kind: :rule}] = check(modules, [])
  end

  test "no roots fails closed" do
    assert [issue] = check([{M, "domain", [{:dead, 0}], []}], [])
    assert issue.kind == :fail_closed
    assert issue.message =~ "no roots"
    assert issue.filename == ".anchor.yml"
  end

  test "selected modules with no authored public function: it checked nothing" do
    rule = %{type: :reachable_from_root, id: "reach", paths: ["lib/domain/**"]}
    model = model([@root, {M, "domain", [{:__struct__, 0}], []}], [])

    assert [issue] = ReachableFromRoot.check(model, rule)
    assert issue.kind == :fail_closed
    assert issue.message =~ "judged no function"
  end

  test "the selector limits the subjects" do
    rule = %{type: :reachable_from_root, id: "reach", paths: ["lib/domain/M.ex"]}
    model = model([@root, {M, "domain", [{:dead, 0}], []}, {N, "domain", [{:dead, 0}], []}], [])

    assert [%{trigger: "M.dead/0"}] = ReachableFromRoot.check(model, rule)
  end

  test "shape/1 and needs/0" do
    assert ReachableFromRoot.shape(@rule) =~ "reachable from a root"
    assert :placement in ReachableFromRoot.needs()
    refute ReachableFromRoot.narrows?("a", "b")
  end
end
