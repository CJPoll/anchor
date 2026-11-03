# Sabotage records: baselines (branch dnd-5648-graph-followups)

- **Domain:** baseline
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- One section per ticket of the batch, in commit order.

## DND-5648: a base config that does not load is one issue

**Code under test:** the base-config handling in `Anchor.Managers.Graph` (`base_config_issues/2`, `compare_baseline/5`) and `Anchor.Domain.Failures.baseline_base_config_unreadable/4`.

**Suite run:** one `test-slot` ran `sab.py`: for each mutation it waited 1.1 s, wrote it, ran `mix test --timeout 2000 --max-cases 2 <tests>`, restored the source and waited 1.1 s, so no run read a stale beam. BC-R is the new test on the unfixed code (its output was captured with `tail -40`, so its block starts inside the assertion). With every source restored: `52 tests, 0 failures` over the graph baseline, failures and task tests.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| BC-R | regression: the unfixed code, with the new test (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `25 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule (three identical issues, one per rule; the captured tail starts inside the assertion) |
| BC-A | the run's one config issue is dropped (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 2 failures` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref; run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |
| BC-B | the issue names only the first unjudged rule (`lib/anchor/domain/failures.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |
| BC-C | an unjudged rule's findings are held, so the verdict changes (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |
| BC-D | only the first rule's id is collected (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |

### BC-R: regression: the unfixed code, with the new test

Run summary: `25 tests, 1 failure`

```text
     code:  assert [issue] = Enum.filter(report.findings, &(&1.message =~ "could not read .anchor.yml at main"))
     left:  [issue]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "Anchor could not read .anchor.yml at main ({:invalid_config, \"the document is empty\"}), so no baseline's copy there could be found by its rule's id and GREW could not be judged. Fix: pass a --base ref whose .anchor.yml loads, or drop --base."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "Anchor could not read .anchor.yml at main ({:invalid_config, \"the document is empty\"}), so no baseline's copy there could be found by its rule's id and GREW could not be judged. Fix: pass a --base ref whose .anchor.yml loads, or drop --base."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "Anchor could not read .anchor.yml at main ({:invalid_config, \"the document is empty\"}), so no baseline's copy there could be found by its rule's id and GREW could not be judged. Fix: pass a --base ref whose .anchor.yml loads, or drop --base."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:398: (test)
```

### BC-A: the run's one config issue is dropped

Run summary: `41 tests, 2 failures`

```text


  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:355
     Expected truthy, got false
     code: assert Enum.any?(
             report.findings,
             &(&1.file == ".anchor.yml" and &1.message =~ "could not read .anchor.yml at main")
           )
     arguments:

         # 1
         [
           %Anchor.Domain.GraphReport.Finding{
             rule_id: "f",
             type: :stub_finds,
             label: "rule 1 (id: \"f\", stub_finds)",
             enforcement: :enforce,
             key: "f|AnchorFixtures.GraphBaselineTest.User|found",
             file: "lib/my_app/domain/user.ex",
             line: 2,
             message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
           }
         ]

         # 2
         #Function<16.13996014/1 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref"/1>



  2) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:377
     match (=) failed
     code:  assert [issue] = Enum.filter(report.findings, &(&1.message =~ "could not read .anchor.yml at main"))
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:398: (test)

............
```

### BC-B: the issue names only the first unjudged rule

Run summary: `41 tests, 2 failures`

```text


  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:257
     baseline_base_config_unreadable: "GREW could not be judged for rules \"web\", \"core\"" in Anchor could not read .anchor.yml at main (:boom), so no baseline's copy there could be found by its rule's id and GREW could not be judged for rules "web". Fix: pass a --base ref whose .anchor.yml loads, or drop --base.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:262: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:258: (test)

........



  2) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:377
     Assertion with =~ failed
     code:  assert issue.message =~ ~s|rules "f", "g", "h"|
     left:  "Anchor could not read .anchor.yml at main ({:invalid_config, \"the document is empty\"}), so no baseline's copy there could be found by its rule's id and GREW could not be judged for rules \"f\". Fix: pass a --base ref whose .anchor.yml loads, or drop --base."
     right: "rules \"f\", \"g\", \"h\""
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:402: (test)

.......................
```

### BC-C: an unjudged rule's findings are held, so the verdict changes

Run summary: `41 tests, 1 failure`

```text


  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:377
     Assertion with == failed
     code:  assert report.held == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "g",
                type: :stub_finds,
                label: "rule 1 (id: \"g\", stub_finds)",
                enforcement: :enforce,
                key: "g|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              },
```

### BC-D: only the first rule's id is collected

Run summary: `41 tests, 1 failure`

```text


  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:377
     Assertion with =~ failed
     code:  assert issue.message =~ ~s|rules "f", "g", "h"|
     left:  "Anchor could not read .anchor.yml at main ({:invalid_config, \"the document is empty\"}), so no baseline's copy there could be found by its rule's id and GREW could not be judged for rules \"f\". Fix: pass a --base ref whose .anchor.yml loads, or drop --base."
     right: "rules \"f\", \"g\", \"h\""
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:402: (test)

..........
```

