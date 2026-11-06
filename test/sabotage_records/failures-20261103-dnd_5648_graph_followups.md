# Sabotage records: failures (branch dnd-5648-graph-followups)

- **Domain:** failures
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5631: a violation both enforcement passes found is printed once (PA-E)

**Run with:** the `## DND-5631: a violation both enforcement passes found is printed once` section of `lint-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-E | the note goes after the Fix: line (`lib/anchor/domain/failures.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 1 failure` (red) | merge/2 a violation both passes found is one, enforced, naming both modes |

### PA-E: the note goes after the Fix: line

Run summary: `38 tests, 1 failure`

```text






  1) test merge/2 a violation both passes found is one, enforced, naming both modes (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:15
     Assertion with == failed
     code:  assert message ==
              "cannot resolve. (Found under rules in enforcement: enforce and report; " <>
                "reported once, enforced.) Fix: name it"
     left:  "cannot resolve. Fix: name it (Found under rules in enforcement: enforce and report; reported once, enforced.)"
     right: "cannot resolve. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name it"
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:22: (test)

.....................................
```


## DND-5655: an absolute apps_path is keyed or refused, never raised (AP-F)

**Run with:** the `## DND-5655: an absolute apps_path is keyed or refused, never raised` section of `graph_runner-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AP-F | the refusal has no Fix: line (`lib/anchor/domain/failures.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |

### AP-F: the refusal has no Fix: line

Run summary: `63 tests, 2 failures`

```text


  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:274
     graph_apps_path_outside
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       test/anchor/domain/failures_graph_test.exs:277: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:275: (test)

........................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     Assertion with =~ failed
     code:  assert message =~ "Fix: "
     left:  "COULD NOT MEASURE: the apps_path of :alpha is /elsewhere/alpha, outside the project root /proj, so its source paths cannot be keyed against the root. Set apps_path in the umbrella's mix.exs to a directory under the project root (Mix's default, \"apps\"), and run mix anchor.graph from that root."
     right: "Fix: "
     stacktrace:
       test/anchor/managers/graph_test.exs:853: (test)

........................
```


## DND-5648: a base config that does not load is one issue (BC-B)

**Run with:** the `## DND-5648: a base config that does not load is one issue` section of `baseline-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| BC-B | the issue names only the first unjudged rule (`lib/anchor/domain/failures.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |

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


## DND-5647: a write that escaped the root after the check is caught and removed (SW-G)

**Run with:** the `## DND-5647: a write that escaped the root after the check is caught and removed` section of `baseline-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| SW-G | the escape message drops where the file landed (`lib/anchor/domain/failures.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 1 failure` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line |

### SW-G: the escape message drops where the file landed

Run summary: `31 tests, 1 failure`

```text


  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:266
     baseline_not_written escaped: "landed at /elsewhere/x.txt, outside the project root, and was removed there" in Anchor did not create b/x.txt: a directory on its path became a symlink while it was written, so the file landed outside the project root, and was removed there. Fix: find what is replacing directories in this checkout during the run, stop it, and run --write-baseline again.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:271: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:267: (test)

...............
```
