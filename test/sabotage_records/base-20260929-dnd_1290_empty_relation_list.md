# Sabotage record — whole file set and enabled rule types (DND-1290)

- **Domain:** base
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Base.whole_file_set?/2`,
  `enabled_rule_types/1` and `lint_opts/3`, new in this run
- **Tests:** `test/anchor/check/base_test.exs` ("whole_file_set?/2",
  "enabled_rule_types/1"), and the e2e rows "a run over explicit files does not
  apply the floor" and "a rule whose check is not enabled"
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

## Fail-first run (unfixed 044f5ae)

All 11 Base rows failed because the functions did not exist:

```
 21) test whole_file_set?/2 a subdirectory path is a subset (Anchor.Check.BaseTest)
     ** (UndefinedFunctionError) function Anchor.Check.Base.whole_file_set?/2 is undefined or private
```

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| R | `whole_file_set?/2` ignores files named on the command line | 1 | `Expected false or nil, got true` / `code: refute Base.whole_file_set?(exec_with_cli(File.cwd!(), %{files_included: ["lib/a.ex"]}), [])` |
| S | `enabled_rule_types/1` ignores `--checks`/`--ignore-checks` | 1 | `code: assert Base.enabled_rule_types(%{base \| only_checks: ["NoDependency"]}) == :unknown` / `left: {:ok, [:no_direct_dependency]}` |
| T | `whole_file_set?/2` ignores stdin | 1 | `Expected false or nil, got true` / `code: refute Base.whole_file_set?(exec, [])` |

## Review round (fail-first, then mutation)

The code review found that `--files-excluded` (which replaces the configured
exclude list) still read as the whole file set, so a rule over the excluded
directory would get a false floor issue. It also asked for tests over argv
parsed by Credo itself (`Credo.CLI.Options.parse/9`), not hand-built options.
Run against the pre-fix branch head: `631 tests, 6 failures`, including

```
  6) test whole_file_set?/2 over Credo-parsed argv --files-excluded is a subset (Anchor.Check.BaseTest)
     Expected false or nil, got true
     code: refute Base.whole_file_set?(exec_from_argv(["--files-excluded", "lib/anchor.ex"]), [])
```

The parsed-argv rows for a bare run, a named file, a subdirectory and
`--working-dir` passed first time: Credo records those shapes as assumed.
After the fix: `631 tests, 0 failures`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| W | `whole_file_set?/2` ignores `--files-excluded` | 2 | `whole_file_set?/2 over Credo-parsed argv --files-excluded is a subset`: `Expected false or nil, got true` |

A live run confirmed the whole-set path: with a probe rule selecting
`lib/nowhere/`, a real `mix credo --strict` printed `Anchor rule 4 (id:
"live-probe", no_direct_dependency) selected 0 of the 80 files this check ran
on, ...` and exited 2; `mix credo --strict lib/anchor.ex` printed no floor
issue and exited 0. The probe rule was then removed.
