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

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| AE-A | the Manager never reports an app that read no module (the unfixed code) (`lib/anchor/managers/graph.ex`) | `graph_test.exs` | `23 tests, 1 failure` (red) | run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
| AE-B | apps_without_modules lists no app (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs`, `graph_test.exs` | `26 tests, 3 failures` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module; apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
| AE-C | a decode error counts as the app's module (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs` | `3 tests, 1 failure` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module |
| AE-D | every app is listed, read or not (`lib/anchor/domain/graph/beam.ex`) | `beam_test.exs`, `graph_test.exs` | `26 tests, 21 failures` (red) | apps_without_modules/2 an app whose every beam failed to decode read no module; apps_without_modules/2 an app with no beam is listed, in apps order; an app with one is not; apps_without_modules/2 positive control: every app read a module, none listed; run/2 --only narrows to the named rules; a running rule's floor is still judged; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app; run/2 an app that read no module (exit 1) positive control: both apps read a module, the run is clean; run/2 graph artifact a failed write is a report-only note; the verdict stands; run/2 happy path a report-only rule's findings print and exit 0; run/2 happy path every module classifies and the rule holds: exit 0, counts exact, artifact written once; run/2 per-module fail-closed issues (exit 1) a beam with no debug_info is an issue on it; the other modules still classify and their findings print; run/2 per-module fail-closed issues (exit 1) a core_v1 refusal is a per-module issue; run/2 per-module fail-closed issues (exit 1) a rule below its min_modules is an issue on the config; run/2 per-module fail-closed issues (exit 1) a source file that cannot be read is an issue on it; run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue; run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue; run/2 per-module fail-closed issues (exit 1) an interfaces.exports entry naming no module is an issue on the config; one naming a module is not; run/2 per-module fail-closed issues (exit 1) an unclassified module is one issue on its source file; run/2 rule crash isolation (AC4) stub_exits: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_malformed: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_raises: one issue naming the rule and reason; a second rule's finding still prints; run/2 rule crash isolation (AC4) stub_throws: one issue naming the rule and reason; a second rule's finding still prints |
| AE-E | the issue sits on the config, not the app's ebin (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs`, `graph_test.exs` | `36 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 an app that read no module (exit 1) one app of two with an empty ebin is one issue on that ebin, naming the app |
