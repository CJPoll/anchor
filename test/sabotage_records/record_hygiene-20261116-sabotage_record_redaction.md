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
| C | the list (then `.anchor/sabotage_record_leaks.txt`) without the `cfa-20261106-...` entry, plus an entry `zzz-20261120-later.md` | `sabotage_record_hygiene_test.exs` "every committed record is clean, or listed while it still leaks" | 1 failure |

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

## Tests the generated runs left lacking a red

The last generated run lists five tests no mutant failed. `record_test.exs` H3
has its red in row A and the runner's root test in row B. The guard's three
tests were run by hand against the guard as it stands after the review round
(list at `.anchor/sabotage/record_leaks.txt`, landed copy pinned in the test),
each with the list file changed and then restored:

| Row | Mutation of the list | Test that failed | Result |
|---|---|---|---|
| C2 | the `cfa-20261106-...` entry removed | "every committed record is clean, or listed while it still leaks" | 3 tests, 1 failure |
| E | an entry added for `aggregates-20261103-dnd_5476_aggregate_decls.md` (a clean record, dated before the cutoff) | "the list only shrinks: every entry is one it landed with" (and the clean-or-listed test, as `:stale`) | 3 tests, 2 failures |
| F | the two `aggregates-` entries swapped | "the list is sorted and has no duplicate" | 3 tests, 1 failure |

C2:

```
  1) test every committed record is clean, or listed while it still leaks (Anchor.SabotageRecordHygieneTest)
     test/anchor/sabotage_record_hygiene_test.exs:49
     [
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        99, :scheduler_line},
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        100, :scheduler_line},
       {:leak, "test/sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md",
        101, :scheduler_line}
     ]
```

E:

```
  1) test the list only shrinks: every entry is one it landed with (Anchor.SabotageRecordHygieneTest)
     test/anchor/sabotage_record_hygiene_test.exs:59
     Fix: a record that was not on the list never joins it
     code: assert listed() -- landed == [], "Fix: a record that was not on the list never joins it"
  2) test every committed record is clean, or listed while it still leaks (Anchor.SabotageRecordHygieneTest)
     test/anchor/sabotage_record_hygiene_test.exs:49
     [stale: "test/sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md"]
```

F:

```
  1) test the list is sorted and has no duplicate (Anchor.SabotageRecordHygieneTest)
     test/anchor/sabotage_record_hygiene_test.exs:64
     Assertion with == failed
     code:  assert listed() == Enum.uniq(Enum.sort(listed()))
     left:  ["test/sabotage_records/aggregates-20261106-dnd_5459_write_sets.md",
             "test/sabotage_records/aggregates-20261103-dnd_5459_write_sets.md",
             ...
```

Row C above is the same guard before the review round (list then at the
repository's `.anchor/` root, no pinned copy).

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

The first generated run's other survivor, ac7e92c56c31 (`RecordHygiene.dated_after?/2`
with_passthrough on `Date.from_iso8601/1`), was a real gap: a listed path
whose date is no calendar date raised instead of being late. The test "a
listed record whose date is no calendar date is late" was added for it; the
rerun's record shows it killed.

The run after the review round (no regex, ADR 004) left one survivor,
fb681b5c945b (`RecordHygiene.digits?/1` return_input: every segment counted
as digits). Two tests were added for it: "keeps a line shaped like a waiting
line whose count is not a number" and "the date is the first eight-digit
segment, not any eight-character one"; the next run's record shows it.
