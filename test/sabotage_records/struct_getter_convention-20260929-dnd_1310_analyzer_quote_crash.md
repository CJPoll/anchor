# Sabotage record — a variable named def or defp (DND-1310)

- **Domain:** struct_getter_convention
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.StructGetterConvention.function_def?/1`
- **Tests:** `test/anchor/managers/lint_variable_names_test.exs` (the `def` and
  `defp` rows)
- **Suite run:** `mix test` (762 tests)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `dependency_analyzer-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

None: the `def` and `defp` rows passed against unfixed a82e01c. A variable
named `def` passed `function_def?/1`, then `getter_candidate?/1` rejected it
(its third element is an atom, not a list), so it never reached a getter.

## Mutations

| # | Mutation | Result |
|---|---|---|
| M8 | drop `when is_list(args)` from both `function_def?/1` clauses (with the analyzer M8 row) | **Measured zero**: `762 tests, 0 failures`, as expected from the above. The guard is kept so `function_def?/1` says what it means; it is not protected by a failing test. |
