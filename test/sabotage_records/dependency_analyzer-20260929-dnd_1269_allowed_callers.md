# Sabotage record — per-module attribution (DND-1269)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer` attribution:
  `owner/1`, `module_scope/2`, `nested_scope/2`, `impl_scope/3`, `impl_for/2`,
  `step_owned/4`, `step_defmodule/5`, `defined_modules/1`
- **Tests:** `test/anchor/domain/dependency_analyzer_owners_test.exs`,
  `test/anchor/domain/checks/no_dependency_allowed_callers_test.exs`
- **Suite run:** `mix test` (800 tests); re-run one mutation with
  `mix test test/anchor/domain/dependency_analyzer_owners_test.exs`
- **Merge base:** `origin/main` = c041060; **mutated tree:** 5ce9ad7 (the
  branch's final code)
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

```
** (UndefinedFunctionError) function Anchor.Domain.DependencyAnalyzer.defined_modules/1 is undefined or private
```

## Fail-first for the alias fix (5ce9ad7), on ae55b4c

The review floor found that the owner of a `defmodule` was its literal
spelling, never alias-expanded. After `alias Evil.Ns, as: App`,
`defmodule App.Allowed` defines `Evil.Ns.Allowed`, but it was exempt as
`App.Allowed`. The new rows, run against ae55b4c, gave `14 tests, 7 failures`:

```
a top-level alias cannot dress another module in the allowed name: want [3], got []
a top-level alias as: renames the module a defmodule defines: want [Evil.Ns.Allowed], got [Athena.Allowed]
a nested Elixir. prefix is absolute: want [O, T.Mod], got [O, O.Elixir.T.Mod]
a nested __MODULE__ prefix is the parent: want [O, O.Inner], got [O]
```

Each expected module is what `elixir` 1.19.4 itself defines for that source.

## Mutations

Applied, run and restored as in the primary record. D1 and D3 first left a
binding unused and did not compile. The rewrites keep every binding used.
Failure text is verbatim.

| # | Mutation | Failed | Failure (owners table unless noted) |
|---|---|---|---|
| D1 | a nested `defmodule` inherits its parent's owner | 7 of 800 | `a nested module is qualified by its parent: want [A, A.B], got [A]`; `a nested name ignores the aliases in scope: want [O, O.Foo.Bar], got [O]` |
| D2 | code in a `quote` is owned by the enclosing module | 7 of 800 | `a module inside a quote is the macro caller's, not this file's: want [A], got [A, A.B]` |
| D3 | a `defimpl` body is owned by the enclosing module | 7 of 800 | `a defimpl with for:: want [String.Chars.A], got []`; `a module nested in a defimpl is qualified by the impl module: want [P.A, P.A.H], got [H]` |
| D4 | a `defimpl` with a `for:` list is attributed to its first type | 7 of 800 | `a defimpl for: a list names no module: want [], got [P.A]` |
| D5 | a non-literal `defmodule` keeps the enclosing owner | 7 of 800 | `a non-literal defmodule names no module, nor anything nested in it: want [], got [B]` |
| D6 | `defined_modules/1` omits `defimpl`/`defprotocol` modules | 1 of 800 | `a defprotocol, nested like a defmodule: want [A, A.P], got [A]`; `a top-level alias renames the module a defprotocol defines: want [Evil.Ns.Proto], got []` |
| D7 | a top-level `defmodule` name is not expanded through aliases | 7 of 800 | allowed_callers table: `a top-level alias cannot dress another module in the allowed name: want [3], got []` |
| D8 | a nested `Elixir.` head is read as a plain child name | 1 of 800 | `a nested Elixir. prefix is absolute: want [O, T.Mod], got [O, O.Elixir.T.Mod]` |
