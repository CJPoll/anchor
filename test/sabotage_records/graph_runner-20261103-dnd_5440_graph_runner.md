# Sabotage record — the graph runner, `mix anchor.graph` (DND-5440)

- **Domain:** graph_runner
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Managers.Graph`, `Mix.Tasks.Anchor.Graph`, `Anchor.Domain.Model`, `Anchor.Domain.GraphRules`, `Anchor.Domain.GraphReport` (+ `Finding`), `Anchor.Domain.GraphKey`, `Anchor.Adapters.GraphArtifact`, `Anchor.Adapters.SourceReader`
- **Suite run:** Each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red: a non-zero ExUnit result naming the test the mutation is meant to break.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| GR-A | 3 does not win: a could-not-check report exits 1 (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `10 tests, 2 failures` | exit_code/1 a could-not-check entry is 3, and 3 wins over 1; render/2 :json decodes with modules, findings and could_not_check; each finding splits message and fix |
| GR-B | a finding with no line prints an empty line number (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `10 tests, 2 failures` | render/2 :text one line per finding, then the summary with exact counts; render/2 :text could-not-check entries print first and count as violations |
| GR-C | report-only findings counted as violations (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `10 tests, 1 failure` | render/2 :text one line per finding, then the summary with exact counts |
| GR-D | the JSON fix is never split from the message (`lib/anchor/domain/graph_report/finding.ex`) | `graph_report_test.exs` | `10 tests, 1 failure` | render/2 :json decodes with modules, findings and could_not_check; each finding splits message and fix |
| GK-A | entries keyed in byte order, not path order (`lib/anchor/domain/graph_key.ex`) | `graph_key_test.exs` | `5 tests, 1 failure` | two paths with the same bytes give one key whichever is read first (sorted by path) |
| GK-B | parts not framed (concatenation collides) (`lib/anchor/domain/graph_key.ex`) | `graph_key_test.exs` | `5 tests, 1 failure` | moving bytes between a path and its beam changes the key (each part is framed) |
| GRL-A | bucket: selects every classified module (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_test.exs` | `29 tests, 11 failures` | below_floor/2 a rule below its min_modules is reported with its count; at the floor it is not; select/2 bucket: selects the bucket's modules, sorted; below_floor/2 the default floor is 1: a rule selecting nothing is below it; run/2 happy path a report-only rule's findings print and exit 0; run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print; run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints; run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config; run/2 --only narrows to the named rules; a running rule's floor is still judged; run/2 rule crash isolation (AC4) stub_raises: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints |
| GRL-B | rule floor off by one (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_test.exs` | `29 tests, 3 failures` | below_floor/2 the default floor is 1: a rule selecting nothing is below it; below_floor/2 a rule below its min_modules is reported with its count; at the floor it is not; run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config |
| MG-A | the rule guard catches raises only: a throw or exit escapes (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 2 failures` | run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints |
| MG-B | no architecture: section is not refused (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 1 failure` | run/2 could not measure (exit 3) a config with no architecture: section is exit 3 |
| MG-C | zero modules read is measured (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 2 failures` | run/2 could not measure (exit 3) zero modules read is exit 3, COULD NOT MEASURE naming the ebins; no artifact written; run/2 could not measure (exit 3) only undecodable beams is zero modules read: exit 3 |
| MG-D | unreadable beams are dropped (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 2 failures` | run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print; run/2 per-module fail-closed issues (exit 1) a core_v1 refusal is a per-module issue |
| MG-E | a running rule's floor is never judged (under --only or not) (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 2 failures` | run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config; run/2 --only narrows to the named rules; a running rule's floor is still judged |
| MG-F | an --only id naming no rule runs nothing and reads clean (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 1 failure` | run/2 --only naming no rule is exit 3: a narrowed run that checks nothing must not read clean |
| MG-G | an unreadable source file is dropped (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 1 failure` | run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it |
| MG-H | a failed artifact write is silent (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 1 failure` | run/2 graph artifact a failed write is a report-only note; the verdict stands |
| MG-I | the Manager reads the artifact (P2) (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 16 failures` | run/2 --only narrows to the named rules; a running rule's floor is still judged; run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue; run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it; run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print; run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue; run/2 happy path every module classifies and the rule holds: exit 0, counts exact, artifact written once; run/2 per-module fail-closed issues (exit 1) a core_v1 refusal is a per-module issue; run/2 per-module fail-closed issues (exit 1) an interfaces.exports entry naming no module is an issue on the config; one naming a module is not; run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints; run/2 per-module fail-closed issues (exit 1) an unclassified module is one issue on its source file; run/2 graph artifact a failed write is a report-only note; the verdict stands; run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints; run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config; run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints; run/2 happy path a report-only rule's findings print and exit 0; run/2 rule crash isolation (AC4) stub_raises: one issue naming the rule and reason; a second rule's finding still prints |
| MD-A | exports naming a project module are reported; ones naming nothing are not (`lib/anchor/domain/model.ex`) | `model_test.exs`, `graph_test.exs` | `29 tests, 2 failures` | build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not; run/2 per-module fail-closed issues (exit 1) an interfaces.exports entry naming no module is an issue on the config; one naming a module is not |
| MD-B | Erlang modules are never classified (`lib/anchor/domain/model.ex`) | `graph_test.exs` | `21 tests, 2 failures` | run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue; run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue |
| AR-A | the artifact dir is not confined (`lib/anchor/adapters/graph_artifact.ex`) | `graph_artifact_test.exs` | `4 tests, 1 failure` | a directory outside _build/<env>/anchor is refused, for write and read |
| AR-B | a stale artifact is used (`lib/anchor/adapters/graph_artifact.ex`) | `graph_artifact_test.exs` | `4 tests, 1 failure` | another key is stale, never used |
| SR-A | a missing file is dropped (`lib/anchor/adapters/source_reader.ex`) | `source_reader_test.exs` | `1 test, 1 failure` | each path relative to the root becomes its facts; unparseable and missing files are errors, never dropped |
| TK-A | --only never reaches the Manager (`lib/mix/tasks/anchor.graph.ex`) | `anchor_graph_test.exs` | `5 tests, 1 failure` | --format json --only a --only b runs only rules a and b, and prints JSON |
| TK-B | a failing report exits 0 (`lib/mix/tasks/anchor.graph.ex`) | `anchor_graph_test.exs` | `5 tests, 3 failures` | a violation exits {:shutdown, 1} after printing it; --format json --only a --only b runs only rules a and b, and prints JSON; could not measure exits {:shutdown, 3} |
| TK-C | the task does not compile first (`lib/mix/tasks/anchor.graph.ex`) | `anchor_graph_test.exs` | `5 tests, 1 failure` | a passing run prints the summary and returns :ok after compiling |
| MD-C | a module whose uses cannot be read is silent (`lib/anchor/domain/model.ex`) | `model_test.exs` | `8 tests, 1 failure` | build/3 uses it cannot read a module its file's literal defmodules do not name, with a uses_module selector, is an issue |
| MD-D | exports include defp and macros (`lib/anchor/domain/model.ex`) | `model_test.exs` | `8 tests, 5 failures` | build/3 uses it cannot read with no uses_module selector it is not (positive control above); build/3 classification through the graph each selector kind classifies its module; no issues when every module lands once; build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not; opaque/1 an Erlang module no bucket classifies is an issue on its beam, not opaque; build/3 classification through the graph facts/2 exports only def functions, sorted, and strips Elixir. to find the uses |
| MD-E | an export naming a module the graph could not build is also reported missing (`lib/anchor/domain/model.ex`) | `model_test.exs` | `8 tests, 1 failure` | build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not |
| MD-F | uses looked up under the Elixir.-prefixed name (`lib/anchor/domain/model.ex`) | `model_test.exs` | `8 tests, 4 failures` | build/3 classification through the graph facts/2 exports only def functions, sorted, and strips Elixir. to find the uses; opaque/1 an Erlang module no bucket classifies is an issue on its beam, not opaque; build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not; build/3 classification through the graph each selector kind classifies its module; no issues when every module lands once |
| MG-J | a rule's non-list return is read as no violations (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `21 tests, 1 failure` | run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints |

## Earlier driver passes, and what changed

Two earlier passes ran on earlier trees of this branch; this record is the
third, on the tree under review. Between them:

- GK-A survived a pass: keying entries in byte order instead of path order
  still gave one key for reordered input, because the test's entries had
  distinct bytes. A test was added ("two paths with the same bytes give one
  key whichever is read first"); GK-A is red on it.
- GK-B, MG-A and AR-A did not compile in a pass (an unused function, an
  unreachable clause; `--warnings-as-errors`), so they proved nothing. Each
  was re-shaped to a mutation that compiles, shown here.
- The review floor's findings changed the code: the source adapter returns
  SourceFacts (SR-A re-shaped), a running rule's floor is judged under
  `--only` too (MG-E re-shaped), and MD-C to MD-F and MG-J were added with
  their tests.

## GR-A — 3 does not win: a could-not-check report exits 1

Run summary: `10 tests, 2 failures`

```

  1) test exit_code/1 a could-not-check entry is 3, and 3 wins over 1 (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:50
     Assertion with == failed
     code:  assert GraphReport.new([], [could_not], @counts).exit_code == 3
     left:  1
     right: 3
     stacktrace:
       test/anchor/domain/graph_report_test.exs:52: (test)

..
```

## GR-B — a finding with no line prints an empty line number

Run summary: `10 tests, 2 failures`

```



  1) test render/2 :text one line per finding, then the summary with exact counts (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:58
     Assertion with == failed
     code:  assert GraphReport.render(report, :text) ==
              ~s|lib/my_app/web.ex:7: [enforce] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                ~s|lib/my_app/web.ex:1: [report] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                "anchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
     left:  "lib/my_app/web.ex:7: [enforce] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nlib/my_app/web.ex:: [report] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nanchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
     right: "lib/my_app/web.ex:7: [enforce] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nlib/my_app/web.ex:1: [report] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nanchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:61: (test)

........
```

## GR-C — report-only findings counted as violations

Run summary: `10 tests, 1 failure`

```

  1) test render/2 :text one line per finding, then the summary with exact counts (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:58
     Assertion with == failed
     code:  assert GraphReport.render(report, :text) ==
              ~s|lib/my_app/web.ex:7: [enforce] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                ~s|lib/my_app/web.ex:1: [report] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                "anchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
     left:  "lib/my_app/web.ex:7: [enforce] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nlib/my_app/web.ex:1: [report] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nanchor.graph: 12 modules in 2 apps, 3 rules, 2 violations (0 report-only, 0 baselined)"
     right: "lib/my_app/web.ex:7: [enforce] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nlib/my_app/web.ex:1: [report] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nanchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:61: (test)

...
```

## GR-D — the JSON fix is never split from the message

Run summary: `10 tests, 1 failure`

```



  1) test render/2 :json decodes with modules, findings and could_not_check; each finding splits message and fix (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:92
     match (=) failed
     code:  assert %{
              "modules" => 12,
              "exit_code" => 3,
              "findings" => [finding_json],
              "could_not_check" => [%{"message" => "COULD NOT MEASURE: x.", "fix" => "y.", "type" => nil}]
            } = JSON.decode!(GraphReport.render(report, :json))
     left:  %{
              "modules" => 12,
              "exit_code" => 3,
              "findings" => [finding_json],
              "could_not_check" => [%{"message" => "COULD NOT MEASURE: x.", "fix" => "y.", "type" => nil}]
            }
     right: %{
              "apps" => 2,
              "could_not_check" => [
                %{
                  "enforcement" => "enforce",
                  "file" => "lib/my_app/web.ex",
                  "fix" => nil,
                  "key" => nil,
                  "line" => 7,
                  "message" => "COULD NOT MEASURE: x. Fix: y.",
                  "rule_id" => nil,
                  "type" => nil
                }
              ],
              "exit_code" => 3,
              "findings" => [
                %{
                  "enforcement" => "report",
                  "file" => "lib/my_app/web.ex",
                  "fix" => nil,
                  "key" => "MyApp.Web->MyApp.Repo",
                  "line" => 7,
     ... (cut at 40 lines)
```

## GK-A — entries keyed in byte order, not path order

Run summary: `5 tests, 1 failure`

```

  1) test two paths with the same bytes give one key whichever is read first (sorted by path) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:19
     Assertion with == failed
     code:  assert GraphKey.key(Enum.reverse(same), "c", "v") == GraphKey.key(same, "c", "v")
     left:  "f7fc5479e5de1c8aa11241700d4ed311ccb3ff89a54539ee6076851d07f65641"
     right: "4be4dadcbe645d3d5e4c6b3edd1197769c4b908034bb9de9eb7c4662d689f189"
     stacktrace:
       test/anchor/domain/graph_key_test.exs:21: (test)

..
```

## GK-B — parts not framed (concatenation collides)

Run summary: `5 tests, 1 failure`

```

  1) test moving bytes between a path and its beam changes the key (each part is framed) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:34
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key([{"ab", "c"}], "", "") == GraphKey.key([{"a", "bc"}], "", "")
     left: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
     stacktrace:
       test/anchor/domain/graph_key_test.exs:35: (test)

..
```

## GRL-A — bucket: selects every classified module

Run summary: `29 tests, 11 failures`

```

  1) test below_floor/2 a rule below its min_modules is reported with its count; at the floor it is not (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:83
     Assertion with == failed
     code:  assert GraphRules.below_floor(model(), [below, at]) == [{below, 2}]
     left:  []
     right: [{%{min_modules: 3, bucket: "domain"}, 2}]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:87: (test)

.
```

## GRL-B — rule floor off by one

Run summary: `29 tests, 3 failures`

```



  1) test below_floor/2 the default floor is 1: a rule selecting nothing is below it (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:90
     Assertion with == failed
     code:  assert GraphRules.below_floor(model(), [none]) == [{none, 0}]
     left:  []
     right: [{%{bucket: "ui"}, 0}]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:92: (test)
```

## MG-A — the rule guard catches raises only: a throw or exit escapes

Run summary: `21 tests, 2 failures`

```

  1) test run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:357
     ** (throw) :thrown
     code: report = Graph.run(request(), deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/managers/graph.ex:236: Anchor.Managers.Graph.guarded_check/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:215: Anchor.Managers.Graph.check/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:200: Anchor.Managers.Graph.run_rule/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:141: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:362: (test)

..........
```

## MG-B — no architecture: section is not refused

Run summary: `21 tests, 1 failure`

```

  1) test run/2 could not measure (exit 3) a config with no architecture: section is exit 3 (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:186
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.268.0>
     code: report = Graph.run(request(), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:126: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:71: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:191: (test)

..................
```

## MG-C — zero modules read is measured

Run summary: `21 tests, 2 failures`

```

  1) test run/2 could not measure (exit 3) zero modules read is exit 3, COULD NOT MEASURE naming the ebins; no artifact written (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:197
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceSourceMock.read/2 in process #PID<0.278.0> with args ["/proj", []]
     code: report = Graph.run(request(), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:165: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:137: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:202: (test)

...
```

## MG-D — unreadable beams are dropped

Run summary: `21 tests, 2 failures`

```

  1) test run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:223
     match (=) failed
     code:  assert [issue, rule_finding] = report.findings
     left:  [issue, rule_finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "AnchorFixtures.GraphManagerTest.User",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:233: (test)
```

## MG-E — a running rule's floor is never judged (under --only or not)

Run summary: `21 tests, 2 failures`

```

  1) test run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:340
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_test.exs:344: (test)
```

## MG-F — an --only id naming no rule runs nothing and reads clean

Run summary: `21 tests, 1 failure`

```



  1) test run/2 --only naming no rule is exit 3: a narrowed run that checks nothing must not read clean (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:403
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.264.0>
     code: report = Graph.run(request(%{format: :text, only: ["ok", "typo"]}), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:129: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:71: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:408: (test)

....................
```

## MG-G — an unreadable source file is dropped

Run summary: `21 tests, 1 failure`

```

  1) test run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:262
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_test.exs:267: (test)

...
```

## MG-H — a failed artifact write is silent

Run summary: `21 tests, 1 failure`

```

  1) test run/2 graph artifact a failed write is a report-only note; the verdict stands (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:417
     match (=) failed
     code:  assert [%{enforcement: :report, message: message}] = report.findings
     left:  [%{enforcement: :report, message: message}]
     right: []
     stacktrace:
       test/anchor/managers/graph_test.exs:424: (test)

...
```

## MG-I — the Manager reads the artifact (P2)

Run summary: `21 tests, 16 failures`

```



  1) test run/2 --only narrows to the named rules; a running rule's floor is still judged (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:378
     ** (Mox.UnexpectedCallError) expected Anchor.GraphStoreMock.read/2 to be called 0 times but it has been called once in process #PID<0.264.0>
     code: report = Graph.run(request(%{format: :text, only: ["a", "c"]}), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:259: Anchor.Managers.Graph.write_artifact/5
       (anchor 0.1.0) lib/anchor/managers/graph.ex:142: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:387: (test)
```

## MD-A — exports naming a project module are reported; ones naming nothing are not

Run summary: `29 tests, 2 failures`

```

  1) test build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not (Anchor.Domain.ModelTest)
     test/anchor/domain/model_test.exs:195
     Assertion with =~ failed
     code:  assert message =~ "architecture interfaces.exports names X.Gone, which is no module"
     left:  "architecture interfaces.exports names X.Agg, which is no module of the project, so it exports nothing today and would export any module later given that name. Fix: in .anchor.yml, rename the entry to the module that is the interface, or remove it."
     right: "architecture interfaces.exports names X.Gone, which is no module"
     stacktrace:
       test/anchor/domain/model_test.exs:212: (test)

............
```

## MD-B — Erlang modules are never classified

Run summary: `21 tests, 2 failures`

```

  1) test run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:272
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_test.exs:288: (test)

.....
```

## AR-A — the artifact dir is not confined

Run summary: `4 tests, 1 failure`

```



  1) test a directory outside _build/<env>/anchor is refused, for write and read (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:27
     Assertion with == failed
     code:  assert GraphArtifact.write(outside, "k", :graph) == {:error, :outside_artifact_dir}
     left:  :ok
     right: {:error, :outside_artifact_dir}
     stacktrace:
       test/anchor/adapters/graph_artifact_test.exs:36: anonymous fn/2 in Anchor.Adapters.GraphArtifactTest."test a directory outside _build/<env>/anchor is refused, for write and read"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/adapters/graph_artifact_test.exs:30: (test)

...
```

## AR-B — a stale artifact is used

Run summary: `4 tests, 1 failure`

```

  1) test another key is stale, never used (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:22
     Assertion with == failed
     code:  assert GraphArtifact.read(dir(tmp_dir), "k2") == {:error, :stale}
     left:  {:ok, :graph}
     right: {:error, :stale}
     stacktrace:
       test/anchor/adapters/graph_artifact_test.exs:24: (test)

.
```

## SR-A — a missing file is dropped

Run summary: `1 test, 1 failure`

```



  1) test each path relative to the root becomes its facts; unparseable and missing files are errors, never dropped (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:12
     Assertion with == failed
     code:  assert SourceReader.read(tmp_dir, ["lib/a.ex", "lib/broken.ex", "lib/gone.ex"]) == %{
              "lib/a.ex" => %{defmodules: ["A"], uses: %{"A" => ["GenServer"]}, nonliteral_defmodule?: false},
              "lib/broken.ex" => {:error, :unparseable},
              "lib/gone.ex" => {:error, :enoent}
            }
     left:  %{
              "lib/a.ex" => %{
                uses: %{"A" => ["GenServer"]},
                defmodules: ["A"],
                nonliteral_defmodule?: false
              }
            }
     right: %{
              "lib/a.ex" => %{
                uses: %{"A" => ["GenServer"]},
                defmodules: ["A"],
                nonliteral_defmodule?: false
              },
              "lib/broken.ex" => {:error, :unparseable},
              "lib/gone.ex" => {:error, :enoent}
            }
     stacktrace:
       test/anchor/adapters/source_reader_test.exs:18: (test)
```

## TK-A — --only never reaches the Manager

Run summary: `5 tests, 1 failure`

```

  1) test --format json --only a --only b runs only rules a and b, and prints JSON (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:101
     match (=) failed
     code:  assert %{"rules" => 2, "findings" => [%{"rule_id" => "a", "file" => @file_path}]} = JSON.decode!(output)
     left:  %{"rules" => 2, "findings" => [%{"rule_id" => "a", "file" => "lib/app/domain/thing.ex"}]}
     right: %{
              "apps" => 1,
              "could_not_check" => [],
              "exit_code" => 1,
              "findings" => [
                %{
                  "enforcement" => "enforce",
                  "file" => "lib/app/domain/thing.ex",
                  "fix" => "do not be found.",
                  "key" => "AnchorFixtures.AnchorGraphTaskTest.Thing",
                  "line" => 2,
                  "message" => "AnchorFixtures.AnchorGraphTaskTest.Thing was found.",
                  "rule_id" => "a",
                  "type" => "stub_finds"
                },
                %{
                  "enforcement" => "enforce",
                  "file" => ".anchor.yml",
                  "fix" => "this is an Anchor bug; file it with this line.",
                  "key" => nil,
                  "line" => nil,
                  "message" => "rule 3 (id: \"c\", stub_raises) could not run: RuntimeError: rule blew up (raised at test/support/graph_rule_stubs.ex:41: Anchor.Test.GraphRuleStubs.Raises.check/2), so it checked nothing.",
                  "rule_id" => nil,
                  "type" => nil
                }
              ],
              "modules" => 1,
              "opaque" => 0,
              "rules" => 3
            }
     stacktrace:
       test/mix/tasks/anchor_graph_test.exs:113: (test)

...
```

## TK-B — a failing report exits 0

Run summary: `5 tests, 3 failures`

```



  1) test a violation exits {:shutdown, 1} after printing it (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:117
     Expected to catch exit, got nothing
     code: output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 1} end)
     stacktrace:
       test/mix/tasks/anchor_graph_test.exs:120: anonymous fn/0 in Mix.Tasks.Anchor.GraphTest."test a violation exits {:shutdown, 1} after printing it"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_graph_test.exs:120: (test)
```

## TK-C — the task does not compile first

Run summary: `5 tests, 1 failure`

```

  1) test a passing run prints the summary and returns :ok after compiling (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:90
     Assertion failed, no matching message after 0ms
     The process mailbox is empty.
     code: assert_received :compiled
     stacktrace:
       test/mix/tasks/anchor_graph_test.exs:95: (test)
```

## MD-C — a module whose uses cannot be read is silent

Run summary: `8 tests, 1 failure`

```

  1) test build/3 uses it cannot read a module its file's literal defmodules do not name, with a uses_module selector, is an issue (Anchor.Domain.ModelTest)
     test/anchor/domain/model_test.exs:173
     Expected truthy, got false
     code: assert Enum.any?(
             issues,
             &(&1.filename == "lib/x/worker.ex" and
                 &1.message =~ "X.Worker's literal uses cannot be read from lib/x/worker.ex")
           )
     arguments:

         # 1
         [
           %Anchor.Domain.Violation{
             line: 1,
             trigger: nil,
             message: "X.Worker is in no architecture bucket. Fix: add a selector that matches lib/x/worker.ex to the bucket this module belongs in (mix anchor.explain lib/x/worker.ex shows the candidates).",
             filename: "lib/x/worker.ex",
             kind: :fail_closed,
             key: nil,
             rule_id: nil
           },
           %Anchor.Domain.Violation{
             line: nil,
             trigger: nil,
             message: "architecture bucket workers selects 0 modules, below min_modules 1. Fix: correct the selector; lowering min_modules is the owner's call.",
             filename: ".anchor.yml",
             kind: :fail_closed,
             key: nil,
             rule_id: nil
           }
         ]

         # 2
         #Function<4.108858759/1 in Anchor.Domain.ModelTest."test build/3 uses it cannot read a module its file's literal defmodules do not name, with a uses_module selector, is an issue"/1>

     stacktrace:
       test/anchor/domain/model_test.exs:176: (test)
```

## MD-D — exports include defp and macros

Run summary: `8 tests, 5 failures`

```



  1) test build/3 uses it cannot read with no uses_module selector it is not (positive control above) (Anchor.Domain.ModelTest)
     test/anchor/domain/model_test.exs:183
     Assertion with == failed
     code:  assert issues == []
     left:  [
              %Anchor.Domain.Violation{
                line: 1,
                trigger: nil,
                message: "X.Domain.Priv is in buckets agg (by exports_function \"__aggregate__/0\") and domain (by paths [\"lib/x/domain/**/*.ex\"]). Fix: narrow one selector; buckets never take precedence.",
                filename: "lib/x/domain/priv.ex",
                kind: :fail_closed,
                key: nil,
                rule_id: nil
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/model_test.exs:190: (test)
```

## MD-E — an export naming a module the graph could not build is also reported missing

Run summary: `8 tests, 1 failure`

```

  1) test build/3 interfaces.exports an entry naming no module is an issue; one naming a module, or one the graph could not build, is not (Anchor.Domain.ModelTest)
     test/anchor/domain/model_test.exs:195
     match (=) failed
     code:  assert [%{filename: ".anchor.yml", message: message}] = issues
     left:  [%{filename: ".anchor.yml", message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "architecture interfaces.exports names X.Crashed, which is no module of the project, so it exports nothing today and would export any module later given that name. Fix: in .anchor.yml, rename the entry to the module that is the interface, or remove it.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "architecture interfaces.exports names X.Gone, which is no module of the project, so it exports nothing today and would export any module later given that name. Fix: in .anchor.yml, rename the entry to the module that is the interface, or remove it.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil
              }
            ]
     stacktrace:
       test/anchor/domain/model_test.exs:211: (test)

.
```

## MD-F — uses looked up under the Elixir.-prefixed name

Run summary: `8 tests, 4 failures`

```

  1) test build/3 classification through the graph facts/2 exports only def functions, sorted, and strips Elixir. to find the uses (Anchor.Domain.ModelTest)
     test/anchor/domain/model_test.exs:132
     match (=) failed
     code:  assert %{exports: [a: 0, b: 1], uses: [GenServer], line: 1} = Model.facts(node, @source_facts)
     left:  %{exports: [a: 0, b: 1], uses: [GenServer], line: 1}
     right: %{
              exports: [a: 0, b: 1],
              line: 1,
              module: X.Worker,
              behaviours: [],
              uses: [],
              app: :x,
              source_file: "lib/x/worker.ex"
            }
     stacktrace:
       test/anchor/domain/model_test.exs:144: (test)
```

## MG-J — a rule's non-list return is read as no violations

Run summary: `21 tests, 1 failure`

```

  1) test run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:357
     match (=) failed
     code:  assert [crash, found] = report.findings
     left:  [crash, found]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 2 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "AnchorFixtures.GraphManagerTest.User",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:365: (test)

...................
```
