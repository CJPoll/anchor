defmodule Anchor.Domain.Graph.BeamTest do
  # DND-5584: which apps of a run gave no module. Pure Domain.
  #
  # Sabotage record: ../../../sabotage_records/graph_runner-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.Beam

  @apps [{:a, "ebin/a"}, {:b, "ebin/b"}, {:c, "ebin/c"}]

  defp beam(app), do: %Beam{module: Module.concat([app, X]), app: app, path: "ebin/#{app}/x.beam"}
  defp error(path), do: {:error, %{path: path, module: nil, reason: :no_debug_info}}

  describe "apps_without_modules/2" do
    test "an app with no beam is listed, in apps order; an app with one is not" do
      assert Beam.apps_without_modules(@apps, [beam(:b)]) == [{:a, "ebin/a"}, {:c, "ebin/c"}]
    end

    test "an app whose every beam failed to decode read no module" do
      assert Beam.apps_without_modules(@apps, [beam(:a), beam(:c), error("ebin/b/y.beam")]) ==
               [{:b, "ebin/b"}]
    end

    test "positive control: every app read a module, none listed" do
      assert Beam.apps_without_modules(@apps, Enum.map([:a, :b, :c], &beam/1)) == []
    end
  end
end
