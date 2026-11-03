# Sabotage record — baseline paths never follow a symlink (DND-5628)

- **Domain:** baseline_symlink
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.BaselineFile` (the lstat walk, the temp file and the hard link of `create/3`), `Anchor.Adapters.GitShow` (mode 120000 at the ref), and `Anchor.Domain.Failures`' symlink messages
- **Suite run:** one `test-slot` ran a driver that, for each mutation, wrote it, waited 1.1 s, ran `mix test --force --max-cases 2 <its test files>`, restored the source and waited 1.1 s again, so no run read a stale beam. Every row is red, and no two rows quote the same failure block. With every source restored: `37 tests, 0 failures`.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| SL-R1 | regression: the code before this fix (`lib/anchor/adapters/baseline_file.ex`, `lib/anchor/adapters/git_show.ex`) | `baseline_file_test.exs`, `git_show_test.exs` | `21 tests, 6 failures` (red) | a symlink on the path (DND-5628) a symlinked file is refused for read and for create; its target is unchanged; a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside; a symlink on the path (DND-5628) a dangling symlink at the file is refused, and its target is never created; a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path; a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it; a symlink at the ref (DND-5628) a symlinked file is refused, naming it |
| SL-R2 | regression: no symlink message before this fix (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `16 tests, 1 failure` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line |
| SL-A | BaselineFile follows a symlink: the lstat walk never halts on one (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `10 tests, 4 failures` (red) | a symlink on the path (DND-5628) a dangling symlink at the file is refused, and its target is never created; a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside; a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path; a symlink on the path (DND-5628) a symlinked file is refused for read and for create; its target is unchanged |
| SL-B | BaselineFile lstats only the file, not the directories above it (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `10 tests, 2 failures` (red) | a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path; a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside |
| SL-C | create/3 renames the temp file over the name, replacing an existing file (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `10 tests, 1 failure` (red) | create/3 on an existing file returns {:error, :exists} and leaves its bytes |
| SL-D | create/3 leaves its temp file behind (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `10 tests, 1 failure` (red) | a symlink on the path (DND-5628) positive control: a plain path is created and read, and leaves no temp file |
| SL-E | GitShow reads a mode-120000 entry as a file (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `11 tests, 2 failures` (red) | a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it; a symlink at the ref (DND-5628) a symlinked file is refused, naming it |
| SL-F | GitShow checks only the file entry, not the directories above it (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `11 tests, 1 failure` (red) | a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it |
| SL-G | baseline_unreadable has no symlink message (the generic one names no Fix for it) (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `16 tests, 1 failure` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line |

## SL-R1 — regression: a symlinked directory or file was read and written through

The unfixed adapters, with the new tests: `mix test --force test/anchor/adapters/baseline_file_test.exs test/anchor/adapters/git_show_test.exs`. Row 4 shows `create/3` returning `:ok` through `.anchor/baselines`, a symlink to a directory outside the root: it wrote there.

Run summary: `21 tests, 6 failures`

```text
  1) test a symlink on the path (DND-5628) a symlinked file is refused for read and for create; its target is unchanged (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:91
     Assertion with == failed
     code:  assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor/r.txt"}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:symlink, ".anchor/r.txt"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:98: (test)



  2) test a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:67
     Assertion with == failed
     code:  assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor"}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:symlink, ".anchor"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:72: (test)

.....

  3) test a symlink on the path (DND-5628) a dangling symlink at the file is refused, and its target is never created (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:106
     Assertion with == failed
     code:  assert BaselineFile.create(root, ".anchor/r.txt", "r|B|y\n") == {:error, {:symlink, ".anchor/r.txt"}}
     left:  {:error, :exists}
     right: {:error, {:symlink, ".anchor/r.txt"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:114: (test)

.

  4) test a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:81
     Assertion with == failed
     code:  assert BaselineFile.create(root, ".anchor/baselines/r.txt", "r|B|y\n") ==
              {:error, {:symlink, ".anchor/baselines"}}
     left:  :ok
     right: {:error, {:symlink, ".anchor/baselines"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:85: (test)

..

  5) test a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:153
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/etc/hostname") == {:error, {:symlink, ".anchor/etc"}}
     left:  {:error, :absent}
     right: {:error, {:symlink, ".anchor/etc"}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:159: (test)



  6) test a symlink at the ref (DND-5628) a symlinked file is refused, naming it (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:143
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/link.txt") ==
              {:error, {:symlink, ".anchor/baselines/link.txt"}}
     left:  {:ok, ["/etc/hostname"]}
     right: {:error, {:symlink, ".anchor/baselines/link.txt"}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:149: (test)

error: Could not read 7f4545ae8fe823c97fa59dedae2c47fe6b00535a
```

## SL-R2 — regression: a symlink refusal printed as a generic read error with the wrong Fix

`mix test --force test/anchor/domain/failures_graph_test.exs` before the symlink clauses.

Run summary: `16 tests, 1 failure`

```text
  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:264
     baseline_unreadable symlink: "rule 2 (id: \"web\", layering)'s baseline b/x.txt was not read: b is a symlink" in rule 2 (id: "web", layering)'s baseline b/x.txt could not be read ({:symlink, "b"}), so none of its findings is held. Fix: create it with mix anchor.graph --write-baseline web and review it, or remove baseline: from the rule.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:269: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:265: (test)
```

## SL-A — BaselineFile follows a symlink: the lstat walk never halts on one

Mutated `lib/anchor/adapters/baseline_file.ex`.

Run summary: `10 tests, 4 failures`

```text
  1) test a symlink on the path (DND-5628) a dangling symlink at the file is refused, and its target is never created (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:106
     Assertion with == failed
     code:  assert BaselineFile.create(root, ".anchor/r.txt", "r|B|y\n") == {:error, {:symlink, ".anchor/r.txt"}}
     left:  {:error, :exists}
     right: {:error, {:symlink, ".anchor/r.txt"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:114: (test)



  2) test a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:67
     Assertion with == failed
     code:  assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor"}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:symlink, ".anchor"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:72: (test)

.

  3) test a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:81
     Assertion with == failed
     code:  assert BaselineFile.create(root, ".anchor/baselines/r.txt", "r|B|y\n") ==
              {:error, {:symlink, ".anchor/baselines"}}
     left:  :ok
     right: {:error, {:symlink, ".anchor/baselines"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:85: (test)



  4) test a symlink on the path (DND-5628) a symlinked file is refused for read and for create; its target is unchanged (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:91
     Assertion with == failed
     code:  assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor/r.txt"}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:symlink, ".anchor/r.txt"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:98: (test)
```

## SL-B — BaselineFile lstats only the file, not the directories above it

Mutated `lib/anchor/adapters/baseline_file.ex`.

Run summary: `10 tests, 2 failures`

```text
  1) test a symlink on the path (DND-5628) a symlink deeper on the path is named by its own path (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:81
     Assertion with == failed
     code:  assert BaselineFile.create(root, ".anchor/baselines/r.txt", "r|B|y\n") ==
              {:error, {:symlink, ".anchor/baselines"}}
     left:  :ok
     right: {:error, {:symlink, ".anchor/baselines"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:85: (test)

...

  2) test a symlink on the path (DND-5628) a symlinked directory is refused for read and for create; nothing is written outside (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:67
     Assertion with == failed
     code:  assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor"}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:symlink, ".anchor"}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:72: (test)
```

## SL-C — create/3 renames the temp file over the name, replacing an existing file

Mutated `lib/anchor/adapters/baseline_file.ex`.

Run summary: `10 tests, 1 failure`

```text
  1) test create/3 on an existing file returns {:error, :exists} and leaves its bytes (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:20
     Assertion with == failed
     code:  assert BaselineFile.create(root, "r.txt", "new\n") == {:error, :exists}
     left:  :ok
     right: {:error, :exists}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:25: (test)
```

## SL-D — create/3 leaves its temp file behind

Mutated `lib/anchor/adapters/baseline_file.ex`.

Run summary: `10 tests, 1 failure`

```text
  1) test a symlink on the path (DND-5628) positive control: a plain path is created and read, and leaves no temp file (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:120
     Assertion with == failed
     code:  assert File.ls!(Path.join(root, ".anchor/baselines")) == ["r.txt"]
     left:  ["r.txt", ".r.txt.22985.tmp"]
     right: ["r.txt"]
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:125: (test)
```

## SL-E — GitShow reads a mode-120000 entry as a file

Mutated `lib/anchor/adapters/git_show.ex`.

Run summary: `11 tests, 2 failures`

```text
  1) test a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:153
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/etc/hostname") == {:error, {:symlink, ".anchor/etc"}}
     left:  {:error, :absent}
     right: {:error, {:symlink, ".anchor/etc"}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:159: (test)

.

  2) test a symlink at the ref (DND-5628) a symlinked file is refused, naming it (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:143
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/link.txt") ==
              {:error, {:symlink, ".anchor/baselines/link.txt"}}
     left:  {:ok, ["/etc/hostname"]}
     right: {:error, {:symlink, ".anchor/baselines/link.txt"}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:149: (test)
```

## SL-F — GitShow checks only the file entry, not the directories above it

Mutated `lib/anchor/adapters/git_show.ex`.

Run summary: `11 tests, 1 failure`

```text
  1) test a symlink at the ref (DND-5628) a symlinked directory on the path is refused, naming it (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:153
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/etc/hostname") == {:error, {:symlink, ".anchor/etc"}}
     left:  {:error, :absent}
     right: {:error, {:symlink, ".anchor/etc"}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:159: (test)
```

## SL-G — baseline_unreadable has no symlink message (the generic one names no Fix for it)

Mutated `lib/anchor/domain/failures.ex`.

Run summary: `16 tests, 1 failure`

```text
  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:264
     baseline_unreadable symlink: "rule 2 (id: \"web\", layering)'s baseline b/x.txt was not read: b is a symlink" in rule 2 (id: "web", layering)'s baseline b/x.txt could not be read ({:symlink, "b"}), so none of its findings is held. Fix: create it with mix anchor.graph --write-baseline web and review it, or remove baseline: from the rule.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:269: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:265: (test)
```
