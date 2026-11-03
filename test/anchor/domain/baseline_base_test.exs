defmodule Anchor.Domain.BaselineBaseTest do
  # DND-5629: under --base REF a rule's baseline is found at REF by the rule's
  # id in the base config, never by the branch's path, so renaming the
  # `baseline:` path cannot turn every entry into a first landing. Pure Domain
  # over hand-built rule maps.
  #
  # Sabotage record: ../../sabotage_records/baseline_rename-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.BaselineBase

  @old ".anchor/baselines/old.txt"
  @new ".anchor/baselines/new.txt"

  defp rule(id, baseline), do: %{type: :layering, id: id, baseline: baseline}

  describe "locate/2" do
    test "a rule whose baseline path was renamed is found at its path at the ref" do
      assert BaselineBase.locate([rule("r", @old)], "r") == {:path, @old}
    end

    test "positive control: an unrenamed path is found at the same path" do
      assert BaselineBase.locate([rule("r", @new)], "r") == {:path, @new}
    end

    test "a rule id with no baseline at the ref compares with an empty one" do
      assert BaselineBase.locate([%{type: :layering, id: "r"}], "r") == :no_baseline
    end

    test "a rule id absent at the ref is a new rule" do
      assert BaselineBase.locate([rule("other", @old)], "r") == :new_rule
    end

    test "no config at the ref: every rule is new" do
      assert BaselineBase.locate(:absent, "r") == :new_rule
    end

    test "the id decides, never the path: another rule's file at the same path is not it" do
      assert BaselineBase.locate([rule("other", @new), rule("r", @old)], "r") == {:path, @old}
    end
  end

  describe "gone/2" do
    test "the ids that had a baseline at the ref and are not rules now, sorted" do
      base = [
        rule("b", @old),
        rule("a", "x.txt"),
        rule("kept", @new),
        %{type: :layering, id: "c"}
      ]

      assert BaselineBase.gone(base, [rule("kept", @new), rule("renamed", @old)]) == ["a", "b"]
    end

    test "nothing is gone when there was no config at the ref" do
      assert BaselineBase.gone(:absent, [rule("r", @new)]) == []
    end
  end
end
