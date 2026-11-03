# Sabotage record — name/arity and Erlang module names for architecture: (DND-5437)

- **Domain:** function_ref
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.FunctionRef.parse_name_arity/1`, `erlang_module_name?/1`
- **Tests:** `test/anchor/domain/function_ref_test.exs`, and the `exports_function` rows of `architecture_checks_nothing_test.exs`
- **Suite run:** each mutation applied alone to fecac77, then
  `MIX_ENV=test mix compile --force` and the `mix test` command named under it,
  then the file restored with `git checkout --`. The full suite (`mix test`)
  was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** fecac77

## Fail-first

Both functions are new; the rest of the file existed.

`mix test test/anchor/domain/function_ref_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: `9 tests, 4 failures`.

```
  1) test parse_name_arity/1 a function name and an arity parse (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:107
     ** (UndefinedFunctionError) function Anchor.Domain.FunctionRef.parse_name_arity/1 is undefined or private. Did you mean:

         * parse/1

     code: assert FunctionRef.parse_name_arity("__aggregate__/0") == {:ok, {:__aggregate__, 0}}

  2) test parse_name_arity/1 a token that does not name one function and arity is an error (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:113
     ** (UndefinedFunctionError) function Anchor.Domain.FunctionRef.parse_name_arity/1 is undefined or private. Did you mean:

         * parse/1

     code: for token <- ["run", "run/x", "run/256", "Mod.run/1", "Run/1", "/1", "run/1/2", ""] do

  3) test erlang_module_name?/1 anything else is not one (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:127
     ** (UndefinedFunctionError) function Anchor.Domain.FunctionRef.erlang_module_name?/1 is undefined or private
     code: for name <- ["", "Gen", ":gen_tcp", "gen.tcp", "gen-tcp", "1gen"] do
```


An earlier run of these mutations, without the forced recompile, let two edits of one file inside one second pass Mix's stale check, so a mutation ran on the previous mutation's beams (M4 recorded M3's failure, G2 recorded G1's). The critic caught it; every mutation here is from the forced-recompile run.

## Mutations

| # | Mutation | Result |
|---|---|---|
| F1 | parse_name_arity/1 accepts a missing arity | `45 tests, 3 failures` |
| M8 | erlang_module_name?/1 accepts a capital first letter | `9 tests, 1 failure` |
| M13 | parse_name_arity/1 accepts any non-empty name | `45 tests, 3 failures` |

### F1: parse_name_arity/1 accepts a missing arity

- File mutated: `lib/anchor/domain/function_ref.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/function_ref_test.exs test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `45 tests, 3 failures`

```
  1) test parse_name_arity/1 a token that does not name one function and arity is an error (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:113
     ** (MatchError) no match of right hand side value:

         {:ok, {:run, :any}}

     code: for token <- ["run", "run/x", "run/256", "Mod.run/1", "Run/1", "/1", "run/1/2", ""] do
```

### M8: erlang_module_name?/1 accepts a capital first letter

- File mutated: `lib/anchor/domain/function_ref.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/function_ref_test.exs`
- Result: `9 tests, 1 failure`

```
  1) test erlang_module_name?/1 anything else is not one (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:127
     "Gen"
     code: for name <- ["", "Gen", ":gen_tcp", "gen.tcp", "gen-tcp", "1gen"] do
```

### M13: parse_name_arity/1 accepts any non-empty name

- File mutated: `lib/anchor/domain/function_ref.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/function_ref_test.exs test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `45 tests, 3 failures`

```
  1) test parse_name_arity/1 a token that does not name one function and arity is an error (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:113
     ** (MatchError) no match of right hand side value:

         {:ok, {:"Mod.run", 1}}

     code: for token <- ["run", "run/x", "run/256", "Mod.run/1", "Run/1", "/1", "run/1/2", ""] do
```
