defmodule Anchor.Domain.Checks.CaseOnBareArgDetectorTest do
  # DND-8063: CaseOnBareArg as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/case_on_bare_arg-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.CaseOnBareArg
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def f(x) do\n    case x do\n      _ -> 1\n    end\n  end\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [Config.parse_rule(Map.merge(%{"type" => "case_on_bare_arg", "pattern" => "*"}, %{}))]

  test "its rule type is :case_on_bare_arg" do
    assert CaseOnBareArg.rule_type() == :case_on_bare_arg
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = CaseOnBareArg.detect_violations(ast(@source))

    assert expected != [], "control: the snippet violates the rule"
    assert CaseOnBareArg.detect(%Input{ast: ast(@source), rules: rules}) == expected
  end
end
