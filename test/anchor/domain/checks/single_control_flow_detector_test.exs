defmodule Anchor.Domain.Checks.SingleControlFlowDetectorTest do
  # DND-8063: SingleControlFlow as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/single_control_flow-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.SingleControlFlow
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def f(x) do\n    if x, do: 1\n    case x do\n      _ -> 2\n    end\n  end\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [Config.parse_rule(Map.merge(%{"type" => "single_control_flow", "pattern" => "*"}, %{}))]

  test "its rule type is :single_control_flow" do
    assert SingleControlFlow.rule_type() == :single_control_flow
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = SingleControlFlow.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert SingleControlFlow.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
