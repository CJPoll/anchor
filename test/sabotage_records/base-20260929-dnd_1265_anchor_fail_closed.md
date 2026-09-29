# Sabotage record — the Framework reports what it could not check (DND-1265)

- **Domain:** base
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Base` (`shared_failure_reporter?/2`, the
  generated `run_on_all_source_files/3`, `check_file/3`,
  `config_failure_issues/2`, `issue_opts/1`)
- **Suite run:** `mix test` (the whole suite, 530 tests)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `failures-`, `lint-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

`base` is a new domain word: the shared Framework layer every check `use`s,
which no single check owns.

## Fail-first run

Against 8cff72b, verbatim. These drive the real entry point Credo calls,
`run_on_all_source_files/3`, and read every issue in the execution:

```
 38) test no configuration present (A6) reports one issue naming the searched path, with a Fix: line (Anchor.E2E.ChecksE2ETest)
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 34) test config load error (A7) malformed YAML is one issue on the config file, not a skip (Anchor.E2E.ChecksE2ETest)
     ** (MatchError) no match of right hand side value:
         %Credo.Execution{
     (the error branch returned `exec` and appended nothing)

 33) test config load error (A7) an unknown rule type (A8) is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     left:  [issue]
     right: []

 37) test config load error (A7) an unknown match token (A9) is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     left:  [issue]
     right: []

 35) test unparseable source file (A9) a file anchor cannot parse is an issue on that file (Anchor.E2E.ChecksE2ETest)
     left:  [issue]
     right: []

 36) test one failure report per run only the first enabled Anchor check reports a config failure (Anchor.E2E.ChecksE2ETest)
     left:  [issue]
     right: []

 30) test check_file/3 on an unparseable file returns an issue on that file instead of no issues (Anchor.Check.BaseTest)
     code:  assert [issue] = NoDependency.check_file(broken, [rule], [])
     left:  [issue]
     right: []
```

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| N | `config_failure_issues(reason, true)` returns `[]` (the A7 defect) | 5 | `code: assert [issue] = issues` / `left: [issue]` / `right: []` (malformed YAML, unknown match, unknown type, one-per-run, no config) |
| O | every Anchor check is the reporter | 3 | `Expected false or nil, got true` / `code: refute Base.shared_failure_reporter?(exec, MustUseModule)`; e2e one-per-run: `left: [issue]` / `right: [` (two issues) |
| P | a check not in the run list never reports | 7 | `Expected truthy, got false` / `code: assert Base.shared_failure_reporter?(Credo.Execution.build(), NoDependency)`; five e2e rows `left: [issue]` / `right: []` |
| Q | `check_file/3` returns `[]` for an unparseable file | 1 | `code: assert [issue] = NoDependency.check_file(broken, [rule], [])` / `left: [issue]` / `right: []` |
| R | fail-closed issues keep the check's own priority | 2 | `assert issue.priority == Credo.Priority.to_integer(:higher)` / `left: 0` / `right: 20` |

No measured zeros.

## Live check

A real `mix credo --strict` on Anchor's own tree, with its two Anchor checks
enabled: no `.anchor.yml`, malformed YAML and an unknown rule type each printed
exactly one issue on `.anchor.yml` and exited 2. The intact config exited 0.
An unparseable file under `test/` never reached Anchor: Credo printed
`Some source files could not be parsed correctly and are excluded` and exited 0.
That is Credo's own pre-filter, documented in the README.
