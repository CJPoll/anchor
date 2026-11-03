# Sabotage record — the git adapters ignore an inherited GIT_DIR (DND-5581)

- **Domain:** sabotage_scope (the `GitStatus` rows are the runner's adapter, labelled below)
- **Branch:** dnd-5581-hardening-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.GitEnv.env/0`, and its use in `Anchor.Adapters.GitChangeSource`
  (`git/2`) and `Anchor.Adapters.GitStatus` (`git/2`, a `sabotage` domain module)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/adapters/git_env_isolation_test.exs test/anchor/adapters/git_change_source_test.exs
  test/anchor/adapters/git_status_test.exs`, each mutation applied alone and restored byte-for-byte (`cmp`)
  after its run.

DND-5581 is a vulnerability: a git hook sets `GIT_DIR` and `GIT_INDEX_FILE`, a wrapper can export
`GIT_WORK_TREE`, and both adapters ran git with the caller's environment, so `mix anchor.sabotage` run
there read another repository. `git_env_isolation_test.exs` makes a real and a decoy repository, points the
three variables at the decoy, and asserts every adapter call still answers for the real one.

## The regression, on the unfixed code

Before the fix (both adapters passing `env: [{"GIT_OPTIONAL_LOCKS", "0"}]`), the new file ran
`3 tests, 2 failures` (E3 passed: it reads `GitEnv` only). E2 is the silent wrong answer the ticket names:
the decoy's untracked file reported as the real repository's.

```
  1) test E1: GitChangeSource reads the repository at its root, not the one GIT_DIR names (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:74
     Assertion with == failed
     code:  assert GitChangeSource.merge_base(real, "main") == {:ok, real_head}
     left:  {:error, :not_a_work_tree}
     right: {:ok, "ffdb6fbd7eab265257d76f64934fb76d418bce37"}

  2) test E2: GitStatus reads the repository at its root, not the one GIT_DIR names (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:93
     Assertion with == failed
     code:  assert GitStatus.dirty_paths(real, ["lib/a.ex", "lib/real_new.ex", "lib/decoy_new.ex"]) ==
              {:ok, ["lib/a.ex", "lib/real_new.ex"]}
     left:  {:ok, ["lib/a.ex", "lib/decoy_new.ex"]}
     right: {:ok, ["lib/a.ex", "lib/real_new.ex"]}
```

With the fix, the same three files run `14 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `GitChangeSource.git/2` passes `Enum.take(GitEnv.env(), 1)` (only `GIT_OPTIONAL_LOCKS`, the old env) | E1 | `14 tests, 1 failure` |
| B | (`sabotage` domain) `GitStatus.git/2` passes `Enum.take(GitEnv.env(), 1)` | E2 | `14 tests, 1 failure` |
| C | `GitEnv` drops `GIT_DIR` from its list | E1, E3 | `14 tests, 2 failures` |
| D | `GitEnv` drops `GIT_INDEX_FILE` from its list | E1 (through the decoy's index, the real repository's tracked `lib/b.ex` reads as untracked), E3 | `14 tests, 2 failures` |
| E | `GitEnv` drops `GIT_WORK_TREE` from its list | E1, E2, E3 | `14 tests, 3 failures` |

Rows that stayed green: under every mutation the existing G1–G6 and GitStatus tests pass: they never set a
repository-locating variable (their own `git!` helpers clear them).

## Failure strings (verbatim)

### A

```
  1) test E1: GitChangeSource reads the repository at its root, not the one GIT_DIR names (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:78
     Assertion with == failed
     code:  assert GitChangeSource.merge_base(real, "main") == {:ok, real_head}
     left:  {:error, :not_a_work_tree}
     right: {:ok, "e7abacbfead2bbab2267ce5236fbdced7f733a70"}
```

### B

```
  1) test E2: GitStatus reads the repository at its root, not the one GIT_DIR names (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:97
     Assertion with == failed
     code:  assert GitStatus.dirty_paths(real, ["lib/a.ex", "lib/real_new.ex", "lib/decoy_new.ex"]) ==
              {:ok, ["lib/a.ex", "lib/real_new.ex"]}
     left:  {:ok, ["lib/a.ex", "lib/decoy_new.ex"]}
     right: {:ok, ["lib/a.ex", "lib/real_new.ex"]}
```

### C

```
  1) test E3: GitEnv unsets every variable the installed git calls repository-local (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:110
     Assertion with == failed
     code:  assert from_git -- GitEnv.local_env_vars() == []
     left:  ["GIT_DIR"]
     right: []
```

### D

```
  2) test E1: GitChangeSource reads the repository at its root, not the one GIT_DIR names (Anchor.Adapters.GitEnvIsolationTest)
     test/anchor/adapters/git_env_isolation_test.exs:78
     Assertion with == failed
     code:  assert GitChangeSource.untracked(real) == {:ok, ["lib/real_new.ex"]}
     left:  {:ok, ["lib/b.ex", "lib/real_new.ex"]}
     right: {:ok, ["lib/real_new.ex"]}
```

## Traps

- A mutation that leaves `alias Anchor.Adapters.GitEnv` unused does not compile (warnings are errors), so
  A and B keep the alias and take the first element of `GitEnv.env/0`, which is the old env.
- The commit ids differ per run: the repositories are made fresh in each test's `tmp_dir`.

---

# `--ignore-submodules=none` pinned by G7 (DND-5582)

- **Code under test:** `Anchor.Adapters.GitChangeSource.diff/2` (the `--ignore-submodules=none` entry of
  `@diff_args`)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/adapters/git_change_source_test.exs`, restored byte-for-byte (`cmp`) after each run.

G7 is two tests, one per setting: `diff.ignoreSubmodules=all` and `submodule.vendor/sub.ignore=all`. Each
makes G6's repository (a submodule whose checkout moved back one commit, and a changed `lib/a.ex`), sets the
config, checks that a plain `git diff --submodule=short` no longer names `vendor/sub` (the positive control:
the setting really hides it), and asserts the adapter's diff still has `+++ b/vendor/sub` and that
`DiffHunks.parse/1` reads both files.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `@diff_args` without `--ignore-submodules=none` (the unfixed code) | G7 (both) | `11 tests, 2 failures` |
| B | `@diff_args` says `--ignore-submodules=all` | G6, G7 (both) | `11 tests, 3 failures` |

Without a mutation the file runs `11 tests, 0 failures`. Rows that stayed green: G1–G5 and `read` under both
(no submodule); G6 under A (it sets no ignore config).

## Failure strings (verbatim)

### A (the same on the unfixed code, before the flag was added)

```
  1) test G7: a user's diff.ignoreSubmodules=all cannot hide a moved submodule (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:127
     Assertion with =~ failed
     code:  assert diff =~ "+++ b/vendor/sub\n"
     left:  "diff --git a/lib/a.ex b/lib/a.ex\nindex 2576990..ca674d3 100644\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 2\n"
     right: "+++ b/vendor/sub\n"
     stacktrace:
       test/anchor/adapters/git_change_source_test.exs:139: (test)

  2) test G7: a user's submodule.vendor/sub.ignore=all cannot hide a moved submodule (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:127
     Assertion with =~ failed
     code:  assert diff =~ "+++ b/vendor/sub\n"
     left:  "diff --git a/lib/a.ex b/lib/a.ex\nindex 2576990..ca674d3 100644\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 2\n"
     right: "+++ b/vendor/sub\n"
     stacktrace:
       test/anchor/adapters/git_change_source_test.exs:139: (test)
```

### B

```
  1) test G7: a user's diff.ignoreSubmodules=all cannot hide a moved submodule (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:127
     Assertion with =~ failed
     code:  assert diff =~ "+++ b/vendor/sub\n"
     left:  "diff --git a/lib/a.ex b/lib/a.ex\nindex 2576990..ca674d3 100644\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 2\n"
     right: "+++ b/vendor/sub\n"
```

---

# git's expected stderr is captured and asserted, not printed (DND-5589)

- **Code under test:** `Anchor.Adapters.GitChangeSource` (`git/2`'s stderr handling), through G4 and G5
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/adapters/git_change_source_test.exs`,
  restored byte-for-byte (`cmp`) after the run.

Before: the green suite printed two git messages from expected failures, G4's probe of a directory that is
not a repository and G5's `show` of a missing path (the full suite at `ee07f1f`, `1587 tests, 0 failures`):

```
fatal: not a git repository (or any of the parent directories): .git
fatal: path 'lib/none.ex' does not exist in '85077c5dd8360b4662652c0ad7482df4d0d6cce0'
```

git writes them to the BEAM's own stderr (fd 2), which `capture_io` cannot read, so those two calls now run
in a child VM (`in_child_vm/1`, Anchor's ebin only), and the test asserts git's message on stderr and the
result on stdout. After: the file runs `11 tests, 0 failures` and prints nothing.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `GitChangeSource.git/2` runs with `stderr_to_stdout: true` (git's message no longer on stderr) | G4, G5 | `11 tests, 2 failures` |

## Failure strings (verbatim)

### A

```
  1) test G4: a root that is not a git repository, or does not exist, is :not_a_work_tree (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:216
     match (=) failed
     code:  assert [message, "{:error, :not_a_work_tree}"] =
              in_child_vm("Anchor.Adapters.GitChangeSource.merge_base(" <> inspect(outside) <> ~s|, "main")|)
     left:  [message, "{:error, :not_a_work_tree}"]
     right: ["{:error, :not_a_work_tree}"]

  2) test G5: show returns a file as it was at a commit, by a path relative to root (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:163
     match (=) failed
     code:  assert [message, result] =
              in_child_vm(
                "Anchor.Adapters.GitChangeSource.show(" <>
                  Enum.map_join([root, sha, "lib/none.ex"], ", ", &inspect/1) <> ")"
              )
     left:  [message, result]
     right: ["{:error, {:git_failed, [\"show\", \"7d05258519bcbc87378750945ab0687ef655613c:./lib/none.ex\"], 128, \"fatal: path 'lib/none.ex' does not exist in '7d05258519bcbc87378750945ab0687ef655613c'\\n\"}}"]
```
