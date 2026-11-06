defmodule Anchor.Domain.GraphRules.FunctionPlacementTest do
  # Domain (ADR 002). DND-5448: rules 2 to 4 as violations, over hand-built models.
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.GraphRules.FunctionPlacement
  alias Anchor.Domain.Placement

  @rule %{type: :function_placement, id: "placed", bucket: "domain"}

  @modules [
    {W, "framework", [{:a, 0}], []},
    {Inv, "domain", [{:total, 1}], struct: [:x]},
    {Inv.Line, "domain", [], struct: [:y]},
    {Lease, "domain", [], struct: [:z]},
    {Fmt, "domain", [{:line, 1}], specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}},
    {Calc, "domain", [{:expired?, 1}],
     specs: %{{:expired?, 1} => "expired?(%Lease{}) :: boolean()"},
     clauses: %{{:expired?, 1} => ["def expired?(%Lease{} = l), do: l.z"]}},
    {Round, "domain", [{:r, 1}], []}
  ]

  @calls [
    {{W, :a, 0}, {Inv, :total, 1}},
    {{W, :a, 0}, {Fmt, :line, 1}},
    {{W, :a, 0}, {Calc, :expired?, 1}},
    {{Inv, :total, 1}, {Round, :r, 1}}
  ]

  setup do
    model = model(@modules, @calls)
    %{model: model, violations: FunctionPlacement.check(model, @rule)}
  end

  test "one violation per proposal, with the def's file and line", %{violations: violations} do
    assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
             {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
             {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
             {"Round.r/1", "lib/domain/Round.ex", 11}
           ]
  end

  test "each message ends with Fix: and exactly render(proposal)", %{
    model: model,
    violations: violations
  } do
    proposals = model |> Placement.build() |> Placement.proposals(model, :function_placement)

    assert length(proposals) == length(violations)

    for {violation, proposal} <- Enum.zip(violations, proposals) do
      assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))

      assert violation.key ==
               "placed|function|" <> (proposal.key |> String.split("|", parts: 3) |> List.last())
    end
  end

  test "the selector limits the subjects" do
    rule = %{type: :function_placement, id: "placed", paths: ["lib/domain/Fmt.ex"]}

    assert [%{trigger: "Fmt.line/1"}] = FunctionPlacement.check(model(@modules, @calls), rule)
  end

  test "selected modules of which no function can be judged: it checked nothing" do
    modules = [{Fmt, "domain", [{:line, 1}], interface: true}]

    assert [issue] = FunctionPlacement.check(model(modules, []), @rule)
    assert issue.kind == :fail_closed
    assert issue.message =~ "judged no function"
    # Positive control: the same module, no interface, is judged, with nothing to say.
    assert FunctionPlacement.check(model([{Fmt, "domain", [{:line, 1}], []}], []), @rule) == []
  end

  test "shape/1 and needs/0" do
    assert FunctionPlacement.shape(@rule) =~ "the struct it returns"
    assert :placement in FunctionPlacement.needs()
    refute FunctionPlacement.narrows?("a", "b")
  end
end
