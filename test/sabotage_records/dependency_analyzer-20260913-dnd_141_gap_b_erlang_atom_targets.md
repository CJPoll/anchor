# Sabotage record — Gap B, Erlang-atom module targets (DND-141)

- **Domain:** dependency_analyzer
- **Branch:** dnd-141-gap-b-erlang-atom-targets
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.DependencyAnalyzer.extract_direct_dependencies/1`, `Anchor.Config.parse_modules/1` (via `parse_rule/1`), `Anchor.Domain.Checks.NoDependency.first_reference_line/2`
- **Suite run:** `mix test test/anchor/domain/dependency_analyzer_test.exs test/anchor/domain/config_test.exs test/anchor/check/no_dependency_test.exs`
- **Merge base:** `git merge-base origin/main HEAD` = 363892e

> ADR-003 note: a run "spanning two domains writes two files, split by domain."
> This Gap-B run touches `dependency_analyzer` and `config`, which would nominally
> be two records. The Mission (DND-141) explicitly directed **ONE** record for the
> Gap-B run; it is filed under the primary domain `dependency_analyzer` (the core
> change) and the `config` mutation is included below, clearly labelled, so no
> mutation is lost. Decision recorded here rather than silently split.

## Mutations

| # | Mutation | Suite run against | Tests failed | Notes |
|---|---|---|---|---|
| A | Delete the bare-atom remote-call callee clause `defp collect_deps({{:., _dmeta, [mod, _fun]}, _meta, args}, ...) when is_atom(mod)` from `DependencyAnalyzer` | analyzer + no_dependency test files | **4** | re-reds extract_direct_dependencies rows 1, 5, 6 + the wired-check integration row |
| B | Revert `Config.parse_modules` to `Enum.map(modules, &Module.concat([&1]))` (drop the leading-colon `parse_module_token/1` branch) | config test file | **3** | re-reds parse_rule rows 9, 11 + the required_modules symmetry row |

Mutation A and Mutation B were applied and measured **separately** (each with the
other's production code intact), then reverted with `git checkout -- <file>`. The
implementation was committed **before** sabotage, so `git checkout` restores the
real implementation, not a blank (ADR-002 trap: an uncommitted impl reverts to
HEAD and reads as a false zero).

### Mutation A — verbatim failures

`extract_direct_dependencies/1` no longer records a bare-atom remote-call callee.

Row 1 — "a bare-atom remote call records the atom module":

```
  3) test extract_direct_dependencies/1 — bare-atom remote-call callees (Gap B / DND-141) a bare-atom remote call records the atom module (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:308
     Assertion with in failed
     code:  assert :telemetry in DependencyAnalyzer.extract_direct_dependencies(
              ast(":telemetry.execute([:a], %{}, %{})")
            )
     left:  :telemetry
     right: []
```

Row 5 — "an atom call and an alias call are both recorded":

```
     Assertion with in failed
     code:  assert :telemetry in deps
     left:  :telemetry
     right: [MyApp.Repo]
       test/anchor/domain/dependency_analyzer_test.exs:343: (test)
```

Row 6 — "the atom callee is keyed as the raw atom, not an Elixir.-prefixed module":

```
  2) test extract_direct_dependencies/1 — bare-atom remote-call callees (Gap B / DND-141) the atom callee is keyed as the raw atom, not an Elixir.-prefixed module (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:348
     Assertion with in failed
     code:  assert :cowboy in deps
     left:  :cowboy
     right: []
```

Integration (wired check) — "an atom forbidden module flags a bare-atom remote call at its first line":

```
  4) test check_file/3 — Erlang-atom forbidden module (Gap B / DND-141, integration) an atom forbidden module flags a bare-atom remote call at its first line (Anchor.Check.NoDependencyTest)
     test/anchor/check/no_dependency_test.exs:140
     match (=) failed
     code:  assert [issue] = issues(source, [:telemetry])
     left:  [issue]
     right: []
```

Result: `53 tests, 4 failures`.

### Mutation B — verbatim failures

`Config.parse_modules` runs every token through `Module.concat`, so a
leading-colon atom token is mangled into `:"Elixir.:telemetry"`.

Row 9 — "a leading-colon forbidden_modules token is kept as a raw atom":

```
  2) test parse_rule/1 — Erlang-atom module tokens (Gap B / DND-141) a leading-colon forbidden_modules token is kept as a raw atom (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:146
     Assertion with == failed
     code:  assert rule.forbidden_modules == [:telemetry]
     left:  [:"Elixir.:telemetry"]
     right: [:telemetry]
```

Row 11 — "a mixed atom + module forbidden_modules list is preserved element-wise":

```
  1) test parse_rule/1 — Erlang-atom module tokens (Gap B / DND-141) a mixed atom + module forbidden_modules list is preserved element-wise (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:160
     Assertion with == failed
     code:  assert rule.forbidden_modules == [:telemetry, MyApp.Repo]
     left:  [:"Elixir.:telemetry", MyApp.Repo]
     right: [:telemetry, MyApp.Repo]
```

required_modules symmetry — "a leading-colon required_modules token is kept as a raw atom":

```
  3) test parse_rule/1 — Erlang-atom module tokens (Gap B / DND-141) a leading-colon required_modules token is kept as a raw atom (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:167
     Assertion with == failed
     code:  assert rule.required_modules == [:cowboy, MyApp.Schema]
     left:  [:"Elixir.:cowboy", MyApp.Schema]
     right: [:cowboy, MyApp.Schema]
```

Result: `20 tests, 3 failures`.

## Rows that stayed green under Mutation B, and why

- **parse_rule row 10** ("an ordinary CamelCase forbidden_modules token still
  becomes a module atom", `"MyApp.Repo" -> MyApp.Repo`) stays green under Mutation
  B: `Module.concat(["MyApp.Repo"])` yields the same `MyApp.Repo` whether or not
  the leading-colon branch exists, so it protects the Elixir-alias path, not the
  atom path. This is exactly why rows 9 and 11 (the atom-token rows) are the
  load-bearing coverage for the Gap-B config change.

## Measured zeros

None. Every claim the fix adds is protected by at least one test that reddens
under the corresponding mutation (analyzer rows 1/5/6 + integration under A;
config rows 9/11 + required_modules under B).

## Traps encountered

- **Commit-before-sabotage** (ADR-002): the implementation was committed before
  applying any mutation, so `git checkout -- <file>` restores the real code. A
  mutation on an uncommitted impl would revert to HEAD (the pre-impl state) and
  read as a spurious zero.
- **`Elixir.<atom>` is not the atom** (test authoring): asserting `refute
  Elixir.cowboy in deps` would compile `Elixir.cowboy` as a remote-call AST node,
  not the mangled atom. Row 6 asserts `refute Module.concat(["cowboy"]) in deps`
  to name the actual `:"Elixir.cowboy"` mangling the fix prevents.
