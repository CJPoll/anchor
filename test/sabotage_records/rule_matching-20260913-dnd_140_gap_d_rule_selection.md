# Sabotage record — RuleMatching paths-presence gating (Gap D)

- **Domain:** rule_matching
- **Branch:** dnd-140-gap-d-rule-selection
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.RuleMatching.rule_matches_file?/2`
- **Suite run:** `mix test test/anchor/domain/rule_matching_test.exs`

Gap D (DND-140): `parse_rule/1` now emits `paths: nil` when YAML omits `paths`,
and this predicate's first clause is guarded on a NON-EMPTY list
(`when is_list(paths) and paths != []`) so an absent/empty `paths` falls through
to the `pattern`/`uses_module` selectors instead of being shadowed by
`Enum.any?([], …)`. Mutations below prove the new guard and the two fall-through
selectors are load-bearing.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | first-clause guard `when is_list(paths) and paths != []` → `when is_list(paths)` (drop the non-empty gate — the Gap D fix) | 1 | `Gap D … row 4: empty paths: [] falls through to the pattern clause` — `Expected truthy, got false` — `assert RuleMatching.rule_matches_file?(rule, facts(%{module_names: ["Elixir.App.Schemas.User"]}))` (rule `%{pattern: "*.Schemas.*", recursive: false, paths: [], uses_module: nil}`) |
| B | `pattern` clause: `Enum.any?(module_names, &matches_module_pattern?(&1, pattern))` → `not Enum.any?(…)` (invert module-pattern selection) | 7 | `Gap D … row 1: pattern rule with paths: nil selects by module name` — `Expected truthy, got false`; `Gap D … row 2: pattern rule with paths: nil does not select a non-matching module` — `Expected false or nil, got true` (also the pre-existing `#4`/`#5` and multi-module rows) |
| C | `uses_module` clause: `Module.concat([uses_module]) in uses` → `not in uses` (invert use-selection) | 3 | `Gap D … row 5: uses_module rule with paths: nil selects a file that uses it` — `Expected truthy, got false` (also pre-existing `#6`/`#7`) |

## Measured zeros (mutation A) and why

The Mission predicted mutation A would re-red rows **1, 4, 5**. Measured: it
re-reds **only row 4**. Rows 1 and 5 stayed **green** under mutation A — they are
**measured zeros** for this mutation.

Reason: rows 1 and 5 carry `paths: nil`, not `paths: []`. Both the fixed guard
(`is_list(paths) and paths != []`) and the mutated guard (`is_list(paths)`)
reject `nil` at `is_list/1`, so the first clause never matches for those rows in
either version — the `!= []` gate is irrelevant to them. What actually protects
rows 1 and 5 is that `parse_rule/1` surfaces the absent selector as `nil` (see
the `config` record for that mutation) together with the `is_list` guard; their
own selection is then proven load-bearing by mutations B (row 1) and C (row 5)
above. Row 4 (`paths: []`, an explicit empty list) is the only row whose
selection depends on the `paths != []` gate, and it is the true reproduction of
the production bug (a parsed `pattern`-only rule was stamped `paths: []`).

## Rows that stayed green, and why

- Under mutation A, every `paths: nil` / sparse row and every `paths`-present row
  held; only the explicit-`[]` row (row 4) moved, isolating exactly what the
  `!= []` gate governs.
- Under mutations B and C, the `paths`-selection rows (`#1`, `#2`, `#3`, row 3,
  row 7) held — module-pattern and use-selection are orthogonal to path
  selection.

## Notes

- Positive controls held on every run; the tree returned to **21 tests, 0
  failures** (full suite **336 tests, 0 failures**) after each
  `git checkout -- lib/anchor/domain/rule_matching.ex`.
- Impl committed **before** sabotage so `git checkout` restores the Gap D fix,
  not the pre-fix HEAD.
