# Sabotage record — forbidden_functions detection (DND-1267)

- **Domain:** no_dependency
- **Branch:** dnd-1267-forbidden-functions
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.NoDependency.function_violations/2`,
  `forbidden_calls/2`, `dynamic_violation/2`
- **Tests:** `test/anchor/domain/checks/no_dependency_forbidden_functions_test.exs`
  (the table, the "the violations" describe),
  `test/anchor/e2e/checks_e2e_test.exs`
- **Suite run:** `mix test` (689 tests)
- **Merge base:** `origin/main` = bfa7aa7; **fix commit:** the DND-1267 commit on
  this branch
- **Primary record (same run):** `dependency_analyzer-20260929-dnd_1267_forbidden_functions.md`

## Fail-first on unfixed bfa7aa7

The detector had no function-level code, so every positive row of the table
failed (`remote call: want [{:call, "Bad.Mod.f/1", 2}], got []`), and so did
every test of "the violations" describe. The e2e test failed at the load:

```
rule 1: unknown key "forbidden_functions" in a no_direct_dependency rule; known keys for no_direct_dependency: context_depth, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module
```

## Mutations

Failure strings are verbatim. `match (=) failed` is ExUnit's own text for a
failed pattern assertion; the test named beside it is the one that failed.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| N1 | `function_violations/2` always returns `[]` | 11 of 689 | test "the same function called twice is reported once, at its first line": `match (=) failed`; table: `remote call: want [{:call, "Bad.Mod.f/1", 2}], got []` |
| N2 | a dynamic call reported without the could-reach filter | 5 of 689 | `x \|> apply(Bad.Mod, :f) is apply(x, Bad.Mod, :f): Bad.Mod is the function name: want [], got [dynamic: 2]` |
| N3 | a dynamic call reported once per rule | 1 of 689 | test "a dynamic call site is reported once, not once per rule": `match (=) failed` |

## Rows no mutation reddens

"a module-level rule keeps the documented dynamic-dispatch boundary" passed on
bfa7aa7 and passes now. It pins that a rule with no `forbidden_functions` does
not start reporting dynamic calls, which would flag every behaviour dispatch
(`adapter.call(x)`). A measured zero, on purpose.
