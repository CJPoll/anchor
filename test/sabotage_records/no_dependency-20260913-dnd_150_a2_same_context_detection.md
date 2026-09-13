# Sabotage record — NoDependency same_context scoping (Gap F, A2)

- **Domain:** no_dependency
- **Branch:** dnd-150-a2-same-context-detection
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoDependency.detect_violations/3`
  (`forbidden?/6`, `in_scope?/4`, `context_prefix/2`), `Anchor.Check.NoDependency.detect_violations/4`,
  `Anchor.Managers.Lint.run/4`
- **Suite run:** `mix test test/anchor/domain/checks/no_dependency_test.exs test/anchor/check/no_dependency_test.exs test/anchor/managers/lint_test.exs`

Four detection branches were mutated, one at a time; each was applied to the
committed implementation, the suite run, the failure captured verbatim, then
`git checkout -- lib/anchor/domain/checks/no_dependency.ex` restored HEAD. All
mutations are reachable and keep every variable used, so they compile under the
project's `warnings_as_errors: true` (applies to the test env too) — a mutation
that leaves an unused var or a dead branch would abort compilation and read as a
false test failure (ADR 002 trap; noted in the mission brief gotcha (b)).

Non-vacuity is built into the same suite: row 1 asserts a same-context call **is**
flagged and row 2 asserts a cross-context call **is** clean, so a detector that
always-reports or never-reports fails one of them.

## Mutation table

| # | Branch | Mutation | Tests failed | Key failure string |
|---|---|---|---|---|
| A | same-context match reported | `in_scope?/4` true-clause: `... and file_ctx == dep_ctx` → `... and file_ctx != dep_ctx` | **10** | see A below |
| B | cross-context skip | `in_scope?/4` true-clause: drop the equality (`not is_nil(file_ctx) and not is_nil(dep_ctx) and file_ctx == dep_ctx` → `not is_nil(file_ctx) and not is_nil(dep_ctx)`) | **4** | see B below |
| C | exact `forbidden_modules` never scoped | `forbidden?/6`: `dependency in forbidden_modules or ...` → `(dependency in forbidden_modules and in_scope?(dependency, same_context, context_depth, file_context)) or ...` | **1** | see C below |
| D | fewer-than-`context_depth` guard | `context_prefix/2`: `length(segments) >= context_depth` → `length(segments) >= context_depth - 1` | **1** | see D below |

### A — same-context match reported (10 failures)

Inverting the equality makes a same-context dependency compare *unequal*, so it
is no longer reported (and a cross-context one now is). This is the decision that
a shared-context pattern match must be flagged.

Failed: domain `/3` rows 1, 8, 10; check `/4` rows 1, 4; lint row 1, row 2, plus
the remaining scoped rows. Verbatim (excerpts):

```
5) test detect_violations/3 — same_context scoping (Gap F) reports only the same-context dep among mixed deps
   Assertion with == failed
   left:  "WaltUi.Search.Managers.B"
   right: "WaltUi.Contacts.Managers.A"

6) test detect_violations/3 — same_context scoping (Gap F) flags a forbidden_patterns match that shares the file's context
   left:  [%Anchor.Domain.Violation{} = violation]
   right: []

7) test run/4 same_context context plumbing (Gap F) threads the file's module names into the check context so scoping runs
   left:  {:ok, [{^source_file, [%Anchor.Domain.Violation{trigger: "WaltUi.Contacts.Managers.Bar"}]}]}
   right: {:ok, [{%SourceFile<lib/foo.ex>, []}]}

10) test detect_violations/4 — same_context context derivation (Gap F) derives the file's context from its defining module name
   left:  [%Anchor.Domain.Violation{trigger: "WaltUi.Contacts.Managers.Bar"}]
   right: []
```

`47 tests, 10 failures`

### B — cross-context skip (4 failures)

Dropping the equality reports every pattern match whose file and dep both have a
derivable context, regardless of whether the contexts match — i.e. cross-context
deps are no longer skipped. The "expects 0" scoped rows redden and the mixed-deps
row over-reports.

```
1) test detect_violations/3 — same_context scoping (Gap F) does not flag a forbidden_patterns match in a different context
   Assertion with == failed
   left:  [ ...
   right: []

2) test detect_violations/3 — same_context scoping (Gap F) context_depth: 3 treats sibling depth-3 contexts as different
   Assertion with == failed
   left:  [ ...
   right: []

3) test detect_violations/3 — same_context scoping (Gap F) reports only the same-context dep among mixed deps
   match (=) failed
   left:  [%Anchor.Domain.Violation{} = violation]
   right: [ ...

4) test detect_violations/4 — same_context context derivation (Gap F) does not flag a cross-context dep under the derived file context
   Assertion with == failed
   left:  [ ...
   right: []
```

`47 tests, 4 failures`

Note row 6 (fewer-than-depth) did **not** redden here — its dep has no derivable
context, so `not is_nil(dep_ctx)` still fails. That branch is proven separately by
mutation D.

### C — exact `forbidden_modules` never scoped (1 failure)

Gating the exact-match arm on `in_scope?/4` makes an exact `forbidden_modules`
entry get scoped too. `WaltUi.Repo` (context `["WaltUi", "Repo"]`) differs from
the file context `["WaltUi", "Contacts"]`, so it is wrongly dropped. Existing
non-`same_context` exact-module tests stay green (their `same_context` is false,
so `in_scope?` returns true).

```
1) test detect_violations/3 — same_context scoping (Gap F) an exact forbidden_modules match is reported even under same_context
   match (=) failed
   left:  [%Anchor.Domain.Violation{trigger: "WaltUi.Repo"}]
   right: []
```

`47 tests, 1 failure`

### D — fewer-than-`context_depth` guard (1 failure)

Relaxing the guard by one lets a segment list shorter than `context_depth` derive
a (short) context instead of `nil`. Row 6 is written so that BOTH the file context
(`["SomeMod"]`) and the dep (`SomeMod`, one segment) are shorter than depth 2 and
share their one segment — so with the guard weakened both truncate to `["SomeMod"]`,
compare equal, and the match is wrongly reported. This makes row 6 a non-vacuous
test of the guard (not merely a different-context case).

```
1) test detect_violations/3 — same_context scoping (Gap F) does not flag a pattern match when neither side has context_depth segments
   Assertion with == failed
   left:  [ ...
   right: []
```

`47 tests, 1 failure`

## Rows that stayed green, and why

- The pre-Gap-F suites (`detect_violations/2` Gap A/A', the exact-module and
  Erlang-atom `check_file/3` rows) do not move under any mutation above: they use
  `same_context: false`/absent, which routes through the `in_scope?/4` false-clause
  (`do: true`) that none of these mutations touch. This is the back-compat
  guarantee — the `/2` path is unchanged.
- Mutation B leaves row 6 green (dep context is `nil`), and mutation D leaves the
  cross-context rows green (their segment counts are `>= context_depth`, so the
  off-by-one take changes nothing) — each mutation isolates its own branch.

## Traps encountered

- None new. Confirmed the known `warnings_as_errors`-in-test trap by keeping every
  mutation reachable and variable-preserving; each run compiled and reported a
  real assertion failure, never a compile abort.
