defmodule Anchor.Domain.Checks.StructGetterConventionDetectorTest do
  # DND-8063: StructGetterConvention as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/struct_getter_convention-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.StructGetterConvention
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  defstruct [:name]\n  def get_name(%__MODULE__{name: n}), do: n\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(Map.merge(%{"type" => "struct_getter_convention", "pattern" => "*"}, %{}))
    ]

  test "its rule type is :struct_getter_convention" do
    assert StructGetterConvention.rule_type() == :struct_getter_convention
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = StructGetterConvention.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert StructGetterConvention.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
