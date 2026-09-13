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
