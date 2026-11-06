defmodule Anchor.Domain.Placement.TieBreakTest do
  # Domain (ADR 002). DND-5462: the tie-break seam's no-evidence clause.
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Placement.TieBreak

  test "no evidence keeps the bucket root, and says it had none" do
    assert TieBreak.choose(["lib/b/domain", "lib/b/domain/d1", "lib/b/domain/d2"], nil) ==
             {:none, "lib/b/domain"}
  end

  test "evidence it cannot read yet is refused, never ignored" do
    assert_raise FunctionClauseError, fn ->
      # Through apply/3: the type checker would refuse the literal call at compile time.
      apply(TieBreak, :choose, [["lib/b/domain"], %{}])
    end
  end
end
