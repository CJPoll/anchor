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
- **Suite run:** `mix test` (800 tests); re-run one mutation with
  `mix test test/anchor/domain/checks/no_dependency_allowed_callers_test.exs`
- **Merge base:** `origin/main` = c041060; **mutated tree:** 5ce9ad7 (the
  branch's final code)
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
compile under `--warnings-as-errors` and proved nothing. Each was rewritten to
keep every binding used, and run again. The table lists the runs that compiled.
Failure text is verbatim. Which test ExUnit prints first depends on its random
seed.

| # | Mutation | Failed |
|---|---|---|
| N1 | `rule_dependencies/2` returns the file-wide set whatever `allowed_callers` says | 10 of 800 |
| N2 | `rule_calls/2` returns the file-wide calls whatever `allowed_callers` says | 4 of 800 |
| N3 | a dynamic call site's owner is never allowed | 2 of 800 |
| N4 | `allows?/2` matches a namespace prefix instead of the exact module | 6 of 800 |
| N5 | `not_exempt/2` keeps the last line, not the first | 6 of 800 |

**N1**, test "allowed_callers with forbidden_modules (match: reference) every
row reports exactly its expected lines":

```
the allowed caller itself: want [], got [2]
two modules in one file, both calling: only the unlisted one is reported: want [6], got [2]
the allowed caller spelled through __MODULE__ in its parent: want [], got [3]
```

**N2**, test "every relation of the rule is exempt for the caller, and only for
it":

```
Assertion with == failed
left:  [{"Bad.Repo", 7}, {"Bad.Repo.insert/1", 3}]
right: [{"Bad.Repo", 7}, {"Bad.Repo.insert/1", 7}]
```

**N3**, test "a dynamic call in the allowed caller is not reported":

```
Assertion with == failed
code:  assert dynamic_lines(source, [ff_rule(@refs, [App.Allowed])]) == []
left:  [2]
right: []
```

**N4**, the forbidden_patterns table:

```
an unlisted module nested in an allowed one: the child's call is not allowed: want [3], got []
a child namespace of the allowed caller is not the caller: want [2], got []
```

**N5**, the forbidden_modules table:

```
two unlisted modules calling: reported once, at the first line: want [2], got [6]
```

## Measured zero, closed

N5 first measured **0 of 800**. No row had two unlisted modules reaching one
target, so nothing pinned "the first line a module that is not exempt reaches
it". The row "two unlisted modules calling: reported once, at the first line"
was added, and N5 now fails 6.
