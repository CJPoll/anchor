# Sabotage record — the forbidden_functions token (DND-1267)

- **Domain:** function_ref (new: `Anchor.Domain.FunctionRef`, the token grammar
  and the comparison of a call with a token)
- **Branch:** dnd-1267-forbidden-functions
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.FunctionRef.parse/1`, `matches?/4`,
  `may_reach?/4`, `to_string/1`
- **Tests:** `test/anchor/domain/function_ref_test.exs`, and the table in
  `test/anchor/domain/checks/no_dependency_forbidden_functions_test.exs`
- **Suite run:** `mix test` (689 tests)
- **Merge base:** `origin/main` = bfa7aa7; **fix commit:** the DND-1267 commit on
  this branch
- **Primary record (same run):** `dependency_analyzer-20260929-dnd_1267_forbidden_functions.md`

## Fail-first on unfixed bfa7aa7

The module did not exist, so the test file did not compile:

```
error: Anchor.Domain.FunctionRef.__struct__/1 is undefined, cannot expand struct Anchor.Domain.FunctionRef. Make sure the struct name is correct. If the struct name exists and is correct but it still cannot be found, you likely have cyclic module usage in your code
== Compilation error in file test/anchor/domain/function_ref_test.exs ==
```

One row was corrected after the fix, before any mutation run.
`"MyApp.Repo.Insert"` was written expecting "is not a function name". A
capitalised last segment reads as a module, as in `"MyApp.Repo"`, so its reason
is "names no function". The token still fails the load.

## Mutations

Failure strings are verbatim.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| F1 | `arity_matches?/2` always true | 4 of 689 | test "matches?/4 compares module and function exactly, and arity when the token has one": `Expected false or nil, got true`; table: `defdelegate with a default argument: want [{:call, "Bad.Mod.g/2", 2}], got [{:call, "Bad.Mod.g/1", 2}, {:call, "Bad.Mod.g/2", 2}]` |
| F2 | `alias_segment?/1` accepts any non-empty segment | 10 of 689 | `no_direct_dependency / positive: forbidden_functions alone: refused: {:error, {:invalid_rule, "rule 1: `forbidden_functions` entry \"MyApp.Slack.user_info\" is not a function reference: it names no function; ...` |
| F3 | the arity upper bound (255) dropped | 1 of 689 | `"MyApp.Repo.insert/256": want an error with "is not an arity", got {:ok, %Anchor.Domain.FunctionRef{module: MyApp.Repo, function: :insert, arity: 256}}` |
| F4 | `may_reach?/4` treats a known module as unknown | 2 of 689 | `apply/3 of a dynamic function on another module: want [], got [dynamic: 2]` |
