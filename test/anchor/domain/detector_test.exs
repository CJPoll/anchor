defmodule Anchor.Domain.DetectorTest do
  # Domain (ADR 002). DND-8063: the contract a check's detection runs through,
  # and run/3, the detection every caller shares (enforcement split, crash
  # guard). Each Credo check's own detector is held by anchor_test.exs (every
  # check names one and exports no detection) and by each check's tests.
  #
  # Sabotage record: ../../sabotage_records/detector-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Detector
  alias Anchor.Domain.Detector.Input
  alias Anchor.Domain.Violation

  defmodule Echo do
    @moduledoc false
    use Anchor.Domain.Detector

    @impl Anchor.Domain.Detector
    def rule_type, do: :echo

    # One violation per rule, its trigger the rule's id; raises or throws on
    # a rule asking for it.
    @impl Anchor.Domain.Detector
    def detect(%Input{rules: rules}) do
      Enum.map(rules, fn
        %{id: "raise"} -> raise ArgumentError, "detector raised"
        %{id: "throw"} -> throw(:detector_threw)
        rule -> %Violation{message: "found", line: 1, trigger: rule.id}
      end)
    end
  end

  defmodule Needy do
    @moduledoc false
    use Anchor.Domain.Detector

    @impl Anchor.Domain.Detector
    def rule_type, do: :needy

    @impl Anchor.Domain.Detector
    def needs_module_graph?, do: true

    @impl Anchor.Domain.Detector
    def needs_lines?, do: true

    @impl Anchor.Domain.Detector
    def detect(%Input{}), do: []
  end

  # Reports one violation whatever its rules, and raises on a rule asking
  # for it: what a detector that reads no key of its rules does.
  defmodule Always do
    @moduledoc false
    use Anchor.Domain.Detector

    @impl Anchor.Domain.Detector
    def rule_type, do: :always

    @impl Anchor.Domain.Detector
    def detect(%Input{rules: rules}) do
      if Enum.any?(rules, &(&1[:id] == "raise")), do: raise(ArgumentError, "always raised")
      [%Violation{message: "found", line: 1, trigger: "always"}]
    end
  end

  defp input(rules), do: %Input{ast: nil, rules: rules, filename: "lib/a.ex"}

  describe "the contract" do
    test "D1: rule_type, and the needs a detector declares (both default false)" do
      assert Detector.rule_type(Echo) == :echo
      refute Detector.needs_module_graph?(Echo)
      refute Detector.needs_lines?(Echo)
      assert Detector.needs_module_graph?(Needy)
      assert Detector.needs_lines?(Needy)
    end

    test "D2: every Credo check's detector implements it, and the check exports no detection" do
      for check <- Anchor.checks() do
        detector = check.__anchor_detector__()

        assert Detector in Keyword.get(detector.__info__(:attributes), :behaviour, []),
               inspect(check)

        assert is_atom(Detector.rule_type(detector))
        refute function_exported?(check, :rule_type, 0), inspect(check)
      end
    end
  end

  describe "run/3" do
    test "R1: with no report rule, one detection over every rule, enforced" do
      rules = [%{id: "a"}, %{id: "b"}]

      assert [
               %Violation{trigger: "a", enforcement: :enforce},
               %Violation{trigger: "b", enforcement: :enforce}
             ] =
               Detector.run(Echo, input(rules), Echo)
    end

    test "R2: a report rule's findings are marked report; enforced ones are not" do
      rules = [%{id: "e"}, %{id: "r", enforcement: :report}]

      assert Enum.map(Detector.run(Echo, input(rules), Echo), &{&1.trigger, &1.enforcement}) ==
               [{"e", :enforce}, {"r", :report}]
    end

    test "R3: only report rules: no enforced pass runs, the findings are report" do
      assert [%Violation{trigger: "r", enforcement: :report}] =
               Detector.run(Echo, input([%{id: "r", enforcement: :report}]), Echo)
    end

    test "R5: with no report rule a detector is run once, its findings untouched" do
      assert [%Violation{message: "found", trigger: "always", enforcement: :enforce}] =
               Detector.run(Always, input([%{id: "e"}]), Always)
    end

    test "R6: with only report rules no enforced pass runs, even for a detector that ignores rules" do
      assert [%Violation{trigger: "always", enforcement: :report}] =
               Detector.run(Always, input([%{id: "r", enforcement: :report}]), Always)
    end

    test "R7: a crash in the report pass stays fail-closed and enforced" do
      assert [%Violation{kind: :fail_closed, enforcement: :enforce}] =
               Detector.run(Always, input([%{id: "raise", enforcement: :report}]), Always)
    end

    test "R4: a raise or a throw is one fail-closed violation naming the check, never escaping" do
      for {id, text} <- [
            {"raise", "ArgumentError: detector raised"},
            {"throw", "throw: :detector_threw"}
          ] do
        assert [%Violation{kind: :fail_closed, trigger: trigger, message: message}] =
                 Detector.run(Echo, input([%{id: id}]), Anchor.Check.SomeCheck)

        assert trigger == "Anchor.Check.SomeCheck"
        assert message =~ text, message
      end
    end
  end
end
