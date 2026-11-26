defmodule Anchor.Domain.Checks.ModulePatternRestrictionsDetectorTest do
  # DND-8063: ModulePatternRestrictions as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/module_pattern_restrictions-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.ModulePatternRestrictions
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def other, do: 1\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "module_pattern_restrictions", "pattern" => "*"}, %{
          "allowed_functions" => ["new"]
        })
      )
    ]

  test "its rule type is :module_pattern_restrictions" do
    assert ModulePatternRestrictions.rule_type() == :module_pattern_restrictions
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = ModulePatternRestrictions.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert ModulePatternRestrictions.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
