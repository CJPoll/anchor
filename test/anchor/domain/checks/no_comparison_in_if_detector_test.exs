defmodule Anchor.Domain.Checks.NoComparisonInIfDetectorTest do
  # DND-8063: NoComparisonInIf as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_comparison_in_if-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.NoComparisonInIf
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def f(a), do: if(a == 1, do: 1, else: 2)\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [Config.parse_rule(Map.merge(%{"type" => "no_comparison_in_if", "pattern" => "*"}, %{}))]

  test "its rule type is :no_comparison_in_if" do
    assert NoComparisonInIf.rule_type() == :no_comparison_in_if
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = NoComparisonInIf.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert NoComparisonInIf.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
