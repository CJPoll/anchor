defmodule Anchor.CoverageMapWorkflowTest do
  # DND-5652: the Coverage map workflow runs on every pull request, with no
  # paths filter, and still publishes on push to main.
  # Sabotage record: ../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  use ExUnit.Case, async: true

  @workflow ".github/workflows/coverage-map.yml"

  defp on_block do
    [block] =
      Regex.run(~r/^on:\n((?:[ #].*\n|\n)*)/m, File.read!(@workflow), capture: :all_but_first)

    block
  end

  test "W1: on every pull request, with no paths filter" do
    assert on_block() =~ ~r/^  pull_request:\s*$/m
    refute on_block() =~ "paths"
  end

  test "W2: positive control: still on push to main, where the map is published" do
    assert on_block() =~ ~r/^  push:\n    branches:\n      - main$/m
  end

  test "W3: a pull request's run never uploads its map (built from unmerged code)" do
    text = File.read!(@workflow)
    [upload] = Regex.run(~r/- name: Upload the map\n(?:\s+.*\n)*?\s+uses:/, text)
    assert upload =~ "if: github.event_name != 'pull_request'"
  end
end
