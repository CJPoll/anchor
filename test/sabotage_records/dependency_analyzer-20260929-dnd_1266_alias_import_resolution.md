# Sabotage record — alias and import resolution (DND-1266)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1266-alias-import-resolution
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer` (the lexical walk behind
  `extract_direct_dependencies/1`, `extract_call_dependencies/1`,
  `dependency_lines/2`, `unresolved_directives/1`, `module_dependencies/1`), and
  `Anchor.Domain.Checks.NoDependency.detect_violations/3` (mutation H)
- **Suite run:** `mix test test/anchor/domain/dependency_analyzer_test.exs test/anchor/domain/checks/no_dependency_alias_resolution_test.exs test/anchor/domain/checks/no_dependency_test.exs test/anchor/check/no_dependency_test.exs` (151 tests)
- **Merge base:** `origin/main` = 6e02f3a

> ADR 003 splits a multi-domain run into one file per domain. Mutation H touches
> `no_dependency`; it is filed here, labelled, because its only job is to surface
> the analyzer's `unresolved_directives/1`. `grep -rl 'NoDependency' test/sabotage_records/`
> finds it.

## Fail-first run (unfixed code, tests only)

The new tests were run against `origin/main` production code before any fix:
`477 tests, 38 failures`. Every failure was a new DND-1266 test. Representative
strings, verbatim:

```
  1) test alias and import resolution (DND-1266) reference mode records a multi-alias's full names, not its prefix or short names (Anchor.Domain.DependencyAnalyzerTest)
     code:  assert DependencyAnalyzer.extract_direct_dependencies(ast(src)) == [A.B, A.C]
     left:  [A, B, C]
     right: [A.B, A.C]

  3) test alias and import resolution (DND-1266) call mode resolves an aliased call to the full module (Anchor.Domain.DependencyAnalyzerTest)
     code:  assert DependencyAnalyzer.extract_call_dependencies(ast(src)) == [A.B]
     left:  [B]
     right: [A.B]

 16) test an aliased target is reported (match: reference) multi-alias alias A.{B, C} then B.f() and C.f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     code:  assert triggers(source, [Forbidden.Target, Forbidden.Other], mode) == [
              "Forbidden.Other",
              "Forbidden.Target"
            ]
     left:  []

 22) test an aliased target is reported (match: call) alias A.B then B.f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     code:  assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]

 25) test an aliased target is reported (match: call) import A.B then bare f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     code:  assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]

 37) test check_file/3 — alias and import resolution (DND-1266) flags a forbidden module reached through a multi-alias (match: reference) (Anchor.Check.NoDependencyTest)
     code:  assert [issue] = NoDependency.check_file(source_file, [rule], [])
     left:  [issue]
     right: []
```

Tests that passed on the unfixed code, and why: in `match: reference`, `alias A.B`,
`as:`, `require ... as:`, outer-module aliases, `__MODULE__` aliases and every
`import` form were already reported **through the directive line itself**. Those
rows guard against a regression that stops recording directive targets; they do
not prove resolution. The negative rows "a same-named module that is not the
target" and the scope-leak rows also passed, since the unfixed code resolved
nothing.

## Mutations (fixed code committed first; each restored with `git checkout -- <file>`)

| # | Mutation | Tests failed | First failure string |
|---|---|---|---|
| A | `alias_bindings(:alias, ...)` binds nothing (`{[], resolved_all?(targets)}`) | **11** | `module_dependencies resolves an outer alias inside a nested module's node` — `left: [B]` / `right: [A.B]` |
| B | Multi-alias `resolve_target/2` returns the base module for each element instead of `base.Elem` | **9** | `reference mode records a multi-alias's full names...` — `left: [A]` / `right: [A.B, A.C]` |
| C | `imports?({:only, _})` ignores the `only:` list (claims any non-builtin call) | **3** | `only: [f: 0] does not claim f with another arity` — `left: [%Anchor.Domain.Violation{line: 4, trigger: "Forbidden.Target", ...}]` / `right: []` |
| D | `imports?({:except, _})` ignores the `except:` list | **1** | `except: [f: 0] does not claim f/0` — `left: [%Anchor.Domain.Violation{line: 4, trigger: "Forbidden.Target", ...}]` / `right: []` |
| E | `nested_module_alias/2` is a no-op (a nested `defmodule` binds no alias) | **2** | `a nested defmodule aliases its name in the enclosing module` (reference) — `left: []` / `right: ["Outer.Target"]` |
| F | `record_bare_call/5` never consults `env.locals` | **1** | `a local function is not claimed by an unrestricted import` — `left: [%Anchor.Domain.Violation{line: 4, ...}]` / `right: []` |
| G | `builtin_call?/2` always `false` (Kernel calls, attributes, heads claimable) | **1** | `Kernel calls, attributes and def heads are not claimed by an unrestricted import` — `left: [%Anchor.Domain.Violation{line: 6, ...}]` / `right: []` |
| H | `NoDependency.detect_violations/3` drops `unresolved_violations/1` | **4** | `alias with a non-literal target` (reference) — `match (=) failed` `left: [%Anchor.Domain.Violation{} = violation]` / `right: []` |
| I | Piped bare call counts `length(args)` instead of `length(args) + 1` | **1** | `a piped bare call counts the piped argument toward its arity` — `left: []` / `right: ["Forbidden.Target"]` |
| J | `__block__` walks its expressions without threading the environment | **26** | `call mode resolves an aliased call to the full module` — `left: [B]` / `right: [A.B]` |
| K | A module body starts with empty aliases/imports (outer scope not inherited) | **2** | `module_dependencies resolves an outer alias inside a nested module's node` — `left: [B]` / `right: [A.B]` |

Each mutation compiled cleanly under `--warnings-as-errors` (the first attempts at B
and J left a function unused and failed to **compile**; per ADR 002 that is not a
test failure, so both were rewritten to keep the function referenced and re-run —
the counts above are from the re-runs).

## Rows that no single mutation isolates

- **Scope non-leak** ("an alias inside a nested module does not leak to its
  sibling", "...inside a function body does not leak...", "an import in one
  module does not resolve bare calls in its sibling"). Non-leak is structural:
  `walk/3` discards the environment a node produces, and only `walk_sequence/3`
  threads it between siblings. No one-line mutation makes a child's directive
  escape without rewriting that contract. **Measured zero for a targeted
  mutation**; the rows stand as regression guards against a future walk that
  returns its environment.
- **"an alias applies only after it is declared"** — likewise structural
  (sequential reduce); no targeted mutation.
- **Local capture `&f/1`** — failed fail-first (row 9 of the before run); covered
  by mutation J (26) but not by a dedicated mutation.

## Traps

- Two mutations first failed to compile (unused private function under
  `--warnings-as-errors`). A compile failure prints no test names; reading the
  exit code alone would have logged them as "red". Check for `N tests, M failures`.
