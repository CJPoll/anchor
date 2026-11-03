# Sabotage record — the graph runner fails closed per app (DND-5584)

- **Domain:** graph_runner
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Managers.Graph` (`empty_app_issues/2`), `Anchor.Domain.Graph.Beam.apps_without_modules/2`, `Anchor.Domain.Failures.graph_app_no_modules/2`
- **Suite run:** each mutation ran `mix test --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red.

## The bug's regression test, on the unfixed code

`run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app`, before the fix:

```
  1) test run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app (Anchor.Managers.GraphTest)
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
23 tests, 1 failure
```

After the fix: `23 tests, 0 failures`. AE-A below re-applies the unfixed shape.

## Review-floor re-run (2026-11-03, on 637a6b7)

The review floor (ADR 003) found that the rows below gave only counts and test
names. Every mutation was re-run on 637a6b7, the head after the review-floor
fixes, by a driver that keeps each failing test's ExUnit block verbatim; the
table and the sections after it are that run. A mutation whose source text the
fixes changed was re-anchored to the same defect in the new code. A row marked
"regression" is the unfixed code itself, not a mutation: its block is quoted
from the run that showed it red before the fix, as the fix commit records it.
The checkout's absolute path in the output reads `<worktree>`. Each run
forced compilation (`mix test --force`, and a write never in the same second
as the last): a first pass of this re-run measured BL-C on BL-B's stale beam,
which the critic caught from its verbatim output.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| AE-A | the Manager never reports an app that read no module (the unfixed code) (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `23 tests, 1 failure` (red) | run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
| AE-B | apps_without_modules lists no app (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs`, `graph_test.exs` | `26 tests, 3 failures` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module; apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
| AE-C | a decode error counts as the app's module (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs` | `3 tests, 1 failure` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module |
| AE-D | every app is listed, read or not (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs`, `graph_test.exs` | `26 tests, 21 failures` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module; apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not; apps_without_modules/2 positive control: every app read a module, none listed; run/2 --only narrows to the named rules; a running rule's floor is still judged; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app; run/2 an app that read no module (exit 1) positive control: both apps read a module, the run is clean; run/2 graph artifact a failed write is a report-only note; the verdict stands; run/2 happy path a report-only rule's findings print and exit 0; run/2 happy path every module classifies and the rule holds: exit 0, counts exact, artifact written once; run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print; run/2 per-module fail-closed issues (exit 1) a core_v1 refusal is a per-module issue; run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config; run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it; run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue; run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue; run/2 per-module fail-closed issues (exit 1) an interfaces.exports entry naming no module is an issue on the config; one naming a module is not; run/2 per-module fail-closed issues (exit 1) an unclassified module is one issue on its source file; run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_raises: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints |
| AE-E | the issue sits on the config, not the app's ebin (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs`, `graph_test.exs` | `37 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
| AE-O | the per-app check ignores the modules left out as outside the root (`lib/anchor/managers/graph.ex`, from the merge with DND-5588) | `graph_test.exs` | `29 tests, 1 failure` (red) | run/2 source paths outside the project root (DND-5588) an app whose only module is outside the root is not an empty ebin |

## AE-A — the Manager never reports an app that read no module (the unfixed code)

Run summary: `23 tests, 1 failure`

```text
  1) test run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:240
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_test.exs:247: (test)
```

## AE-B — apps_without_modules lists no app

Run summary: `26 tests, 3 failures`

```text
  1) test apps_without_modules/2 an app whose every beam failed to decode read no module (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:19
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, [beam(:a), beam(:c), error("ebin/b/y.beam")]) == [b: "ebin/b"]
     left:  []
     right: [b: "ebin/b"]
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:20: (test)

  2) test apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:15
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, [beam(:b)]) == [a: "ebin/a", c: "ebin/c"]
     left:  []
     right: [a: "ebin/a", c: "ebin/c"]
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:16: (test)

  3) test run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:240
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_test.exs:247: (test)
```

## AE-C — a decode error counts as the app's module

Run summary: `3 tests, 1 failure`

```text
  1) test apps_without_modules/2 an app whose every beam failed to decode read no module (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:19
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, [beam(:a), beam(:c), error("ebin/b/y.beam")]) == [b: "ebin/b"]
     left:  []
     right: [b: "ebin/b"]
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:20: (test)
```

## AE-D — every app is listed, read or not

Run summary: `26 tests, 21 failures`

```text
  1) test apps_without_modules/2 an app whose every beam failed to decode read no module (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:19
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, [beam(:a), beam(:c), error("ebin/b/y.beam")]) == [b: "ebin/b"]
     left:  [a: "ebin/a", b: "ebin/b", c: "ebin/c"]
     right: [b: "ebin/b"]
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:20: (test)

  2) test apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:15
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, [beam(:b)]) == [a: "ebin/a", c: "ebin/c"]
     left:  [a: "ebin/a", b: "ebin/b", c: "ebin/c"]
     right: [a: "ebin/a", c: "ebin/c"]
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:16: (test)

  3) test apps_without_modules/2 positive control: every app read a module, none listed (Anchor.Domain.Graph.BeamTest)
     test/anchor/domain/graph/beam_test.exs:24
     Assertion with == failed
     code:  assert Beam.apps_without_modules(@apps, Enum.map([:a, :b, :c], &beam/1)) == []
     left:  [a: "ebin/a", b: "ebin/b", c: "ebin/c"]
     right: []
     stacktrace:
       test/anchor/domain/graph/beam_test.exs:25: (test)

  4) test run/2 graph artifact a failed write is a report-only note; the verdict stands (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:459
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_test.exs:465: (test)

  5) test run/2 an app that read no module (exit 1) positive control: both apps read a module, the run is clean (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:254
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/proj/_build/test/lib/my_app/ebin",
                  line: nil,
                  message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
                },
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/proj/_build/test/lib/other/ebin",
                  line: nil,
                  message: "read 0 modules for app :other from /proj/_build/test/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; check that /proj/_build/test/lib/other/ebin is the app's ebin (its build path and app name)."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 2, opaque: 0, apps: 2, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:260: (test)

  6) test run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:382
     match (=) failed
     code:  assert [%{file: ".anchor.yml", message: message}] = report.findings
     left:  [%{file: ".anchor.yml", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"ok\", stub_ok) selects 1 modules, below min_modules 2. Fix: correct the selector; lowering min_modules is the owner's call."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:387: (test)

  7) test run/2 rule crash isolation (AC4) stub_raises: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:399
     match (=) failed
     code:  assert [crash, found] = report.findings
     left:  [crash, found]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"crash\", stub_raises) could not run: RuntimeError: rule blew up (raised at test/support/graph_rule_stubs.ex:43: Anchor.Test.GraphRuleStubs.Raises.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 2 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphManagerTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     ... (block cut at 40 lines)

  8) test run/2 happy path a report-only rule's findings print and exit 0 (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:159
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [finding]} = Graph.run(request(), deps())
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [finding]}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/proj/_build/test/lib/my_app/ebin",
                  line: nil,
                  message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
                },
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :report,
                  key: "f|AnchorFixtures.GraphManagerTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 2, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:162: (test)

  9) test run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:265
     match (=) failed
     code:  assert [issue, rule_finding] = report.findings
     left:  [issue, rule_finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin/Elixir.Broken.beam",
                line: nil,
                message: "Broken was compiled without debug_info, so Anchor cannot read it. Fix: remove debug_info: false from the project's elixirc_options (Elixir keeps debug_info by default)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphManagerTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     ... (block cut at 40 lines)

 10) test run/2 --only narrows to the named rules; a running rule's floor is still judged (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:420
     Assertion with == failed
     code:  assert Enum.map(report.findings, & &1.rule_id) == ["a", nil]
     left:  [nil, "a", nil]
     right: ["a", nil]
     stacktrace:
       test/anchor/managers/graph_test.exs:431: (test)

 11) test run/2 per-module fail-closed issues (exit 1) an interfaces.exports entry naming no module is an issue on the config; one naming a module is not (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:353
     match (=) failed
     code:  assert [%{file: ".anchor.yml", message: message}] = report.findings
     left:  [%{file: ".anchor.yml", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "architecture interfaces.exports names MyApp.Gone, which is no module of the project, so it exports nothing today and would export any module later given that name. Fix: in .anchor.yml, rename the entry to the module that is the interface, or remove it."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:378: (test)

 12) test run/2 happy path every module classifies and the rule holds: exit 0, counts exact, artifact written once (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:149
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/proj/_build/test/lib/my_app/ebin",
                  line: nil,
                  message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 2, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:155: (test)

 13) test run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:240
     match (=) failed
     code:  assert [%{file: @other_ebin, label: "anchor.graph", message: message}] = report.findings
     left:  [%{file: "/proj/_build/test/lib/other/ebin", label: "anchor.graph", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/other/ebin",
                line: nil,
                message: "read 0 modules for app :other from /proj/_build/test/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; check that /proj/_build/test/lib/other/ebin is the app's ebin (its build path and app name)."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:248: (test)

 14) test run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:399
     match (=) failed
     code:  assert [crash, found] = report.findings
     left:  [crash, found]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"crash\", stub_exits) could not run: exit: :gone (raised at test/support/graph_rule_stubs.ex:57: Anchor.Test.GraphRuleStubs.Exits.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 2 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphManagerTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     ... (block cut at 40 lines)

 15) test run/2 per-module fail-closed issues (exit 1) an unclassified module is one issue on its source file (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:295
     match (=) failed
     code:  assert [%{file: @stray_file, line: 1, message: message}] = report.findings
     left:  [%{file: "lib/my_app/stray.ex", line: 1, message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "lib/my_app/stray.ex",
                line: 1,
                message: "AnchorFixtures.GraphManagerTest.Stray is in no architecture bucket. Fix: add a selector that matches lib/my_app/stray.ex to the bucket this module belongs in (mix anchor.explain lib/my_app/stray.ex shows the candidates)."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:300: (test)

 16) test run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:399
     match (=) failed
     code:  assert [crash, found] = report.findings
     left:  [crash, found]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"crash\", stub_throws) could not run: throw: :thrown (raised at test/support/graph_rule_stubs.ex:50: Anchor.Test.GraphRuleStubs.Throws.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 2 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphManagerTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     ... (block cut at 40 lines)

 17) test run/2 per-module fail-closed issues (exit 1) a core_v1 refusal is a per-module issue (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:284
     match (=) failed
     code:  assert [%{message: message}] = report.findings
     left:  [%{message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin/r.beam",
                line: nil,
                message: "R the beam's backend could not produce Core Erlang (:boom). Fix: recompile with the project's own Elixir; report the reason if it persists."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:290: (test)

 18) test run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:314
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_test.exs:330: (test)

 19) test run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:399
     match (=) failed
     code:  assert [crash, found] = report.findings
     left:  [crash, found]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"crash\", stub_malformed) could not run: ArgumentError: check/2 returned :oops, not a list (raised at lib/anchor/managers/graph.ex:378: Anchor.Managers.Graph.violations!/1), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 2 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphManagerTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphManagerTest.User was found. Fix: do not be found."
              }
            ]
     ... (block cut at 40 lines)

 20) test run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:304
     match (=) failed
     code:  assert [%{file: @accounts_file, message: message}] = report.findings
     left:  [%{file: "lib/my_app/managers/accounts.ex", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "lib/my_app/managers/accounts.ex",
                line: nil,
                message: "Anchor could not read the source of lib/my_app/managers/accounts.ex (:enoent), so its uses_module selectors and generated? are unknown. Fix: make lib/my_app/managers/accounts.ex a readable file that parses (mix compile reports a syntax error), or run from the project root."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:310: (test)

 21) test run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:335
     match (=) failed
     code:  assert [%{message: message}] = report.findings
     left:  [%{message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin",
                line: nil,
                message: "read 0 modules for app :my_app from /proj/_build/test/lib/my_app/ebin, so none of its code was checked. Fix: run mix compile for :my_app; check that /proj/_build/test/lib/my_app/ebin is the app's ebin (its build path and app name)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/proj/_build/test/lib/my_app/ebin/my_erl.beam",
                line: nil,
                message: ":my_erl is Erlang source; the graph engine reads Elixir only, and no architecture bucket classifies it. Fix: move it under a dependency, or classify it with a pattern: selector so its calls are checked as a black box."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:348: (test)
```

## AE-E — the issue sits on the config, not the app's ebin

Run summary: `37 tests, 2 failures`

```text
  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:199
     ** (MatchError) no match of right hand side value:

         %Anchor.Domain.Violation{
           line: nil,
           trigger: nil,
           message: "read 0 modules for app :other from _build/dev/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; check that _build/dev/lib/other/ebin is the app's ebin (its build path and app name).",
           filename: ".anchor.yml",
           kind: :fail_closed,
           key: nil,
           rule_id: nil,
           enforcement: :enforce
         }

     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       test/anchor/domain/failures_graph_test.exs:201: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:200: (test)

  2) test run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:240
     match (=) failed
     code:  assert [%{file: @other_ebin, label: "anchor.graph", message: message}] = report.findings
     left:  [%{file: "/proj/_build/test/lib/other/ebin", label: "anchor.graph", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "read 0 modules for app :other from /proj/_build/test/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; check that /proj/_build/test/lib/other/ebin is the app's ebin (its build path and app name)."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_test.exs:248: (test)
```

## AE-O — the per-app check ignores the modules left out as outside the root

The merge of origin/main 93f72d4 (9fb0289) passes `beams ++ outside` to the
per-app check, so an app whose only module was left out as outside the root
(DND-5588) is named in the outside note, never reported as an empty ebin. The
whole-MR critic on f5406a7 found no test held that. The mutation drops
`++ outside`; the driver wrote it, waited 1.1 s, ran `mix test --force
test/anchor/managers/graph_test.exs` and restored the source.

Run summary: `29 tests, 1 failure`

```text
  1) test run/2 source paths outside the project root (DND-5588) an app whose only module is outside the root is not an empty ebin (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:582
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/proj/_build/test/lib/other/ebin",
                  line: nil,
                  message: "read 0 modules for app :other from /proj/_build/test/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; check that /proj/_build/test/lib/other/ebin is the app's ebin (its build path and app name)."
                },
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :report,
                  key: nil,
                  file: "/shared/lib/shared.ex",
                  line: nil,
                  message: "AnchorFixtures.GraphManagerTest.Shared was compiled from /shared/lib/shared.ex, outside the project root /proj, so it is left out of the graph and no rule judged it. Fix: move its source under /proj, or run mix anchor.graph from the root that holds it."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 2,
                opaque: 0,
                apps: 2,
                excluded: 1,
                rules: 1,
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_test.exs:587: (test)
```
