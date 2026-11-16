# Sabotage record: sabotage records carry no local-only text

- **Domain:** record_hygiene
- **Branch:** athena/sabotage-record-redaction
- **Date:** 2026-11-16
- **Code under test:** `Anchor.Domain.Sabotage.RecordHygiene`, `Anchor.Domain.Sabotage.Record.render/2`, `Anchor.Managers.Sabotage.Runner.recording/7`, the guard `test/anchor/sabotage_record_hygiene_test.exs`
- **Suite run:** `mix test test/anchor/domain/sabotage/record_test.exs`, `mix test test/anchor/managers/sabotage_run_test.exs`, `mix test test/anchor/managers/sabotage_scan_test.exs test/mix/tasks/anchor_sabotage_run_test.exs`, `mix test test/anchor/sabotage_record_hygiene_test.exs`

The generated record for this branch is
`sabotage-20261116-sabotage_record_redaction.md`. This file holds the reds
watched by hand: the tests written before the fix, and the mutants of
`Runner.recording/7` that no `test_mirror` rule sends to the runner's tests
(they live in `sabotage_run_test.exs` and `sabotage_scan_test.exs`, not
`runner_test.exs`).

## Reds before the fix

| Row | Mutation (the code as it was) | Test that failed | Result |
|---|---|---|---|
| A | `Record.render/2` with no redaction (before this branch) | `record_test.exs` H1, H2, H3 | 3 failures |
| B | `Runner.recording/7` builds its ctx with `root: nil` | `sabotage_run_test.exs` "a path under the run's root in a failure is written relative to it" | 1 failure |
| C | `.anchor/sabotage_record_leaks.txt` without the `cfa-20261106-...` entry, plus an entry `zzz-20261120-later.md` | `sabotage_record_hygiene_test.exs` "every committed record is clean, or listed while it still leaks" | 1 failure |

A (H1, verbatim):

```
  1) test local-only text never reaches a record H1: a first failure's scheduler lines are dropped and its home paths rewritten (Anchor.Domain.Sabotage.RecordTest)
     test/anchor/domain/sabotage/record_test.exs:500
     Assertion with == failed
     code:  assert Anchor.Domain.Sabotage.RecordHygiene.leaks(entry.content) == []
     left:  [
              {33, :local_path},
              {34, :local_path},
              {36, :scheduler_line},
              {37, :scheduler_line}
            ]
     right: []
```

H2 failed the same way at lines 29, 30, 32, 33 (the appended section), and H3
at 33, 34, 36, 37.

B: with `root: nil` the scheduler line was already dropped (the domain
redaction runs without a root), but the path under the run's root stayed
absolute:

```
     Assertion with =~ failed
     code:  assert content =~ ~s(left: "_build/test/calc"\n)
     ...
     test/calc_test.exs:4 test adds\nleft: \"/repo/_build/test/calc\"\n
     right: "left: \"_build/test/calc\"\n"
```

C:

```
     [
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        99, :scheduler_line},
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        100, :scheduler_line},
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        101, :scheduler_line},
       {:late, "test/sabotage_records/zzz-20261120-later.md"},
       {:missing, "test/sabotage_records/zzz-20261120-later.md"}
     ]
     Fix: a :leak is a record carrying a scheduler line or a home path: ...
```

## Tests the generated run left lacking a red

The rerun lists four tests no generated mutant failed. Three have their red
above: `record_test.exs` H3 (row A), the runner's root test (row B) and the
guard (row C). The fourth:

| Row | Mutation | Test that failed | Result |
|---|---|---|---|
| D | `@start` (the "no path character before it" lookbehind of every path pattern) set to `""` | `record_hygiene_test.exs:94` "paths that are not under a home directory are kept" | 1 test, 1 failure |

```
  1) test redact/2: local absolute paths paths that are not under a home directory are kept (Anchor.Domain.Sabotage.RecordHygieneTest)
     test/anchor/domain/sabotage/record_hygiene_test.exs:94
     Assertion with == failed
     code:  assert RecordHygiene.redact(text, @root) == text
     left:  "/tmp/a /usr/lib/erlang /homework/x lib~"
     right: "/tmp/a /usr/lib/erlang /homework/x lib/home/y"
```

## Runner.recording/7 mutants, run by hand against the runner's tests

Each patch is the generated record's, applied with `git apply`, then the file
restored.

| Row | Mutant | Suite | Result | First failure |
|---|---|---|---|---|
| R1 | 34aa3db042fb narrow_clause on the `no_record: true` clause | `sabotage_run_test.exs` | 89 tests, 33 failures | "a multi-target defimpl mutant (DND-5639) T1": `(Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1 ... with args ["/repo"]` |
| R2 | 50d6c21a6124 narrow_clause on the `dry_run: true` clause | `sabotage_run_test.exs` | 89 tests, 1 failure | "a dry run needs nothing a record needs: a detached HEAD is not refused": `(Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |
| R3 | acc5eca2b610 narrow_clause on the full clause | `sabotage_run_test.exs` | 89 tests, 12 failures | "ticket_nn_what: a number another run took meanwhile is retried once, at the next": `(FunctionClauseError) no function clause matching in Anchor.Managers.Sabotage.Runner.recording/7` |
| R4 | e8bc5325923e narrow_clause on the `planned: []` clause | `sabotage_run_test.exs` | 89 tests, 1 failure | "a run with no mutant to run writes no record and needs no branch": `(Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |
| R5 | 57c836c00014 with_passthrough on `:ok <- name_overrides(facts)` | `sabotage_run_test.exs` | 89 tests, 1 failure | "--domain and --ticket must be names, never paths: exit 2 before anything is read": `(Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |
| R6 | 6d2d236822c7 narrow_clause on the scan (`report:`) clause | `sabotage_run_test.exs` | 89 tests, 0 failures | (none: the scan tests are elsewhere) |
| R6' | the same | `sabotage_scan_test.exs`, `anchor_sabotage_run_test.exs` | 20 tests, 1 failure | "run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0": `(Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |

## Measured zeros: mutants no test can tell apart

| Row | Mutant | Suite | Result | Why it cannot be killed |
|---|---|---|---|---|
| E1 | 2487c78df8b8 with_passthrough: `{_, slot} <- record_slot(branch, facts)` | `sabotage_run_test.exs` | 89 tests, 0 failures | `record_slot/2` returns `{:ok, slot}` or a three-element `{:refuse, 2, message}`; `{_, slot}` cannot match the refusal, so `with` passes it through exactly as before |
| E2 | 2a94c6d56834 with_passthrough: `{_, branch} <- branch(facts.root, ports)` | `sabotage_run_test.exs` | 89 tests, 0 failures | the same: `branch/2` refuses with `{:refuse, 3, message}` |
| E3 | 198c78fe3380 with_passthrough: `{_, dir} <- RecordNaming.dir(ctx.records, app)` in `Record.entry/5` | generated run (`record_test.exs` and neighbours) | 59 tests, 0 failures | on `{:error, :no_app}` the next step, `RecordNaming.path/2`, calls `dir/2` with the same config and app and returns the same error, so the result is identical |

The generated run's other survivor, ac7e92c56c31 (`RecordHygiene.dated_after?/2`
with_passthrough on `Date.from_iso8601/1`), was a real gap: a listed path
whose date is no calendar date raised instead of being late. The test "a
listed record whose date is no calendar date is late" was added for it; the
rerun's record shows it killed.
