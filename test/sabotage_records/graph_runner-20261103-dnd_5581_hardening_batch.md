# Sabotage record — the graph artifact under Mix's build path (DND-5585)

- **Domain:** graph_runner
- **Branch:** dnd-5581-hardening-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Managers.Graph` (`write_artifact/5`: the artifact dir),
  `Mix.Tasks.Anchor.Graph` (`Request.build_path`), `Anchor.Adapters.GraphArtifact` (`artifact_dir/1`)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2 test/mix/tasks/anchor_graph_test.exs
  test/anchor/managers/graph_test.exs test/anchor/integration/graph_canary_test.exs
  test/anchor/adapters/graph_artifact_test.exs`, each mutation applied alone and restored byte-for-byte
  (`cmp`) after its run.

The artifact was written under `<root>/_build/<env>/anchor` whatever Mix's build path was, so a project
built with `MIX_BUILD_PATH` wrote it outside its own build. The task now gathers `Mix.Project.build_path/0`
into `Request.build_path` and the Manager writes under `<build_path>/anchor`. The adapter's guard was the
path shape `_build/<env>/anchor`, which a `MIX_BUILD_PATH` directory need not have; it now accepts a
directory named `anchor` whose parent holds `lib/` (a Mix build path: every app's ebin is under it).

## The regression, on the unfixed code

The Manager tests' build path is `/builds/my_app-test`, not `<root>/_build/<env>`, so every Manager test
that expects a write failed (17), and the task test that sets `MIX_BUILD_PATH` failed: `34 tests, 18
failures`. The adapter's two new tests failed against the old shape check: `5 tests, 2 failures`.

```
 18) test the artifact goes under Mix's build path, as MIX_BUILD_PATH sets it (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:120
     Assertion with == failed
     code:  assert dir == Path.join(build, "anchor")
     left:  "/home/cjpoll/.local/worktrees/anchor/dnd-5581-hardening-batch/_build/test/anchor"
     right: "/tmp/anchor-build-3716/anchor"

  1) test a build path not named _build/<env> is accepted (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:56
     Assertion with == failed
     code:  assert GraphArtifact.write(Path.join(build, "anchor"), "k", :graph) == :ok
     left:  {:error, :outside_artifact_dir}
     right: :ok
```

With the fix the four files run `35 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `write_artifact/5` derives the dir from `root` and `env` again | the 17 Manager tests that expect a write, and the task's `MIX_BUILD_PATH` test | `35 tests, 18 failures` |
| B | `artifact_dir/1` checks only that the dir is named `anchor` (no `lib/` beside it) | "a directory that is not <build_path>/anchor is refused" | `35 tests, 1 failure` |
| C | `artifact_dir/1` is the old `_build/<env>/anchor` shape check | the refusal test (a `_build/test/anchor` with no build there is now refused) and "a build path not named _build/<env> is accepted" | `35 tests, 2 failures` |

Rows that stayed green: under A the adapter tests and the canary (its store is a double that accepts any
dir); under B and C every Manager and task test (the store is a double).

## Failure strings (verbatim)

### A

```
  1) test run/2 per-module fail-closed issues (exit 1) an Erlang module a pattern selector classifies is opaque and counted, not an issue (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:311
     ** (FunctionClauseError) no function clause matching in anonymous fn/3 in Anchor.Managers.GraphTest.expect_run/3

     The following arguments were given to anonymous fn/3 in Anchor.Managers.GraphTest.expect_run/3:

         # 1
         "/proj/_build/test/anchor"

 18) test the artifact goes under Mix's build path, as MIX_BUILD_PATH sets it (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:120
     Assertion with == failed
     code:  assert dir == Path.join(build, "anchor")
     left:  "/home/cjpoll/.local/worktrees/anchor/dnd-5581-hardening-batch/_build/test/anchor"
     right: "/tmp/anchor-build-2/anchor"
```

### B

```
  1) test a directory that is not <build_path>/anchor is refused, for write and read (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:32
     Assertion with == failed
     code:  assert GraphArtifact.write(outside, "k", :graph) == {:error, :outside_artifact_dir}
     left:  :ok
     right: {:error, :outside_artifact_dir}
```

### C

```
  2) test a build path not named _build/<env> is accepted (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:56
     Assertion with == failed
     code:  assert GraphArtifact.write(Path.join(build, "anchor"), "k", :graph) == :ok
     left:  {:error, :outside_artifact_dir}
     right: :ok
```

## Review round 1 (critic): a project root is not a build path

The first guard (a directory named `anchor` whose parent holds `lib/`) accepted `<project root>/anchor`,
since every project root holds `lib/` too. The guard now asks for `lib/<app>/ebin` under the parent, and the
refusal test has a `project/` with `lib/app` and no ebin. The Fix: hint of
`Failures.graph_artifact_not_written/2` no longer names `_build/<env>/anchor`.

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| D | `build_path?/1` accepts any `lib/` it can list (no `ebin` check) | "a directory that is not <build_path>/anchor is refused" (the `project/anchor` row) | `50 tests, 1 failure` |

Without a mutation the five files (the four above and `failures_graph_test.exs`) run `50 tests, 0 failures`.

```
  1) test a directory that is not <build_path>/anchor is refused, for write and read (Anchor.Adapters.GraphArtifactTest)
     test/anchor/adapters/graph_artifact_test.exs:33
     Assertion with == failed
     code:  assert GraphArtifact.write(outside, "k", :graph) == {:error, :outside_artifact_dir}
     left:  :ok
     right: {:error, :outside_artifact_dir}
```

---

# The artifact key covers the source facts (DND-5586)

- **Code under test:** `Anchor.Domain.GraphKey.key/4` (now beams, sources, config, version) and
  `Anchor.Managers.Graph` (`write_artifact/5`: the source entries)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph_key_test.exs
  test/anchor/managers/graph_test.exs`, restored byte-for-byte (`cmp`) after each run.

The key hashed the beams, the config and the version. The graph also takes `generated?` and the literal
`use`s from each source file's `SourceFacts`, which a source edit can change without changing a beam, so the
artifact could be read for a graph it was not. The source entries are each file's `SourceFacts` in the
external term format, not the file's bytes: no raw text leaves `SourceReader` (ADR 001), and the facts are
exactly what the graph reads from a source file. A comment, which changes no fact, leaves the key alone.

## The regression, on the unfixed code

The Manager test runs the same beams with three sets of sources: as compiled, with a leading comment, and
with one more literal `defmodule` in the user file. Unfixed, the last run's key equalled the first:

```
  1) test run/2 graph artifact the key changes with the source facts, not with a comment (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:462
     Refute with == failed, both sides are exactly equal
     code: refute key.(another_module) == base
     left: "39f7323e17b100f9f4cda1254a2bd9f1dc7ad1e61e341948fdd7dad9a3f404fc"
```

`23 tests, 1 failure` (`graph_test.exs`). After: the two files run `31 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `write_artifact/5` passes no source entries | the Manager key test | `31 tests, 1 failure` |
| B | `key/4` hashes an empty source list | "a changed source entry changes the key", the Manager key test | `31 tests, 2 failures` |
| C | `section/1` drops the list's length prefix | "an entry moved from the beams to the sources changes the key" | `31 tests, 1 failure` |
| D | the source entries are framed unsorted | "the same sources in another order give the same key" | `31 tests, 1 failure` |

C first survived: the test moved the first beam, whose path sorts first, so the two inputs framed in a
different order even with no counts. It now moves the last beam, the one case where only the counts tell the
inputs apart, and C fails it.

## Failure strings (verbatim)

### A

```
  1) test run/2 graph artifact the key changes with the source facts, not with a comment (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:462
     Refute with == failed, both sides are exactly equal
     code: refute key.(another_module) == base
     left: "82c72b9b1969cbfbe3c173da18b603a6727c1ef050d62a7b6a3502a89e3eceb3"
```

### B

```
  1) test sources a changed source entry changes the key; one more or one fewer does too (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:45
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key(@entries, [{"lib/a.ex", "facts A"}, {"lib/b.ex", "facts b"}], "c", "v") == base
     left: "5ca8004a98abf62affcf25b006a3811a2183e415a5a95834bca44c3a650e1119"
```

### C

```
  1) test sources an entry moved from the beams to the sources changes the key (each list is counted) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:60
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key([first], [last], "c", "v") == GraphKey.key(@entries, [], "c", "v")
     left: "c6c71cb9c299897693687837a88349db0e0bb7cea3c704a19e142299a6a5d5ca"
```

### D

```
  1) test sources the same sources in another order give the same key (sorted by path) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:55
     Assertion with == failed
     code:  assert GraphKey.key(@entries, Enum.reverse(@sources), "c", "v") ==
              GraphKey.key(@entries, @sources, "c", "v")
     left:  "0b473c57264bd12b2a264870fd33151a81dd2f07cdbf6752c1dbbbd6038c2e7a"
     right: "dd12bf74e1194542c6fa328ac358c1fe03e9ffcc7196e50aac9ded17eab983c0"
```
