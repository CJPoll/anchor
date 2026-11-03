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
