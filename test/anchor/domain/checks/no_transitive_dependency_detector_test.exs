defmodule Anchor.Domain.Checks.NoTransitiveDependencyDetectorTest do
  # DND-8063: NoTransitiveDependency as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_transitive_dependency-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.NoTransitiveDependency
  alias Anchor.Domain.Detector.Input

  @source "defmodule A do\n  def f, do: B.call()\nend"

  @graph %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [MyApp.Repo]}}

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "no_transitive_dependency", "pattern" => "*"}, %{
          "forbidden_modules" => ["MyApp.Repo"]
        })
      )
    ]

  test "its rule type is :no_transitive_dependency" do
    assert NoTransitiveDependency.rule_type() == :no_transitive_dependency
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = NoTransitiveDependency.detect_violations(ast(@source), rules, @graph)

    assert expected != [], "control: the snippet violates the rule"

    assert NoTransitiveDependency.detect(%Input{
             ast: ast(@source),
             rules: rules,
             modules_map: @graph
           }) == expected
  end
end
