defmodule Anchor.Domain.Checks.StructOwnedByModuleDetectorTest do
  # DND-8063: StructOwnedByModule as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/struct_owned_by_module-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.StructOwnedByModule
  alias Anchor.Domain.Detector.Input

  @source "defmodule A do\n  def f, do: %B{x: 1}\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(Map.merge(%{"type" => "struct_owned_by_module", "pattern" => "*"}, %{}))
    ]

  test "its rule type is :struct_owned_by_module" do
    assert StructOwnedByModule.rule_type() == :struct_owned_by_module
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = StructOwnedByModule.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert StructOwnedByModule.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
