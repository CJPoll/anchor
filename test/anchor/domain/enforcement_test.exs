defmodule Anchor.Domain.EnforcementTest do
  # DND-5441: a rule's findings judged against its baseline. Pure Domain over
  # hand-built findings.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
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
  end
end
