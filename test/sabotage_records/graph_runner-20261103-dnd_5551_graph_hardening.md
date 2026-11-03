# Sabotage record — the runner counts functions with no Core body (DND-5549)

- **Domain:** graph_runner
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphReport` (`summary/1`, `render/2` JSON), `Anchor.Managers.Graph` (`no_core_count/1`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph_report_test.exs` (RW-C, RW-D); `test/anchor/managers/graph_test.exs` (RW-E)

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy. After each run the driver printed `git status`, which listed only this branch's own edits, and the mutated text was grepped for after the batch: none was left.

Rows that stayed green, and why: the summary and JSON rows written before this change use a count of 0, which the summary prints nothing for, so they do not move.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| RW-C | the summary never names functions with no Core body (`lib/anchor/domain/graph_report.ex`) | 1 | render/2 functions with no Core body (DND-5549) are counted in the summary and the JSON when there are any |
| RW-D | the JSON drops the no_core count (`lib/anchor/domain/graph_report.ex`) | 1 | render/2 functions with no Core body (DND-5549) are counted in the summary and the JSON when there are any |
| RW-E | the Manager counts no function with no Core body (`lib/anchor/managers/graph.ex`) | 1 | run/2 happy path a public function with no Core body is an issue, and the summary counts it |

## RW-C — the summary never names functions with no Core body

Run summary: `11 tests, 1 failure`

```

  1) test render/2 functions with no Core body (DND-5549) are counted in the summary and the JSON when there are any (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:92
     Assertion with == failed
     code:  assert GraphReport.render(report, :text) ==
              "anchor.graph: 12 modules (2 opaque, 5 functions with no Core body) in 2 apps, " <>
                "3 rules, 0 violations (0 report-only, 0 baselined)"
     left:  "anchor.graph: 12 modules (2 opaque) in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 12 modules (2 opaque, 5 functions with no Core body) in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:95: (test)

.....
```

## RW-D — the JSON drops the no_core count

Run summary: `11 tests, 1 failure`

```

  1) test render/2 functions with no Core body (DND-5549) are counted in the summary and the JSON when there are any (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:92
     match (=) failed
     code:  assert %{"no_core" => 5} = JSON.decode!(GraphReport.render(report, :json))
     left:  %{"no_core" => 5}
     right: %{
              "apps" => 2,
              "could_not_check" => [],
              "exit_code" => 0,
              "findings" => [],
              "modules" => 12,
              "opaque" => 2,
              "rules" => 3
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:99: (test)

........
```

## RW-E — the Manager counts no function with no Core body

Run summary: `22 tests, 1 failure`

```

  1) test run/2 happy path a public function with no Core body is an issue, and the summary counts it (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:159
     Assertion with == failed
     code:  assert report.counts.no_core == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_test.exs:182: (test)

...................
```

