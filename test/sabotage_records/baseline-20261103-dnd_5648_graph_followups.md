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
| BC-C | an unjudged rule's findings are held, so the verdict changes (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |
| BC-D | only the first rule's id is collected (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `failures_graph_test.exs` | `41 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read is one issue naming every baselined rule |

Filed under their own domain word (ADR 003): BC-B in `failures-20261103-dnd_5648_graph_followups.md`.

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

Filed under their own domain word (ADR 003): SW-G in `failures-20261103-dnd_5648_graph_followups.md`.

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

## DND-5634: GitShow's tests capture git's stderr instead of printing it

**Code under test:** the test "a path git cannot look up at a resolved ref is a git error, never :absent" in `git_show_test.exs`, now run in a child VM whose stderr it asserts, and `Anchor.Adapters.GitShow`'s stderr handling it pins.

**Before:** `mix test test/anchor/adapters/git_show_test.exs test/anchor/adapters/git_env_isolation_test.exs` printed `error: Could not read 7f4545ae8fe823c97fa59dedae2c47fe6b00535a` between the dots of a green run. **After:** `git_show_test.exs` prints no git line (`grep -c 'Could not read'` on its output: 0), `14 tests, 0 failures`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s).

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| GS-A | git's stderr merged into the output it reads (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `14 tests, 1 failure` (red) | a path git cannot look up at a resolved ref is a git error, never :absent |
| GS-B | a failed path probe reads as an absent file (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `14 tests, 1 failure` (red) | a path git cannot look up at a resolved ref is a git error, never :absent |

### GS-A: git's stderr merged into the output it reads

Run summary: `14 tests, 1 failure`

```text


  1) test a path git cannot look up at a resolved ref is a git error, never :absent (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:87
     Assertion with == failed
     code:  assert message == "error: Could not read #{tree}"
     left:  "{:error,"
     right: "error: Could not read 7f4545ae8fe823c97fa59dedae2c47fe6b00535a"
     stacktrace:
       test/anchor/adapters/git_show_test.exs:106: (test)

.....
```

### GS-B: a failed path probe reads as an absent file

Run summary: `14 tests, 1 failure`

```text


  1) test a path git cannot look up at a resolved ref is a git error, never :absent (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:87
     Assertion with =~ failed
     code:  assert result =~ ~r/^\{:error, \{:git, [1-9]\d*, ""\}\}$/
     left:  "{:error, :absent}"
     right: ~r/^\{:error, \{:git, [1-9]\d*, ""\}\}$/
     stacktrace:
       test/anchor/adapters/git_show_test.exs:107: (test)

...
```


## DND-5632: baselines for ast (Credo-engine) rules

**Code under test:** `Anchor.Domain.AstBaseline` (`judge/4`, `entry_file/2`, `exit_code/1`, `render/2`), `Anchor.Domain.ViolationKey.ast_key/3`, the ratchet in `Anchor.Managers.Lint` (per-rule detection, keys, held/STALE/unjudged), `Anchor.Managers.AstBaseline` (`write/2`, `grew/2`), `Anchor.Check.Base`'s issue meta, `Mix.Tasks.Anchor.Baseline`, and `baseline` as an ast common key in `Anchor.Domain.RuleSchema`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s) over the seven test files below. AB-Q's first form (`if meta == [] or true`) did not compile (the type checker reads it as always true), so it was rerun as the form recorded. With every source restored: `mix test` 2236 tests, 0 failures; `mix credo --strict` no issues; `MIX_ENV=dev mix anchor.graph` 0 violations.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AB-A | a narrowed run judges every entry (scope ignored) (`lib/anchor/domain/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 6 failures` (red) | judge/4 an entry on a file the run could not parse is unjudged, never STALE; judge/4 a narrowed run still finds STALE on a file it read; judge/4 a narrowed run judges no entry on a file it did not read: no false STALE; a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE; a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so; write, then held, STALE, and a narrowed run with no false STALE |
| AB-B | an unparsed file's entries are judged (`lib/anchor/domain/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 2 failures` (red) | judge/4 an entry on a file the run could not parse is unjudged, never STALE; a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE |
| AB-C | a whole run judges only the files it read (a deleted file's entry never STALE) (`lib/anchor/domain/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 4 failures` (red) | judge/4 STALE in a whole run: an entry on a file that no longer exists; a baselined rule's findings STALE takes the rule's enforcement: report; a narrowed run (DND-5632) the same entry in a whole run is STALE; write, then held, STALE, and a narrowed run with no false STALE |
| AB-D | held findings are not dropped (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 7 failures` (red) | beside rules with no baseline a violation every pass makes once per file is printed once; a baselined rule's findings an absolute filename is keyed relative to the root; a baselined rule's findings NEW: a finding no entry covers stands; a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so; a baselined rule's findings STALE: an entry no finding consumes is a finding on the baseline path; a baselined rule's findings positive control: every finding held, nothing printed; write, then held, STALE, and a narrowed run with no false STALE |
| AB-E | STALE entries are not reported (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 5 failures` (red) | a baselined rule's findings STALE takes the rule's enforcement: report; a baselined rule's findings STALE: an entry no finding consumes is a finding on the baseline path; a narrowed run (DND-5632) a narrowed run still fails STALE on a file it read; a narrowed run (DND-5632) the same entry in a whole run is STALE; write, then held, STALE, and a narrowed run with no false STALE |
| AB-F | the unjudged note is not printed (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 3 failures` (red) | a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE; a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so; write, then held, STALE, and a narrowed run with no false STALE |
| AB-G | a once-per-file violation is printed by every pass (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | beside rules with no baseline a violation every pass makes once per file is printed once |
| AB-H | a finding is keyed on the wrong file (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 14 failures` (red) | a baselined rule's findings NEW: a finding no entry covers stands; a baselined rule's findings STALE takes the rule's enforcement: report; beside rules with no baseline a violation every pass makes once per file is printed once; a baselined rule's findings an absolute filename is keyed relative to the root; a baseline the run cannot use unreadable: one fail-closed issue naming the writer, and every finding stands; a narrowed run (DND-5632) a narrowed run still fails STALE on a file it read; a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so; a baselined rule's findings STALE: an entry no finding consumes is a finding on the baseline path; a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE; a baselined rule's findings each finding carries the rule's id and its key; a baseline the run cannot use another rule's entry: one fail-closed issue, and every finding stands; a baselined rule's findings positive control: every finding held, nothing printed; a narrowed run (DND-5632) the same entry in a whole run is STALE; write, then held, STALE, and a narrowed run with no false STALE |
| AB-I | the key's file is not made relative to the root (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 14 failures` (red) | a baseline the run cannot use unreadable: one fail-closed issue naming the writer, and every finding stands; a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE; a baselined rule's findings NEW: a finding no entry covers stands; a baseline the run cannot use another rule's entry: one fail-closed issue, and every finding stands; beside rules with no baseline a violation every pass makes once per file is printed once; a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so; a baselined rule's findings STALE takes the rule's enforcement: report; a narrowed run (DND-5632) a narrowed run still fails STALE on a file it read; a narrowed run (DND-5632) the same entry in a whole run is STALE; a baselined rule's findings an absolute filename is keyed relative to the root; a baselined rule's findings STALE: an entry no finding consumes is a finding on the baseline path; a baselined rule's findings positive control: every finding held, nothing printed; a baselined rule's findings each finding carries the rule's id and its key; write, then held, STALE, and a narrowed run with no false STALE |
| AB-J | a baseline issue does not name its rule (`lib/anchor/managers/lint.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | a baseline the run cannot use unreadable: one fail-closed issue naming the writer, and every finding stands |
| AB-K | write keeps every rule's keys (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0) |
| AB-L | write runs for a rule no check judged (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | write/2 a rule whose check Credo does not run writes nothing (exit 3) |
| AB-M | write over an existing file is not refused before Credo (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 3 failures` (red) | write/2 an existing file is refused before Credo runs (exit 2); write, then held, STALE, and a narrowed run with no false STALE; --write over an existing file exits 2 |
| AB-N | GREW compares the branch with itself (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 4 failures` (red) | grew/2 GREW: an entry the branch added since the ref (exit 1); grew/2 GREW takes the rule's enforcement: report (exit 0); grew/2 a rule that had no baseline at the ref: every entry is GREW; --base REF prints a GREW entry and exits 1, without compiling |
| AB-O | GREW ignores the rule's enforcement (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | grew/2 GREW takes the rule's enforcement: report (exit 0) |
| AB-P | a base config that does not load is silent (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | grew/2 a base config that does not load is one issue naming every rule (exit 1) |
| AB-Q | Credo issues carry no key (`lib/anchor/check/base.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | write, then held, STALE, and a narrowed run with no false STALE |
| AB-R | --base passes any ref to git (`lib/mix/tasks/anchor.baseline.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs` | `99 tests, 1 failure` (red) | no mode, both modes, an unknown flag, an argument or a bad ref is usage: exit 2 with Fix: |
| AB-S | baseline is refused on an ast rule again (`lib/anchor/domain/rule_schema.ex`) | `ast_baseline_test.exs`, `lint_baseline_test.exs`, `ast_baseline_test.exs`, `anchor_baseline_test.exs`, `ast_baseline_integration_test.exs`, `rule_checks_nothing_test.exs`, `failures_graph_test.exs`, `rule_schema_test.exs` | `132 tests, 18 failures` (red) | the positive case every rule type accepts its engine's common keys; no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load; no_direct_dependency: every rule that checks nothing is refused, and the positive rows load; no_forwarding_function: every rule that checks nothing is refused, and the positive rows load; no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load; no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load; module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load; single_control_flow: every rule that checks nothing is refused, and the positive rows load; struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load; max_file_length: every rule that checks nothing is refused, and the positive rows load; must_use_module: every rule that checks nothing is refused, and the positive rows load; no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load; no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load; alphabetized_functions: every rule that checks nothing is refused, and the positive rows load; struct_getter_convention: every rule that checks nothing is refused, and the positive rows load; case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load; an unknown key inside a rule the reason names every known key for the rule's type; write, then held, STALE, and a narrowed run with no false STALE |

### AB-A: a narrowed run judges every entry (scope ignored)

Run summary: `99 tests, 6 failures`

```text
  1) test judge/4 an entry on a file the run could not parse is unjudged, never STALE (Anchor.Domain.AstBaselineTest)
     test/anchor/domain/ast_baseline_test.exs:114
     match (=) failed
     code:  assert %{stale: [], unjudged: ["pure|lib/broken.ex|File"]} =
              AstBaseline.judge(
                "pure",
                [],
                ~w(pure|lib/broken.ex|File),
                whole(~w(lib/a.ex lib/broken.ex), ~w(lib/broken.ex))
              )
     left:  %{stale: [], unjudged: ["pure|lib/broken.ex|File"]}
     right: %{
              new: [],
              stale: ["pure|lib/broken.ex|File"],
              held: [],
              unjudged: []
            }
     stacktrace:
       test/anchor/domain/ast_baseline_test.exs:115: (test)

  2) test judge/4 a narrowed run still finds STALE on a file it read (Anchor.Domain.AstBaselineTest)
     test/anchor/domain/ast_baseline_test.exs:104
     match (=) failed
     code:  assert %{stale: ["pure|lib/a.ex|IO"], unjudged: ["pure|lib/b.ex|File"]} =
              AstBaseline.judge("pure", [], ~w(pure|lib/a.ex|IO pure|lib/b.ex|File), narrowed(~w(lib/a.ex)))
     left:  %{stale: ["pure|lib/a.ex|IO"], unjudged: ["pure|lib/b.ex|File"]}
     right: %{
              new: [],
              stale: ["pure|lib/a.ex|IO", "pure|lib/b.ex|File"],
              held: [],
              unjudged: []
            }
     stacktrace:
       test/anchor/domain/ast_baseline_test.exs:105: (test)

.....

  3) test judge/4 a narrowed run judges no entry on a file it did not read: no false STALE (Anchor.Domain.AstBaselineTest)
     test/anchor/domain/ast_baseline_test.exs:92
     Assertion with == failed
     code:  assert AstBaseline.judge("pure", ~w(pure|lib/a.ex|File), entries, narrowed(~w(lib/a.ex))) == %{
              new: [],
              held: ~w(pure|lib/a.ex|File),
              stale: [],
              unjudged: ~w(pure|lib/b.ex|File pure|lib/b.ex|IO)
            }
     left:  %{
              new: [],
              stale: ["pure|lib/b.ex|File", "pure|lib/b.ex|IO"],
              held: ["pure|lib/a.ex|File"],
              unjudged: []
            }
     right: %{
              new: [],
              stale: [],
              held: ["pure|lib/a.ex|File"],
              unjudged: ["pure|lib/b.ex|File", "pure|lib/b.ex|IO"]
            }
     stacktrace:
       test/anchor/domain/ast_baseline_test.exs:95: (test)

........................................
```

(3 more failures in this run, not quoted; every failing test is named in the table.)

### AB-B: an unparsed file's entries are judged

Run summary: `99 tests, 2 failures`

```text
  1) test judge/4 an entry on a file the run could not parse is unjudged, never STALE (Anchor.Domain.AstBaselineTest)
     test/anchor/domain/ast_baseline_test.exs:114
     match (=) failed
     code:  assert %{stale: [], unjudged: ["pure|lib/broken.ex|File"]} =
              AstBaseline.judge(
                "pure",
                [],
                ~w(pure|lib/broken.ex|File),
                whole(~w(lib/a.ex lib/broken.ex), ~w(lib/broken.ex))
              )
     left:  %{stale: [], unjudged: ["pure|lib/broken.ex|File"]}
     right: %{
              new: [],
              stale: ["pure|lib/broken.ex|File"],
              held: [],
              unjudged: []
            }
     stacktrace:
       test/anchor/domain/ast_baseline_test.exs:115: (test)

..............................

  2) test a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:174
     match (=) failed
     code:  assert [%Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}] = config(results)
     left:  [%Anchor.Domain.Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "pure|lib/bad.ex|File in .anchor/baselines/pure.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/pure.txt; a baseline only shrinks.",
                filename: ".anchor/baselines/pure.txt",
                kind: :rule,
                key: "pure|lib/bad.ex|File",
                rule_id: "pure",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:179: (test)

...............................................................
```

### AB-C: a whole run judges only the files it read (a deleted file's entry never STALE)

Run summary: `99 tests, 4 failures`

```text
  1) test judge/4 STALE in a whole run: an entry on a file that no longer exists (Anchor.Domain.AstBaselineTest)
     test/anchor/domain/ast_baseline_test.exs:87
     match (=) failed
     code:  assert %{stale: ["pure|lib/gone.ex|File"], unjudged: []} =
              AstBaseline.judge("pure", [], ~w(pure|lib/gone.ex|File), whole(~w(lib/a.ex)))
     left:  %{stale: ["pure|lib/gone.ex|File"], unjudged: []}
     right: %{new: [], stale: [], held: [], unjudged: ["pure|lib/gone.ex|File"]}
     stacktrace:
       test/anchor/domain/ast_baseline_test.exs:88: (test)

..................

  2) test a baselined rule's findings STALE takes the rule's enforcement: report (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:128
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/gone.ex|File", enforcement: :report}] = config(results)
     left:  [%Anchor.Domain.Violation{key: "pure|lib/gone.ex|File", enforcement: :report}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "NOTE: 1 entry of .anchor/baselines/pure.txt names a file this run did not read or could not parse, so it was not judged STALE. Fix: run mix credo over the whole project (no paths) to judge every entry.",
                filename: ".anchor/baselines/pure.txt",
                kind: :rule,
                key: nil,
                rule_id: "pure",
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:132: (test)

  3) test a narrowed run (DND-5632) the same entry in a whole run is STALE (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:166
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/b.ex|File", enforcement: :enforce}] = config(results)
     left:  [%Anchor.Domain.Violation{key: "pure|lib/b.ex|File", enforcement: :enforce}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "NOTE: 1 entry of .anchor/baselines/pure.txt names a file this run did not read or could not parse, so it was not judged STALE. Fix: run mix credo over the whole project (no paths) to judge every entry.",
                filename: ".anchor/baselines/pure.txt",
                kind: :rule,
                key: nil,
                rule_id: "pure",
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:171: (test)

...........................................................
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### AB-D: held findings are not dropped

Run summary: `99 tests, 7 failures`

```text
  1) test beside rules with no baseline a violation every pass makes once per file is printed once (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:214
     Expected truthy, got false
     code: assert Enum.all?(violations, &is_nil(&1.key))
     arguments:

         # 1
         [
           %Anchor.Domain.Violation{
             line: 2,
             trigger: "alias",
             message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
             filename: nil,
             kind: :rule,
             key: nil,
             rule_id: nil,
             enforcement: :enforce
           },
           %Anchor.Domain.Violation{
             line: 4,
             trigger: "File",
             message: "Module has forbidden direct dependency on File",
             filename: nil,
             kind: :rule,
             key: "pure|lib/c.ex|File",

  2) test a baselined rule's findings an absolute filename is keyed relative to the root (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:136
     Assertion with == failed
     code:  assert run([rule()], files([{@b, "/proj/lib/b.ex"}])) |> findings() == []
     left:  [{"/proj/lib/b.ex", "File", "pure|lib/b.ex|File"}]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:139: (test)

...............

  3) test a baselined rule's findings NEW: a finding no entry covers stands (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:108
     Assertion with == failed
     code:  assert findings(results) == [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     left:  [
              {"lib/a.ex", "File", "pure|lib/a.ex|File"},
              {"lib/a.ex", "IO", "pure|lib/a.ex|IO"},
              {"lib/b.ex", "File", "pure|lib/b.ex|File"}
            ]
     right: [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:112: (test)

.
```

(4 more failures in this run, not quoted; every failing test is named in the table.)

### AB-E: STALE entries are not reported

Run summary: `99 tests, 5 failures`

```text
  1) test a baselined rule's findings STALE takes the rule's enforcement: report (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:128
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/gone.ex|File", enforcement: :report}] = config(results)
     left:  [%Anchor.Domain.Violation{key: "pure|lib/gone.ex|File", enforcement: :report}]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:132: (test)

................

  2) test a baselined rule's findings STALE: an entry no finding consumes is a finding on the baseline path (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:116
     match (=) failed
     code:  assert [%Violation{filename: @path, key: "pure|lib/b.ex|IO", enforcement: :enforce} = stale] =
              config(results)
     left:  [
              %Anchor.Domain.Violation{
                filename: ".anchor/baselines/pure.txt",
                key: "pure|lib/b.ex|IO",
                enforcement: :enforce
              } = stale
            ]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:122: (test)

  3) test a narrowed run (DND-5632) a narrowed run still fails STALE on a file it read (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:158
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/a.ex|IO", enforcement: :enforce}] = config(results)
     left:  [%Anchor.Domain.Violation{key: "pure|lib/a.ex|IO", enforcement: :enforce}]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:163: (test)

.......
```

(2 more failures in this run, not quoted; every failing test is named in the table.)

### AB-F: the unjudged note is not printed

Run summary: `99 tests, 3 failures`

```text
  1) test a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:174
     match (=) failed
     code:  assert [%Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}] = config(results)
     left:  [%Anchor.Domain.Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:179: (test)

......

  2) test a narrowed run (DND-5632) no false STALE for an entry on a file it did not read, and a note says so (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:144
     match (=) failed
     code:  assert [%Violation{filename: @path, enforcement: :report, message: message}] = config(results)
     left:  [
              %Anchor.Domain.Violation{
                filename: ".anchor/baselines/pure.txt",
                enforcement: :report,
                message: message
              }
            ]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:152: (test)

.............................

  3) test write, then held, STALE, and a narrowed run with no false STALE (Anchor.Integration.AstBaselineIntegrationTest)
     test/anchor/integration/ast_baseline_integration_test.exs:67
     match (=) failed
     code:  assert [note] = credo(["--strict", "lib/a.ex"])
     left:  [note]
     right: []
     stacktrace:
       test/anchor/integration/ast_baseline_integration_test.exs:90: (test)

.....
```

### AB-G: a once-per-file violation is printed by every pass

Run summary: `99 tests, 1 failure`

```text
  1) test beside rules with no baseline a violation every pass makes once per file is printed once (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:214
     [%Anchor.Domain.Violation{line: 2, trigger: "alias", message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "alias", message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).", filename: nil, kind: :rule, key: "pure|lib/c.ex|alias", rule_id: "pure", enforcement: :enforce}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:236: (test)

.......................................
```

### AB-H: a finding is keyed on the wrong file

Run summary: `99 tests, 14 failures`

```text
  1) test a baselined rule's findings NEW: a finding no entry covers stands (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:108
     Assertion with == failed
     code:  assert findings(results) == [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     left:  [
              {"lib/a.ex", "File", "pure|lib/a.ex.x|File"},
              {"lib/a.ex", "IO", "pure|lib/a.ex.x|IO"},
              {"lib/b.ex", "File", "pure|lib/b.ex.x|File"}
            ]
     right: [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:112: (test)

...................

  2) test a baselined rule's findings STALE takes the rule's enforcement: report (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:128
     match (=) failed
     code:  assert [{"lib/b.ex", "File", "pure|lib/b.ex|File"}] = findings(results)
     left:  [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
     right: [{"lib/b.ex", "File", "pure|lib/b.ex.x|File"}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:133: (test)

  3) test beside rules with no baseline a violation every pass makes once per file is printed once (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:214
     Expected truthy, got false
     code: assert Enum.all?(violations, &is_nil(&1.key))
     arguments:

         # 1
         [
           %Anchor.Domain.Violation{
             line: 2,
             trigger: "alias",
             message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
             filename: nil,
             kind: :rule,
             key: nil,
             rule_id: nil,
             enforcement: :enforce
           },
           %Anchor.Domain.Violation{
             line: 4,
             trigger: "File",
             message: "Module has forbidden direct dependency on File",
             filename: nil,
             kind: :rule,
             key: "pure|lib/c.ex.x|File",
```

(11 more failures in this run, not quoted; every failing test is named in the table.)

### AB-I: the key's file is not made relative to the root

Run summary: `99 tests, 14 failures`

```text
  1) test a baseline the run cannot use unreadable: one fail-closed issue naming the writer, and every finding stands (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:185
     Assertion with == failed
     code:  assert findings(results) == [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
     left:  [{"lib/b.ex", "File", "pure|/proj/lib/b.ex|File"}]
     right: [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:189: (test)

  2) test a narrowed run (DND-5632) an entry on a file that does not parse is unjudged, never STALE (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:174
     match (=) failed
     code:  assert [%Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}] = config(results)
     left:  [%Anchor.Domain.Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "pure|lib/a.ex|File in .anchor/baselines/pure.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/pure.txt; a baseline only shrinks.",
                filename: ".anchor/baselines/pure.txt",
                kind: :rule,
                key: "pure|lib/a.ex|File",
                rule_id: "pure",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "pure|lib/a.ex|IO in .anchor/baselines/pure.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/pure.txt; a baseline only shrinks.",
                filename: ".anchor/baselines/pure.txt",
                kind: :rule,
                key: "pure|lib/a.ex|IO",
                rule_id: "pure",
                enforcement: :enforce

  3) test a baselined rule's findings NEW: a finding no entry covers stands (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:108
     Assertion with == failed
     code:  assert findings(results) == [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     left:  [
              {"lib/a.ex", "File", "pure|/proj/lib/a.ex|File"},
              {"lib/a.ex", "IO", "pure|/proj/lib/a.ex|IO"},
              {"lib/b.ex", "File", "pure|/proj/lib/b.ex|File"}
            ]
     right: [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:112: (test)
```

(11 more failures in this run, not quoted; every failing test is named in the table.)

### AB-J: a baseline issue does not name its rule

Run summary: `99 tests, 1 failure`

```text
  1) test a baseline the run cannot use unreadable: one fail-closed issue naming the writer, and every finding stands (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:185
     match (=) failed
     code:  assert [%Violation{kind: :fail_closed, filename: @path, rule_id: "pure", message: message}] =
              config(results)
     left:  [
              %Anchor.Domain.Violation{
                kind: :fail_closed,
                filename: ".anchor/baselines/pure.txt",
                rule_id: "pure",
                message: message
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"pure\", no_direct_dependency)'s baseline .anchor/baselines/pure.txt could not be read (:enoent), so none of its findings is held. Fix: create it with mix anchor.baseline --write pure and review it, or remove baseline: from the rule.",
                filename: ".anchor/baselines/pure.txt",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
```

### AB-K: write keeps every rule's keys

Run summary: `99 tests, 1 failure`

```text
  1) test write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:49
     Assertion with == failed
     code:  assert contents == "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"
     left:  "# anchor baseline for pure; shrink only\nother|lib/a.ex|IO\npure|lib/a.ex|File\npure|lib/b.ex|File\n"
     right: "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:62: anonymous fn/3 in Anchor.Managers.AstBaselineTest."test write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0)"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:127: Anchor.Managers.AstBaseline.create/4
       test/anchor/managers/ast_baseline_test.exs:68: (test)

...........................................
```

### AB-L: write runs for a rule no check judged

Run summary: `99 tests, 1 failure`

```text
  1) test write/2 a rule whose check Credo does not run writes nothing (exit 3) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:125
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BaselineStoreMock.create/3 in process #PID<0.386.0> with args ["/proj", ".anchor/baselines/pure.txt", "# anchor baseline for pure; shrink only\n"]
     code: report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:127: Anchor.Managers.AstBaseline.create/4
       test/anchor/managers/ast_baseline_test.exs:130: (test)

.....................................................
```

### AB-M: write over an existing file is not refused before Credo

Run summary: `99 tests, 3 failures`

```text
  1) test write/2 an existing file is refused before Credo runs (exit 2) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:74
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.LintKeysMock.keys/0 in process #PID<0.358.0> with args []
     code: report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:115: Anchor.Managers.AstBaseline.rule_keys/3
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:59: Anchor.Managers.AstBaseline.write/2
       test/anchor/managers/ast_baseline_test.exs:78: (test)

............................................................

  2) test write, then held, STALE, and a narrowed run with no false STALE (Anchor.Integration.AstBaselineIntegrationTest)
     test/anchor/integration/ast_baseline_integration_test.exs:67
     match (=) failed
     code:  assert %{exit_code: 2} = AstBaseline.write(%{root: root, id: "pure"}, [])
     left:  %{exit_code: 2}
     right: %{
              exit_code: 3,
              violations: [
                %Anchor.Domain.Violation{
                  line: nil,
                  trigger: nil,
                  message: "COULD NOT MEASURE: no enabled Credo check reads no_direct_dependency, so rule 1 (id: \"pure\", no_direct_dependency) has no findings and its baseline was not written. Fix: enable the Anchor check for no_direct_dependency in .credo.exs, then run mix anchor.baseline --write pure again.",
                  filename: ".anchor.yml",
                  kind: :fail_closed,
                  key: nil,
                  rule_id: nil,
                  enforcement: :enforce
                }
              ],
              baselines: 1
            }
     stacktrace:
       test/anchor/integration/ast_baseline_integration_test.exs:80: (test)

.

  3) test --write over an existing file exits 2 (Mix.Tasks.Anchor.BaselineTest)
     test/mix/tasks/anchor_baseline_test.exs:71
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.LintKeysMock.keys/0 in process #PID<0.515.0> with args []
     code: capture_io(fn ->
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:115: Anchor.Managers.AstBaseline.rule_keys/3
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:59: Anchor.Managers.AstBaseline.write/2
       (anchor 0.1.0) lib/mix/tasks/anchor.baseline.ex:68: Mix.Tasks.Anchor.Baseline.write/2
       test/mix/tasks/anchor_baseline_test.exs:77: anonymous fn/0 in Mix.Tasks.Anchor.BaselineTest."test --write over an existing file exits 2"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_baseline_test.exs:76: (test)

...
```

### AB-N: GREW compares the branch with itself

Run summary: `99 tests, 4 failures`

```text
  1) test grew/2 GREW: an entry the branch added since the ref (exit 1) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:173
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:185: (test)

...

  2) test grew/2 GREW takes the rule's enforcement: report (exit 0) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:191
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/c.ex|File", enforcement: :report}] = report.violations
     left:  [%Anchor.Domain.Violation{key: "pure|lib/c.ex|File", enforcement: :report}]
     right: []
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:201: (test)

..

  3) test grew/2 a rule that had no baseline at the ref: every entry is GREW (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:220
     match (=) failed
     code:  assert %{exit_code: 1, violations: [%Violation{key: "pure|lib/a.ex|File"}]} =
              AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
     left:  %{exit_code: 1, violations: [%Anchor.Domain.Violation{key: "pure|lib/a.ex|File"}]}
     right: %{exit_code: 0, violations: [], baselines: 1}
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:228: (test)

...............................................
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### AB-O: GREW ignores the rule's enforcement

Run summary: `99 tests, 1 failure`

```text
  1) test grew/2 GREW takes the rule's enforcement: report (exit 0) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:191
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:200: (test)

........................................
```

### AB-P: a base config that does not load is silent

Run summary: `99 tests, 1 failure`

```text
  1) test grew/2 a base config that does not load is one issue naming every rule (exit 1) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:264
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:272: (test)

.......................
```

### AB-Q: Credo issues carry no key

Run summary: `99 tests, 1 failure`

```text
  1) test write, then held, STALE, and a narrowed run with no false STALE (Anchor.Integration.AstBaselineIntegrationTest)
     test/anchor/integration/ast_baseline_integration_test.exs:67
     match (=) failed
     code:  assert %{exit_code: 0} = AstBaseline.write(%{root: root, id: "pure"}, [])
     left:  %{exit_code: 0}
     right: %{
              exit_code: 3,
              violations: [
                %Anchor.Domain.Violation{
                  line: nil,
                  trigger: nil,
                  message: "COULD NOT MEASURE: no enabled Credo check reads no_direct_dependency, so rule 1 (id: \"pure\", no_direct_dependency) has no findings and its baseline was not written. Fix: enable the Anchor check for no_direct_dependency in .credo.exs, then run mix anchor.baseline --write pure again.",
                  filename: ".anchor.yml",
                  kind: :fail_closed,
                  key: nil,
                  rule_id: nil,
                  enforcement: :enforce
                }
              ],
              baselines: 1
            }
     stacktrace:
       test/anchor/integration/ast_baseline_integration_test.exs:71: (test)

.....
```

### AB-R: --base passes any ref to git

Run summary: `99 tests, 1 failure`

```text
  1) test no mode, both modes, an unknown flag, an argument or a bad ref is usage: exit 2 with Fix: (Mix.Tasks.Anchor.BaselineTest)
     test/mix/tasks/anchor_baseline_test.exs:112
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load/0 in process #PID<0.618.0> with args []
     code: for argv <- [
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:85: Anchor.Managers.AstBaseline.load_config/1
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:69: Anchor.Managers.AstBaseline.grew/2
       (anchor 0.1.0) lib/mix/tasks/anchor.baseline.ex:75: Mix.Tasks.Anchor.Baseline.base/2
       test/mix/tasks/anchor_baseline_test.exs:124: anonymous fn/1 in Mix.Tasks.Anchor.BaselineTest."test no mode, both modes, an unknown flag, an argument or a bad ref is usage: exit 2 with Fix:"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_baseline_test.exs:123: anonymous fn/2 in Mix.Tasks.Anchor.BaselineTest."test no mode, both modes, an unknown flag, an argument or a bad ref is usage: exit 2 with Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/mix/tasks/anchor_baseline_test.exs:113: (test)

..
```

### AB-S: baseline is refused on an ast rule again

Run summary: `132 tests, 18 failures`

```text
  1) test the positive case every rule type accepts its engine's common keys (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:185
     Assertion with == failed
     code:  assert RuleSchema.common_keys(:ast) ==
              ~w(baseline enforcement id min_files paths pattern recursive type uses_module)
     left:  ["enforcement", "id", "min_files", "paths", "pattern", "recursive",
             "type", "uses_module"]
     right: ["baseline", "enforcement", "id", "min_files", "paths", "pattern",
             "recursive", "type", "uses_module"]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:191: (test)

........

  2) test no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_transitive_dependency / positive: baseline with an id: refused: {:error, {:invalid_rule, "rule 1 (id: \"r\"): unknown key \"baseline\" in a no_transitive_dependency rule (`baseline` applies to graph rules only); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module"}}
     no_transitive_dependency / baseline without id (entries start with it): wrong reason (want "`baseline` needs the rule's `id`"): rule 1: unknown key "baseline" in a no_transitive_dependency rule (`baseline` applies to graph rules only); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module
     no_transitive_dependency / an absolute baseline path: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): unknown key "baseline" in a no_transitive_dependency rule (`baseline` applies to graph rules only); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

.

  3) test no_direct_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_direct_dependency / positive: baseline with an id: refused: {:error, {:invalid_rule, "rule 1 (id: \"r\"): unknown key \"baseline\" in a no_direct_dependency rule (`baseline` applies to graph rules only); known keys for no_direct_dependency: allowed_callers, context_depth, enforcement, forbidden_functions, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module"}}
     no_direct_dependency / baseline without id (entries start with it): wrong reason (want "`baseline` needs the rule's `id`"): rule 1: unknown key "baseline" in a no_direct_dependency rule (`baseline` applies to graph rules only); known keys for no_direct_dependency: allowed_callers, context_depth, enforcement, forbidden_functions, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module
     no_direct_dependency / an absolute baseline path: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): unknown key "baseline" in a no_direct_dependency rule (`baseline` applies to graph rules only); known keys for no_direct_dependency: allowed_callers, context_depth, enforcement, forbidden_functions, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

(15 more failures in this run, not quoted; every failing test is named in the table.)


## DND-5632 critic round 1: a finding two rules make is judged by each, printed once, enforced first

**Finding (critic, fb9004e):** `Lint` joined a file's passes with a first-wins `unique/1` before the ratchet, so a `report` rule's copy could replace an enforced baselined rule's NEW finding (the run passed), and a baselined rule could lose the keyed copy of a finding it had (a false STALE). **Fix:** every pass's copies reach the ratchet; afterwards `Anchor.Domain.EnforcementPasses.unique/1` keeps one copy per finding, the enforced one when any is.

**Regression (R1):** the four new `lint_baseline_test.exs` tests ("a finding two rules make") against the unfixed `lint.ex` of fb9004e: `18 tests, 4 failures`. After: `60 tests, 0 failures` over lint_baseline, enforcement_passes and lint tests. Mutations ran through `sab.py` as above; AB-T's first form (`... and false`) did not compile (the type checker reads the clause as never matching), so it was rerun as the form recorded.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AB-R1 | regression: the unfixed lint.ex (first-wins unique before the ratchet), with the new tests (`lib/anchor/managers/lint.ex`) | `lint_baseline_test.exs` | `18 tests, 4 failures` (red) | a finding two rules make an enforced plain rule's copy stands when the baselined rule holds its own; a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding; a finding two rules make held by the baseline: the report rule's copy still prints, report-only; no STALE; a finding two rules make two baselined rules each judge their own copy: both held, no false STALE |
| AB-U | the passes are not joined: a finding two rules make prints twice (`lib/anchor/managers/lint.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs`, `lint_test.exs` | `60 tests, 2 failures` (red) | a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding; beside rules with no baseline a violation every pass makes once per file is printed once |

Filed under their own domain word (ADR 003): AB-T in `lint-20261103-dnd_5648_graph_followups.md`.

### AB-R1: regression: the unfixed lint.ex (first-wins unique before the ratchet), with the new tests

Run summary: `18 tests, 4 failures`

```text
  1) test a finding two rules make an enforced plain rule's copy stands when the baselined rule holds its own (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:283
     match (=) failed
     code:  assert [{_file, [%Violation{enforcement: :enforce, key: nil}]}] =
              run([@plain, rule()], files([{@b, "lib/b.ex"}]))
     left:  [{_file, [%Anchor.Domain.Violation{enforcement: :enforce, key: nil}]}]
     right: [
              {%SourceFile<lib/b.ex>,
               [
                 %Anchor.Domain.Violation{
                   line: 2,
                   trigger: "File",
                   message: "Module has forbidden direct dependency on File",
                   filename: nil,
                   kind: :rule,
                   key: nil,
                   rule_id: nil,
                   enforcement: :enforce
                 }
               ]},
              {:config,
               [
                 %Anchor.Domain.Violation{
                   line: nil,
                   trigger: nil,

  2) test a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:251
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}] = violations
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:259: (test)

..........

  3) test a finding two rules make held by the baseline: the report rule's copy still prints, report-only; no STALE (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:262
     match (=) failed
     code:  assert [{_file, [%Violation{enforcement: :report, key: nil}]}] = results
     left:  [{_file, [%Anchor.Domain.Violation{enforcement: :report, key: nil}]}]
     right: [
              {%SourceFile<lib/b.ex>,
               [
                 %Anchor.Domain.Violation{
                   line: 2,
                   trigger: "File",
                   message: "Module has forbidden direct dependency on File",
                   filename: nil,
                   kind: :rule,
                   key: nil,
                   rule_id: nil,
                   enforcement: :report
                 }
               ]},
              {:config,
               [
                 %Anchor.Domain.Violation{
                   line: nil,
                   trigger: nil,
                   message: "pure|lib/b.ex|File in .anchor/baselines/pure.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/pure.txt; a baseline only shrinks.",
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### AB-U: the passes are not joined: a finding two rules make prints twice

Run summary: `60 tests, 2 failures`

```text
  1) test a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:251
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}] = violations
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File",
                filename: nil,
                kind: :rule,
                key: "pure|lib/b.ex|File",
                rule_id: "pure",
                enforcement: :enforce

  2) test beside rules with no baseline a violation every pass makes once per file is printed once (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:214
     [%Anchor.Domain.Violation{line: 2, trigger: "alias", message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "alias", message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).", filename: nil, kind: :rule, key: "pure|lib/c.ex|alias", rule_id: "pure", enforcement: :enforce}]
     code: assert length(unresolved) == 1, inspect(violations)
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:236: (test)

..................................
```


## DND-5632 critic round 2: a baselined rule's keyed copy is never dropped for an unkeyed one

**Finding (critic, 78461f8):** round 1's `EnforcementPasses.unique/1` kept the first copy on a tie, and the unkeyed copy came first, so with two `report` (or two `enforce`) rules making one finding the baselined rule's keyed copy was dropped and `mix anchor.baseline --write` left its entry out. Round 1 already named the same loss ("`--write` would also leave the entry out"), so this is the same pre-existing class, swept at its root: a keyed copy is always kept, and an unkeyed copy is dropped only when a kept copy of the finding fails at least as hard. In the same class, `--write` now takes keys by the rule id each issue names (`{rule_id, key}` from `CredoKeys`), never by a key prefix, so an id that starts with another's (`pure`, `pure|x`) cannot take its keys.

**Regression (R2):** the new tests against round 1's `enforcement_passes.ex`: `31 tests, 5 failures`. After: `88 tests, 0 failures` over the lint, enforcement-passes, Manager, task and integration tests. AB-V's first spec did not match the formatted source (a SPEC ERROR, nothing ran) and was rerun on the formatted text.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AB-X | --write takes another rule's keys whose id starts with this one's (`lib/anchor/managers/ast_baseline.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs`, `lint_test.exs`, `ast_baseline_test.exs`, `ast_baseline_integration_test.exs` | `83 tests, 1 failure` (red) | write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0) |

Filed under their own domain word (ADR 003): AB-R2, AB-V, AB-W in `lint-20261103-dnd_5648_graph_followups.md`.

### AB-X: --write takes another rule's keys whose id starts with this one's

Run summary: `83 tests, 1 failure`

```text
  1) test write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0) (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:49
     Assertion with == failed
     code:  assert contents == "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"
     left:  "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\npure|x|lib/c.ex|File\n"
     right: "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:67: anonymous fn/3 in Anchor.Managers.AstBaselineTest."test write/2 creates the rule's baseline from its keys alone, sorted, and notes it (exit 0)"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/ast_baseline.ex:127: Anchor.Managers.AstBaseline.create/4
       test/anchor/managers/ast_baseline_test.exs:73: (test)

.....................................
```

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers (DY-J, DY-K, DY-P)

**Run with:** the `## DND-5633: a dynamic call narrowed to a declared behaviour's implementers` section of `layering-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-J | the judgement ignores the rule's narrows? (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 2 failures` (red) | judge/4 an added entry narrowing a removed one is a report NOTE, not GREW; run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |
| DY-K | the Manager does not hand the rule's narrows? over (`lib/anchor/managers/graph.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 1 failure` (red) | run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |
| DY-P | an entry still in the base file can be narrowed (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 1 failure` (red) | judge/4 a narrowing of an entry still there is GREW (it replaced nothing) |

### DY-J: the judgement ignores the rule's narrows?

Run summary: `39 tests, 2 failures`

```text


  1) test judge/4 an added entry narrowing a removed one is a report NOTE, not GREW (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:129
     Assertion with == failed
     code:  assert note.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/enforcement_test.exs:136: (test)

..............................



  2) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

.
```

### DY-K: the Manager does not hand the rule's narrows? over

Run summary: `39 tests, 1 failure`

```text


  1) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

........
```

### DY-P: an entry still in the base file can be narrowed

Run summary: `39 tests, 1 failure`

```text


  1) test judge/4 a narrowing of an entry still there is GREW (it replaced nothing) (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:153
     match (=) failed
     code:  assert [%{enforcement: :enforce, message: message}] = standing
     left:  [%{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :report,
                key: "r|A,B",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "NOTE: r|A,B in .anchor/baselines/r.txt narrows r|A,B,C, the entry it replaced since main; a narrower entry is not growth. Fix: review the narrowing in this change."
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_test.exs:165: (test)

...................................
```

## Whole-MR critic (DND-5632): a new rule's note names only rules gone from the whole config

**Code under test:** `Anchor.Managers.AstBaseline.grew/2`, the `:new_rule` note's list from `Anchor.Domain.BaselineBase.gone/2`.

**Found by:** the whole-MR critic on f4b18ff: `gone/2` was given only the ast rules with a baseline, so a graph rule still in the config (Anchor's own `layering`, `context_acyclic`) read as "no longer in this config". The graph Manager already passes every rule (`now: config.rules`); this Manager now does too. Class check: `grep -rn 'BaselineBase.gone' lib` shows two callers, both passing every rule of the config.

**Suite run:** GN-R is the new test on the unfixed code (`mix test --timeout 2000 --max-cases 2 test/anchor/managers/ast_baseline_test.exs` in `test-slot`). After the fix: `25 tests, 0 failures` over the Manager, task and integration tests.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| GN-R | regression: the unfixed Manager (gone/2 given the ast baselined rules only), with the new test (`lib/anchor/managers/ast_baseline.ex`) | `ast_baseline_test.exs` | `19 tests, 1 failure` (red) | grew/2 a new rule's note names only the baselined rules gone from the whole config |

### GN-R: regression: the unfixed Manager (gone/2 given the ast baselined rules only), with the new test

Run summary: `19 tests, 1 failure`

```text
  1) test grew/2 a new rule's note names only the baselined rules gone from the whole config (Anchor.Managers.AstBaselineTest)
     test/anchor/managers/ast_baseline_test.exs:261
     Assertion with =~ failed
     code:  assert message =~ ~s(this config no longer has: "old-pure".)
     left:  "NOTE: first landing of rule \"pure\": no rule with that id had a baseline at main; rules with a baseline at main that this config no longer has: \"layering\", \"old-pure\". Fix: review every line of .anchor/baselines/pure.txt in this change; from here it only shrinks."
     right: "this config no longer has: \"old-pure\"."
     stacktrace:
       test/anchor/managers/ast_baseline_test.exs:274: (test)

...
```

