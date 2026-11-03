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

## DND-5647: a write that escaped the root after the check is caught and removed

**Code under test:** `Anchor.Adapters.BaselineFile.create/4` (the `before_write:` seam, the post-write real-path check, the removal) and `Anchor.Domain.Failures.baseline_not_written/2` for `{:escaped_root, real}`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). The swap is a function the test passes as `before_write:`, run at a fixed point between the checks and the write: no timing, no race. With every source restored: `31 tests, 0 failures`. SW-R runs the final `baseline_file_test.exs` against the write as it was before the fix (the `within_root/2` check not called), the `before_write:` seam in place: each swap's `create/4` answers `:ok`, the write having landed outside the root.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| SW-R | regression: the unfixed write (no post-write check), with the seam in place (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `15 tests, 3 failures` (red) | a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too; a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside; a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it |
| SW-A | the post-write check passes everything (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 3 failures` (red) | a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too; a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it; a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside |
| SW-B | what was written outside is left there (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 3 failures` (red) | a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too; a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside; a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it |
| SW-C | the real path follows no symlink (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 3 failures` (red) | a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too; a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it; a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside |
| SW-D | the root is not resolved to its real path (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 1 failure` (red) | a directory swapped for a symlink after the check (DND-5647) a root reached through a symlink is its real path, not an escape |
| SW-E | the before_write seam is never run (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 4 failures` (red) | a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too; a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it; a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside; a directory swapped for a symlink after the check (DND-5647) positive control: with no swap the hook runs and the file is written |
| SW-F | a sibling sharing the root's prefix reads as inside it (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 1 failure` (red) | a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it |
| SW-G | the escape message drops where the file landed (`lib/anchor/domain/failures.ex`) | `baseline_file_test.exs`, `failures_graph_test.exs` | `31 tests, 1 failure` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line |

### SW-R: regression: the unfixed write (no post-write check), with the seam in place

Run summary: `15 tests, 3 failures`

```text


  1) test a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:164
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n", before_write: swap_anchor)
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:175: (test)

..



  2) test a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:151
     match (=) failed
     code:  assert {:error, {:escaped_root, real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, outside)
              )
     left:  {:error, {:escaped_root, real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:155: (test)







  3) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, sibling)
              )
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:190: (test)

.......
```

### SW-A: the post-write check passes everything

Run summary: `31 tests, 3 failures`

```text






  1) test a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:164
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n", before_write: swap_anchor)
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:175: (test)

..



  2) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, sibling)
              )
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:190: (test)

.........



  3) test a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:151
     match (=) failed
     code:  assert {:error, {:escaped_root, real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, outside)
              )
     left:  {:error, {:escaped_root, real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:155: (test)

.................
```

### SW-B: what was written outside is left there

Run summary: `31 tests, 3 failures`

```text






  1) test a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:164
     Assertion with == failed
     code:  assert File.ls!(Path.join(outside, "baselines")) == []
     left:  ["r.txt"]
     right: []
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:180: (test)

..........



  2) test a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:151
     Assertion with == failed
     code:  assert File.ls!(outside) == []
     left:  ["r.txt"]
     right: []
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:161: (test)

.



  3) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     Assertion with == failed
     code:  assert File.ls!(sibling) == []
     left:  ["r.txt"]
     right: []
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:195: (test)

.................
```

### SW-C: the real path follows no symlink

Run summary: `31 tests, 3 failures`

```text


  1) test a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:164
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n", before_write: swap_anchor)
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:175: (test)

..



  2) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, sibling)
              )
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:190: (test)

...



  3) test a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:151
     match (=) failed
     code:  assert {:error, {:escaped_root, real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, outside)
              )
     left:  {:error, {:escaped_root, real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:155: (test)

.....................
```

### SW-D: the root is not resolved to its real path

Run summary: `31 tests, 1 failure`

```text


  1) test a directory swapped for a symlink after the check (DND-5647) a root reached through a symlink is its real path, not an escape (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:214
     match (=) failed
     code:  assert :ok = BaselineFile.create(alias_root, ".anchor/baselines/r.txt", "r|A|x\n")
     left:  :ok
     right: {:error,
             {:escaped_root,
              "/home/cjpoll/.local/worktrees/anchor/dnd-5648-graph-followups/tmp/Anchor.Adapters.BaselineFileTest/test-a-directory-swapped-for-a-symlink-after-the-check-(DND-5647)-a-root-reached-through-a-symlink-is-its-real-path,-not-an-escape-64c266c4/root/.anchor/baselines/r.txt"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:221: (test)

............................
```

### SW-E: the before_write seam is never run

Run summary: `31 tests, 4 failures`

```text


  1) test a directory swapped for a symlink after the check (DND-5647) a swap of a directory higher on the path is caught too (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:164
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n", before_write: swap_anchor)
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:175: (test)







  2) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, sibling)
              )
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:190: (test)

.......



  3) test a directory swapped for a symlink after the check (DND-5647) the write is refused, naming where it went, and nothing remains outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:151
     match (=) failed
     code:  assert {:error, {:escaped_root, real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, outside)
              )
     left:  {:error, {:escaped_root, real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:155: (test)

.



  4) test a directory swapped for a symlink after the check (DND-5647) positive control: with no swap the hook runs and the file is written (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:198
     Assertion failed, no matching message after 0ms
     The process mailbox is empty.
     code: assert_received :hook_ran
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:209: (test)

................
```

### SW-F: a sibling sharing the root's prefix reads as inside it

Run summary: `31 tests, 1 failure`

```text






  1) test a directory swapped for a symlink after the check (DND-5647) a sibling whose name starts with the root's is outside it (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:183
     match (=) failed
     code:  assert {:error, {:escaped_root, _real}} =
              BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                before_write: swap(root, sibling)
              )
     left:  {:error, {:escaped_root, _real}}
     right: :ok
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:190: (test)

..............................
```

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

