# Sabotage record — `--submodule=short` pinned by a submodule test (DND-5519)

- **Domain:** sabotage_scope
- **Branch:** dnd-5519-scope-findings
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.GitChangeSource.diff/2` (the `--submodule=short` entry of `@diff_args`)
- **Suite run:** per mutation, `mix test test/anchor/adapters/git_change_source_test.exs`, each mutation applied
  alone to the branch's tree and restored byte-for-byte (`cmp`) after its run.

This closes the measured zero row AH of `sabotage_scope-20261103-dnd_5472.md`: no test made a repository
with a submodule and `diff.submodule=log`. G6 does, from a local path (`protocol.file.allow=always`, no
network), moves the submodule's checkout back one commit, changes `lib/a.ex`, and asserts the diff text and
that `DiffHunks.parse/1` accepts it.

## Mutations

| # | Mutation | Test file | Tests that failed | Run |
|---|---|---|---|---|
| A | `GitChangeSource.diff/2` drops `--submodule=short` from `@diff_args` | `git_change_source_test.exs` | G6 | `9 tests, 1 failure` |
| B | as A, with G6's two text assertions (`refute diff =~ "Submodule vendor/sub"`, `assert diff =~ "+Subproject commit "`) removed, so only the parse assertion is left | `git_change_source_test.exs` | G6 | `9 tests, 1 failure` |
| C | `@diff_args` says `--submodule=log` in place of `--submodule=short` | `git_change_source_test.exs` | G6 | `9 tests, 1 failure` |

Without the mutation, the same file runs `9 tests, 0 failures`.

## Failure strings (verbatim)

### A

```
  1) test G6: a user's diff.submodule=log cannot change the diff format (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:67
     Refute with =~ failed
     code:  refute diff =~ "Submodule vendor/sub"
     left:  "diff --git a/lib/a.ex b/lib/a.ex\nindex 2576990..ca674d3 100644\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 2\nSubmodule vendor/sub 0ddfa6c..176a401 (rewind):\n  < s2\n"
     right: "Submodule vendor/sub"
     stacktrace:
       test/anchor/adapters/git_change_source_test.exs:107: (test)
```

### B

The parse assertion fails on its own, with the exact refusal the ticket names (a false COULD NOT MEASURE
in `mix anchor.sabotage scope`):

```
  1) test G6: a user's diff.submodule=log cannot change the diff format (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:67
     match (=) failed
     code:  assert {:ok, files} = DiffHunks.parse(diff)
     left:  {:ok, files}
     right: {:error,
             {:unrecognised_diff_line, 8,
              "Submodule vendor/sub aa662f8..a65110d (rewind):"}}
     stacktrace:
       test/anchor/adapters/git_change_source_test.exs:108: (test)
```

### C

```
  1) test G6: a user's diff.submodule=log cannot change the diff format (Anchor.Adapters.GitChangeSourceTest)
     test/anchor/adapters/git_change_source_test.exs:67
     Refute with =~ failed
     code:  refute diff =~ "Submodule vendor/sub"
     left:  "diff --git a/lib/a.ex b/lib/a.ex\nindex 2576990..ca674d3 100644\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 2\nSubmodule vendor/sub 54c0a5e..564722c (rewind):\n  < s2\n"
     right: "Submodule vendor/sub"
     stacktrace:
       test/anchor/adapters/git_change_source_test.exs:107: (test)
```

(The commit ids in each string differ per run: the repositories are made fresh in each test's `tmp_dir`.)

## Traps

- Line numbers in the stacktrace (107, 108) are G6's own assertion lines; they move if the test is edited.
- A suite run under a git hook inherits `GIT_DIR` and its siblings; the test's `git!/2` unsets them, as the
  rest of the file does, so G6's repositories are never the outer one.
