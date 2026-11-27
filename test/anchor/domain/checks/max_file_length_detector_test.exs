defmodule Anchor.Domain.Checks.MaxFileLengthDetectorTest do
  # DND-8063: MaxFileLength as an `Anchor.Domain.Detector`: its rule type, and detect/1
  # over a plain `%Detector.Input{}` finding what detect_violations finds.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/max_file_length-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks.MaxFileLength
  alias Anchor.Domain.Detector.Input

  @source "defmodule M do\n  def a, do: 1\n  def b, do: 2\nend"

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp lines(source),
    do: source |> String.split("\n") |> Enum.with_index(1) |> Enum.map(fn {l, i} -> {i, l} end)

  defp rules,
    do: [
      Config.parse_rule(
        Map.merge(%{"type" => "max_file_length", "pattern" => "*"}, %{"max_lines" => 1})
      )
    ]

  test "its rule type is :max_file_length" do
    assert MaxFileLength.rule_type() == :max_file_length
  end

  test "detect/1 finds what detect_violations finds, from the input's fields" do
    rules = rules()
    expected = MaxFileLength.detect_violations(lines(@source), rules, "lib/m.ex")

    assert expected != [], "control: the snippet violates the rule"

    assert MaxFileLength.detect(%Input{
             ast: ast(@source),
             rules: rules,
             lines: lines(@source),
             filename: "lib/m.ex"
           }) == expected
  end
end
