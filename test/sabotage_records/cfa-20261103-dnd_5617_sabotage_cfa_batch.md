# Sabotage record — 0-CFA letrec names keyed per scope (DND-5575)

- **Domain:** cfa
- **Branch:** dnd-5617-sabotage-cfa-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Cfa` (`letrec_scopes/4`,
  `lambda_scope/4`, the program's `letrec_scopes`),
  `Anchor.Domain.Cfa.Eval` (`unit_scope/2`, the `:letrec` branch of
  `eval/3`), `Anchor.Domain.Core.letrec_bindings/2` (new)
- **Suite run:** `mix test test/anchor/domain/cfa_test.exs
  test/anchor/domain/core_test.exs --timeout 2000 --max-cases 2` (46 tests,
  green after the fix and after every row), through `test-slot`
- **Method:** each mutation applied alone by a scratch driver outside the
  repo (one exact text replaced; for U3 the two files replaced whole by their
  copies at the base commit 04266e3), the files run, the file restored and
  touched. Failure strings copied from the output.
- **Why the fixture is renamed:** Elixir's compiler names each letrec of one
  function apart (`lc$^0`, `lc$^2`; `recv$^0`, `recv$^1`; also inside nested
  `fn`s and nested comprehensions, probed on Elixir 1.19.4 / OTP 28), but Core
  lets a name be bound again in another scope. The tests rename every letrec
  of a real fixture function to the first one's name, so one function holds
  two letrecs of one name: siblings (`two/1`) and nested (`nested/1`).

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U3 | the unfixed code: `cfa.ex` and `eval.ex` as at 04266e3 (names keyed per function, every letrec of the function in one map) | 1 | L1 `code:  assert sites(cfa, @two, 0..3) == @two_sites` `left:  [ ok: MapSet.new([ {{AnchorFixtures.CfaTest.Letrec, :two, 1}, 1}, {{AnchorFixtures.CfaTest.Letrec, :two, 1}, 3} ]), ok: MapSet.new([ ... 1}, ... 3} ]),` (each comprehension reaches the other's lambda) |
| C1 | `eval/3`'s `:letrec` branch adds no names (`scope = ctx.letrecs`) | 3 | L1 `code:  assert sites(cfa, @two, 0..3) == @two_sites` `left:  [:any, :any, :any, :any]` (also L2, L3) |
| C2 | at the letrec node an outer binding wins over the letrec's own (`Map.merge(bindings, ctx.letrecs)`) | 1 | L2 `code:  assert sites(cfa, @nested, 0..1) == [set([lambda(@nested, 2)]), set([lambda(@nested, 2)])]` `left:  [ok: MapSet.new([]), ok: MapSet.new([])]` |
| C3 | in the per-lambda scope an outer binding wins (`Map.merge(bindings, scope)`) | 1 | L2, same `code:`, `left:  [ ok: MapSet.new([ {{AnchorFixtures.CfaTest.Letrec, :nested, 1}, 2} ]), ok: MapSet.new([]) ]` (the inner letrec's recursive call reached the outer one) |
| C4 | every lambda starts with no letrec name in scope | 3 | L1 `code:  assert sites(cfa, @two, 0..3) == @two_sites` `left:  [:any, :any, :any, :any]` (also L2, L3) |
| C5 | a letrec definition's body does not see its own letrec's names | 3 | L1, same `code:`, `left:  [:any, :any, :any, :any]` (also L2, L3) |

C3 first survived: L2 then read only the head of the inner list, which the
apply in the outer letrec's body produces (and `eval/3` scopes correctly);
the tail comes from the inner letrec's own recursive call, which only the
per-lambda scope resolves. L2 now reads the second element too (site 1), and
C3 fails it.

Positive control: L3 (the compiler's own distinct names, no renaming)
passes on U3, C2 and C3; it fails on C1, C4 and C5, which break every letrec
name, renamed or not.
