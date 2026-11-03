# Sabotage record — the last run is saved under Mix's build path (DND-5635)

- **Domain:** sabotage
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Managers.Sabotage.Runner` (`run/2`'s `build_path` fact, `save/3`) and
  `Mix.Tasks.Anchor.Sabotage` (the `build_path` fact it gathers)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/managers/sabotage_run_test.exs test/mix/tasks/anchor_sabotage_run_test.exs`, each mutation
  applied alone and restored byte-for-byte (sha256 compared) after its run.

`last-run.etf` was written under `<root>/_build/<env>` whatever Mix's build path was, so a project built
with `MIX_BUILD_PATH` saved it outside its own build: the defect DND-5585 fixed for the graph artifact. The
task now gathers `Mix.Project.build_path/0` into the facts as `build_path`, `Runner.run/2` requires it,
and the run is saved to `<build_path>/anchor/sabotage/last-run.etf`. Only the last-run path moved; the
results file the test VM writes keeps its path (a follow-up is proposed in the batch report).

## The regression, on the unfixed code

The Manager tests' build path is `/builds/repo-test`, so every test that expects a save failed (9), and
the task test that sets `MIX_BUILD_PATH` failed: `49 tests, 10 failures`.

```
  7) test run/2: the mutants zero changed functions from a good diff read: exit 0, loud, no baseline, no write (Anchor.Managers.SabotageRunTest)
     test/anchor/managers/sabotage_run_test.exs:615
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.SabotageRunTest.expect_save/0
         # 1
         "/repo/_build/test/anchor/sabotage/last-run.etf"

 10) test the last run is saved under Mix's build path, as MIX_BUILD_PATH sets it (Mix.Tasks.Anchor.SabotageRunTest)
     test/mix/tasks/anchor_sabotage_run_test.exs:139
     Assertion with == failed
     code:  assert path == Path.join(build, "anchor/sabotage/last-run.etf")
     left:  "/home/cjpoll/.local/worktrees/anchor/dnd-5630-graph-hardening/_build/test/anchor/sabotage/last-run.etf"
     right: "/tmp/anchor-build-3779/anchor/sabotage/last-run.etf"
```

After: the two files and the run integration test run `50 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `save/3` derives the path from `root` and `env` again | the nine Manager tests that expect a save, the task's `MIX_BUILD_PATH` test | `49 tests, 10 failures` |
| B | the task passes `<cwd>/_build/<env>` as `build_path` | the task's `MIX_BUILD_PATH` test | `49 tests, 1 failure` |

## Failure strings (verbatim)

### A

```
  1) test run/2: changed functions that yield no mutant (DND-5617) M1: only a function in a defimpl whose for: is not a literal: exit 0, its own reason and the count (Anchor.Managers.SabotageRunTest)
     test/anchor/managers/sabotage_run_test.exs:833
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.SabotageRunTest.expect_save/0
         # 1
         "/repo/_build/test/anchor/sabotage/last-run.etf"
```

### B

```
  1) test the last run is saved under Mix's build path, as MIX_BUILD_PATH sets it (Mix.Tasks.Anchor.SabotageRunTest)
     test/mix/tasks/anchor_sabotage_run_test.exs:139
     Assertion with == failed
     code:  assert path == Path.join(build, "anchor/sabotage/last-run.etf")
     left:  "/home/cjpoll/.local/worktrees/anchor/dnd-5630-graph-hardening/_build/test/anchor/sabotage/last-run.etf"
     right: "/tmp/anchor-build-1092/anchor/sabotage/last-run.etf"
```
