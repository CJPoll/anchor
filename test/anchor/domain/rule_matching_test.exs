defmodule Anchor.Domain.RuleMatchingTest do
  # Owns docs/five-bucket-test-matrix.md rows:
  #   base.ex -> rule_matches_file?/2 -> #1-8
  # rule_matches_file?/2 is now a PURE predicate (Anchor.Domain.RuleMatching)
  # that receives already-derived facts (filename, module-name list, use list)
  # and never acquires AST itself (T2 / DND-122).
  #
  # Sabotage record: ../../sabotage_records/rule_matching-20260913-dnd_122_t2_domain_patterns.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.RuleMatching

  # Facts as the caller (Anchor.Check.Base) derives them: filename plus the
  # file's module-name list and its use list. Individual rows override the keys
  # the selector under test reads.
  defp facts(overrides \\ %{}) do
    Map.merge(%{filename: "lib/a/b.ex", module_names: [], uses: []}, overrides)
  end

  describe "rule_matches_file?/2 (rule selection)" do
    test "#1 path rule, recursive, matches" do
      rule = %{paths: ["lib/**/*.ex"], recursive: true}
      assert RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b.ex"}))
    end

    test "#2 path rule, recursive, no match" do
      rule = %{paths: ["lib/**/*.ex"], recursive: true}
      refute RuleMatching.rule_matches_file?(rule, facts(%{filename: "test/a_test.exs"}))
    end

    test "#3 path rule, non-recursive, uses single-* semantics" do
      rule = %{paths: ["lib/*.ex"], recursive: false}
      refute RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b.ex"}))
    end

    # Routing coverage (closes a sabotage measured-zero): these pin that the
    # `recursive` flag chooses which GlobPattern matcher runs. The `lib/a/b.ex`
    # rows above cannot distinguish the two matchers on a `lib/**/*.ex` pattern
    # (both accept a one-level-deep path), so a deeper path is used here.
    test "#3a recursive path selects a deep file that single-* semantics would miss" do
      rule = %{paths: ["lib/**/*.ex"], recursive: true}
      assert RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b/c.ex"}))
    end

    test "#3b non-recursive path uses single-* semantics even for a ** pattern" do
      rule = %{paths: ["lib/**/*.ex"], recursive: false}
      refute RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b/c.ex"}))
    end

    test "#4 module pattern rule matches by module name" do
      rule = %{pattern: "*.Schemas.*"}
      assert RuleMatching.rule_matches_file?(rule, facts(%{module_names: ["App.Schemas.User"]}))
    end

    test "#5 module pattern rule does not match" do
      rule = %{pattern: "*.Schemas.*"}
      refute RuleMatching.rule_matches_file?(rule, facts(%{module_names: ["App.Service"]}))
    end

    test "#6 uses_module rule matches a module that uses it" do
      rule = %{uses_module: "Ecto.Schema"}
      assert RuleMatching.rule_matches_file?(rule, facts(%{uses: [Ecto.Schema]}))
    end

    test "#7 uses_module rule does not match" do
      rule = %{uses_module: "Ecto.Schema"}
      refute RuleMatching.rule_matches_file?(rule, facts(%{uses: [Phoenix.LiveView]}))
    end

    test "#8 rule with neither paths/pattern/uses_module -> false (deny by default)" do
      rule = %{type: :no_direct_dependency, forbidden_modules: []}
      refute RuleMatching.rule_matches_file?(rule, facts())
    end
  end

  # A file with several top-level modules is selectable by a module `pattern`
  # rule if ANY of its module names matches (owner decision 1 / BUG 1/4 fix
  # caveat on the matrix's rule_matches_file? row 4). The pure predicate already
  # honors this because it folds over the module-name list.
  describe "rule_matches_file?/2 module-pattern over a multi-module file" do
    test "selects when any module name matches the pattern" do
      rule = %{pattern: "*.Schemas.*"}
      names = ["App.Service", "App.Schemas.User"]
      assert RuleMatching.rule_matches_file?(rule, facts(%{module_names: names}))
    end

    test "does not select when no module name matches the pattern" do
      rule = %{pattern: "*.Schemas.*"}
      names = ["App.Service", "App.Repo"]
      refute RuleMatching.rule_matches_file?(rule, facts(%{module_names: names}))
    end
  end

  # Gap D (DND-140) — test-matrix rule_matching.ex -> rule_matches_file?/2 rows 1-7.
  # With parse_rule/1 now emitting `paths: nil` when YAML omits `paths` (and the
  # first clause guarded on a NON-EMPTY list), a `pattern`/`uses_module` rule
  # falls through to its own clause instead of being shadowed by
  # `Enum.any?([], …)`.
  # Sabotage record: ../../sabotage_records/rule_matching-20260913-dnd_140_gap_d_rule_selection.md
  describe "rule_matches_file?/2 Gap D: paths-presence gating (DND-140)" do
    # Row 1
    test "row 1: pattern rule with paths: nil selects by module name" do
      rule = %{pattern: "*.Schemas.*", paths: nil, uses_module: nil}

      assert RuleMatching.rule_matches_file?(
               rule,
               facts(%{module_names: ["Elixir.App.Schemas.User"]})
             )
    end

    # Row 2
    test "row 2: pattern rule with paths: nil does not select a non-matching module" do
      rule = %{pattern: "*.Schemas.*", paths: nil, uses_module: nil}

      refute RuleMatching.rule_matches_file?(
               rule,
               facts(%{module_names: ["Elixir.App.Service"]})
             )
    end

    # Row 3
    test "row 3: paths rule (recursive) still selects by path" do
      rule = %{paths: ["lib/**/*.ex"], recursive: true, pattern: nil, uses_module: nil}

      assert RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b.ex"}))
    end

    # Row 4 — the real bug reproduction: an empty `paths: []` must no longer
    # shadow the pattern selector.
    test "row 4: empty paths: [] falls through to the pattern clause" do
      rule = %{paths: [], recursive: false, pattern: "*.Schemas.*", uses_module: nil}

      assert RuleMatching.rule_matches_file?(
               rule,
               facts(%{module_names: ["Elixir.App.Schemas.User"]})
             )
    end

    # Row 5
    test "row 5: uses_module rule with paths: nil selects a file that uses it" do
      rule = %{uses_module: "Ecto.Schema", paths: nil, pattern: nil}

      assert RuleMatching.rule_matches_file?(rule, facts(%{uses: [Ecto.Schema]}))
    end

    # Row 6
    test "row 6: rule with no selector (all nil) selects nothing (deny by default)" do
      rule = %{paths: nil, pattern: nil, uses_module: nil}

      refute RuleMatching.rule_matches_file?(rule, facts())
    end

    # Row 7
    test "row 7: non-recursive single-* paths rule does not select a nested file" do
      rule = %{paths: ["lib/*.ex"], recursive: false, pattern: nil, uses_module: nil}

      refute RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b.ex"}))
    end
  end

  describe "rule_matches_type?/2" do
    test "true when rule type equals the check's type" do
      assert RuleMatching.rule_matches_type?(
               %{type: :no_direct_dependency},
               :no_direct_dependency
             )
    end

    test "false when rule type differs" do
      refute RuleMatching.rule_matches_type?(%{type: :must_use_module}, :no_direct_dependency)
    end
  end
end
