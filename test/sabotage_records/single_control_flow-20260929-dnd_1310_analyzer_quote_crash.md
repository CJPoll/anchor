# Sabotage record — a variable named like a control-flow structure (DND-1310)

- **Domain:** single_control_flow
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.SingleControlFlow`,
  `count_control_flow_structures/1`: the `@control_flow_structures` clause
- **Tests:** `test/anchor/managers/lint_variable_names_test.exs` (every check,
  one row per name)
- **Suite run:** `mix test` (762 tests)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `dependency_analyzer-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

Against unfixed a82e01c, seven rows of the Lint table failed. A variable named
`case`, `cond`, `for`, `if`, `receive`, `unless` or `with` was counted as a
control-flow structure (the sample function has none):

```
5) test every check reads a variable named case as it reads one named value
   Anchor.Check.SingleControlFlow on a variable named case: want [], got [{:rule, 4, "run", "Function clause `run` contains 3 control-flow structures (maximum allowed: 1). ..."}]
```

and the same for `cond` (6), `for` (7), `if` (8), `receive` (10), `unless`
(11), `with` (12). After the fix: `762 tests, 0 failures`.

## Mutations

| # | Mutation | Result |
|---|---|---|
| M2 | the clause guard `is_list(args)` becomes `(is_list(args) or true)` | `762 tests, 7 failures`: the `case`, `cond`, `for`, `if`, `receive`, `unless`, `with` rows, each `{Anchor.Check.SingleControlFlow, [want: [], got: [{:rule, 4, "run", "Function clause `run` contains 3 control-flow structures ..."}]]}` |
