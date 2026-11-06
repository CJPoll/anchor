defmodule Anchor.Domain.ViolationTest do
  # Domain data type: a violation is `{line, trigger, message}`, free of any
  # Credo type. `Anchor.Check.Base` is what maps it to a `Credo.Issue`.
  #
  # Sabotage record (FX-C): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Violation

  describe "struct" do
    test "carries line, trigger, and message" do
      violation = %Violation{line: 12, trigger: "MyApp.Repo", message: "forbidden"}

      assert violation.line == 12
      assert violation.trigger == "MyApp.Repo"
      assert violation.message == "forbidden"
    end

    test "line and trigger are optional (default nil); message is required" do
      violation = %Violation{message: "something"}

      assert violation.line == nil
      assert violation.trigger == nil
      assert violation.message == "something"
    end

    test "building without the required :message key raises" do
      assert_raise ArgumentError, fn ->
        # `struct!/2` enforces @enforce_keys; wrapped so the missing-key raise is
        # asserted rather than a compile-time error.
        struct!(Violation, line: 1)
      end
    end
  end

  # The anchor.graph review (struct_owned_by_module_flow): a violation's
  # enforcement is changed by its own module, never by a map update elsewhere.
  describe "with_enforcement/2" do
    test "sets the enforcement and keeps every other field" do
      violation = %Violation{line: 3, trigger: "t", message: "m", key: "k", rule_id: "r"}
      reported = Violation.with_enforcement(violation, :report)

      assert reported.enforcement == :report
      assert %{reported | enforcement: violation.enforcement} == violation
    end
  end
end
