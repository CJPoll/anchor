# Sabotage record — name/arity and Erlang module names for architecture: (DND-5437)

- **Domain:** function_ref
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.FunctionRef.parse_name_arity/1`, `erlang_module_name?/1`
- **Tests:** `test/anchor/domain/function_ref_test.exs`, and the `exports_function` rows of `architecture_checks_nothing_test.exs`
- **Suite run:** targeted `mix test <files>` per mutation; full `mix test` green before and after (876 tests, 0 failures)
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 3e2861e

Fail-first: the code under test is new in this run (absent on 185ecc9), so each
new test first failed as an undefined module or function; the mutations below
are its proof. Each mutation was applied alone to 3e2861e, the named tests run,
and the file restored with `git checkout --`.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing test) |
|---|---|---|---|
| F1 | parse_name_arity/1 accepts a missing arity | 3 failures (`45 tests, 3 failures`) | `parse_name_arity/1 a token that does not name one function and arity is an error (Anchor.Domain.FunctionRefTest)`: `** (MatchError) no match of right hand side value:` |
