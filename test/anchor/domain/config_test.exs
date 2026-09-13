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

  describe "parse_rule/1 — Erlang-atom module tokens (Gap B / DND-141)" do
    # See docs/phase-d-gap-test-matrix.md, config.ex :: parse_rule/1 rows 9-11.
    # Sabotage record: ../../sabotage_records/dependency_analyzer-20260913-dnd_141_gap_b_erlang_atom_targets.md

    # Matrix row 9 — Validation (leading-`:` token -> String.to_atom, NOT Module.concat)
    test "a leading-colon forbidden_modules token is kept as a raw atom" do
      rule = Config.parse_rule(%{"forbidden_modules" => [":telemetry"]})

      assert rule.forbidden_modules == [:telemetry]
    end

    # Matrix row 10 — Happy Path (regression guard: ordinary module string still concats)
    test "an ordinary CamelCase forbidden_modules token still becomes a module atom" do
      rule = Config.parse_rule(%{"forbidden_modules" => ["MyApp.Repo"]})

      assert rule.forbidden_modules == [MyApp.Repo]
    end

    # Matrix row 11 — Validation (mixed list preserved element-wise)
    test "a mixed atom + module forbidden_modules list is preserved element-wise" do
      rule = Config.parse_rule(%{"forbidden_modules" => [":telemetry", "MyApp.Repo"]})

      assert rule.forbidden_modules == [:telemetry, MyApp.Repo]
    end

    # required_modules honors the same leading-colon rule (symmetry).
    test "a leading-colon required_modules token is kept as a raw atom" do
      rule = Config.parse_rule(%{"required_modules" => [":cowboy", "MyApp.Schema"]})

      assert rule.required_modules == [:cowboy, MyApp.Schema]
    end
  end

  describe "parse_rule/1 — forbidden_patterns and match (Gap A + A' / DND-142)" do
    # See docs/phase-d-gap-test-matrix.md, config.ex :: parse_rule/1 rows 1,2,5,6,7,8,12.
    # Sabotage record: ../../sabotage_records/no_dependency-20260913-dnd_142_gap_a_forbidden_patterns_match.md

    # Matrix row 1 — Happy Path (A): forbidden_patterns surfaced as a list.
    test "surfaces forbidden_patterns as a list" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["*.Adapters.*"]
        })

      assert rule.forbidden_patterns == ["*.Adapters.*"]
    end

    # Matrix row 2 — Validation (A): absent forbidden_patterns defaults to [].
    test "an absent forbidden_patterns defaults to an empty list" do
      rule = Config.parse_rule(%{"type" => "no_direct_dependency"})

      assert rule.forbidden_patterns == []
    end

    # Matrix row 5 — Validation (A'): absent match defaults to :reference.
    test "an absent match defaults to :reference" do
      rule = Config.parse_rule(%{"type" => "no_direct_dependency"})

      assert rule.match == :reference
    end

    # Matrix row 6 — Happy Path (A'): "call" coerced to :call.
    test "match: \"call\" is coerced to :call" do
      rule = Config.parse_rule(%{"match" => "call"})

      assert rule.match == :call
    end

    # Matrix row 7 — Validation (A'): "reference" coerced to :reference.
    test "match: \"reference\" is coerced to :reference" do
      rule = Config.parse_rule(%{"match" => "reference"})

      assert rule.match == :reference
    end

    # Matrix row 8 — Error Handling (A'): an unknown token falls back to
    # :reference and does NOT raise.
    test "an unknown match token falls back to :reference without raising" do
      rule = Config.parse_rule(%{"match" => "sideways"})

      assert rule.match == :reference
    end

    # Matrix row 12 — Control Flow Decisioning (A): forbidden_patterns and
    # forbidden_modules coexist on one rule.
    test "forbidden_patterns and forbidden_modules coexist on one rule" do
      rule =
        Config.parse_rule(%{
          "forbidden_modules" => ["MyApp.Repo"],
          "forbidden_patterns" => ["*.Adapters.*"]
        })

      assert rule.forbidden_modules == [MyApp.Repo]
      assert rule.forbidden_patterns == ["*.Adapters.*"]
    end
  end

  describe "parse_rule/1 — same_context / context_depth (Gap F / DND-149)" do
    # See docs/gap-f-same-context-test-matrix.md, config.ex -> parse_rule/1 (A1) rows 1-7.
    # Sabotage record: ../../sabotage_records/config-20260913-dnd_149_a1_same_context_config.md

    # Matrix row 1 — Happy Path: same_context: true with default depth.
    test "row 1: same_context true surfaces true with default context_depth 2" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["A.*.Managers.*"],
          "same_context" => true
        })

      assert rule.same_context == true
      assert rule.context_depth == 2
    end

    # Matrix row 2 — Happy Path: explicit context_depth carried.
    test "row 2: an explicit context_depth is carried through" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["A.*.Managers.*"],
          "same_context" => true,
          "context_depth" => 3
        })

      assert rule.same_context == true
      assert rule.context_depth == 3
    end

    # Matrix row 3 — Control Flow: keys absent => back-compat defaults.
    # PINNED CHOICE: keys absent => context_depth defaults to 2 (not nil/absent),
    # same_context defaults to false. Detection (A2) is unchanged by these keys.
    test "row 3: keys absent default to same_context false and context_depth 2" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["A.*.Managers.*"]
        })

      assert rule.same_context == false
      assert rule.context_depth == 2
    end

    # Matrix row 4 — Validation: same_context true with no forbidden_patterns
    # (nothing to scope) fails, naming the rule.
    test "row 4: same_context true with no forbidden_patterns is rejected, naming the rule" do
      result =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "same_context" => true,
          "forbidden_modules" => ["Repo"]
        })

      assert {:error, {:invalid_rule, reason}} = result
      assert reason =~ "no_direct_dependency"
      assert reason =~ "forbidden_patterns"
    end

    # Matrix row 5 — Validation: non-boolean same_context is rejected.
    test "row 5: a non-boolean same_context is rejected" do
      result =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["A.*.Managers.*"],
          "same_context" => "yes"
        })

      assert {:error, {:invalid_rule, reason}} = result
      assert reason =~ "same_context"
    end

    # Matrix row 6 — Validation: non-positive context_depth is rejected.
    test "row 6: a non-positive context_depth is rejected" do
      result =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "forbidden_patterns" => ["A.*.Managers.*"],
          "same_context" => true,
          "context_depth" => 0
        })

      assert {:error, {:invalid_rule, reason}} = result
      assert reason =~ "context_depth"
    end

    # Matrix row 7 — Control Flow: context_depth without same_context is inert
    # (parses, same_context false, no forbidden_patterns requirement applies).
    test "row 7: context_depth without same_context parses inertly (same_context false)" do
      rule =
        Config.parse_rule(%{
          "type" => "no_direct_dependency",
          "context_depth" => 3
        })

      assert rule.same_context == false
      assert rule.context_depth == 3
    end
  end

  describe "parse_config/1 — invalid rules surface {:error, _} (Gap F / DND-149)" do
    # Malformed rules must NEVER become a silent green no-op: an invalid rule in
    # the document makes parse_config/1 surface {:error, _} rather than a
    # %Config{} with an unusable rule, so the load channel can fail.
    test "an invalid same_context rule makes parse_config surface an error" do
      data = %{
        "rules" => [
          %{"type" => "no_direct_dependency", "same_context" => true}
        ]
      }

      assert {:error, {:invalid_rule, _reason}} = Config.parse_config(data)
    end

    test "a document of only valid rules still yields a %Config{}" do
      data = %{
        "rules" => [
          %{
            "type" => "no_direct_dependency",
            "forbidden_patterns" => ["A.*.Managers.*"],
            "same_context" => true
          }
        ]
      }

      assert %Config{rules: [rule]} = Config.parse_config(data)
      assert rule.same_context == true
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
