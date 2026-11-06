defmodule Anchor.Domain.ConfigDeferredTest do
  # DND-5658: `Anchor.Config.parse_config/2` with `defer_unknown_types: true`,
  # the load the landed judge (`mix anchor.graph --project`) uses. A rule type
  # the judge does not know is set aside, not refused; every other refusal
  # stands. Pure Domain over decoded YAML maps.
  #
  # Sabotage record: ../../sabotage_records/landed_judge-20261103-dnd_5658_ci_base_ratchet.md
  use ExUnit.Case, async: true

  alias Anchor.Config

  @known %{
    "type" => "no_direct_dependency",
    "paths" => ["lib/web/**/*.ex"],
    "forbidden_modules" => ["MyApp.Repo"]
  }

  @unknown %{
    "type" => "brand_new_graph_rule",
    "id" => "fresh",
    "bucket" => "domain",
    "baseline" => ".anchor/baselines/fresh.txt"
  }

  defp defer(data), do: Config.parse_config(data, defer_unknown_types: true)

  describe "judged/3" do
    test "every section is the base's; only the path and the set-aside rules are the change's" do
      change = %Config{
        rules: [:change],
        path: "change.yml",
        architecture: :change,
        aggregates: :change,
        sabotage: :change,
        deferred: [:set_aside]
      }

      base = %Config{
        rules: [:base],
        path: "base.yml",
        architecture: :base,
        aggregates: :base,
        sabotage: :base,
        deferred: []
      }

      assert Config.judged(change, base, [:merged]) == %Config{
               rules: [:merged],
               path: "change.yml",
               architecture: :base,
               aggregates: :base,
               sabotage: :base,
               deferred: [:set_aside]
             }
    end
  end

  test "an unknown rule type is set aside with its position, id, type and baseline" do
    assert %Config{rules: [rule], deferred: [deferred]} =
             defer(%{"rules" => [@unknown, @known]})

    assert deferred == %{
             index: 1,
             id: "fresh",
             type: "brand_new_graph_rule",
             baseline: ".anchor/baselines/fresh.txt"
           }

    assert rule.type == :no_direct_dependency
    assert rule.index == 2
  end

  test "a set-aside rule with no id or baseline keeps nil for both" do
    assert %Config{deferred: [%{index: 1, id: nil, type: "other_new_rule", baseline: nil}]} =
             defer(%{"rules" => [%{"type" => ":other_new_rule"}]})
  end

  test "positive control: without the option an unknown rule type is still refused" do
    assert {:error, {:invalid_rule, reason}} = Config.parse_config(%{"rules" => [@unknown]})
    assert reason =~ ~s(unknown rule type "brand_new_graph_rule")
  end

  test "a known rule is parsed as before: deferred is empty" do
    assert %Config{rules: [_rule], deferred: []} = defer(%{"rules" => [@known]})
  end

  test "an unknown key on a known rule is still refused (the base cannot vouch for it)" do
    assert {:error, {:invalid_rule, reason}} =
             defer(%{"rules" => [Map.put(@known, "exclude_everything", true)]})

    assert reason =~ "exclude_everything"
  end

  test "an unknown top-level section is still refused" do
    assert {:error, {:invalid_config, reason}} =
             defer(%{"rules" => [@unknown], "brand_new_section" => %{}})

    assert reason =~ "brand_new_section"
  end
end
