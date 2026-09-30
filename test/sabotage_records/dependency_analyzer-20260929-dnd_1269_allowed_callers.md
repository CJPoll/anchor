# Sabotage record — per-module attribution (DND-1269)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer` attribution:
  `owner/1`, `nested_scope/2`, `impl_scope/3`, `impl_for/2`, `step_owned/4`,
  `step_defmodule/4`, `defined_modules/1`
- **Tests:** `test/anchor/domain/dependency_analyzer_owners_test.exs`,
  `test/anchor/domain/checks/no_dependency_allowed_callers_test.exs`
- **Suite run:** `mix test` (800 tests)
- **Merge base:** `origin/main` = c041060; **fix commit:** the DND-1269 commit on
  this branch
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

```
** (UndefinedFunctionError) function Anchor.Domain.DependencyAnalyzer.defined_modules/1 is undefined or private
```

## Mutations

Applied, run and restored as in the primary record. D3 first left
`impl_scope/3` unused and did not compile; the rewrite below keeps it called.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| D1 | a nested `defmodule` inherits its parent's owner | 7 of 800 | `a nested module is qualified by its parent: want [A, A.B], got [A]` |
| D2 | code in a `quote` is owned by the enclosing module | 7 of 800 | `a module inside a quote is the macro caller's, not this file's: want [A], got [A, A.B]` |
| D3 | a `defimpl` body is owned by the enclosing module | 7 of 800 | `a defimpl inside the allowed caller is the impl module, not the caller: want [3], got []` |
| D4 | a `defimpl` with a `for:` list is attributed to its first type | 7 of 800 | `a defimpl for: a list names no module: want [], got [P.A]` |
| D5 | a non-literal `defmodule` keeps the enclosing owner | 7 of 800 | `a non-literal defmodule names no module, nor anything nested in it: want [], got [B]` |
| D6 | `defined_modules/1` omits `defimpl`/`defprotocol` modules | 1 of 800 | `a defprotocol, nested like a defmodule: want [A, A.P], got [A]` |
