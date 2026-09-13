# Sabotage record — RuleMatching rule-selection predicate

- **Domain:** rule_matching
- **Branch:** dnd-122-t2-domain-patterns
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.RuleMatching.rule_matches_file?/2`
- **Suite run:** `mix test test/anchor/domain/rule_matching_test.exs`

Anchors proven: each of the three selector clauses (`paths` + `recursive`
routing, module `pattern`, `uses_module`) and the deny-by-default catch-all,
each with a positive control that stays green beside the failing case.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| D | `paths` clause: recursive branch `matches_recursive_pattern?` → `matches_pattern?` (route the recursive flag to the single-`*` matcher) | 1 | `#3a recursive path selects a deep file that single-* semantics would miss` — `Expected truthy, got false` — `assert RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/a/b/c.ex"}))` |
| E | `pattern` clause: `Enum.any?(module_names, &matches_module_pattern?(&1, pattern))` → `not (…)` (invert module-pattern selection) | 4 | `#4` & multi-module "selects when any matches" — `Expected truthy, got false`; `#5` & multi-module "does not select when no name matches" — `Expected false or nil, got true` |
| F | `uses_module` clause: `Module.concat([uses_module]) in uses` → `not in uses` | 2 | `#6 uses_module rule matches` — `Expected truthy, got false` — `assert RuleMatching.rule_matches_file?(rule, facts(%{uses: [Ecto.Schema]}))`; `#7 uses_module rule does not match` — `Expected false or nil, got true` |
| G | catch-all: `def rule_matches_file?(_rule, _facts), do: false` → `do: true` | 1 | `#8 rule with neither paths/pattern/uses_module -> false (deny by default)` — `Expected false or nil, got true` — `refute RuleMatching.rule_matches_file?(rule, facts())` |

## Measured zero and its fix (mutation D)

The FIRST attempt at mutation D — recursive branch → `matches_pattern?` — reddened
**0** tests against the original matrix rows (#1 `lib/a/b.ex` + `lib/**/*.ex`,
recursive; #2 `test/a_test.exs`; #3 `lib/*.ex` non-recursive). The single-`*`
matcher happens to accept a **one-level-deep** path against a `lib/**/*.ex`
pattern (`**` → `[^/]*[^/]*`, which matches a single `a`), so no matrix row
distinguished the recursive matcher from the single-`*` matcher at the selector
level. The recursive-vs-single distinction was pinned only inside
`GlobPattern` (records C/A), not in `RuleMatching`'s routing.

**Fix (this pass):** added routing tests `#3a` (recursive, deep path
`lib/a/b/c.ex` → must select) and `#3b` (non-recursive, same deep path → must
not). With `#3a` present, mutation D reddens exactly 1 test (row above); `#3b`
pins the else branch symmetrically. Zero recorded and closed per ADR 003.

## Traps hit

- **Mutation E, first attempt (`… → true`) was a warnings-as-errors compile
  failure, not a test failure.** Replacing the clause body with a literal `true`
  orphaned both `module_names` and `pattern`, so `mix test` reported
  "Compilation failed due to warnings while using the --warnings-as-errors
  option" — a false signal, not evidence. The compile-clean mutation that keeps
  both bindings live is the negation `not (…)`, recorded above (reddens 4 tests,
  proving the selector is load-bearing in both directions). ADR 002 orphaned-
  binding trap.

## Notes

- Positive controls held on every run; the tree returned to **14 tests, 0
  failures** after `git checkout -- lib/anchor/domain/rule_matching.ex`.
- Impl committed **before** sabotage so `git checkout` restores T2 code, not the
  pre-T2 HEAD.
