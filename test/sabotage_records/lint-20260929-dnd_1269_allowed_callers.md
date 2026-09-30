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
- **Suite run:** `mix test` (800 tests)
- **Merge base:** `origin/main` = c041060; **fix commit:** the DND-1269 commit on
  this branch
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

The rule failed the load, so the e2e test saw only the config issue:

```
unknown key "allowed_callers" in a no_direct_dependency rule
```

and the Manager test reported the allowed caller as a violation
(`{%SourceFile<lib/adapter.ex>, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Repo", ...}]}`).

## Mutations

| # | Mutation | Failed | First failure |
|---|---|---|---|
| L1 | the Manager never reports a missing allowed caller | 2 of 800 | test "a missing caller is one fail-closed violation on the config, naming it": `match (=) failed` |
| L2 | file facts never carry `defined_modules` (every caller reads as missing) | 3 of 800 | same test: `Assertion with =~ failed` on `lists MyApp.RenamedAdapter in allowed_callers` (the message named both entries) |
| L3 | missing callers reported on a partial run too | 1 of 800 | test "a partial file set (enforce_selection_floors: false) reports no missing caller": `match (=) failed` |
