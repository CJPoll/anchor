defmodule Anchor.Domain.EnforcementTest do
  # DND-5441: a rule's findings judged against its baseline. Pure Domain over
  # hand-built findings.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5629 (a new rule id): ../../sabotage_records/baseline_rename-20261103-dnd_5441_graph_rules_a.md
  # Sabotage record (DND-5633): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Enforcement
  alias Anchor.Domain.GraphReport.Finding

  @path ".anchor/baselines/r.txt"

  defp rule(enforcement \\ :enforce),
    do: %{type: :layering, id: "r", index: 1, enforcement: enforcement}

  defp context(rule \\ rule(), ref \\ nil),
    do: %{rule: rule, label: ~s|rule 1 (id: "r", layering)|, path: @path, ref: ref}

  defp finding(key, enforcement \\ :enforce) do
    %Finding{
      rule_id: "r",
      type: :layering,
      label: ~s|rule 1 (id: "r", layering)|,
      enforcement: enforcement,
      key: key,
      file: "lib/a.ex",
      line: 3,
      message: "#{key} found. Fix: do not."
    }
  end

  describe "judge/4" do
    test "a covered finding is held; an uncovered one (NEW) stands" do
      {standing, held} =
        Enforcement.judge([finding("r|A|x"), finding("r|B|y")], ["r|A|x"], nil, context())

      assert Enum.map(held, & &1.key) == ["r|A|x"]
      assert Enum.map(standing, & &1.key) == ["r|B|y"]
    end

    test "an entry no finding consumes is a STALE finding on the baseline path" do
      {[stale], []} = Enforcement.judge([], ["r|Gone|x"], nil, context())

      assert stale.file == @path
      assert stale.key == "r|Gone|x"
      assert stale.enforcement == :enforce
      assert stale.rule_id == "r"
      assert stale.message =~ "r|Gone|x in #{@path} matches no finding"
    end

    test "a report rule's STALE entry is :report" do
      {[stale], []} = Enforcement.judge([], ["r|Gone|x"], nil, context(rule(:report)))
      assert stale.enforcement == :report
    end

    test "two findings with one key and one entry: one held, one stands (multiset)" do
      {standing, held} =
        Enforcement.judge([finding("r|A|x"), finding("r|A|x")], ["r|A|x"], nil, context())

      assert length(standing) == 1 and length(held) == 1
    end

    test "a finding with no key is never held" do
      {[%{key: nil}], []} = Enforcement.judge([finding(nil)], [], nil, context())
    end

    test "base entries: what the working file added is GREW, naming the ref" do
      {standing, _held} =
        Enforcement.judge(
          [finding("r|A|x"), finding("r|B|y")],
          ["r|A|x", "r|B|y"],
          {:ok, ["r|A|x"]},
          context(rule(), "main")
        )

      assert [grew] = Enum.filter(standing, &(&1.file == @path))
      assert grew.key == "r|B|y"
      assert grew.enforcement == :enforce
      assert grew.message =~ "r|B|y was added to #{@path} since main."
    end

    test "positive control for GREW: the same files with nothing added give none" do
      {standing, _held} =
        Enforcement.judge(
          [finding("r|A|x")],
          ["r|A|x"],
          {:ok, ["r|A|x"]},
          context(rule(), "main")
        )

      assert standing == []
    end

    test "a baseline absent at the ref is a report-only first-landing NOTE" do
      {[note], [_held]} =
        Enforcement.judge([finding("r|A|x")], ["r|A|x"], :absent, context(rule(), "main"))

      assert note.enforcement == :report
      assert note.file == @path
      assert note.message =~ "NOTE: first landing of #{@path} (absent at main)"
    end

    # DND-5629: a rule id new at the ref is a first landing named by the id,
    # with the ids that had a baseline there and are gone now, so a renamed id
    # (a remove plus an add) shows review both.
    test "a rule id new at the ref is a first landing naming it and the ids gone" do
      {[note], [_held]} =
        Enforcement.judge(
          [finding("r|A|x")],
          ["r|A|x"],
          {:new_rule, ["old_r"]},
          context(rule(), "main")
        )

      assert note.enforcement == :report
      assert note.file == @path

      assert note.message =~
               ~s|NOTE: first landing of rule "r": no rule with that id had a baseline at main|

      assert note.message =~
               ~s|rules with a baseline at main that this config no longer has: "old_r"|
    end

    # DND-5633: a cycle that lost a context changes its key; the narrower
    # entry replacing the removed one is a NOTE, not GREW.
    test "an added entry narrowing a removed one is a report NOTE, not GREW" do
      narrows = fn base_key, key -> {base_key, key} == {"r|A,B,C", "r|A,B"} end
      context = Map.put(context(rule(), "main"), :narrows, narrows)

      {[note], _held} =
        Enforcement.judge([finding("r|A,B")], ["r|A,B"], {:ok, ["r|A,B,C"]}, context)

      assert note.enforcement == :report
      assert note.file == @path
      assert note.message =~ "NOTE: r|A,B in #{@path} narrows r|A,B,C"

      # Positive control: the same files with no narrowing are GREW.
      {[grew], _held} =
        Enforcement.judge(
          [finding("r|A,B")],
          ["r|A,B"],
          {:ok, ["r|A,B,C"]},
          context(rule(), "main")
        )

      assert grew.enforcement == :enforce
      assert grew.message =~ "was added to"
    end

    test "a narrowing of an entry still there is GREW (it replaced nothing)" do
      narrows = fn _base_key, _key -> true end
      context = Map.put(context(rule(), "main"), :narrows, narrows)

      {standing, _held} =
        Enforcement.judge(
          [finding("r|A,B"), finding("r|A,B,C")],
          ["r|A,B", "r|A,B,C"],
          {:ok, ["r|A,B,C"]},
          context
        )

      assert [%{enforcement: :enforce, message: message}] = standing
      assert message =~ "r|A,B was added to"
    end

    test "a new rule id with nothing gone says so" do
      {[note], _held} =
        Enforcement.judge([], [], {:new_rule, []}, context(rule(), "main"))

      assert note.message =~ ~s|first landing of rule "r"|
      refute note.message =~ "no longer has"
    end
  end
end
