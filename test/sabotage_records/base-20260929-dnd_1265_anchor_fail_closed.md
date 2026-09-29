# Sabotage record — the Framework reports what it could not check (DND-1265)

- **Domain:** base
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Base` (`shared_failure_reporter?/2`,
  `enabled_anchor_check/1`, the generated `run_on_all_source_files/3`,
  `check_file/3`, `config_failure_issues/2`, `issue_opts/1`)
- **Suite run:** `mix test` (the whole suite; 530 tests in round 1, 534 in round 2)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `failures-`, `lint-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

`base` is a new domain word: the shared Framework layer every check `use`s,
which no single check owns.

## Fail-first run

Against 8cff72b, verbatim. These drive the real entry point Credo calls,
`run_on_all_source_files/3`, and read every issue in the execution:

```
 38) test no configuration present (A6) reports one issue naming the searched path, with a Fix: line (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 34) test config load error (A7) malformed YAML is one issue on the config file, not a skip (Anchor.E2E.ChecksE2ETest)
     ** (MatchError) no match of right hand side value:
         %Credo.Execution{
           argv: [],
           cli_options: nil,
           ...

 33) test config load error (A7) an unknown rule type (A8) is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 37) test config load error (A7) an unknown match token (A9) is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 35) test unparseable source file (A9) a file anchor cannot parse is an issue on that file (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 36) test one failure report per run only the first enabled Anchor check reports a config failure (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 30) test check_file/3 on an unparseable file returns an issue on that file instead of no issues (Anchor.Check.BaseTest)
     match (=) failed
     code:  assert [issue] = NoDependency.check_file(broken, [rule], [])
     left:  [issue]
     right: []
```

Row 34's `MatchError` is the helper's `:ok = check.run_on_all_source_files(...)`:
on 8cff72b the config-error branch returned the `exec` struct, not `:ok`, and
appended no issue.

The `shared_failure_reporter?/2` rows in `base_test.exs` failed first only
because the function did not exist:

```
 27) test shared_failure_reporter?/2 the first enabled Anchor check in the run is the reporter (Anchor.Check.BaseTest)
     ** (UndefinedFunctionError) function Anchor.Check.Base.shared_failure_reporter?/2 is undefined or private
```

That is not a behavioural failure, so each row is proven by a mutation below.

"A9" in the e2e describe names follows the design doc's defect table, where A9
covers both the unknown `match` token and the parse error that yielded an empty
AST.

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| N | `config_failure_issues(reason, true)` returns `[]` (the A7 defect) | 5 | `code: assert [issue] = issues` / `left: [issue]` / `right: []` (malformed YAML, unknown match, unknown type, one-per-run, no config) |
| O | every Anchor check is the reporter | 3 | `Expected false or nil, got true` / `code: refute Base.shared_failure_reporter?(exec, MustUseModule)` (first-enabled and `{module}` rows); e2e one-per-run: `code: assert [issue] = issues` / `left: [issue]` / `right: [` followed by two `%Credo.Issue{}` structs (the capture kept the first line) |
| P | a check not in the run list never reports | 7 | `Expected truthy, got false` / `code: assert Base.shared_failure_reporter?(Credo.Execution.build(), NoDependency)`; five e2e rows `left: [issue]` / `right: []` |
| Q | `check_file/3` returns `[]` for an unparseable file | 1 | `code: assert [issue] = NoDependency.check_file(broken, [rule], [])` / `left: [issue]` / `right: []` |
| R | fail-closed issues keep the check's own priority | 2 | `code: assert issue.priority == Credo.Priority.to_integer(:higher)` / `left: 0` / `right: 20` |
| AB | drop the `{_module, false}` clause, so a disabled check counts | 1 | `Expected truthy, got false` / `code: assert Base.shared_failure_reporter?(exec, MustUseModule)` (the `false`-params row) |
| AC | read `exec.checks.enabled` directly, ignoring `--checks` / `--ignore-checks` | 2 | `Expected truthy, got false` / `code: assert Base.shared_failure_reporter?(exec, MustUseModule)` (the `only_checks` and `ignore_checks` rows) |
| AD | drop the fallback clause for an unexpected check-list shape | 13 | `** (FunctionClauseError) no function clause matching in Anchor.Check.Base.shared_failure_reporter?/2` / `code: assert Base.shared_failure_reporter?(exec, NoDependency)`; every e2e row, because `Credo.Execution.build()` has `checks: nil` |

N to R ran in round 1 (530 tests); AB, AC and AD in round 2 (534 tests), with
the rows the review round added (`only_checks`, the unexpected shape, and the
e2e once-per-run row for an unparseable file).

No measured zeros.

## Rows that stayed green, and why

- Under O, the "not listed" and "no check list" rows stay green: they expect
  `true`, which O returns everywhere.
- Under P, the "first enabled" rows stay green: P changes only the unlisted
  case.
- Under AB and AC, the e2e rows stay green: their executions list no disabled
  check and set no `--checks` filter.

## Traps

- The first run of O reported `NO COUNT LINE`: replacing both `case` clauses
  with `_listed -> true` made `check` unused, and `mix test` compiles with
  `--warnings-as-errors`. It was rewritten as `listed -> is_list(listed)` and
  re-run.
- Every run started from a committed tree; the driver restored each file with
  `git checkout -- <file>`, and `git status --short` was clean after each batch.

## Live check

A real `mix credo --strict` on Anchor's own tree, with its two Anchor checks
enabled: no `.anchor.yml`, malformed YAML and an unknown rule type each printed
exactly one issue on `.anchor.yml` and exited 2. The intact config exited 0.
An unparseable file under `test/` never reached Anchor: Credo printed
`Some source files could not be parsed correctly and are excluded` and exited 0.
That is Credo's own pre-filter, documented in the README.
