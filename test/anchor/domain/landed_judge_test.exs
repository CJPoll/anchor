defmodule Anchor.Domain.LandedJudgeTest do
  # DND-5658: what the landed judge decides about a change's rules beyond the
  # ratchet. Pure Domain over hand-built rule maps.
  #
  # Sabotage record: ../../sabotage_records/landed_judge-20261103-dnd_5658_ci_base_ratchet.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.LandedJudge

  @config ".anchor.yml"
  @ref "origin/main"

  defp rule(id, type), do: %{id: id, type: type}
  defp deferred(id, type), do: %{index: 3, id: id, type: type, baseline: nil}

  defp judge(base, rules, set_aside \\ []),
    do: LandedJudge.judge(base, rules, set_aside, @config, @ref)

  test "positive control: the base's rules, unchanged, give no failure and no note" do
    base = [rule("layering", :layering), rule("acyclic", :context_acyclic)]
    assert judge(base, base) == {[], []}
  end

  test "a base rule the change removes fails, naming it" do
    {[failure], []} = judge([rule("layering", :layering)], [])

    assert failure.message =~
             ~s|rule "layering" (layering) is in .anchor.yml at origin/main and not in this change|
  end

  test "a base rule renamed is a removal (the new id is not a base rule)" do
    {[failure], []} = judge([rule("layering", :layering)], [rule("layers", :layering)])
    assert failure.message =~ ~s|rule "layering" (layering) is in .anchor.yml|
  end

  test "a base rule retyped to a type the judge knows fails" do
    {[failure], []} = judge([rule("layering", :layering)], [rule("layering", :context_acyclic)])

    assert failure.message =~
             ~s|rule "layering" is layering in .anchor.yml at origin/main and context_acyclic|
  end

  test "a base rule retyped to a type the judge set aside fails, and is no first landing" do
    {[failure], []} = judge([rule("layering", :layering)], [], [deferred("layering", "new_type")])

    assert failure.message =~
             ~s|rule "layering" is layering in .anchor.yml at origin/main and new_type|
  end

  test "a set-aside rule new in the change is a FIRST LANDING note" do
    {[], [note]} =
      judge([rule("layering", :layering)], [rule("layering", :layering)], [
        deferred("fresh", "new_type")
      ])

    assert note.message =~
             ~s|NOTE: FIRST LANDING of rule 3 (id: "fresh", new_type): the anchor landed on origin/main has no rule type "new_type"|
  end

  test "with no base config to compare, every set-aside rule is a note and nothing fails" do
    for base <- [nil, :absent] do
      assert {[], [_note]} = judge(base, [], [deferred(nil, "new_type")])
    end
  end

  test "a base rule with no id is not followed" do
    assert judge([%{type: :layering}], []) == {[], []}
  end

  describe "rules/2: what the landed judge runs" do
    @base %{id: "layering", type: :layering, bucket: "domain", enforcement: :enforce, index: 1}

    test "a base rule the change narrows or downgrades runs as the base defines it" do
      narrowed = %{@base | bucket: "nothing", enforcement: :report, index: 4}
      assert LandedJudge.rules([@base], [narrowed]) == [@base]
    end

    test "positive control: a rule whose id the base lacks is added after the base's" do
      fresh = %{id: "fresh", type: :layering, bucket: "domain", index: 2}
      assert LandedJudge.rules([@base], [@base, fresh]) == [@base, fresh]
    end

    test "an id-less rule runs once when the base has it as written, and is added when new" do
      base = %{type: :context_acyclic, paths: ["lib/**/*.ex"], index: 3}
      same = %{base | index: 7}
      new = %{base | paths: ["lib/web/**/*.ex"], index: 8}
      assert LandedJudge.rules([base], [same, new]) == [base, new]
    end
  end
end
