defmodule Anchor.Domain.Checks.AlphabetizedFunctionsDetectorTest do
  # DND-8063: AlphabetizedFunctions as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/alphabetized_functions-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.AlphabetizedFunctions
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def b(x), do: x\n  def a(x), do: x\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "alphabetized_functions", "pattern" => "*"}, %{"mode" => "all"})
      )
    ]

  test "its rule type is :alphabetized_functions" do
    assert AlphabetizedFunctions.rule_type() == :alphabetized_functions
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = AlphabetizedFunctions.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert AlphabetizedFunctions.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
