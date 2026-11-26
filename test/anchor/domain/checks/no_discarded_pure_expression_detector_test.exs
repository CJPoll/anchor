defmodule Anchor.Domain.Checks.NoDiscardedPureExpressionDetectorTest do
  # DND-8063: NoDiscardedPureExpression as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_discarded_pure_expression-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.NoDiscardedPureExpression
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def f(x) do\n    String.upcase(x)\n    :ok\n  end\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "no_discarded_pure_expression", "pattern" => "*"}, %{})
      )
    ]

  test "its rule type is :no_discarded_pure_expression" do
    assert NoDiscardedPureExpression.rule_type() == :no_discarded_pure_expression
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = NoDiscardedPureExpression.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert NoDiscardedPureExpression.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
