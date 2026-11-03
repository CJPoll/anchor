# Sabotage record — a record write failure no longer masks the measured verdict (DND-5641)

- **Domain:** sabotage
- **Branch:** dnd-5474-coverage-records
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.Report` (`exit_code/1`, the
  record lines of `render/1`)
- **Suite run:** per row, `mix test test/anchor/domain/sabotage/report_test.exs
  --timeout 2000 --max-cases 2` through `test-slot`. The file was green
  before and after every row.

The defect (introduced by DND-5484): `Report.exit_code/1` checked
`record_error` before the verdict, so a run whose sabotage record could not
be written exited 2 even when a mutant survived (1) or nothing was measured
(3, COULD NOT MEASURE): a survivor or an unmeasured run was reported as a
plain refusal. The fix: the measured verdict keeps precedence; a record
failure turns only a pass (0) into 2, and is said loudly in every case as
`sabotage: record not written: <why>`.

Regression tests, seen failing on the unfixed code (2215d37) first:

```
  1) test a record that could not be written (DND-5641) nothing measured keeps exit 3, COULD NOT MEASURE; the record failure is said loudly (Anchor.Domain.Sabotage.ReportTest)
     code:  assert Report.exit_code(run) == 3
     left:  2
     right: 3
  2) test a record that could not be written (DND-5641) a survivor keeps exit 1; the record failure is said loudly (Anchor.Domain.Sabotage.ReportTest)
     code:  assert Report.exit_code(run) == 1
     left:  2
     right: 1
  3) test a record that could not be written (DND-5641) only a passing verdict becomes exit 2 (Anchor.Domain.Sabotage.ReportTest)
     code:  assert Report.render(run) =~ "sabotage: record not written: ..."
28 tests, 3 failures
```

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| R1 | every verdict becomes 2 on a record failure (the unfixed precedence) | 2 of 28: "a survivor keeps exit 1 ...", "nothing measured keeps exit 3 ..." | `code:  assert Report.exit_code(run) == 3` `left:  2` |
| R2 | a pass is not turned into 2 | 1 of 28: "only a passing verdict becomes exit 2" | `code:  assert Report.exit_code(run) == 2` `left:  0` |
| R3 | the loud `sabotage: record not written:` prefix dropped | 3 of 28: all three record-failure rows | `code:  assert Report.render(run) =~ "sabotage: record not written: ..."` |

The two Manager tests that had asserted exit 2 for a run with a survivor now
assert 1 and the loud line (`sabotage_run_test.exs`, "a record that cannot be
written is said loudly; the survivor keeps exit 1 (DND-5641)" and
"domain_date_slot: a record that appeared meanwhile is never overwritten,
said loudly").

After the fix, every row restored: `report_test.exs`, `28 tests, 0 failures`;
`sabotage_run_test.exs` and the integration test, `84 tests, 0 failures`.
