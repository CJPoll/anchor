# Sabotage record — GitStatus ignores an inherited GIT_DIR (DND-5581)

- **Domain:** sabotage (`Anchor.Adapters.GitStatus`, the runner's dirty check). The `GitEnv` and
  `GitChangeSource` rows of the same run are `sabotage_scope-20261103-dnd_5581_hardening_batch.md`.
- **Branch:** dnd-5581-hardening-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.GitStatus` (`git/2`: its `env:` is `GitEnv.env/0`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/adapters/git_env_isolation_test.exs
  test/anchor/adapters/git_change_source_test.exs test/anchor/adapters/git_status_test.exs`, the mutation
  applied alone and restored byte-for-byte (`cmp`) after its run.

GitStatus was not named in DND-5581; it ran git with the caller's environment too, so inside a git hook the
runner's dirty check asked about another repository. On the unfixed code E2 failed with exactly the
string under B below (the decoy's untracked file reported as the real repository's). With the fix the three
files run `14 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| B | `GitStatus.git/2` passes `Enum.take(GitEnv.env(), 1)` (only `GIT_OPTIONAL_LOCKS`, the old env) | E2 | `14 tests, 1 failure` |

Rows that stayed green: E1 and E3 (they do not call GitStatus), and `git_status_test.exs` (it sets no
repository-locating variable).

## Failure strings (verbatim)

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

## Traps

- The mutation keeps `alias Anchor.Adapters.GitEnv` used (warnings are errors) by taking the first element
  of `GitEnv.env/0`.
