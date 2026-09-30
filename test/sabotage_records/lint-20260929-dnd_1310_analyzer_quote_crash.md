# Sabotage record — an analysis crash is a per-file issue (DND-1310)

- **Domain:** lint
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Managers.Lint`: `guarded/2`, `detect_file/5`,
  the facts guard in `result_for_parse/3`, the graph guard in
  `put_module_analyses/3`
- **Tests:** `test/anchor/managers/lint_analysis_crash_test.exs` (an injected
  exception), `test/anchor/managers/lint_variable_names_test.exs` (the `quote`
  row and the fragment test, under paired mutations)
- **Suite run:** `mix test` (762 tests; 770 on the review-round head)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `base-`, `failures-` and
  `dependency_analyzer-20260929-dnd_1310_analyzer_quote_crash.md`

## Where the exception went before

`Anchor.Check.Base.run_on_all_source_files/3` let it escape. Credo's runner
(`deps/credo/lib/credo/check/runner.ex:92`, Credo 1.7.12) rescues it, prints
`Error while running <check>`, then re-raises when `exec.crash_on_error` (the
default, `execution.ex:41`), aborting the whole Credo run, every file and every
check. With `crash_on_error: false` it returns `[]`: every issue that check
found in the run is dropped, and the run reads as a pass.

## Fail-first

Against unfixed a82e01c:

```
3) test an exception on one file is one fail-closed violation on that file; the others are checked
   ** (ArgumentError) injected by the test
   (anchor 0.1.0) lib/anchor/managers/lint.ex:192: Anchor.Managers.Lint.detect_for_file/6
```

After the fix: `762 tests, 0 failures`.

## Mutations

Each applied to the fix commit, the whole suite run, then restored
(`git diff | wc -l` = 0).

| # | Mutation | Result |
|---|---|---|
| M3 | `guarded/2`'s rescue re-raises first (`reraise exception, __STACKTRACE__`) | `762 tests, 2 failures`: both crash tests, `** (ArgumentError) injected by the test` |
| M5 | the graph guard: `put_module_analyses/3` calls `module_dependencies/1` unguarded | **Measured zero** alone (`762 tests, 0 failures`): no real source crashes the analyzer after the fix, so nothing reaches it. Paired below. |
| M1+M5 | M5 plus the analyzer's `quote` guard dropped | `762 tests, 4 failures`; the Lint `quote` row is now `** (FunctionClauseError) no function clause matching in Anchor.Domain.DependencyAnalyzer.walk_children/3`. Under M1 alone that row reports `NoTransitiveDependency` as one `:fail_closed` violation from the graph build instead. The pair shows the graph guard turns a graph crash into an issue. |
| M6a | the analyzer's `top_defmodules/1` `quote` clause made to crash on a variable (`Enum.flat_map(args, ...)`), facts guard in place | `762 tests, 4 failures`; the Lint `quote` row shows every check with a `:fail_closed` violation from the facts step |
| M6b | M6a plus the facts guard removed (`{:ok, file_facts(...)}` behind an `if` so the compiler keeps the `:crashed` branch reachable) | `762 tests, 4 failures`; the Lint `quote` row is now `** (Protocol.UndefinedError) protocol Enumerable not implemented for Atom`. The pair shows the facts guard is load-bearing. |

M1 to M6b ran on the first commit (762 tests). The review round (code review
finding: no standing test for the facts and graph guards, and a facts crash
reported once per check under the wrong name) added the `:analyzer` option,
`FactsCrashAnalyzer`/`GraphCrashAnalyzer` in the crash test, reporting a facts
crash once through the shared-failure reporter as `:file_analysis`, and
`catch kind, reason` for throws and exits. Mutations on that head (770 tests):

| # | Mutation | Result |
|---|---|---|
| S1 | facts step unguarded (`{:ok, file_facts(...)}` behind an `if` so the compiler keeps the `:crashed` branch reachable) | `770 tests, 3 failures`: the three facts-crash tests, `** (ArgumentError) facts crash injected` |
| S2 | graph step unguarded (same shape) | `770 tests, 1 failure`: "the graph check reports it on that file; the other file is still checked", `** (ArgumentError) graph crash injected` |
| S3 | `facts_crash/2`'s non-reporter clause returns `[violation]` | `770 tests, 1 failure`: "every other check stays quiet about it", `match (=) failed` |
| S4 | the crashed file's facts marked `parsed?: true` | `770 tests, 1 failure`: "the file counts toward a pattern rule's floor as an unparsed file does", `match (=) failed` (a `{:config, [floor violation]}` entry appears) |
| S5 | `guarded/2` catches `:error` only | `770 tests, 1 failure`: "a throw from a check is reported the same way", `** (throw) :injected_by_the_test` |
