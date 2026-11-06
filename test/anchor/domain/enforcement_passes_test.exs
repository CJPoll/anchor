defmodule Anchor.Domain.EnforcementPassesTest do
  # DND-5631: one file's enforced and report detection passes, joined so a
  # violation both found is printed once.
  #
  # Sabotage record: ../../sabotage_records/lint-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5632): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5631, PA-E): ../../sabotage_records/failures-20261103-dnd_5648_graph_followups.md
  # Sabotage record (one finding, two Fix: texts): ../../sabotage_records/enforcement_passes-20261106-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.EnforcementPasses
  alias Anchor.Domain.Violation

  defp v(message, extra \\ %{}),
    do: struct!(Violation, Map.merge(%{message: message, line: 3, trigger: "alias"}, extra))

  describe "merge/2" do
    test "a violation both passes found is one, enforced, naming both modes" do
      enforced = [v("cannot resolve. Fix: name it")]
      reported = [v("cannot resolve. Fix: name it", %{enforcement: :report})]

      assert [%Violation{enforcement: :enforce, message: message}] =
               EnforcementPasses.merge(enforced, reported)

      assert message ==
               "cannot resolve. (Found under rules in enforcement: enforce and report; " <>
                 "reported once, enforced.) Fix: name it"
    end

    test "two rules' copies differing only in their Fix: are one finding, the enforced one's" do
      enforced = [v("cannot resolve. Fix: enforced rule's shape")]
      reported = [v("cannot resolve. Fix: report rule's shape", %{enforcement: :report})]

      assert [%Violation{enforcement: :enforce, message: message}] =
               EnforcementPasses.merge(enforced, reported)

      assert message ==
               "cannot resolve. (Found under rules in enforcement: enforce and report; " <>
                 "reported once, enforced.) Fix: enforced rule's shape"
    end

    test "violations only one pass found are kept, unchanged, enforced first" do
      enforced = [v("a", %{trigger: "A"})]
      reported = [v("b", %{trigger: "B", enforcement: :report})]

      assert EnforcementPasses.merge(enforced, reported) == enforced ++ reported
    end

    test "the same message on another line is another violation" do
      enforced = [v("x")]
      reported = [v("x", %{line: 4, enforcement: :report})]

      assert [%{line: 3, message: "x"}, %{line: 4, enforcement: :report}] =
               EnforcementPasses.merge(enforced, reported)
    end

    test "a message with no Fix: gets the note at its end" do
      assert [%{message: "x (Found under rules in enforcement: enforce and report; " <> _}] =
               EnforcementPasses.merge([v("x")], [v("x", %{enforcement: :report})])
    end

    test "empty passes give nothing" do
      assert EnforcementPasses.merge([], []) == []
    end
  end

  describe "unique/1 (DND-5632)" do
    # Whole-MR critic: merge/2's note is not part of what the finding is.
    test "a copy naming both modes is the same finding as one that does not" do
      [merged] =
        EnforcementPasses.merge([v("a Fix: b")], [v("a Fix: b", %{enforcement: :report})])

      keyed = v("a Fix: b", %{key: "pure|lib/a.ex|alias", rule_id: "pure"})

      assert merged.message != keyed.message
      assert EnforcementPasses.unique([merged, keyed]) == [keyed]
    end

    test "a different message is a different finding, note or no note" do
      [merged] = EnforcementPasses.merge([v("a")], [v("a", %{enforcement: :report})])
      other = v("c", %{key: "pure|lib/a.ex|alias", rule_id: "pure"})

      assert EnforcementPasses.unique([merged, other]) == [merged, other]
    end

    test "one copy per finding, in first-seen order" do
      assert [%Violation{trigger: "A"}, %Violation{trigger: "B"}] =
               EnforcementPasses.unique([
                 v("a", %{trigger: "A"}),
                 v("b", %{trigger: "B"}),
                 v("a", %{trigger: "A"})
               ])
    end

    test "the enforced copy wins over a report copy seen first" do
      reported = v("a", %{enforcement: :report})
      enforced = v("a", %{key: "pure|lib/a.ex|alias", rule_id: "pure"})

      assert [%Violation{enforcement: :enforce, key: "pure|lib/a.ex|alias"}] =
               EnforcementPasses.unique([reported, enforced])
    end

    test "a keyed copy is kept over an unkeyed one of the same enforcement (its key is written)" do
      plain = v("a", %{enforcement: :report})
      keyed = v("a", %{enforcement: :report, key: "pure|lib/a.ex|alias", rule_id: "pure"})

      assert [%Violation{key: "pure|lib/a.ex|alias"}] = EnforcementPasses.unique([plain, keyed])
    end

    test "two baselined rules' keyed copies are both kept" do
      a = v("a", %{key: "pure|lib/a.ex|alias", rule_id: "pure"})
      b = v("a", %{key: "other|lib/a.ex|alias", rule_id: "other"})

      assert EnforcementPasses.unique([a, b]) == [a, b]
    end

    test "an enforced unkeyed copy is kept beside a report keyed copy" do
      plain = v("a")
      keyed = v("a", %{enforcement: :report, key: "pure|lib/a.ex|alias", rule_id: "pure"})

      assert EnforcementPasses.unique([plain, keyed]) == [plain, keyed]
    end

    test "two report copies stay one report copy" do
      reported = v("a", %{enforcement: :report})
      assert [%Violation{enforcement: :report}] = EnforcementPasses.unique([reported, reported])
    end

    test "positive control: different findings are all kept" do
      vs = [v("a"), v("a", %{line: 4}), v("a", %{trigger: "x"}), v("a", %{kind: :fail_closed})]
      assert EnforcementPasses.unique(vs) == vs
    end
  end
end
