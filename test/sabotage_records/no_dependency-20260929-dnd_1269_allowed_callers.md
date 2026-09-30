# Sabotage record — allowed_callers exemption (DND-1269)

- **Domain:** no_dependency
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.NoDependency.rule_dependencies/2`,
  `rule_calls/2`, `not_exempt/2`, `reachable_refs/2`;
  `Anchor.Domain.AllowedCallers.allows?/2`
- **Tests:** `test/anchor/domain/checks/no_dependency_allowed_callers_test.exs`
  (the table, run for each relation in both `match` modes; "the exemption is
  per rule"; "dynamic calls")
- **Suite run:** `mix test` (800 tests)
- **Merge base:** `origin/main` = c041060; **fix commit:** the DND-1269 commit on
  this branch
- **Other records (same run):** `dependency_analyzer-`, `lint-`,
  `rule_coverage-`, `rule_schema-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

The detector read file-wide sets only, so every exempt row failed in every
relation and mode:

```
the allowed caller itself: want [], got [2]
two modules in one file, both calling: only the unlisted one is reported: want [6], got [2]
an unlisted module nested in an allowed one: the parent's call after it is allowed: want [], got [6]
```

## Mutations

Each mutation was applied to the committed tree, the suite run, and the file
restored with `git checkout`. A mutation that left a binding unused failed to
compile under `--warnings-as-errors` and proved nothing; each was rewritten to
keep every binding used and run again. The rows below are the runs that
compiled. Failure strings are verbatim.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| N1 | `rule_dependencies/2` returns the file-wide set whatever `allowed_callers` says | 10 of 800 | `the allowed caller itself: want [], got [2]` |
| N2 | `rule_calls/2` returns the file-wide calls whatever `allowed_callers` says | 4 of 800 | test "every relation of the rule is exempt for the caller, and only for it": `Assertion with == failed` |
| N3 | a dynamic call site's owner is never allowed | 2 of 800 | test "a dynamic call exempt under one rule names only the rules that still apply": `Assertion with =~ failed` (`assert message =~ "(Other.Mod.f)"`) |
| N4 | `allows?/2` matches a namespace prefix instead of the exact module | 6 of 800 | `an unlisted module nested in an allowed one: the child's call is not allowed: want [3], got []` |
| N5 | `not_exempt/2` keeps the last line, not the first | 6 of 800 | `two unlisted modules calling: reported once, at the first line: want [2], got [6]` |

## Measured zero, closed

N5 first measured **0 of 800**: no row had two unlisted modules reaching one
target, so nothing pinned "the first line a module that is not exempt reaches
it". The row "two unlisted modules calling: reported once, at the first line"
was added, and N5 now fails 6.
