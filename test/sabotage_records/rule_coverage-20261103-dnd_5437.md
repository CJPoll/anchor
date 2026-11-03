# Sabotage record — graph rules are never reported unchecked (DND-5437)

- **Domain:** rule_coverage
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleCoverage.unchecked/3`
- **Tests:** `test/anchor/domain/rule_coverage_test.exs` ("unchecked/3")
- **Suite run:** targeted `mix test <files>` per mutation; full `mix test` green before and after (876 tests, 0 failures)
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 3e2861e

Fail-first: the code under test is new in this run (absent on 185ecc9), so each
new test first failed as an undefined module or function; the mutations below
are its proof. Each mutation was applied alone to 3e2861e, the named tests run,
and the file restored with `git checkout --`.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing test) |
|---|---|---|---|
| C1 | unchecked/3 ignores engine_of | 2 failures (`21 tests, 2 failures`) | `unchecked/3 a graph-engine rule is never reported unchecked (Anchor.Domain.RuleCoverageTest)`: `Assertion with == failed` |
