# Sabotage records: graph runner (branch dnd-5648-graph-followups)

- **Domain:** graph_runner
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- One section per ticket of the batch, in commit order.

## DND-5655: an absolute apps_path is keyed or refused, never raised

**Code under test:** `Anchor.Domain.Graph.ProjectFile.source_dirs/2`, its call in `Anchor.Managers.Graph.run/2`, and `Anchor.Domain.Failures.graph_apps_path_outside/3`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). AP-R is the new tests on the unfixed code: the Manager raised `ArgumentError` (`the directory must be relative to the root, got: "/proj/apps/alpha"`) with no `Fix:` line. With every source restored: `74 tests, 0 failures` over project_file, the graph Manager, failures and task tests.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AP-R | regression: the unfixed code, with the new tests (`lib/anchor/managers/graph.ex`) | `project_file_test.exs`, `graph_test.exs` | `47 tests, 5 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine; place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app; place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |
| AP-A | the Manager does not key the app directories (`lib/anchor/managers/graph.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one |
| AP-B | an absolute dir under the root is kept absolute (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one |
| AP-C | a dir outside the root is keyed through .. instead of refused (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |
| AP-D | a sibling sharing the root's prefix reads as under it (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 1 failure` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app |
| AP-E | the root itself is not made "." (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 1 failure` (red) | place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine |

Filed under their own domain word (ADR 003): AP-F in `failures-20261103-dnd_5648_graph_followups.md`.

### AP-R: regression: the unfixed code, with the new tests

Run summary: `47 tests, 5 failures`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:105
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(%{alpha: "/work/my_app"}, @root) == {:ok, %{alpha: "."}}
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/work/my_app"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:106: (test)

...



  2) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/elsewhere/alpha", beta: "apps/beta", gamma: "/work/my_app/../x"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:99: (test)







  3) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:90
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:91: (test)

...................................



  4) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:59: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:293: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:290: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:216: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)







  5) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.411.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:196: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:114: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

...
```

### AP-A: the Manager does not key the app directories

Run summary: `63 tests, 2 failures`

```text


  1) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.364.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:210: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:115: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

.........................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:99: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:307: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:304: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:230: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)

.....
```

### AP-B: an absolute dir under the root is kept absolute

Run summary: `63 tests, 2 failures`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:90
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"},
              @root
            ) == {:ok, %{alpha: "apps/alpha", beta: "apps/beta"}}
     left:  {:ok, %{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"}}
     right: {:ok, %{alpha: "apps/alpha", beta: "apps/beta"}}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:91: (test)

.................................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:99: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:307: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:304: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:230: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)

.......................
```

### AP-C: a dir outside the root is keyed through .. instead of refused

Run summary: `63 tests, 2 failures`

```text






  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{
                alpha: "/elsewhere/alpha",
                beta: "apps/beta",
                gamma: "/work/my_app/../x",
                delta: "/work/my_app_other/delta"
              },
              @root
            ) ==
              {:error,
               alpha: "/elsewhere/alpha", delta: "/work/my_app_other/delta", gamma: "/work/my_app/../x"}
     left:  {:ok,
             %{
               alpha: "../../elsewhere/alpha",
               beta: "apps/beta",
               gamma: "../x",
               delta: "../my_app_other/delta"
             }}
     right: {:error,
             [
               alpha: "/elsewhere/alpha",
               delta: "/work/my_app_other/delta",



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.436.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:210: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:115: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

.........
```

### AP-D: a sibling sharing the root's prefix reads as under it

Run summary: `63 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{
                alpha: "/elsewhere/alpha",
                beta: "apps/beta",
                gamma: "/work/my_app/../x",
                delta: "/work/my_app_other/delta"
              },
              @root
            ) ==
              {:error,
               alpha: "/elsewhere/alpha", delta: "/work/my_app_other/delta", gamma: "/work/my_app/../x"}
     left:  {:error, [alpha: "/elsewhere/alpha", gamma: "/work/my_app/../x"]}
     right: {:error,
             [
               alpha: "/elsewhere/alpha",
               delta: "/work/my_app_other/delta",
               gamma: "/work/my_app/../x"
             ]}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:99: (test)

.......................................................
```

### AP-E: the root itself is not made "."

Run summary: `63 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:116
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(%{alpha: "/work/my_app"}, @root) == {:ok, %{alpha: "."}}
     left:  {:ok, %{alpha: "/work/my_app"}}
     right: {:ok, %{alpha: "."}}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:117: (test)

...........................................................
```

## DND-5656: the outside-root count is taken after the builder dedupes beams

**Code under test:** `Anchor.Managers.Graph`'s `outside_root_count/1` (now over the graph's modules) and `Anchor.Domain.Graph.ProjectFile.outside_root?/1`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). OR-R is the new Manager test on the unfixed code (graph_test.exs alone: `outside_root?/1` did not exist yet): a stale duplicate of an outside-root module was counted twice (`outside_root: 2`). With every source restored: `49 tests, 0 failures` over graph_test.exs and project_file_test.exs.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| OR-R | regression: the unfixed code, with the new tests (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `38 tests, 1 failure` (red) | run/2 source paths outside the project root (DND-5588, DND-5630) a stale duplicate of an outside-root module counts once |
| OR-A | the count is taken over every beam read, the stale duplicate included (`lib/anchor/managers/graph.ex`) | `graph_test.exs`, `project_file_test.exs` | `49 tests, 1 failure` (red) | run/2 source paths outside the project root (DND-5588, DND-5630) a stale duplicate of an outside-root module counts once |
| OR-B | ".." alone is not outside (`lib/anchor/domain/graph/project_file.ex`) | `graph_test.exs`, `project_file_test.exs` | `49 tests, 1 failure` (red) | place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path |
| OR-C | no path reads as outside (`lib/anchor/domain/graph/project_file.ex`) | `graph_test.exs`, `project_file_test.exs` | `49 tests, 1 failure` (red) | place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path |
| OR-D | a name starting with .. ("..cache/x.ex") reads as outside (`lib/anchor/domain/graph/project_file.ex`) | `graph_test.exs`, `project_file_test.exs` | `49 tests, 2 failures` (red) | the table; place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path |

### OR-R: regression: the unfixed code, with the new tests

Run summary: `38 tests, 1 failure`

```text


  1) test run/2 source paths outside the project root (DND-5588, DND-5630) a stale duplicate of an outside-root module counts once (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:697
     match (=) failed
     code:  assert %{modules: 3, outside_root: 1} = report.counts
     left:  %{modules: 3, outside_root: 1}
     right: %{
              modules: 3,
              opaque: 0,
              apps: 2,
              rules: 1,
              no_core: 0,
              outside_root: 2,
              dynamic_calls: %{narrowed: [], fanned_out: []},
              apply_sites: nil
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:723: (test)

.......................
```

### OR-A: the count is taken over every beam read, the stale duplicate included

Run summary: `49 tests, 1 failure`

```text


  1) test run/2 source paths outside the project root (DND-5588, DND-5630) a stale duplicate of an outside-root module counts once (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:697
     match (=) failed
     code:  assert %{modules: 3, outside_root: 1} = report.counts
     left:  %{modules: 3, outside_root: 1}
     right: %{
              modules: 3,
              opaque: 0,
              apps: 2,
              rules: 1,
              no_core: 0,
              outside_root: 2,
              apply_sites: nil,
              dynamic_calls: %{narrowed: [], fanned_out: []}
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:723: (test)

...................................
```

### OR-B: ".." alone is not outside

Run summary: `49 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:85
     Expected truthy, got false
     code: assert ProjectFile.outside_root?("..")
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:87: (test)

...........................................
```

### OR-C: no path reads as outside

Run summary: `49 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:85
     Expected false or nil, got true
     code: refute ProjectFile.outside_root?(nil)
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:90: (test)

..........................................
```

### OR-D: a name starting with .. ("..cache/x.ex") reads as outside

Run summary: `49 tests, 2 failures`

```text


  1) test the table (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:16
     "..foo/x.ex"
     code: for {file, expected} <- [
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:40: anonymous fn/2 in Anchor.Domain.Graph.ProjectFileTest."test the table"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph/project_file_test.exs:17: (test)

.



  2) test place/3 with the directory the compiler ran in outside_root?/1 reads a keyed path (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:85
     Expected false or nil, got true
     code: refute ProjectFile.outside_root?("..x/y.ex")
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:89: (test)

............................................
```

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers (DY-M)

**Run with:** the `## DND-5633: a dynamic call narrowed to a declared behaviour's implementers` section of `layering-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-M | the summary drops the dynamic-call counts (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `24 tests, 1 failure` (red) | dynamic calls (DND-5633) the summary ends with the fanned-out and narrowed counts |

### DY-M: the summary drops the dynamic-call counts

Run summary: `24 tests, 1 failure`

```text


  1) test dynamic calls (DND-5633) the summary ends with the fanned-out and narrowed counts (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:207
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                "(0 report-only, 0 baselined); dynamic calls: 2 fanned out to every " <>
                "exporter, 1 narrowed by behaviour"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); dynamic calls: 2 fanned out to every exporter, 1 narrowed by behaviour"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:210: (test)

....
```

## anchor.graph after the merge of main: the new graph rules judge this branch clean (FX-B, FX-D)

**Run with:** the section of the same name in `baseline-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated (ADR 003).

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| FX-B | narrows?/3 asks no rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `enforcement_test.exs`, `graph_baseline_test.exs` | `53 tests, 3 failures` (red) | narrows?/3 a rule declaring narrows?/2 is asked; judge/4 an added entry narrowing a removed one is a report NOTE, not GREW; run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |
| FX-D | Finding.with_enforcement/2 keeps the old enforcement (`lib/anchor/domain/graph_report/finding.ex`) | `graph_report_test.exs`, `enforcement_test.exs`, `graph_baseline_test.exs` | `64 tests, 3 failures` (red) | Finding.with_enforcement/2 sets the enforcement and keeps every other field; judge/4 an added entry narrowing a removed one is a report NOTE, not GREW; run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |

### FX-B: narrows?/3 asks no rule

Run summary: `53 tests, 3 failures`

```text
  1) test narrows?/3 a rule declaring narrows?/2 is asked (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:91
     Expected truthy, got false
     code: assert GraphRules.narrows?(Anchor.Domain.GraphRules.ContextAcyclic, "c|A,B,C", "c|A,B")
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:92: (test)

...............

  2) test judge/4 an added entry narrowing a removed one is a report NOTE, not GREW (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:130
     Assertion with == failed
     code:  assert note.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/enforcement_test.exs:136: (test)

....................

  3) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

.............
```

### FX-D: Finding.with_enforcement/2 keeps the old enforcement

Run summary: `64 tests, 3 failures`

```text
  1) test Finding.with_enforcement/2 sets the enforcement and keeps every other field (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:310
     Assertion with == failed
     code:  assert reported.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/graph_report_test.exs:321: (test)

.......

  2) test judge/4 an added entry narrowing a removed one is a report NOTE, not GREW (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:130
     Assertion with == failed
     code:  assert note.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/enforcement_test.exs:136: (test)

..........

  3) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

.......................
```

