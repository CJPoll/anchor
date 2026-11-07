# Sabotage record: the nightly improvement scan

- **Domain:** sabotage
- **Branch:** dnd-5516-sabotage-verify
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Sabotage.Plan.shard/3` and `shard_of_day/2`, `Anchor.Domain.Sabotage.Scope.all/1`, `Anchor.Domain.Sabotage.ScanReport`, `Anchor.Domain.Sabotage.Report`'s scan exit code, the scan path of `Anchor.Managers.Sabotage.Runner` (`--scope all`, `--shard`, `--report`), the `--scope`, `--shard` and `--report` flags of `Mix.Tasks.Anchor.Sabotage`, `sabotage.scan_shards` in `Anchor.Domain.Sabotage.Config`, `Anchor.Adapters.RecordFile.write_report/4`, and `.github/workflows/sabotage-scan.yml` (DND-5490)
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, moved the file's mtime ahead (so no same-second rewrite reuses a stale beam), ran the files and wrote the original back byte for byte. The checkout's absolute path in the output reads `<worktree>`.

Every mutation below reddens a test; each section shows the first failure, cut at 70 lines. The QA plan's three required breaks are SP-A (shard by line number instead of id), SR-A (listed survivors reported as findings) and SM-A (`--report` writes records).

Green first: every test file below, unmutated: `115 tests, 0 failures`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| SP-A | shard by line number instead of id (the QA plan's break) (`lib/anchor/domain/sabotage/plan.ex`) | `plan_test.exs`, `sabotage_scan_test.exs` | `13 tests, 4 failures` (red) | shard/3 (DND-5490) 1: shards 0..6 of 70 mutants are pairwise disjoint and together the input; shard/3 (DND-5490) a mutant's shard is its id's: the same id is in the same shard wherever it moved; run/2 as a scan --shard auto is the day's shard of sabotage.scan_shards; run/2 as a scan a shard keeps only the mutants of its id class; a dry run writes nothing |
| SP-B | a shard keeps every mutant (`lib/anchor/domain/sabotage/plan.ex`) | `plan_test.exs`, `sabotage_scan_test.exs` | `13 tests, 3 failures` (red) | shard/3 (DND-5490) 1: shards 0..6 of 70 mutants are pairwise disjoint and together the input; shard/3 (DND-5490) a mutant's shard is its id's: the same id is in the same shard wherever it moved; run/2 as a scan a shard keeps only the mutants of its id class; a dry run writes nothing |
| SP-C | i = n is accepted (`lib/anchor/domain/sabotage/plan.ex`) | `plan_test.exs` | `8 tests, 1 failure` (red) | shard/3 (DND-5490) 2: i = n, a negative i, or n = 0 is {:error, :bad_shard} |
| SP-D | the day's shard ignores the date (`lib/anchor/domain/sabotage/plan.ex`) | `plan_test.exs`, `sabotage_scan_test.exs` | `13 tests, 2 failures` (red) | shard/3 (DND-5490) shard_of_day/2 is the day of the year modulo n; run/2 as a scan --shard auto is the day's shard of sabotage.scan_shards |
| SS-A | all/1 reads each file as modified with no hunk: nothing scoped (`lib/anchor/domain/sabotage/scope.ex`) | `scope_test.exs`, `sabotage_scan_test.exs` | `28 tests, 6 failures` (red) | run/2 as a scan 3: a failing baseline is exit 3, and no mutant is applied; run/2 as a scan --shard auto is the day's shard of sabotage.scan_shards; run/2 as a scan a shard keeps only the mutants of its id class; a dry run writes nothing; all/1 (DND-5490) 1: every literal def and defp of every file, nested modules too, in path order; run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0; all/1 (DND-5490) 2: a module whose functions come only from a use gives none; a macro neither |
| SR-A | listed survivors are reported as findings (the QA plan's break) (`lib/anchor/domain/sabotage/scan_report.ex`) | `scan_report_test.exs` | `2 tests, 1 failure` (red) | render/3 1: findings are only the unlisted survivors; no_tests, totals and the markdown |
| SR-B | the no_tests section is empty (`lib/anchor/domain/sabotage/scan_report.ex`) | `scan_report_test.exs` | `2 tests, 1 failure` (red) | render/3 1: findings are only the unlisted survivors; no_tests, totals and the markdown |
| SR-C | no coverage map is not said (`lib/anchor/domain/sabotage/scan_report.ex`) | `scan_report_test.exs` | `2 tests, 1 failure` (red) | render/3 2: with no coverage map, the first line says selection fell back to kill maps and mirror |
| SX-A | a scan's survivors fail it (`lib/anchor/domain/sabotage/report.ex`) | `report_test.exs`, `sabotage_scan_test.exs` | `48 tests, 2 failures` (red) | run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0; a scan (DND-5490) its survivors and no_tests mutants are findings, never a failure: exit 0 |
| SX-B | a scan that measured nothing exits 0 (`lib/anchor/domain/sabotage/report.ex`) | `report_test.exs` | `43 tests, 1 failure` (red) | a scan (DND-5490) a scan that measured nothing is 3; a report not written is 2, said loudly |
| SX-C | a report not written still exits 0 (`lib/anchor/domain/sabotage/report.ex`) | `report_test.exs` | `43 tests, 1 failure` (red) | a scan (DND-5490) a scan that measured nothing is 3; a report not written is 2, said loudly |
| SM-A | --report writes records (the QA plan's break) (`lib/anchor/managers/sabotage/runner.ex`) | `sabotage_scan_test.exs` | `5 tests, 1 failure` (red) | run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0 |
| SM-B | zero functions in scope is measured (`lib/anchor/managers/sabotage/runner.ex`) | `sabotage_scan_test.exs` | `5 tests, 1 failure` (red) | run/2 as a scan 2: zero functions in scope is COULD NOT MEASURE, exit 3, nothing applied |
| SM-C | the report is never written (`lib/anchor/managers/sabotage/runner.ex`) | `sabotage_scan_test.exs` | `5 tests, 1 failure` (red) | run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0 |
| SM-D | --shard auto ignores scan_shards (`lib/anchor/managers/sabotage/runner.ex`) | `sabotage_scan_test.exs` | `5 tests, 1 failure` (red) | run/2 as a scan --shard auto is the day's shard of sabotage.scan_shards |
| ST-A | --report does not imply no record (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_run_test.exs` | `15 tests, 1 failure` (red) | DND-5490: run_facts/1 maps --scope, --shard and --report; a scan writes no record |
| ST-B | --shard I/N accepts I = N (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_run_test.exs` | `15 tests, 1 failure` (red) | DND-5490: run_facts/1 maps --scope, --shard and --report; a scan writes no record |
| SC-A | scan_shards is not read (`lib/anchor/domain/sabotage/config.ex`) | `config_test.exs` | `7 tests, 2 failures` (red) | parse/1 every key is read; parse/1 2: each refusal names its key and ends with a Fix: line |
| SF-A | the .etf is not written (`lib/anchor/adapters/record_file.ex`) | `record_file_test.exs` | `5 tests, 1 failure` (red) | DND-5490: write_report writes the markdown and its .etf, overwriting both |
| SW-A | the workflow runs on pull requests (`.github/workflows/sabotage-scan.yml`) | `sabotage_scan_workflow_test.exs` | `7 tests, 1 failure` (red) | it runs nightly and by hand, never on a pull request |
| SW-B | the scan's exit is masked (`.github/workflows/sabotage-scan.yml`) | `sabotage_scan_workflow_test.exs` | `7 tests, 1 failure` (red) | the scan is the day's shard, every mutant, a report and no record |

## SP-A: shard by line number instead of id (the QA plan's break)

```

  1) test shard/3 (DND-5490) 1: shards 0..6 of 70 mutants are pairwise disjoint and together the input (Anchor.Domain.Sabotage.PlanTest)
     test/anchor/domain/sabotage/plan_test.exs:75
     Expected truthy, got false
     code: assert Enum.all?(shards, &(&1 != [] and length(&1) < 70))
     arguments:

         # 1
         [
           [],
           [
             %Anchor.Domain.Sabotage.Mutant{
               id: "ca0df2c95aa1",
               file: "lib/f1.ex",
               module: M,
               function: {:f1, 1},
               operator: :return_input,
               variant: nil,
               target: "t",
               range: {{1, 1}, {1, 2}},
               original: "a",
               replacement: "b",
               patch: ""
             },
             %Anchor.Domain.Sabotage.Mutant{
               id: "29c1b289e752",
               file: "lib/f2.ex",
               module: M,
               function: {:f2, 1},
               operator: :delete_statement,
               variant: nil,
               target: "t",
               range: {{1, 1}, {1, 2}},
               original: "a",
               replacement: "b",
               patch: ""
             },
             %Anchor.Domain.Sabotage.Mutant{
               id: "153812ae5fea",
               file: "lib/f0.ex",
               module: M,
               function: {:f3, 1},
               operator: :return_input,
               variant: nil,
               target: "t",
               range: {{1, 1}, {1, 2}},
               original: "a",
               replacement: "b",
               patch: ""
             },
             %Anchor.Domain.Sabotage.Mutant{
               id: "2396a1256ac4",
               file: "lib/f1.ex",
               module: M,
               function: {:f0, 1},
               operator: :delete_statement,
               variant: nil,
               target: "t",
               range: {{1, 1}, {1, 2}},
               original: "a",
               replacement: "b",
               patch: ""
             },
             %Anchor.Domain.Sabotage.Mutant{
               id: "b5f2031eb62e",
               file: "lib/f2.ex",
               module: M,
               function: {:f1, 1},
               operator: :return_input,
               variant: nil,
```

## SP-B: a shard keeps every mutant

```

  1) test shard/3 (DND-5490) 1: shards 0..6 of 70 mutants are pairwise disjoint and together the input (Anchor.Domain.Sabotage.PlanTest)
     test/anchor/domain/sabotage/plan_test.exs:75
     Assertion with == failed
     code:  assert Enum.sort(Enum.concat(shards)) == Enum.sort(mutants)
     left:  [
              %Anchor.Domain.Sabotage.Mutant{
                id: "0c331f4dab22",
                file: "lib/f0.ex",
                module: M,
                function: {:f0, 1},
                operator: :delete_statement,
                variant: nil,
                target: "t",
                range: {{1, 1}, {1, 2}},
                original: "a",
                replacement: "b",
                patch: ""
              },
              %Anchor.Domain.Sabotage.Mutant{
                id: "0c331f4dab22",
                file: "lib/f0.ex",
                module: M,
                function: {:f0, 1},
                operator: :delete_statement,
                variant: nil,
                target: "t",
                range: {{1, 1}, {1, 2}},
                original: "a",
                replacement: "b",
                patch: ""
              },
              %Anchor.Domain.Sabotage.Mutant{
                id: "0c331f4dab22",
                file: "lib/f0.ex",
                module: M,
                function: {:f0, 1},
                operator: :delete_statement,
                variant: nil,
                target: "t",
                range: {{1, 1}, {1, 2}},
                original: "a",
                replacement: "b",
                patch: ""
              },
              %Anchor.Domain.Sabotage.Mutant{
                id: "0c331f4dab22",
                file: "lib/f0.ex",
                module: M,
                function: {:f0, 1},
                operator: :delete_statement,
                variant: nil,
                target: "t",
                range: {{1, 1}, {1, 2}},
                original: "a",
                replacement: "b",
                patch: ""
              },
              %Anchor.Domain.Sabotage.Mutant{
                id: "0c331f4dab22",
                file: "lib/f0.ex",
                module: M,
                function: {:f0, 1},
                operator: :delete_statement,
                variant: nil,
                target: "t",
                range: {{1, 1}, {1, 2}},
                original: "a",
                replacement: "b",
                patch: ""
```

## SP-C: i = n is accepted

```

  1) test shard/3 (DND-5490) 2: i = n, a negative i, or n = 0 is {:error, :bad_shard} (Anchor.Domain.Sabotage.PlanTest)
     test/anchor/domain/sabotage/plan_test.exs:98
     Assertion with == failed
     code:  assert Plan.shard(seventy(), 7, 7) == {:error, :bad_shard}
     left:  {:ok, []}
     right: {:error, :bad_shard}
     stacktrace:
       test/anchor/domain/sabotage/plan_test.exs:99: (test)

....
```

## SP-D: the day's shard ignores the date

```

  1) test shard/3 (DND-5490) shard_of_day/2 is the day of the year modulo n (Anchor.Domain.Sabotage.PlanTest)
     test/anchor/domain/sabotage/plan_test.exs:104
     Assertion with == failed
     code:  assert Plan.shard_of_day(~D[2026-01-01], 7) == {1, 7}
     left:  {0, 7}
     right: {1, 7}
     stacktrace:
       test/anchor/domain/sabotage/plan_test.exs:105: (test)

.......
```

## SS-A: all/1 reads each file as modified with no hunk: nothing scoped

```



  1) test run/2 as a scan 3: a failing baseline is exit 3, and no mutant is applied (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:156
     Assertion with =~ failed
     code:  assert message =~ "the selected tests fail with no mutant applied"
     left:  "COULD NOT MEASURE: --scope all found no function with a literal clause in 1 lib source files. Fix: run it from the project root, whose lib/ holds the code to scan"
     right: "the selected tests fail with no mutant applied"
     stacktrace:
       test/anchor/managers/sabotage_scan_test.exs:169: (test)
```

## SR-A: listed survivors are reported as findings (the QA plan's break)

```



  1) test render/3 1: findings are only the unlisted survivors; no_tests, totals and the markdown (Anchor.Domain.Sabotage.ScanReportTest)
     test/anchor/domain/sabotage/scan_report_test.exs:86
     Assertion with == failed
     code:  assert markdown == @golden
     left:  "# Sabotage scan: tests selected by the coverage map cov/anchor-coverage.etf\n\n- Shard: 3/7\n- Mutants: 4; findings: 2; listed survivors: 1\n\n## Totals\n\n| killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|\n| 1 | 2 | 0 | 0 | 0 | 1 |\n\n## By module\n\n| module | killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|---|\n| Calc | 1 | 1 | 0 | 0 | 0 | 0 |\n| Store | 0 | 1 | 0 | 0 | 0 | 1 |\n\n## Findings: survivors not on the survivors list\n\n- `bbbbbbbbbbbb` lib/calc.ex Calc.add/2 delete_statement\n- `cccccccccccc` lib/store.ex Store.put/1 delete_statement\n\n## Functions whose mutants had no test\n\n- Store.get/1 (lib/store.ex)\n"
     right: "# Sabotage scan: tests selected by the coverage map cov/anchor-coverage.etf\n\n- Shard: 3/7\n- Mutants: 4; findings: 1; listed survivors: 1\n\n## Totals\n\n| killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|\n| 1 | 2 | 0 | 0 | 0 | 1 |\n\n## By module\n\n| module | killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|---|\n| Calc | 1 | 1 | 0 | 0 | 0 | 0 |\n| Store | 0 | 1 | 0 | 0 | 0 | 1 |\n\n## Findings: survivors not on the survivors list\n\n- `cccccccccccc` lib/store.ex Store.put/1 delete_statement\n\n## Functions whose mutants had no test\n\n- Store.get/1 (lib/store.ex)\n"
     stacktrace:
       test/anchor/domain/sabotage/scan_report_test.exs:93: (test)

.
```

## SR-B: the no_tests section is empty

```



  1) test render/3 1: findings are only the unlisted survivors; no_tests, totals and the markdown (Anchor.Domain.Sabotage.ScanReportTest)
     test/anchor/domain/sabotage/scan_report_test.exs:86
     Assertion with == failed
     code:  assert markdown == @golden
     left:  "# Sabotage scan: tests selected by the coverage map cov/anchor-coverage.etf\n\n- Shard: 3/7\n- Mutants: 4; findings: 1; listed survivors: 1\n\n## Totals\n\n| killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|\n| 1 | 2 | 0 | 0 | 0 | 1 |\n\n## By module\n\n| module | killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|---|\n| Calc | 1 | 1 | 0 | 0 | 0 | 0 |\n| Store | 0 | 1 | 0 | 0 | 0 | 1 |\n\n## Findings: survivors not on the survivors list\n\n- `cccccccccccc` lib/store.ex Store.put/1 delete_statement\n\n## Functions whose mutants had no test\n\nNone.\n"
     right: "# Sabotage scan: tests selected by the coverage map cov/anchor-coverage.etf\n\n- Shard: 3/7\n- Mutants: 4; findings: 1; listed survivors: 1\n\n## Totals\n\n| killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|\n| 1 | 2 | 0 | 0 | 0 | 1 |\n\n## By module\n\n| module | killed | survived | timeout | invalid | crashed | no_tests |\n|---|---|---|---|---|---|---|\n| Calc | 1 | 1 | 0 | 0 | 0 | 0 |\n| Store | 0 | 1 | 0 | 0 | 0 | 1 |\n\n## Findings: survivors not on the survivors list\n\n- `cccccccccccc` lib/store.ex Store.put/1 delete_statement\n\n## Functions whose mutants had no test\n\n- Store.get/1 (lib/store.ex)\n"
     stacktrace:
       test/anchor/domain/sabotage/scan_report_test.exs:93: (test)

.
```

## SR-C: no coverage map is not said

```



  1) test render/3 2: with no coverage map, the first line says selection fell back to kill maps and mirror (Anchor.Domain.Sabotage.ScanReportTest)
     test/anchor/domain/sabotage/scan_report_test.exs:101
     Assertion with == failed
     code:  assert hd(String.split(markdown, "\n")) ==
              "# Sabotage scan: no coverage map, so tests were selected from the kill maps " <>
                "and the test mirror"
     left:  "# Sabotage scan: tests were selected from the kill maps and the test mirror"
     right: "# Sabotage scan: no coverage map, so tests were selected from the kill maps and the test mirror"
     stacktrace:
       test/anchor/domain/sabotage/scan_report_test.exs:104: (test)

.
```

## SX-A: a scan's survivors fail it

```

  1) test run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0 (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:114
     05ccd80be8e0	Calc.add/2	return_input	survived		selected by mirror: test/calc_test.exs	Fix: add a test that fails under this mutant
     tests selected by: 1 mirror
     sabotage scan report written: /tmp/scan/scan.md
     sabotage scan report written: /tmp/scan/scan.etf
     NEW survivor 05ccd80be8e0 lib/calc.ex Calc.add/2 return_input
       Fix: add a test that fails under this mutant, or add to .anchor/sabotage/survivors.txt:
       05ccd80be8e0 lib/calc.ex Calc.add/2 return_input  # <why no test can kill it>
     survivors: 0 held, 1 new, 0 stale, 0 not judged
     anchor.sabotage run: 1 mutants run: 0 killed, 1 survived, 0 timeout, 0 invalid, 0 crashed, 0 no_tests; 0 skipped; 0 not run (cap); 0 errors
     code: assert Report.exit_code(run) == 0, Report.render(run)
     stacktrace:
       test/anchor/managers/sabotage_scan_test.exs:139: (test)

..........................
```

## SX-B: a scan that measured nothing exits 0

```

  1) test a scan (DND-5490) a scan that measured nothing is 3; a report not written is 2, said loudly (Anchor.Domain.Sabotage.ReportTest)
     test/anchor/domain/sabotage/report_test.exs:454
     Assertion with == failed
     code:  assert Report.exit_code(%Run{scan: @scan, outcomes: [outcome("a", :invalid, [], "why")]}) == 3
     left:  0
     right: 3
     stacktrace:
       test/anchor/domain/sabotage/report_test.exs:455: (test)

......................................
```

## SX-C: a report not written still exits 0

```

  1) test a scan (DND-5490) a scan that measured nothing is 3; a report not written is 2, said loudly (Anchor.Domain.Sabotage.ReportTest)
     test/anchor/domain/sabotage/report_test.exs:454
     Assertion with == failed
     code:  assert Report.exit_code(run) == 2
     left:  0
     right: 2
     stacktrace:
       test/anchor/domain/sabotage/report_test.exs:459: (test)

....
```

## SM-A: --report writes records (the QA plan's break)

```

  1) test run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0 (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:114
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1 in process #PID<0.1398.0> with args ["/repo"]
     code: run = Sabotage.run(%{@facts | only: [mutant.id], no_record: false}, @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:1116: Anchor.Managers.Sabotage.Runner.branch/2
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:1092: Anchor.Managers.Sabotage.Runner.recording/7
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:264: Anchor.Managers.Sabotage.Runner.checked_run/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:187: Anchor.Managers.Sabotage.Runner.locked/4
       test/anchor/managers/sabotage_scan_test.exs:133: (test)

..
```

## SM-B: zero functions in scope is measured

```



  1) test run/2 as a scan 2: zero functions in scope is COULD NOT MEASURE, exit 3, nothing applied (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:142
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.dirty_paths/2 in process #PID<0.1386.0> with args ["/repo", []]
     code: run = Sabotage.run(@facts, @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:456: Anchor.Managers.Sabotage.Runner.clean_targets/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:258: Anchor.Managers.Sabotage.Runner.checked_run/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:187: Anchor.Managers.Sabotage.Runner.locked/4
       test/anchor/managers/sabotage_scan_test.exs:149: (test)

....
```

## SM-C: the report is never written

```

  1) test run/2 as a scan 1: one unlisted survivor: the report is written, no record, exit 0 (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:114
     Assertion with == failed
     code:  assert run.report == ["/tmp/scan/scan.md", "/tmp/scan/scan.etf"]
     left:  []
     right: ["/tmp/scan/scan.md", "/tmp/scan/scan.etf"]
     stacktrace:
       test/anchor/managers/sabotage_scan_test.exs:136: (test)

...
```

## SM-D: --shard auto ignores scan_shards

```

  1) test run/2 as a scan --shard auto is the day's shard of sabotage.scan_shards (Anchor.Managers.SabotageScanTest)
     test/anchor/managers/sabotage_scan_test.exs:192
     ** (FunctionClauseError) no function clause matching in anonymous fn/1 in Anchor.Managers.SabotageScanTest.expect_tests_exist/0

     The following arguments were given to anonymous fn/1 in Anchor.Managers.SabotageScanTest.expect_tests_exist/0:

         # 1
         []

     code: run = Sabotage.run(facts, @opts)
     stacktrace:
       test/anchor/managers/sabotage_scan_test.exs:101: anonymous fn/1 in Anchor.Managers.SabotageScanTest.expect_tests_exist/0
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:727: Anchor.Managers.Sabotage.Runner.select/5
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:276: Anchor.Managers.Sabotage.Runner.checked_run/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/runner.ex:187: Anchor.Managers.Sabotage.Runner.locked/4
       test/anchor/managers/sabotage_scan_test.exs:203: (test)

...
```

## ST-A: --report does not imply no record

```

  1) test DND-5490: run_facts/1 maps --scope, --shard and --report; a scan writes no record (Mix.Tasks.Anchor.SabotageRunTest)
     test/mix/tasks/anchor_sabotage_run_test.exs:231
     match (=) failed
     code:  assert {:ok, %{scope: :diff, no_record: true}} = Sabotage.run_facts(["--report", "r.md"])
     left:  {:ok, %{scope: :diff, no_record: true}}
     right: {:ok,
             %{
               command: "mix anchor.sabotage run --report r.md",
               env: :test,
               max: nil,
               scope: :diff,
               version: "0.1.0",
               now: ~U[2026-11-06 22:22:30.857440Z],
               slot: nil,
               root: "<worktree>",
               domain: nil,
               report: "r.md",
               base: "origin/main",
               only: [],
               build_path: "<worktree>/_build/test",
               ticket: nil,
               coverage: nil,
               dry_run: false,
               print_survivor_lines: false,
               shard: nil,
               no_record: false
             }}
     stacktrace:
       test/mix/tasks/anchor_sabotage_run_test.exs:240: (test)

.............
```

## ST-B: --shard I/N accepts I = N

```

  1) test DND-5490: run_facts/1 maps --scope, --shard and --report; a scan writes no record (Mix.Tasks.Anchor.SabotageRunTest)
     test/mix/tasks/anchor_sabotage_run_test.exs:231
     ["--shard", "7/7"]
     code: for bad <- [
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/mix/tasks/anchor_sabotage_run_test.exs:243: (test)

............
```

## SC-A: scan_shards is not read

```

  1) test parse/1 every key is read (Anchor.Domain.Sabotage.ConfigTest)
     test/anchor/domain/sabotage/config_test.exs:44
     Assertion with == failed
     code:  assert config.scan_shards == 30
     left:  7
     right: 30
     stacktrace:
       test/anchor/domain/sabotage/config_test.exs:76: (test)
```

## SF-A: the .etf is not written

```

  1) test DND-5490: write_report writes the markdown and its .etf, overwriting both (Anchor.Adapters.RecordFileTest)
     test/anchor/adapters/record_file_test.exs:48
     ** (File.Error) could not read file "<worktree>/tmp/Anchor.Adapters.RecordFileTest/test-DND-5490--write_report-writes-the-markdown-and-its-.etf,-overwriting-both-66fb946e/out/scan.etf": no such file or directory
     code: assert File.read!(Path.join(root, "out/scan.etf")) == term
     stacktrace:
       (elixir 1.19.4) lib/file.ex:435: File.read!/1
       test/anchor/adapters/record_file_test.exs:59: (test)
```

## SW-A: the workflow runs on pull requests

```

  1) test it runs nightly and by hand, never on a pull request (Anchor.SabotageScanWorkflowTest)
     test/anchor/sabotage_scan_workflow_test.exs:20
     Expected false or nil, got true
     code: refute Map.has_key?(triggers, "pull_request")
     arguments:

         # 1
         %{
           "pull_request" => nil,
           "schedule" => [%{"cron" => "41 3 * * *"}],
           "workflow_dispatch" => nil
         }

         # 2
         "pull_request"

     stacktrace:
       test/anchor/sabotage_scan_workflow_test.exs:26: (test)
```

## SW-B: the scan's exit is masked

```

  1) test the scan is the day's shard, every mutant, a report and no record (Anchor.SabotageScanWorkflowTest)
     test/anchor/sabotage_scan_workflow_test.exs:36
     Assertion with == failed
     code:  assert String.trim(run) ==
              ~s(mix anchor.sabotage run --scope all --shard auto --max all --base HEAD ) <>
                ~s(--report "$RUNNER_TEMP/scan/sabotage-scan.md" $SCAN_COVERAGE)
     left:  "mix anchor.sabotage run --scope all --shard auto --max all --base HEAD --report \"$RUNNER_TEMP/scan/sabotage-scan.md\" $SCAN_COVERAGE || true"
     right: "mix anchor.sabotage run --scope all --shard auto --max all --base HEAD --report \"$RUNNER_TEMP/scan/sabotage-scan.md\" $SCAN_COVERAGE"
     stacktrace:
       test/anchor/sabotage_scan_workflow_test.exs:42: (test)

..
```

## Critic round: the shard of the day crosses a new year

The critic found `--shard auto` keyed on the day of the year, which restarts each 1 January: one shard ran twice and others waited past the artifact retention. `shard_of_day/2` now counts days since 1970-01-01. The red, against the day-of-year code (`mix test --max-cases 2 test/anchor/domain/sabotage/plan_test.exs`), before the fix:

```
  1) test shard/3 (DND-5490) shard_of_day/2: any n days in a row run every shard once, across a new year too (Anchor.Domain.Sabotage.PlanTest)
     test/anchor/domain/sabotage/plan_test.exs:104
     n=30 from 2026-12-20
     code: for n <- [7, 30], start <- [~D[2026-12-20], ~D[2028-12-15], ~D[2026-06-01]] do
     stacktrace:
       test/anchor/domain/sabotage/plan_test.exs:107: anonymous fn/3 in Anchor.Domain.Sabotage.PlanTest."test shard/3 (DND-5490) shard_of_day/2: any n days in a row run every shard once, across a new year too"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/sabotage/plan_test.exs:105: (test)

8 tests, 1 failure
```

After the fix: `8 tests, 0 failures`.

## Critic round: the coverage listing falls back

The critic found that 14be9b9 added `|| run_id=""` after the `gh run list` substitution in the coverage download step with no test holding it. GitHub runs `run:` under `bash -e`, so a listing error would end the job. The new test, "a failing listing of coverage runs falls back to no map", asserts the clause and, as its positive control, refutes the same step with the clause removed. The red, with ` || run_id=""` deleted from `.github/workflows/sabotage-scan.yml` (`mix test test/anchor/sabotage_scan_workflow_test.exs`):

```
  1) test a failing listing of coverage runs falls back to no map (Anchor.SabotageScanWorkflowTest)
     test/anchor/sabotage_scan_workflow_test.exs:60
     Expected truthy, got false
     code: assert listing_falls_back?(run)
     arguments:

         # 1
         "run_id=$(gh run list --repo \"$GITHUB_REPOSITORY\" --workflow coverage-map.yml \\\n  --branch main --event push --status success --limit 1 \\\n  --json databaseId --jq '.[0].databaseId // empty')\nif [ -n \"$run_id\" ] &&\n  gh run download \"$run_id\" --repo \"$GITHUB_REPOSITORY\" \\\n    --name anchor-coverage --dir \"$RUNNER_TEMP/coverage\"; then\n  echo \"SCAN_COVERAGE=--coverage=$RUNNER_TEMP/coverage/anchor-coverage.etf\" >> \"$GITHUB_ENV\"\nelse\n  echo \"No anchor-coverage artifact: selecting from the kill maps and the test mirror.\"\nfi\n"

     stacktrace:
       test/anchor/sabotage_scan_workflow_test.exs:63: (test)

.....
Finished in 0.1 seconds (0.1s async, 0.00s sync)
8 tests, 1 failure
```

On the real workflow: `8 tests, 0 failures`.
