defmodule Anchor.Domain.Checks.NoDiscardingArrowInWithDetectorTest do
  # DND-8063: NoDiscardingArrowInWith as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_discarding_arrow_in_with-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.NoDiscardingArrowInWith
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def f do\n    with _ <- g(), {:ok, y} <- h() do\n      y\n    end\n  end\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "no_discarding_arrow_in_with", "pattern" => "*"}, %{})
      )
    ]

  test "its rule type is :no_discarding_arrow_in_with" do
    assert NoDiscardingArrowInWith.rule_type() == :no_discarding_arrow_in_with
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = NoDiscardingArrowInWith.detect_violations(ast(@source))

    assert expected != [], "control: the snippet violates the rule"
    assert NoDiscardingArrowInWith.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
