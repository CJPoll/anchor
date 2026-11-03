# Sabotage record — 0-CFA over Core Erlang (DND-5497)

- **Domain:** cfa (one combined record, as the QA plan directs; the `core` and `higher_order` mutations are labelled CORE-* and HO-* below)
- **Branch:** dnd-5497-zero-cfa
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Cfa` (`analyze/3`, the solver and report), `Anchor.Domain.Cfa.Eval` (the abstract interpreter), `Anchor.Domain.Cfa.Value` (`present/1`), `Anchor.Domain.Core` (`label/1`, `lambdas/1`, `apply_sites/2`), `Anchor.Domain.HigherOrder` (`invocations/1`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/cfa_test.exs test/anchor/domain/core_test.exs test/anchor/domain/higher_order_test.exs test/anchor/integration/cfa_self_test.exs`, through `test-slot`

Each mutation was applied to one file of this branch's first commit (09ed753) by a driver that asserted the replaced text occurs exactly once, ran the suite, restored the file with `git checkout -- <file>`, and printed `git status --short`, which was empty after every row. Every mutation compiled (the suite ran its 41 tests each time), so no row is a compile failure read as a test failure.

The two mutations the QA plan names are CFA-A (drop the return-value edge: the returned-lambda test fails) and CFA-B (treat `:any` as the empty set: the receive test fails, and an `:any` site never reads as resolved).

No mutation reddened nothing: there is no measured zero in this run.

| # | Mutation | Tests failed | Failing tests |
|---|---|---|---|
| CFA-A | drop the return-value edge (a call reads nothing back) | 2 | analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns |
| CFA-B | treat :any as the empty set at the report | 6 | analyze/2 a lambda stored in a container escapes: its parameter's site is :any; analyze/2 a fun read from :ets.lookup is :any; analyze/2 a lambda handed to outside code is called with anything: its parameter's site is :any; counts the fixture's exact resolved and any counts, total and per function; analyze/2 AC6 a fun received in a message is :any; analyze/2 an exported parameter under the default seed is :any; a seed naming its closures resolves |
| CFA-C | drop the argument-to-parameter edge | 4 | analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both; analyze/2 recursion: a function passing its own lambda parameter to itself terminates and resolves; analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda; analyze/2 a captured local &helper/1 passed and applied resolves to the capture |
| CFA-D | a receive primop's result is nothing instead of any | 2 | counts the fixture's exact resolved and any counts, total and per function; analyze/2 AC6 a fun received in a message is :any |
| CFA-E | an escaped closure's parameters stay as they were | 3 | counts the fixture's exact resolved and any counts, total and per function; analyze/2 a lambda stored in a container escapes: its parameter's site is :any; analyze/2 a lambda handed to outside code is called with anything: its parameter's site is :any |
| CFA-F | the step bound is never enforced | 1 | the bound a run that hits :max_steps reports every site :any and says so |
| CFA-G | a run that hit the bound reports its partial values | 1 | the bound a run that hits :max_steps reports every site :any and says so |
| CFA-H | a literal-key field read ignores the key (reads only the wildcard) | 4 | analyze/2 Map.put then Map.get on the same map resolves; analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply; analyze/2 a field kept through a map update is read from the map it was built on; analyze/2 AC4 stored in a struct field and read back resolves (literal key) |
| CFA-I | a map update does not read through to its base | 1 | analyze/2 a field kept through a map update is read from the map it was built on |
| CFA-J | a HigherOrder invocation records nothing at its site | 1 | analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture |
| CFA-K | a literal-key field read skips the wildcard slot | 1 | analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot |
| CFA-L | the seed is ignored (no root gets its parameter values) | 3 | analyze/2 a seed naming the wrong number of parameter values raises, naming the function; counts the fixture's exact resolved and any counts, total and per function; analyze/2 an exported parameter under the default seed is :any; a seed naming its closures resolves |
| CFA-N | a raise call returns any instead of nothing | 4 | analyze/2 AC4 stored in a struct field and read back resolves (literal key); counts the fixture's exact resolved and any counts, total and per function; analyze/2 a field kept through a map update is read from the map it was built on; analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot |
| CFA-P | a closure stored in a container does not escape | 2 | counts the fixture's exact resolved and any counts, total and per function; analyze/2 a lambda stored in a container escapes: its parameter's site is :any |
| CORE-A | lambda ordinals start at 1 (the function's own fun counted) | 14 | lambdas/1 labelling labelled Core again gives the same ordinals; lambdas/1 nested fns are numbered outer first; the function's own fun is not a lambda; lambdas/1 a receive's letrec loop is a lambda with its own ordinal; lambdas/1 two fns are ordinals 0 and 1 in source order; analyze/2 a field kept through a map update is read from the map it was built on; analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot; analyze/2 AC4 stored in a struct field and read back resolves (literal key); analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply; analyze/2 recursion: a function passing its own lambda parameter to itself terminates and resolves; analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda; analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns; analyze/2 Map.put then Map.get on the same map resolves; analyze/2 AC1 direct: a lambda bound and applied resolves to that lambda |
| CORE-B | every apply is a site, a local call too | 4 | apply_sites/2 a remote call with a literal module, apply/3 and a local call are not sites; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns; counts the fixture's exact resolved and any counts, total and per function; analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply |
| CORE-C | a HigherOrder call is no site | 4 | apply_sites/2 f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3; counts the fixture's exact resolved and any counts, total and per function; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; Anchor's own code: no bound hit, every site counted, and the sites are many |
| HO-A | Enum.map/2 invokes argument 0 | 3 | invocations/1 Enum.map/2 invokes argument 1 with arity 1; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; counts the fixture's exact resolved and any counts, total and per function |
| SELF-A | the default bound is the floor alone (0 steps per unit) | 1 | Anchor's own code: no bound hit, every site counted, and the sites are many |

## CFA-A — drop the return-value edge (a call reads nothing back)

Run summary: `41 tests, 2 failures`

```
  2) test analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:173
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :use_make, 0})) == set([lambda({A, :make, 0}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :make, 0}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:174: (test)
```

## CFA-B — treat :any as the empty set at the report

Run summary: `41 tests, 6 failures`

```
  5) test analyze/2 AC6 a fun received in a message is :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:217
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :received, 0})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:218: (test)
```

## CFA-C — drop the argument-to-parameter edge

Run summary: `41 tests, 4 failures`

```
  1) test analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:167
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({B, :run, 1})) ==
              set([lambda({A, :first, 0}, 0), lambda({A, :second, 0}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok,
             MapSet.new([
               {{AnchorFixtures.CfaTest.A, :first, 0}, 0},
               {{AnchorFixtures.CfaTest.A, :second, 0}, 0}
             ])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:169: (test)
```

## CFA-D — a receive primop's result is nothing instead of any

Run summary: `41 tests, 2 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:272
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 17, resolved: 12, any: 5}
     left:  %{any: 4, total: 17, resolved: 13}
     right: %{any: 5, total: 17, resolved: 12}
     stacktrace:
       test/anchor/domain/cfa_test.exs:273: (test)
```

## CFA-E — an escaped closure's parameters stay as they were

Run summary: `41 tests, 3 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:272
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 17, resolved: 12, any: 5}
     left:  %{any: 3, total: 17, resolved: 14}
     right: %{any: 5, total: 17, resolved: 12}
     stacktrace:
       test/anchor/domain/cfa_test.exs:273: (test)
```

## CFA-F — the step bound is never enforced

Run summary: `41 tests, 1 failure`

```
  1) test the bound a run that hits :max_steps reports every site :any and says so (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:311
     Expected truthy, got false
     code: assert cfa.bound_hit?
     stacktrace:
       test/anchor/domain/cfa_test.exs:314: (test)
```

## CFA-G — a run that hit the bound reports its partial values

Run summary: `41 tests, 1 failure`

```
  1) test the bound a run that hits :max_steps reports every site :any and says so (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:311
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :direct, 0})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:316: (test)
```

## CFA-H — a literal-key field read ignores the key (reads only the wildcard)

Run summary: `41 tests, 4 failures`

```
  1) test analyze/2 Map.put then Map.get on the same map resolves (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:189
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :put_get_on, 1})) == set([lambda({A, :put_get_on, 1}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :put_get_on, 1}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:190: (test)
```

## CFA-I — a map update does not read through to its base

Run summary: `41 tests, 1 failure`

```
  1) test analyze/2 a field kept through a map update is read from the map it was built on (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:198
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :updated, 0})) == set([lambda({A, :updated, 0}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :updated, 0}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:199: (test)
```

## CFA-J — a HigherOrder invocation records nothing at its site

Run summary: `41 tests, 1 failure`

```
  1) test analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:202
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :mapped, 1})) == set([{B, :f, 1}])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{AnchorFixtures.CfaTest.B, :f, 1}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:204: (test)
```

## CFA-K — a literal-key field read skips the wildcard slot

Run summary: `41 tests, 1 failure`

```
  1) test analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:182
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({Wild, :keyed, 1})) == set([lambda({Wild, :keyed, 1}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.Wild, :keyed, 1}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:185: (test)
```

## CFA-L — the seed is ignored (no root gets its parameter values)

Run summary: `41 tests, 3 failures`

```
  1) test analyze/2 a seed naming the wrong number of parameter values raises, naming the function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:246
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError,
     stacktrace:
       test/anchor/domain/cfa_test.exs:248: (test)
```

## CFA-N — a raise call returns any instead of nothing

Run summary: `41 tests, 4 failures`

```
  1) test analyze/2 AC4 stored in a struct field and read back resolves (literal key) (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:178
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :stored, 0})) == set([lambda({A, :stored, 0}, 0)])
     left:  :any
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :stored, 0}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:179: (test)
```

## CFA-P — a closure stored in a container does not escape

Run summary: `41 tests, 2 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:272
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 17, resolved: 12, any: 5}
     left:  %{any: 4, total: 17, resolved: 13}
     right: %{any: 5, total: 17, resolved: 12}
     stacktrace:
       test/anchor/domain/cfa_test.exs:273: (test)
```

## CORE-A — lambda ordinals start at 1 (the function's own fun counted)

Run summary: `41 tests, 14 failures`

```
  1) test lambdas/1 labelling labelled Core again gives the same ordinals (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:92
     Assertion with == failed
     code:  assert Core.lambdas(Core.label(fun)) |> Enum.map(&elem(&1, 0)) == [0, 1]
     left:  [1, 2]
     right: [0, 1]
     stacktrace:
       test/anchor/domain/core_test.exs:94: (test)
```

## CORE-B — every apply is a site, a local call too

Run summary: `41 tests, 4 failures`

```
  1) test apply_sites/2 a remote call with a literal module, apply/3 and a local call are not sites (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:116
     Assertion with == failed
     code:  assert Core.apply_sites(mfa({:not_sites, 2}), core(binary, {:not_sites, 2})) == []
     left:  [
              {{{AnchorFixtures.CoreTest.M, :not_sites, 2}, 0},
               {:c_apply,
                [
                  {:anchor_sites, [0]},
                  {19, 5},
                  {:file, ~c"core_test.ex"}
                ],
                {:c_var, [{19, 5}, {:file, ~c"core_test.ex"}],
                 {:helper, 1}},
                [
                  {:c_var, [{19, 12}, {:file, ~c"core_test.ex"}],
                   :_x@1}
                ]}}
            ]
     right: []
     stacktrace:
       test/anchor/domain/core_test.exs:118: (test)
```

## CORE-C — a HigherOrder call is no site

Run summary: `41 tests, 4 failures`

```
  1) test apply_sites/2 f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3 (two) and :lists.map/2 are sites (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:99
     Assertion with == failed
     code:  assert Enum.map(sites, &elem(&1, 0)) == Enum.map(0..5, &{mfa({:applies, 2}), &1})
     left:  [
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 0},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 1}
            ]
     right: [
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 0},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 1},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 2},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 3},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 4},
              {{AnchorFixtures.CoreTest.M, :applies, 2}, 5}
            ]
     stacktrace:
       test/anchor/domain/core_test.exs:103: (test)
```

## HO-A — Enum.map/2 invokes argument 0

Run summary: `41 tests, 3 failures`

```
  1) test invocations/1 Enum.map/2 invokes argument 1 with arity 1 (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:12
     Assertion with == failed
     code:  assert HigherOrder.invocations({Enum, :map, 2}) == [{1, 1}]
     left:  [{0, 1}]
     right: [{1, 1}]
     stacktrace:
       test/anchor/domain/higher_order_test.exs:13: (test)
```

## SELF-A — the default bound is the floor alone (0 steps per unit)

Run summary: `41 tests, 1 failure`

```
  1) test Anchor's own code: no bound hit, every site counted, and the sites are many (Anchor.Integration.CfaSelfTest)
     test/anchor/integration/cfa_self_test.exs:14
     Expected false or nil, got true
     code: refute cfa.bound_hit?
     stacktrace:
       test/anchor/integration/cfa_self_test.exs:21: (test)
```

