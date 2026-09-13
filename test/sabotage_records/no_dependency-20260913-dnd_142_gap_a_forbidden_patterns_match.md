# Sabotage record — Gap A + A', forbidden_patterns + match mode (DND-142)

- **Domain:** no_dependency
- **Branch:** dnd-142-gap-a-forbidden-patterns-match
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoDependency.detect_violations/2`, `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3`, `Anchor.Domain.DependencyAnalyzer.extract_call_dependencies/1`, `Anchor.Config.parse_rule/1` (`forbidden_patterns` / `match`)
- **Suite run:** `mix test test/anchor/domain/checks/no_dependency_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs test/anchor/domain/dependency_analyzer_test.exs test/anchor/domain/config_test.exs`
- **Merge base:** `git merge-base origin/main HEAD` = f8b1cba

> **ADR-003 note (one record for a multi-domain run).** ADR-003 nominally writes
> one file per domain, and this run touches four (`no_dependency`,
> `no_transitive_dependency`, `dependency_analyzer`, `config`). The Mission
> (DND-142) explicitly directed **ONE** record. Following the DND-141 precedent,
> it is filed under the primary domain `no_dependency` — the check where both
> Gap A (`forbidden_patterns`) and Gap A′ (`match`) manifest as observable
> behavior — and every mutation to the other three units is included below,
> clearly labelled, so no mutation is lost. All four test files' "Sabotage
> record:" comments point here.

## Mutations

| # | Mutation | Suite run against | Tests failed | Notes |
|---|---|---|---|---|
| A | Delete the `forbidden_patterns` filter from `NoDependency.forbidden?/3` (drop the `or matches_any_pattern?(...)` branch, the helper, and the `GlobPattern` alias) | no_dependency test | **5** | re-reds no_dependency rows 1, 4, 5, 6, 8 |
| B | Delete the `forbidden_patterns` filter from `NoTransitiveDependency` (same shape) | no_transitive test | **2** | re-reds no_transitive rows 1, 3 |
| C1 | Add an inert-alias-recording clause to `collect_call_deps` (so `extract_call_dependencies/1` records references like `extract_direct_dependencies/1`) | analyzer test | **2** | re-reds extract_call_dependencies rows 3, 6 |
| C2 | Make the typespec-skip clause **descend** instead of returning `acc` (so a typespec body's aliases are walked) | analyzer test | **1** | re-reds extract_call_dependencies row 4 |
| C3 | Point `NoDependency.dependencies_for(ast, :call)` at `extract_direct_dependencies/1` | no_dependency test | **1** | re-reds no_dependency row 7 |
| D | Force `Config.parse_rule/1` `forbidden_patterns` to `[]` (drop `rule["forbidden_patterns"] \|\| []`) | config test | **2** | re-reds parse_rule rows 1, 12 |
| E | Delete the `parse_match("call")` clause (so `"call"` falls through to `:reference`) | config test | **1** | re-reds parse_rule row 6 |

Each mutation was applied and measured **separately** (with the other mutations'
production code intact), then reverted with `git checkout -- <file>`. The
implementation was committed **before** sabotage (commit `8019b75`), so
`git checkout` restores the real implementation, not a blank (ADR-002 trap: an
uncommitted impl reverts to HEAD and reads as a false zero).

### Compile-clean constraint (why C is decomposed into C1/C2/C3)

`mix test` compiles with `--warnings-as-errors`, so a mutation must not orphan
code. The Mission predicted a single "point `:call` mode at
`extract_direct_dependencies`" mutation re-redding no_dependency row 7 **and**
extract_call_dependencies rows 3, 4, 6. Rewriting `extract_call_dependencies/1`
to literally delegate to `extract_direct_dependencies/1` orphans the entire
call-walk (`collect_call_deps/3` and its helpers, the `@type_attributes` module
attribute), which fails compilation under `--warnings-as-errors` before any test
runs. The literal mutation is therefore **decomposed** into the three minimal,
compile-clean mutations that each isolate one carve-out claim and collectively
re-red exactly the predicted rows: C1 (inert map value + plain reference not
recorded → rows 3, 6), C2 (typespec body skipped → row 4), C3 (`:call` mode
consults the call set → no_dependency row 7). This is a mechanics deviation from
the prediction's phrasing, not a coverage gap — the predicted rows all re-red.

### Prediction vs. measured reality (dot-bounded negative rows)

The Mission predicted Mutation A (delete the pattern filter) would re-red
no_dependency rows **1, 3, 4, 5** and Mutation B would re-red no_transitive rows
**1, 3, 4**. Measured reality differs on the **dot-bounded negative rows**
(no_dependency row 3, no_transitive row 4):

- Those rows assert `[]` for a near-miss name (`Foo.AdaptersHelper` vs
  `*.Adapters.*`). Deleting the pattern **filter** makes the pattern contribute
  nothing, so a rule with empty `forbidden_modules` yields `[]` — which is
  exactly what those rows already assert. They stay **green**, so they cannot
  re-red under Mutation A/B. Their dot-bounding is protected by
  `Anchor.Domain.GlobPattern.matches_module_pattern?/2` (whose own dot-escaping
  is sabotaged in `glob_pattern-20260913-dnd_122_t2_domain_patterns.md`), not by
  the check's filter.
- Conversely, Mutation A additionally re-reds no_dependency rows **6 and 8**
  (the `match: :reference` inert-reference row and the `match: :call` real-call
  row), which the prediction did not enumerate but which are pattern-positive
  rows the filter genuinely protects.

Measured truth: **A → rows 1, 4, 5, 6, 8**; **B → rows 1, 3**. Recorded as
measured, honesty over matching the prediction.

### Mutation A — verbatim failures

Suite: `mix test test/anchor/domain/checks/no_dependency_test.exs`

```
  1) test detect_violations/2 — forbidden_patterns and match (Gap A + A') a pattern-matched module referenced twice is reported once at the first line (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:99
     match (=) failed
     code:  assert [%Violation{} = violation] = detect(source, rule)
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:110: (test)

  2) test detect_violations/2 — forbidden_patterns and match (Gap A + A') match: :reference flags an inert alias held as a map value (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:117
     match (=) failed
     code:  assert [%Violation{} = violation] = detect(source, rule)
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:126: (test)

  3) test detect_violations/2 — forbidden_patterns and match (Gap A + A') match: :call flags a real call on the forbidden pattern (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:146
     match (=) failed
     code:  assert [%Violation{} = violation] = detect(source, rule)
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:155: (test)

  4) test detect_violations/2 — forbidden_patterns and match (Gap A + A') forbidden_modules and forbidden_patterns both fire (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:75
     Assertion with == failed
     code:  assert length(violations) == 2
     left:  1
     right: 2
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:91: (test)

  5) test detect_violations/2 — forbidden_patterns and match (Gap A + A') forbidden_patterns flags a matching dependency (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:28
     match (=) failed
     code:  assert [%Violation{} = violation] = detect(source, rule)
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:39: (test)

Finished in 0.04 seconds (0.04s async, 0.00s sync)
10 tests, 5 failures
```

### Mutation B — verbatim failures

Suite: `mix test test/anchor/domain/checks/no_transitive_dependency_test.exs`

```
  1) test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter (Anchor.Domain.Checks.NoTransitiveDependencyTest)
     test/anchor/domain/checks/no_transitive_dependency_test.exs:254
     match (=) failed
     code:  assert [%Violation{} = violation] =
              NoTransitiveDependency.detect_violations(
                a_refs_b(),
                [pattern_rule(["*.Adapters.*"])],
                modules_map
              )
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_transitive_dependency_test.exs:260: (test)

  2) test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively (Anchor.Domain.Checks.NoTransitiveDependencyTest)
     test/anchor/domain/checks/no_transitive_dependency_test.exs:289
     Assertion with == failed
     code:  assert length(violations) == 2
     left:  1
     right: 2
     stacktrace:
       test/anchor/domain/checks/no_transitive_dependency_test.exs:304: (test)

Finished in 0.07 seconds (0.07s async, 0.00s sync)
13 tests, 2 failures
```

### Mutation C1 — verbatim failures

`collect_call_deps` given an inert `{:__aliases__, _, parts}` recording clause,
so `extract_call_dependencies/1` records references (like the direct walk).

Suite: `mix test test/anchor/domain/dependency_analyzer_test.exs`

```
  1) test extract_call_dependencies/1 — call-position only (Gap A' / DND-142) does not record an inert alias held as a map value (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:377
     Refute with in failed
     code:  refute Foo.Adapters.Loader in DependencyAnalyzer.extract_call_dependencies(
              ast("%{yaml: Foo.Adapters.Loader}")
            )
     left:  Foo.Adapters.Loader
     right: [Foo.Adapters.Loader]
     stacktrace:
       test/anchor/domain/dependency_analyzer_test.exs:378: (test)

  2) test extract_call_dependencies/1 — call-position only (Gap A' / DND-142) does not record a plain alias reference (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:399
     Refute with in failed
     code:  refute Foo.Bar in DependencyAnalyzer.extract_call_dependencies(ast("x = Foo.Bar"))
     left:  Foo.Bar
     right: [Foo.Bar]
     stacktrace:
       test/anchor/domain/dependency_analyzer_test.exs:400: (test)

Finished in 0.06 seconds (0.06s async, 0.00s sync)
48 tests, 2 failures
```

### Mutation C2 — verbatim failures

The typespec-skip clause made to descend into the attribute body instead of
returning `acc`, so `@spec f(Foo.Bar.t()) :: :ok`'s `Foo.Bar.t()` call is
recorded.

Suite: `mix test test/anchor/domain/dependency_analyzer_test.exs`

```
  1) test extract_call_dependencies/1 — call-position only (Gap A' / DND-142) does not record an alias inside a typespec (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:385
     Refute with in failed
     code:  refute Foo.Bar in DependencyAnalyzer.extract_call_dependencies(ast("@spec f(Foo.Bar.t()) :: :ok"))
     left:  Foo.Bar
     right: [Foo.Bar]
     stacktrace:
       test/anchor/domain/dependency_analyzer_test.exs:386: (test)

Finished in 0.05 seconds (0.05s async, 0.00s sync)
48 tests, 1 failure
```

### Mutation C3 — verbatim failures

`dependencies_for(ast, :call)` pointed at `extract_direct_dependencies/1`, so the
`:call`-mode carve-out no longer holds and the inert map value is flagged.

Suite: `mix test test/anchor/domain/checks/no_dependency_test.exs`

```
  1) test detect_violations/2 — forbidden_patterns and match (Gap A + A') match: :call passes an inert alias held as a map value (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:133
     Assertion with == failed
     code:  assert detect(source, rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "Foo.Adapters.L",
                message: "Module has forbidden direct dependency on Foo.Adapters.L"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/checks/no_dependency_test.exs:142: (test)

Finished in 0.04 seconds (0.04s async, 0.00s sync)
10 tests, 1 failure
```

### Mutation D — verbatim failures

`Config.parse_rule/1` forced to surface `forbidden_patterns: []` regardless of
input.

Suite: `mix test test/anchor/domain/config_test.exs`

```
  1) test parse_rule/1 — forbidden_patterns and match (Gap A + A' / DND-142) forbidden_patterns and forbidden_modules coexist on one rule (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:250
     Assertion with == failed
     code:  assert rule.forbidden_patterns == ["*.Adapters.*"]
     left:  []
     right: ["*.Adapters.*"]
     stacktrace:
       test/anchor/domain/config_test.exs:258: (test)

  2) test parse_rule/1 — forbidden_patterns and match (Gap A + A' / DND-142) surfaces forbidden_patterns as a list (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:202
     Assertion with == failed
     code:  assert rule.forbidden_patterns == ["*.Adapters.*"]
     left:  []
     right: ["*.Adapters.*"]
     stacktrace:
       test/anchor/domain/config_test.exs:209: (test)

Finished in 0.06 seconds (0.06s async, 0.00s sync)
29 tests, 2 failures
```

### Mutation E — verbatim failures

The `parse_match("call")` clause deleted, so `"call"` falls through to the
`:reference` default.

Suite: `mix test test/anchor/domain/config_test.exs`

```
  1) test parse_rule/1 — forbidden_patterns and match (Gap A + A' / DND-142) match: "call" is coerced to :call (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:227
     Assertion with == failed
     code:  assert rule.match == :call
     left:  :reference
     right: :call
     stacktrace:
       test/anchor/domain/config_test.exs:230: (test)

Finished in 0.06 seconds (0.06s async, 0.00s sync)
29 tests, 1 failure
```

(Elixir additionally prints a compile-time "comparison between distinct types"
warning for the `:reference == :call` assertion under this mutation; it is the
type checker observing that the mutated code makes the two operands disjoint,
not a second test failure.)

## Measured zeros

None. Every claim the fix adds is protected by at least one test that reddens
under the corresponding mutation:

- `forbidden_patterns` filter in `NoDependency` → rows 1, 4, 5, 6, 8 (Mutation A);
- `forbidden_patterns` filter in `NoTransitiveDependency` → rows 1, 3 (Mutation B);
- call-position-only recording (inert refs skipped) → extract_call rows 3, 6 (C1);
- typespec bodies skipped → extract_call row 4 (C2);
- `:call` mode consults the call set → no_dependency row 7 (C3);
- `forbidden_patterns` parsed/surfaced → parse_rule rows 1, 12 (D);
- `match` token coerced → parse_rule row 6 (E).

The dot-bounded negative rows (no_dependency row 3, no_transitive row 4) are
**not** measured zeros for this change: their guarantee belongs to
`GlobPattern.matches_module_pattern?/2` and is sabotaged in that module's own
record (`glob_pattern-20260913-dnd_122_t2_domain_patterns.md`). Here they serve
as positive controls that the check delegates dot-bounding to the glob matcher
rather than re-implementing it.

## Traps encountered

- **`--warnings-as-errors` under `mix test`** — a mutation may not orphan code
  (unused private fn / module attr / alias fails compilation before tests run).
  The "delete the filter" mutations (A, B) therefore also drop the now-unused
  helper and `GlobPattern` alias in the same edit, and the "point `:call` at
  `extract_direct`" prediction is decomposed into C1/C2/C3 rather than a literal
  delegation (see the compile-clean note above).
- **Commit-before-sabotage** (ADR-002): the implementation was committed at
  `8019b75` before any mutation, so `git checkout -- <file>` restores the real
  code, not the pre-impl HEAD.
- **`to_string/1` of a module keeps the `Elixir.` prefix** — a pattern match runs
  against `"Elixir.WaltUi.…Adapters.…"`, which is fine because a `*` in a
  module-name glob crosses dots; this matches the matrix's `module_names`
  convention (`"Elixir.App.Schemas.User"`).
