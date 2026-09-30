# Sabotage record — missing allowed callers in the run (DND-1269)

- **Domain:** lint
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Managers.Lint.floor_violations/4`,
  `put_defined_modules/4`, `lists_allowed_callers?/2`;
  `Anchor.Domain.Failures.missing_allowed_callers_violation/3`
- **Tests:** `test/anchor/managers/lint_test.exs` ("run/4 allowed callers that
  no selected file defines"), `test/anchor/e2e/checks_e2e_test.exs`
  ("allowed_callers through the real pipeline")
- **Suite run:** `mix test` (800 tests); re-run one mutation with
  `mix test test/anchor/managers/lint_test.exs`
- **Merge base:** `origin/main` = c041060; **mutated tree:** 5ce9ad7 (the
  branch's final code)
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

The rule failed the load, so the e2e test saw only the config issue:

```
unknown key "allowed_callers" in a no_direct_dependency rule
```

The Manager test reported the allowed caller as a violation:
`{%SourceFile<lib/adapter.ex>, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Repo", ...}]}`.

## Mutations

Failure text is verbatim. A `%Violation{}` is abbreviated to its `trigger`,
`kind` and the start of its `message`.

| # | Mutation | Failed |
|---|---|---|
| L1 | the Manager never reports a missing allowed caller | 2 of 800 |
| L2 | file facts never carry `defined_modules`, so every caller reads as missing | 3 of 800 |
| L3 | missing callers are reported on a partial run too | 1 of 800 |

**L1**, test "a missing caller is one fail-closed violation on the config,
naming it". There is no `{:config, _}` entry:

```
match (=) failed
left:  {:ok, [{^adapter, []}, {^other, [_repo]}, config: [violation]]}
right: {:ok, [{%SourceFile<lib/adapter.ex>, []}, {%SourceFile<lib/other.ex>, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Repo", kind: :rule, ...}]}]}
```

**L2**, test "the allowed caller is exempt, the other caller is reported". The
caller that exists is reported as missing:

```
match (=) failed
left:  {:ok, [{^adapter, []}, {^other, [%Anchor.Domain.Violation{trigger: "MyApp.Repo", line: 2}]}]}
right: {:ok, [..., {:config, [%Anchor.Domain.Violation{trigger: "rule 1 (id: \"repo-via-adapter\", no_direct_dependency)", kind: :fail_closed, message: "Anchor rule 1 (id: \"repo-via-adapter\", no_direct_dependency) lists MyApp.Adapter in allowed_callers, but no file it selects defines it, ..."}]}]}
```

**L3**, test "a partial file set (enforce_selection_floors: false) reports no
missing caller":

```
match (=) failed
left:  {:ok, [{^other, [_repo]}]}
right: {:ok, [{%SourceFile<lib/other.ex>, [...]}, {:config, [%Anchor.Domain.Violation{... lists MyApp.Adapter in allowed_callers, but no file it selects defines it, ...}]}]}
```
