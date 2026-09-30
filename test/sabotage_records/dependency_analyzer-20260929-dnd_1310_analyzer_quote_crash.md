# Sabotage record — a variable named like a special form (DND-1310)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer`: the `quote` clause of
  `step/3`, the `quote` clause of `top_defmodules/1`, the `defmodule` and
  `quote` clauses of `local_definitions/1`'s prewalk
- **Tests:** `test/anchor/domain/dependency_analyzer_variable_names_test.exs`
  (the name table, 33 names from `test/fixtures/special_variable_names.txt`,
  and Elixir's `OptionParser.split/1` verbatim from
  `test/fixtures/option_parser_split.txt`),
  `test/anchor/managers/lint_variable_names_test.exs` (every check over the
  same table and fragment)
- **Suite run:** `mix test` (762 tests)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `single_control_flow-`,
  `struct_getter_convention-`, `lint-`, `base-` and
  `failures-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

The three new test files, run against unfixed a82e01c (`70 tests, 13
failures`). The analyzer rows, verbatim:

```
1) test a variable named like a special form or a matched call a variable named quote analyses exactly as a variable named value
   ** (FunctionClauseError) no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3
       # 1
       nil
   (anchor 0.1.0) lib/anchor/domain/dependency_analyzer.ex:729: Anchor.Domain.DependencyAnalyzer.walk_children/3
   (anchor 0.1.0) lib/anchor/domain/dependency_analyzer.ex:434: Anchor.Domain.DependencyAnalyzer.step/3

2) test Elixir's own OptionParser.split/1 (a variable named quote), verbatim analyses without crashing and records its real dependencies
   ** (FunctionClauseError) no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3

9) test every check reads a variable named quote as it reads one named value
   ** (FunctionClauseError) no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3

13) test every check runs over Elixir's OptionParser.split/1 without failing closed
   ** (FunctionClauseError) no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3
```

The other 32 names passed the analyzer table unfixed: no other analyzer clause
confused a variable with a call. The other failures are in the
`single_control_flow-` and `lint-` records.

After the fix: `762 tests, 0 failures`.

## Mutations

Each was applied alone to the fix commit, the whole suite run, and the file
restored (`git diff | wc -l` = 0 after the run).

| # | Mutation | Result |
|---|---|---|
| M1 | `step({:quote, _meta, args}, ...)` loses `when is_list(args)` | `762 tests, 4 failures`: the `quote` table row and the fragment test in the analyzer file (`FunctionClauseError ... walk_children/3`), and the `quote` row and fragment test in the Lint file. The Lint `quote` row names both dependency checks: `Anchor.Check.NoDependency` got `[{:fail_closed, nil, "Anchor.Check.NoDependency", "Anchor check Anchor.Check.NoDependency crashed on this file, so it checked no Anchor rule against it: FunctionClauseError: no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3 ..."}]`, and `Anchor.Check.NoTransitiveDependency` got the same from the module-graph build. |
| M8 | drop `when is_list(args)` from `top_defmodules/1`'s `quote` clause and from both `local_definitions/1` clauses (with the `struct_getter_convention` M8 row) | **Measured zero**: `762 tests, 0 failures`. Expected: all three clauses prune (`[]`, `{nil, locals}`), and a variable has no children, so pruning it is the identity. The guards are kept so every name-matched clause in the file matches calls only; a later body that recursed into `args` would otherwise crash on a variable. |
