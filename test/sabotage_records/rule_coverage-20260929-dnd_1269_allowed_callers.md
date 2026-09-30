# Sabotage record — missing_allowed_callers/2 (DND-1269)

- **Domain:** rule_coverage
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleCoverage.missing_allowed_callers/2`;
  `Anchor.Domain.AllowedCallers.missing/2`
- **Tests:** `test/anchor/domain/rule_coverage_test.exs`
  ("missing_allowed_callers/2")
- **Suite run:** `mix test` (800 tests)
- **Merge base:** `origin/main` = c041060; **fix commit:** the DND-1269 commit on
  this branch
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

```
** (UndefinedFunctionError) function Anchor.Domain.RuleCoverage.missing_allowed_callers/2 is undefined or private
```

## Mutations

C1 first left `unparsed?/1` unused and did not compile; the rewrite below keeps
it called.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| C1 | a rule that may select an unparsed file is still reported | 1 of 800 | test "a rule that may select an unparsed file is not reported (the parse failure is)": `Assertion with == failed` |
| C2 | defined modules read from every file, not only the selected ones | 1 of 800 | test "a caller defined only in a file the rule does not select is reported": `Assertion with == failed` |
| C3 | a rule that selects no file is reported here as well as by the floor | 1 of 800 | test "a rule that selects no file is left to the floor report": `Assertion with == failed` |
