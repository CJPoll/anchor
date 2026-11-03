# Sabotage record — drop_effect_call keeps its arguments (DND-5564)

- **Domain:** sabotage
- **Branch:** dnd-5473-sabotage-run
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.Operators.drop_effect_call/1`
  (`kept_arguments/2`, `call_arguments/1`, `argument_range/1`)
- **Suite run:** `mix test test/anchor/domain/sabotage/operators_test.exs
  test/anchor/domain/sabotage/mutator_test.exs
  test/anchor/domain/sabotage/mutator_compile_test.exs --timeout 2000 --max-cases 2`
  through `test-slot --weight 2` (44 tests, green before and after every row)

Each mutation was applied alone by a scratch driver outside the repo (it
replaces one exact text, runs the three files, and restores the file).
Every failure string is copied from its output.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D1 | the unfixed code: `operators.ex` as on main (452de16), the call's line deleted whole | 3: operators "2: drop_effect_call replaces the Logger call with `_ = {y}`", operators "2: every argument is kept"; mutator 1 | `code:  assert edit.range == {{6, 5}, {6, 19}}` `left:  {{6, 1}, {7, 1}}` `right: {{6, 5}, {6, 19}}`; mutator 1: `{AnchorFixtures.Sabotage.Canary, :effects, 2}` `code: for {mfa, {mutants, skipped}} <- @pinned do` |
| D2 | a piped value is not kept (`call_arguments({:|>, ...})` returns the call's own arguments only) | 1 (+1 bound, below): operators "2: every argument is kept" | `left: [... {"x |> Logger.info(meta: 1)", "_ = {meta: 1}"}, ...]` |
| D3 | the last argument is dropped (`Enum.drop(args, -1)`) | 3: operators "2: ... `_ = {y}`", operators "2: every argument is kept"; mutator 1 | `code:  assert edit.replacement == "_ = {y}"` `left:  "_ = {}"` |

The positive control (operators "2: positive control: a drop that orphans
something else is still refused") passes on D1, D2 and D3 and on the fix, as
it must: a `pat = effect(...)` statement whose binding a later line reads, and
a call through an alias used nowhere else, are refused either way.

## The compile canary

The canary (`test/fixtures/sabotage/canary.ex`) gained `logged/1` (the
`y = ...; Logger.info(y)` case, now a compiling mutant) and `remembered/1`
(`previous = Process.put(...)` with `previous` read later, still refused).
`mutator_compile_test.exs` 1 compiles every emitted mutant with zero
diagnostics on the fix, the new `_ = {y}`, `_ = {pid, {:value, x}}` and
`_ = {self(), :twice}` mutants included; test 2 still proves each refused
edit does not compile cleanly.

## Bound, not a kill

On D2, compile canary 1 also reported `** (ExUnit.TimeoutError) test timed out
after 2000ms`: the canary compiles about 40 modules, and 2000 ms is the
sabotage load rule's short bound, not a verdict on D2. It passed on the fix and
on D1 and D3 under the same bound.
