defmodule Anchor.Domain.ConfigTest do
  # Domain (pure) parser. No IO — see Anchor.Adapters.ConfigFile for the
  # file-boundary tests.
  #
  # Sabotage record: ../../sabotage_records/config-20260913-dnd_123_t3_config_split.md
  use ExUnit.Case, async: true

  alias Anchor.Config

  describe "parse_rule/1 (test-matrix: config.ex -> parse_rule/1)" do
    # Row 1
    test "parses a no_direct_dependency rule" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "paths" => ["lib/web/**/*.ex"],
          "forbidden_modules" => ["MyApp.Repo"],
          "recursive" => true
        })

      assert rule.type == :no_direct_dependency
      assert rule.paths == ["lib/web/**/*.ex"]
      assert rule.forbidden_modules == [MyApp.Repo]
      assert rule.recursive == true
    end

    # Row 2
    test "parses a must_use_module rule" do
      rule =
        Config.parse_rule(%{
          "type" => "must_use_module",
          "required_modules" => ["MyApp.Schema"],
          "recursive" => false
        })

      assert rule.type == :must_use_module
      assert rule.required_modules == [MyApp.Schema]
      assert rule.recursive == false
    end

    # Row 3
    test "module strings become module atoms via Module.concat" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_modules" => ["MyApp.Repo", "Ecto.Query"]
        })

      assert rule.forbidden_modules == [MyApp.Repo, Ecto.Query]
    end

    # Row 4 — absent list fields default to [], EXCEPT `paths` which surfaces as
    # nil (Gap D, DND-140): an absent `paths` must be distinguishable from an
    # explicit empty list so RuleMatching can fall through to pattern/uses_module.
    test "absent list fields default to [] (paths surfaces as nil)" do
      rule = Config.parse_rule(%{"type" => "no_direct_dependency"})

      assert rule.paths == nil
      assert rule.forbidden_modules == []
      assert rule.required_modules == []
      assert rule.allowed_functions == []
    end

    # Row 5
    test "absent recursive defaults to false" do
      rule = Config.parse_rule(%{"type" => "no_direct_dependency"})

      assert rule.recursive == false
    end

    # Row 6
    test "pattern and uses_module are preserved (uses_module nil when absent)" do
      rule =
        Config.parse_rule(%{
          "type" => "module_pattern_restrictions",
          "pattern" => "*.Schemas.*"
        })

      assert rule.pattern == "*.Schemas.*"
      assert rule.uses_module == nil
    end

    # Row 7
    test "allowed_functions preserved verbatim" do
      rule =
        Config.parse_rule(%{
          "type" => "module_pattern_restrictions",
          "allowed_functions" => ["new", "with_*"]
        })

      assert rule.allowed_functions == ["new", "with_*"]
    end

    # Row 8 (BUG 2)
    test "max_lines surfaced as an atom-keyed integer" do
      rule =
        Config.parse_rule(%{
          "type" => "max_file_length",
          "max_lines" => 10
        })

      assert rule.max_lines == 10
    end

    # Row 9 (BUG 2)
    test "bare mode: all coerced to :all" do
      rule =
        Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => "all"})

      assert rule.mode == :all
    end

    # Row 10 (BUG 2)
    test "bare mode: public_only coerced to :public_only" do
      rule = Config.parse_rule(%{"mode" => "public_only"})

      assert rule.mode == :public_only
    end

    # Row 11 (BUG 2)
    test "bare mode: separate coerced to :separate" do
      rule = Config.parse_rule(%{"mode" => "separate"})

      assert rule.mode == :separate
    end

    # Row 12 (BUG 2)
    test "unknown mode token falls back to :separate without crashing" do
      rule = Config.parse_rule(%{"mode" => "sideways"})

      assert rule.mode == :separate
    end

    # Row 13
    test "absent max_lines/mode leave the check on its own default (nil)" do
      rule = Config.parse_rule(%{"type" => "alphabetized_functions"})

      assert rule.max_lines == nil
      assert rule.mode == nil
    end

    # Gap D (DND-140) — test-matrix config.ex -> parse_rule/1 rows 3-4.
    # Sabotage record: ../../sabotage_records/config-20260913-dnd_140_gap_d_rule_selection.md

    # Matrix row 3: absent `paths` surfaces as nil (not []). Previously the
    # parser stamped `|| []`, which made RuleMatching's first clause shadow the
    # pattern/uses_module selectors.
    test "Gap D row 3: absent paths surfaces as nil, not []" do
      rule =
        Config.parse_rule(%{"type" => "no_direct_dependency", "pattern" => "*.Schemas.*"})

      assert rule.paths == nil
    end

    # Matrix row 4 (regression guard): a present `paths` list is preserved as-is.
    test "Gap D row 4: present paths preserved as a list" do
      rule =
        Config.parse_rule(%{"type" => "no_direct_dependency", "paths" => ["lib/**/*.ex"]})

      assert rule.paths == ["lib/**/*.ex"]
    end
  end

  describe "parse_config/1" do
    test "maps every rule in the document through parse_rule/1" do
      data = %{
        "rules" => [
          %{"type" => "no_direct_dependency", "forbidden_modules" => ["MyApp.Repo"]},
          %{"type" => "must_use_module", "required_modules" => ["MyApp.Schema"]}
        ]
      }

      assert %Config{rules: [rule1, rule2]} = Config.parse_config(data)
      assert rule1.type == :no_direct_dependency
      assert rule1.forbidden_modules == [MyApp.Repo]
      assert rule2.type == :must_use_module
      assert rule2.required_modules == [MyApp.Schema]
    end

    test "a document with no rules yields an empty config" do
      assert %Config{rules: []} = Config.parse_config(%{})
    end

    test "a non-map document (empty YAML decodes to nil) yields an empty config" do
      assert %Config{rules: []} = Config.parse_config(nil)
    end
  end
end
