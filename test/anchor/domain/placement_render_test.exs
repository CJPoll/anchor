defmodule Anchor.Domain.PlacementRenderTest do
  # Domain (ADR 002). DND-5448: render/1 has one clause per reason, and an unknown
  # reason raises; a key has no line number.
  #
  # Sabotage record: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Placement
  alias Anchor.Domain.Proposal

  defp proposal(reason, proposed, evidence \\ []) do
    %Proposal{
      level: :function,
      subject: {F, :line, 1},
      current: F,
      proposed: proposed,
      rule: :function_placement,
      reason: reason,
      evidence: evidence
    }
  end

  test "output owner text" do
    assert Placement.render(proposal(:output_type_owner, Inv.Line)) ==
             "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its " <>
               "transitions)"
  end

  test "input owner text" do
    assert Placement.render(proposal(:input_type_owner, Lease)) ==
             "move F.line/1 to Lease (its result is computed from %Lease{})"
  end

  test "dominated text" do
    assert Placement.render(proposal(:dominated_by, Inv)) ==
             "move F.line/1 into Inv as a private function (only Inv calls it)"
  end

  test "unreachable text starts delete and names the alternative" do
    assert Placement.render(proposal(:unreachable, :delete)) ==
             "delete F.line/1 (no root reaches it), or add the root that should call it"
  end

  test "bucket text names the context and module when known, and the evidence" do
    assert Placement.render(
             proposal(:bucket_from_effects, {:bucket, :managers, "App.B", App.B.Inv}, ["a -> b"])
           ) == "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"

    assert Placement.render(proposal(:bucket_from_effects, {:bucket, :domain, nil, nil}, ["x"])) ==
             "move F.line/1 to the domain bucket: x"
  end

  test "an unknown reason raises: there is no default text" do
    assert_raise FunctionClauseError, fn -> Placement.render(proposal(:nope, F)) end
  end

  test "the key has no line number and is stable when lines shift" do
    build = fn line ->
      model =
        model(
          [
            {W, "framework", [{:run, 1}], []},
            {Round, "domain", [{:r, 1}], []},
            {Inv, "domain", [{:total, 1}], []}
          ],
          [{{W, :run, 1}, {Inv, :total, 1}}, {{Inv, :total, 1}, {Round, :r, 1}}]
        )

      model = put_in(model.graph.modules[Round].functions[{:r, 1}].line, line)
      model |> Placement.build() |> Placement.proposals(model, :function) |> Enum.map(& &1.key)
    end

    assert build.(10) == build.(500)
    assert build.(10) == ["function_placement|function|Round.r/1|Inv"]
  end
end
