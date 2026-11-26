defmodule Anchor.Domain.Checks.MustUseModuleDetectorTest do
  # DND-8063: MustUseModule as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/must_use_module-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.MustUseModule
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "must_use_module", "pattern" => "*"}, %{
          "required_modules" => ["MyApp.Base"]
        })
      )
    ]

  test "its rule type is :must_use_module" do
    assert MustUseModule.rule_type() == :must_use_module
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = MustUseModule.detect_violations(ast(@source), rules)

    assert expected != [], "control: the snippet violates the rule"
    assert MustUseModule.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
