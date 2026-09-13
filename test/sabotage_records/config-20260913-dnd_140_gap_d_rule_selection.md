# Sabotage record — Config parse_rule absent-paths semantics (Gap D)

- **Domain:** config
- **Branch:** dnd-140-gap-d-rule-selection
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Config.parse_rule/1`
- **Suite run:** `mix test test/anchor/domain/config_test.exs`

Gap D (DND-140): `parse_rule/1` now surfaces an ABSENT `paths` as `nil` instead
of `[]`, so a `pattern`/`uses_module`-only rule is distinguishable from a rule
with an empty path list and is not shadowed by `RuleMatching`'s path clause. A
present `paths` list is preserved unchanged.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | `paths: rule["paths"]` → `paths: rule["paths"] \|\| []` (restore the pre-fix `\|\| []`, so an absent `paths` is stamped `[]` again) | 2 | `parse_rule/1 … absent list fields default to [] (paths surfaces as nil)` — `Assertion with == failed` — `code: assert rule.paths == nil` — `left: []` — `right: nil`; `parse_rule/1 … Gap D row 3: absent paths surfaces as nil, not []` — `Assertion with == failed` — `code: assert rule.paths == nil` — `left: []` — `right: nil` |

## Rows that stayed green, and why

- `Gap D row 4: present paths preserved as a list` held under mutation A: a
  present list is truthy, so `rule["paths"] || []` returns the list unchanged —
  the mutation only affects the *absent* case. Preservation is proven instead by
  row 4's positive assertion (`rule.paths == ["lib/**/*.ex"]`), which no
  `|| []`-style mutation can break; a mutation dropping `paths` entirely would
  red it, but is out of scope for this fix.
- All non-`paths` fields (`forbidden_modules`, `required_modules`,
  `allowed_functions`, `recursive`, `max_lines`, `mode`) were untouched by this
  fix and stayed green.

## Notes

- This mutation is the parser half of the Gap D fix; the selection half (how a
  `nil`/`[]` `paths` falls through) is in the companion record
  `rule_matching-20260913-dnd_140_gap_d_rule_selection.md`.
- Positive controls held; the tree returned to **39 tests, 0 failures** for the
  config + rule_matching suites (full suite **336 tests, 0 failures**) after
  `git checkout -- lib/anchor/domain/config.ex`.
- Impl committed **before** sabotage so `git checkout` restores the Gap D fix.
