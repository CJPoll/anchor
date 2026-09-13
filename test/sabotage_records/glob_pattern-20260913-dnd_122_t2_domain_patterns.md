# Sabotage record — GlobPattern glob / module-name matching

- **Domain:** glob_pattern
- **Branch:** dnd-122-t2-domain-patterns
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.GlobPattern` (`pattern_to_regex/1`, `module_pattern_to_regex/1`, `recursive_pattern_to_regex/1`)
- **Suite run:** `mix test test/anchor/domain/glob_pattern_test.exs`

Anchors proven: each of the three `*_to_regex` helpers, with a positive control
that stays green beside the failing negative case.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | `pattern_to_regex/1`: single-`*` replacement `[^/]*` → `.*` (let `*` cross `/`) | 1 | `matches_pattern?/2 #2 * does not cross /` — `Expected false or nil, got true` — `refute GlobPattern.matches_pattern?("lib/a/b.ex", "lib/*.ex")` |
| B | `module_pattern_to_regex/1`: drop the `String.replace(".", "\\.")` line (stop escaping literal dots) | 1 | `matches_module_pattern?/2 #5 literal dots are escaped` — `Expected false or nil, got true` — `refute GlobPattern.matches_module_pattern?("AppXSchemasXUser", "*.Schemas.*")` |
| C | `recursive_pattern_to_regex/1`: single-`*` replacement `[^/]*` → `.*` (let `*` cross `/`) | 1 | `matches_recursive_pattern?/2 #3 single * does not cross a /` — `Expected false or nil, got true` — `refute GlobPattern.matches_recursive_pattern?("lib/a/b.ex", "lib/*.ex")` |

## Notes

- **Positive controls held.** Under A, `matches_pattern?/2 #1` (a `*` that *does*
  stay within a segment) stayed green — the mutation flips only the
  crosses-a-slash case, so the failure is specific, not a blanket break. Same
  shape for B (module rows #1-#3 held) and C (recursive rows #1, #2, #4-#7 held).
- Every run left the suite at **16 tests, 1 failure**, and the tree returned to
  **16 tests, 0 failures** after `git checkout -- lib/anchor/domain/glob_pattern.ex`.
- The impl was committed **before** sabotage so `git checkout` restores the T2
  code, not the pre-T2 HEAD (ADR 002 restore-trap).
