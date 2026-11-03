defmodule Anchor.Domain.EnforcementPassesTest do
  # DND-5631: one file's enforced and report detection passes, joined so a
  # violation both found is printed once.
  #
  # Sabotage record: ../../sabotage_records/lint-20261103-dnd_5648_graph_followups.md
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
end
