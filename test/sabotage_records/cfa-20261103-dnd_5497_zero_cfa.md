# Sabotage record — 0-CFA over Core Erlang (DND-5497)

- **Domain:** cfa (one combined record, as the QA plan directs; the `core` and `higher_order` mutations are labelled CORE-* and HO-* below)
- **Branch:** dnd-5497-zero-cfa
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Cfa` (`analyze/3`, the solver and report), `Anchor.Domain.Cfa.Eval` (the abstract interpreter), `Anchor.Domain.Cfa.Value` (`present/1`), `Anchor.Domain.Core` (`label/1`, `lambdas/1`, `apply_sites/2`, `alloc_ordinal/1`, `line/1`), `Anchor.Domain.HigherOrder` (`invocations/1`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/cfa_test.exs test/anchor/domain/core_test.exs test/anchor/domain/higher_order_test.exs test/anchor/integration/cfa_self_test.exs`, through `test-slot`

Each mutation was applied to one file of this branch's first commit (09ed753) by a driver that asserted the replaced text occurs exactly once, ran the suite, restored the file with `git checkout -- <file>`, and printed `git status --short`, which was empty after every row. Every mutation compiled (the suite ran its 41 tests each time), so no row is a compile failure read as a test failure.

The two mutations the QA plan names are CFA-A (drop the return-value edge: the returned-lambda test fails) and CFA-B (treat `:any` as the empty set: the receive test fails, and an `:any` site never reads as resolved).

No mutation of this first run reddened nothing. That does not mean every test went red here: the review floor found 13 tests no row reached, and the second run below covers each of them.

The labels CFA-M and CFA-O were never used: the driver's list skipped them, and no mutation ran under either. The CORE-C row's test name was first copied cut off at "(two)"; it is corrected to the name in the run's output.

The failure strings of this first run quote line numbers of commit 09ed753; later commits moved the tests.

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
| CORE-C | a HigherOrder call is no site | 4 | apply_sites/2 f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3 (two) and :lists.map/2 are sites; counts the fixture's exact resolved and any counts, total and per function; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; Anchor's own code: no bound hit, every site counted, and the sites are many |
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

# Second run — the tests the first run did not reach, and the review fixes

- **Branch:** dnd-5497-zero-cfa
- **Date:** 2026-11-03
- **Code under test:** as above, plus `Anchor.Domain.Cfa.Eval`'s `mfa_call` (apply/3 and the spawn family), `invoked/1` (a constant HigherOrder argument), the caught-exception and variable-module paths, and `Anchor.Domain.Cfa`'s unknown-root check
- **Suite run:** the same command, at commit 168dcd9 (51 tests)

Same driver: each mutation asserted its text once, ran the suite, restored with `git checkout -- <file>`; `git status --short` was empty after every row.

Traps (runs that lied, kept so they are not repeated):

- R2-P and R2-Q first ran as edits that left a variable or a function unused. The project compiles with warnings as errors, so the suite did not run at all (`Compilation failed due to warnings while using the --warnings-as-errors option`), and the run's exit code 1 is a compile failure, not a red test. Both were rewritten to keep every binding used and rerun; the rows below are the reruns.
- R2-S (a call on a variable module returns nothing) first ran against a fixture calling `mod.maker()` with no argument, and was a measured zero: `51 tests, 0 failures`. Elixir lowers a zero-arity `mod.f()` to a case whose map branch calls into `elixir_erl_pass`, a library call that is `:any` by itself, so the variable-module call never decided that row. The fixture now calls `mod.maker_with(1)`; the row below is the rerun against it (commit 168dcd9).

| # | Mutation | Tests failed | Failing tests |
|---|---|---|---|
| R2-A | default_seed/1 also roots private functions | 1 | analyze/2 default_seed/1 makes every exported function a root, never a private one |
| R2-B | an unknown site id reads as the empty set | 1 | analyze/2 an unknown site id is an error, never an empty set |
| R2-C | by_function also lists functions with no site | 2 | counts the fixture's exact resolved and any counts, total and per function; counts an empty graph and a graph with no apply sites count zero sites |
| R2-D | the default bound is tiny (0 per unit, floor 2) | 20 | analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda; analyze/2 AC1 direct: a lambda bound and applied resolves to that lambda; analyze/2 a captured local &helper/1 passed and applied resolves to the capture; analyze/2 an exported parameter under the default seed is :any; a seed naming its closures resolves; analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both; analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply; analyze/2 elem/2 on a tuple reads the field at that position; analyze/2 recursion: a function passing its own lambda parameter to itself terminates and resolves; the bound the default bound is not hit on the fixture; analyze/2 apply/3 with a variable module may call any exported function of that arity with anything; analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot; analyze/2 a field kept through a map update is read from the map it was built on; counts the fixture's exact resolved and any counts, total and per function; analyze/2 Map.put then Map.get on the same map resolves; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns; analyze/2 apply/2 spreads its argument list over the applied lambda's parameters; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; analyze/2 AC4 stored in a struct field and read back resolves (literal key); analyze/2 apply/3 and spawn/3 with a literal project M:F feed its parameters; Anchor's own code: no bound hit, every site counted, and the sites are many |
| R2-E | lambda ordinals start from a run-dependent number | 16 | lambdas/1 two fns are ordinals 0 and 1 in source order; lambdas/1 labelling labelled Core again gives the same ordinals; lambdas/1 recompiling the same source gives the same ids; lambdas/1 nested fns are numbered outer first; the function's own fun is not a lambda; analyze/2 Map.put then Map.get on the same map resolves; analyze/2 apply/3 and spawn/3 with a literal project M:F feed its parameters; analyze/2 recursion: a function passing its own lambda parameter to itself terminates and resolves; analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot; analyze/2 apply/2 spreads its argument list over the applied lambda's parameters; analyze/2 AC1 direct: a lambda bound and applied resolves to that lambda; analyze/2 AC4 stored in a struct field and read back resolves (literal key); analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda; analyze/2 elem/2 on a tuple reads the field at that position; analyze/2 a field kept through a map update is read from the map it was built on; analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns |
| R2-F | allocation ordinals start at 1 | 1 | alloc_ordinal/1 every tuple, cons and map is an allocation site, numbered in pre-order |
| R2-G | line/1 returns the column of a {line, column} annotation | 3 | line/1 the source line of the Core annotation; nil when there is none; lambdas/1 two fns are ordinals 0 and 1 in source order; apply_sites/2 f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3 (two) and :lists.map/2 are sites |
| R2-H | Enum.reduce/3 invokes with arity 1 | 1 | invocations/1 Enum.reduce/3 invokes argument 2 with arity 2 |
| R2-I | Enum.group_by/3 lists only its key function | 2 | invocations/1 a function invoking two arguments lists both, in argument order; apply_sites/2 f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3 (two) and :lists.map/2 are sites |
| R2-J | :lists.map/2 invokes argument 1 | 1 | invocations/1 Erlang's :lists.map/2 invokes argument 0 |
| R2-K | an unknown function invokes argument 0 | 13 | invocations/1 an unknown function, and a known name at another arity, give []; apply_sites/2 a remote call with a literal module, apply/3 and a local call are not sites; analyze/2 elem/2 on a tuple reads the field at that position; analyze/2 Map.put then Map.get on the same map resolves; analyze/2 AC4 stored in a struct field and read back resolves (literal key); analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; counts the fixture's exact resolved and any counts, total and per function; analyze/2 a field kept through a map update is read from the map it was built on; analyze/2 a dot-call on a module read from a literal is :any, never the empty set; analyze/2 a module in a literal tuple, passed to another function, dot-called: :any; analyze/2 a fun caught from a throw is :any; Anchor's own code: no bound hit, every site counted, and the sites are many |
| R2-L | a row names an argument past the arity | 2 | invocations/1 every entry names an argument the function has, once, in ascending order; Anchor's own code: no bound hit, every site counted, and the sites are many |
| R2-M | a row names a function the runtime does not export | 1 | invocations/1 every entry names a function the runtime exports |
| R2-N | a dot-call on a constant reads as nothing | 3 | analyze/2 a dot-call on a module read from a literal is :any, never the empty set; analyze/2 a module in a literal tuple, passed to another function, dot-called: :any; counts the fixture's exact resolved and any counts, total and per function |
| R2-O | a non-empty constant literal reads as nothing | 3 | counts the fixture's exact resolved and any counts, total and per function; analyze/2 a module in a literal tuple, passed to another function, dot-called: :any; analyze/2 a dot-call on a module read from a literal is :any, never the empty set |
| R2-P | apply/3 and spawn/3 to a project M:F pass nothing | 1 | analyze/2 apply/3 and spawn/3 with a literal project M:F feed its parameters |
| R2-Q | an open apply/3 leaves exported parameters alone | 1 | analyze/2 apply/3 with a variable module may call any exported function of that arity with anything |
| R2-R | a caught exception binds nothing | 2 | analyze/2 a fun caught from a throw is :any; counts the fixture's exact resolved and any counts, total and per function |
| R2-S | a call on a variable module returns nothing | 2 | analyze/2 a call on a variable module returns :any; counts the fixture's exact resolved and any counts, total and per function |
| R2-T | apply/2 passes nothing to the applied closure | 1 | analyze/2 apply/2 spreads its argument list over the applied lambda's parameters |
| R2-U | elem/2 reads nothing | 1 | analyze/2 elem/2 on a tuple reads the field at that position |
| R2-V | a constant HigherOrder argument records only its closures | 2 | counts the fixture's exact resolved and any counts, total and per function; analyze/2 a module passed where Enum invokes an argument (a sorter) is :any, never empty |
| R2-W | a seed naming an unknown function is silently dropped | 1 | analyze/2 a seed naming a function the graph does not hold raises, with a Fix |
| R2-X | make_fun/3 with literal arguments is any | 2 | analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; counts the fixture's exact resolved and any counts, total and per function |

## R2-A — default_seed/1 also roots private functions

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 default_seed/1 makes every exported function a root, never a private one (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:357
     Expected false or nil, got true
     code: refute Map.has_key?(seed, {A, :helper, 1})
     arguments:

         # 1
         %{
           {AnchorFixtures.CfaTest.A, :mapped, 1} => :any,
           {AnchorFixtures.CfaTest.B, :maker, 0} => :any,
           {AnchorFixtures.CfaTest.B, :run_apply, 1} => :any,
           {AnchorFixtures.CfaTest.A, :lit_cross, 0} => :any,
           {AnchorFixtures.CfaTest.A, :from_ets, 1} => :any,
           {AnchorFixtures.CfaTest.A, :spread, 0} => :any,
           {AnchorFixtures.CfaTest.A, :via_spawn, 0} => :any,
           {AnchorFixtures.CfaTest.A, :via_module, 0} => :any,
           {AnchorFixtures.CfaTest.B, :f, 1} => :any,
           {AnchorFixtures.CfaTest.A, :put_get, 0} => :any,
           {AnchorFixtures.CfaTest.B, :run_spawn, 1} => :any,
           {AnchorFixtures.CfaTest.A, :helper, 1} => :any,
           {AnchorFixtures.CfaTest.A, :local_capture, 1} => :any,
           {AnchorFixtures.CfaTest.B, :run1, 2} => :any,
           {AnchorFixtures.CfaTest.A, :stored, 0} => :any,
           {AnchorFixtures.CfaTest.A, :loop_start, 0} => :any,
           {AnchorFixtures.CfaTest.S, :__struct__, 1} => :any,
           {AnchorFixtures.CfaTest.A, :first, 0} => :any,
           {AnchorFixtures.CfaTest.A, :updated, 0} => :any,
           {AnchorFixtures.CfaTest.A, :make, 0} => :any,
           {AnchorFixtures.CfaTest.B, :run, 1} => :any,
           {AnchorFixtures.CfaTest.A, :loop, 2} => :any,
           {AnchorFixtures.CfaTest.B, :run_once, 1} => :any,
           {AnchorFixtures.CfaTest.A, :via_apply3, 0} => :any,
           {AnchorFixtures.CfaTest.S, :__struct__, 0} => :any,
           ...
         }

         # 2
         {AnchorFixtures.CfaTest.A, :helper, 1}

     stacktrace:
       test/anchor/domain/cfa_test.exs:363: (test)
```

## R2-B — an unknown site id reads as the empty set

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 an unknown site id is an error, never an empty set (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:372
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :direct, 0}, 99)) == {:error, :unknown_site}
     left:  {:ok, MapSet.new([])}
     right: {:error, :unknown_site}
     stacktrace:
       test/anchor/domain/cfa_test.exs:373: (test)
```

## R2-C — by_function also lists functions with no site

Run summary: `51 tests, 2 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:380
     Assertion with == failed
     code:  assert cfa.counts.by_function == %{
              {A, :boxed, 0} => %{total: 1, resolved: 0, any: 1},
              {A, :caught, 0} => %{total: 1, resolved: 0, any: 1},
              {A, :direct, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :escapes, 0} => %{total: 1, resolved: 0, any: 1},
              {A, :from_ets, 1} => %{total: 1, resolved: 0, any: 1},
              {A, :lit_use, 1} => %{total: 1, resolved: 0, any: 1},
              {A, :loop, 2} => %{total: 1, resolved: 1, any: 0},
              {A, :mapped, 1} => %{total: 1, resolved: 1, any: 0},
              {A, :open, 1} => %{total: 1, resolved: 0, any: 1},
              {A, :put_get_on, 1} => %{total: 1, resolved: 1, any: 0},
              {A, :received, 0} => %{total: 1, resolved: 0, any: 1},
              {A, :sorter, 1} => %{total: 1, resolved: 0, any: 1},
              {A, :spread, 0} => %{total: 2, resolved: 2, any: 0},
              {A, :stored, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :tagged, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :updated, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :use_make, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :var_mod, 1} => %{total: 1, resolved: 0, any: 1},
              {A, :via_element, 0} => %{total: 1, resolved: 1, any: 0},
              {A, :via_module, 0} => %{total: 1, resolved: 0, any: 1},
              {B, :run, 1} => %{total: 1, resolved: 1, any: 0},
              {B, :run1, 2} => %{total: 1, resolved: 1, any: 0},
              {B, :run_apply, 1} => %{total: 1, resolved: 1, any: 0},
              {B, :run_once, 1} => %{total: 1, resolved: 1, any: 0},
              {B, :run_spawn, 1} => %{total: 1, resolved: 1, any: 0},
              {S, :__struct__, 1} => %{total: 1, resolved: 1, any: 0}
            }
     left:  %{
              {AnchorFixtures.CfaTest.A, :via_apply3, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :loop_start, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :boxed, 0} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :put_get, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :var_mod, 1} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :loop, 2} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :direct, 0} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.B, :run_apply, 1} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :second, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :use_make, 0} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :wrap, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :lit_cross, 0} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :local_capture, 1} => %{
                any: 0,
                total: 0,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :mapped, 1} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, ...} => %{...},
              ...
            }
     right: %{
              {AnchorFixtures.CfaTest.A, :boxed, 0} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :caught, 0} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :direct, 0} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :escapes, 0} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :from_ets, 1} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :lit_use, 1} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :loop, 2} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :mapped, 1} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :open, 1} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :put_get_on, 1} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, :received, 0} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :sorter, 1} => %{
                any: 1,
                total: 1,
                resolved: 0
              },
              {AnchorFixtures.CfaTest.A, :spread, 0} => %{
                any: 0,
                total: 2,
                resolved: 2
              },
              {AnchorFixtures.CfaTest.A, :stored, 0} => %{
                any: 0,
                total: 1,
                resolved: 1
              },
              {AnchorFixtures.CfaTest.A, ...} => %{...},
              ...
            }
     stacktrace:
       test/anchor/domain/cfa_test.exs:383: (test)
```

## R2-D — the default bound is tiny (0 per unit, floor 2)

Run summary: `51 tests, 20 failures`

```
  1) test analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:210
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({B, :run_once, 1})) == set([lambda({A, :go, 0}, 0)])
     left:  :any
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :go, 0}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:212: (test)
```

## R2-E — lambda ordinals start from a run-dependent number

Run summary: `51 tests, 16 failures`

```
  1) test lambdas/1 two fns are ordinals 0 and 1 in source order (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:58
     Assertion with == failed
     code:  assert Enum.map(lambdas, &elem(&1, 0)) == [0, 1]
     left:  [2, 3]
     right: [0, 1]
     stacktrace:
       test/anchor/domain/core_test.exs:61: (test)
```

## R2-F — allocation ordinals start at 1

Run summary: `51 tests, 1 failure`

```
  1) test alloc_ordinal/1 every tuple, cons and map is an allocation site, numbered in pre-order (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:123
     Assertion with == failed
     code:  assert labelled == [{0, :map}, {1, :map}, {2, :tuple}, {3, :cons}, {4, :tuple}]
     left:  [{1, :map}, {2, :map}, {3, :tuple}, {4, :cons}, {5, :tuple}]
     right: [{0, :map}, {1, :map}, {2, :tuple}, {3, :cons}, {4, :tuple}]
     stacktrace:
       test/anchor/domain/core_test.exs:133: (test)
```

## R2-G — line/1 returns the column of a {line, column} annotation

Run summary: `51 tests, 3 failures`

```
  1) test line/1 the source line of the Core annotation; nil when there is none (Anchor.Domain.CoreTest)
     test/anchor/domain/core_test.exs:138
     Assertion with == failed
     code:  assert Core.line(:cerl.set_ann(:cerl.c_atom(:a), [{9, 3}])) == 9
     left:  3
     right: 9
     stacktrace:
       test/anchor/domain/core_test.exs:141: (test)
```

## R2-H — Enum.reduce/3 invokes with arity 1

Run summary: `51 tests, 1 failure`

```
  1) test invocations/1 Enum.reduce/3 invokes argument 2 with arity 2 (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:16
     Assertion with == failed
     code:  assert HigherOrder.invocations({Enum, :reduce, 3}) == [{2, 2}]
     left:  [{2, 1}]
     right: [{2, 2}]
     stacktrace:
       test/anchor/domain/higher_order_test.exs:17: (test)
```

## R2-I — Enum.group_by/3 lists only its key function

Run summary: `51 tests, 2 failures`

```
  1) test invocations/1 a function invoking two arguments lists both, in argument order (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:20
     Assertion with == failed
     code:  assert HigherOrder.invocations({Enum, :group_by, 3}) == [{1, 1}, {2, 1}]
     left:  [{1, 1}]
     right: [{1, 1}, {2, 1}]
     stacktrace:
       test/anchor/domain/higher_order_test.exs:21: (test)
```

## R2-J — :lists.map/2 invokes argument 1

Run summary: `51 tests, 1 failure`

```
  1) test invocations/1 Erlang's :lists.map/2 invokes argument 0 (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:24
     Assertion with == failed
     code:  assert HigherOrder.invocations({:lists, :map, 2}) == [{0, 1}]
     left:  [{1, 1}]
     right: [{0, 1}]
     stacktrace:
       test/anchor/domain/higher_order_test.exs:25: (test)
```

## R2-K — an unknown function invokes argument 0

Run summary: `51 tests, 13 failures`

```
  1) test invocations/1 an unknown function, and a known name at another arity, give [] (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:28
     Assertion with == failed
     code:  assert HigherOrder.invocations({String, :upcase, 1}) == []
     left:  [{0, 1}]
     right: []
     stacktrace:
       test/anchor/domain/higher_order_test.exs:29: (test)
```

## R2-L — a row names an argument past the arity

Run summary: `51 tests, 2 failures`

```
  1) test invocations/1 every entry names an argument the function has, once, in ascending order (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:33
     {Enum, :count, 2}: [2]
     code: for {_m, _f, arity} = mfa <- HigherOrder.functions() do
     stacktrace:
       test/anchor/domain/higher_order_test.exs:39: anonymous fn/2 in Anchor.Domain.HigherOrderTest."test invocations/1 every entry names an argument the function has, once, in ascending order"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/higher_order_test.exs:34: (test)
```

## R2-M — a row names a function the runtime does not export

Run summary: `51 tests, 1 failure`

```
  1) test invocations/1 every entry names a function the runtime exports (Anchor.Domain.HigherOrderTest)
     test/anchor/domain/higher_order_test.exs:43
     {Enum, :all_of?, 2} is not exported
     code: for {m, f, a} = mfa <- HigherOrder.functions() do
     stacktrace:
       test/anchor/domain/higher_order_test.exs:45: anonymous fn/2 in Anchor.Domain.HigherOrderTest."test invocations/1 every entry names a function the runtime exports"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/higher_order_test.exs:44: (test)
```

## R2-N — a dot-call on a constant reads as nothing

Run summary: `51 tests, 3 failures`

```
  1) test analyze/2 a dot-call on a module read from a literal is :any, never the empty set (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:282
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :via_module, 0})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:284: (test)
```

## R2-O — a non-empty constant literal reads as nothing

Run summary: `51 tests, 3 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:380
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 27, resolved: 17, any: 10}
     left:  %{any: 8, total: 27, resolved: 19}
     right: %{any: 10, total: 27, resolved: 17}
     stacktrace:
       test/anchor/domain/cfa_test.exs:381: (test)
```

## R2-P — apply/3 and spawn/3 to a project M:F pass nothing

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 apply/3 and spawn/3 with a literal project M:F feed its parameters (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:295
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({B, :run_apply, 1})) == set([lambda({A, :via_apply3, 0}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok, MapSet.new([{{AnchorFixtures.CfaTest.A, :via_apply3, 0}, 0}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:296: (test)
```

## R2-Q — an open apply/3 leaves exported parameters alone

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 apply/3 with a variable module may call any exported function of that arity with anything (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:303
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({Open, :run_open, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:306: (test)
```

## R2-R — a caught exception binds nothing

Run summary: `51 tests, 2 failures`

```
  1) test analyze/2 a fun caught from a throw is :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:310
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :caught, 0})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:311: (test)
```

## R2-S — a call on a variable module returns nothing

Run summary: `51 tests, 2 failures`

```
  1) test analyze/2 a call on a variable module returns :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:317
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :var_mod, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:318: (test)
```

## R2-T — apply/2 passes nothing to the applied closure

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 apply/2 spreads its argument list over the applied lambda's parameters (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:318
     Assertion with == failed
     code:  assert Enum.sort(results) ==
              Enum.sort([set([lambda({A, :spread, 0}, 0)]), set([lambda({A, :spread, 0}, 1)])])
     left:  [
              ok: MapSet.new([]),
              ok: MapSet.new([
                {{AnchorFixtures.CfaTest.A, :spread, 0}, 0}
              ])
            ]
     right: [
              ok: MapSet.new([
                {{AnchorFixtures.CfaTest.A, :spread, 0}, 0}
              ]),
              ok: MapSet.new([
                {{AnchorFixtures.CfaTest.A, :spread, 0}, 1}
              ])
            ]
     stacktrace:
       test/anchor/domain/cfa_test.exs:322: (test)
```

## R2-U — elem/2 reads nothing

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 elem/2 on a tuple reads the field at that position (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:326
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :via_element, 0})) == set([lambda({A, :via_element, 0}, 0)])
     left:  {:ok, MapSet.new([])}
     right: {:ok,
             MapSet.new([
               {{AnchorFixtures.CfaTest.A, :via_element, 0}, 0}
             ])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:327: (test)
```

## R2-V — a constant HigherOrder argument records only its closures

Run summary: `51 tests, 2 failures`

```
  1) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:380
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 27, resolved: 17, any: 10}
     left:  %{any: 9, total: 27, resolved: 18}
     right: %{any: 10, total: 27, resolved: 17}
     stacktrace:
       test/anchor/domain/cfa_test.exs:381: (test)
```

## R2-W — a seed naming an unknown function is silently dropped

Run summary: `51 tests, 1 failure`

```
  1) test analyze/2 a seed naming a function the graph does not hold raises, with a Fix (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:366
     Expected exception ArgumentError but got KeyError (key {AnchorFixtures.CfaTest.A, :nope, 0} not found in:

         %{
           {AnchorFixtures.CfaTest.B, :run_apply, 1} => %{
             params: [{:var, {AnchorFixtures.CfaTest.B, :run_apply, 1}, 0}],
             ret: {:ret, {AnchorFixtures.CfaTest.B, :run_apply, 1}}
           },
           {{AnchorFixtures.CfaTest.A, :stored, 0}, 0} => %{
             params: [],
             ret: {:lret, {{AnchorFixtures.CfaTest.A, :stored, 0}, 0}}
           },
           {AnchorFixtures.CfaTest.A, :local_capture, 1} => %{
             params: [{:var, {AnchorFixtures.CfaTest.A, :local_capture, 1}, 0}],
             ret: {:ret, {AnchorFixtures.CfaTest.A, :local_capture, 1}}
           },
           {AnchorFixtures.CfaTest.A, :lit_use, 1} => %{
             params: [{:var, {AnchorFixtures.CfaTest.A, :lit_use, 1}, 0}],
             ret: {:ret, {AnchorFixtures.CfaTest.A, :lit_use, 1}}
           },
           {AnchorFixtures.CfaTest.A, :lit_cross, 0} => %{
             params: [],
             ret: {:ret, {AnchorFixtures.CfaTest.A, :lit_cross, 0}}
           },
           {AnchorFixtures.CfaTest.B, :run1, 2} => %{
             params: [
               {:var, {AnchorFixtures.CfaTest.B, :run1, 2}, 0},
               {:var, {AnchorFixtures.CfaTest.B, :run1, 2}, 1}
             ],
             ret: {...}
           },
           ...
         }
     )
     code: assert_raise ArgumentError, ~r/:nope, 0.*Fix: /, fn ->
     stacktrace:
       :erlang.map_get({AnchorFixtures.CfaTest.A, :nope, 0}, %{{AnchorFixtures.CfaTest.B, :run_apply, 1} => %{params: [{:var, {AnchorFixtures.CfaTest.B, :run_apply, 1}, 0}], ret: {:ret, {AnchorFixtures.CfaTest.B, :run_apply, 1}}}, {{AnchorFixtures.CfaTest.A, :stored, 0}, 0} => %{params: [], ret: {:lret, {{AnchorFixtures.CfaTest.A, :stored, 0}, 0}}}, {AnchorFixtures.CfaTest.A, :local_capture, 1} => %{params: [{:var, {AnchorFixtures.CfaTest.A, :local_capture, 1}, 0}], ret: {:ret, {AnchorFixtures.CfaTest.A, :local_capture, 1}}}, {AnchorFixtures.CfaTest.A, :lit_use, 1} => %{params: [{:var, {AnchorFixtures.CfaTest.A, :lit_use, 1}, 0}], ret: {:ret, {AnchorFixtures.CfaTest.A, :lit_use, 1}}}, {AnchorFixtures.CfaTest.A, :lit_cross, 0} => %{params: [], ret: {:ret, {AnchorFixtures.CfaTest.A, :lit_cross, 0}}}, {AnchorFixtures.CfaTest.B, :run1, 2} => %{params: [{:var, {AnchorFixtures.CfaTest.B, :run1, 2}, 0}, {:var, {AnchorFixtures.CfaTest.B, :run1, 2}, 1}], ret: {...}}, ...})
       (anchor 0.1.0) lib/anchor/domain/cfa.ex:272: anonymous fn/3 in Anchor.Domain.Cfa.seed_values/1
       (stdlib 7.1) maps.erl:894: :maps.fold_1/4
       (anchor 0.1.0) lib/anchor/domain/cfa.ex:264: Anchor.Domain.Cfa.solve/2
       (anchor 0.1.0) lib/anchor/domain/cfa.ex:152: Anchor.Domain.Cfa.analyze/3
       test/anchor/domain/cfa_test.exs:367: (test)
```

## R2-X — make_fun/3 with literal arguments is any

Run summary: `51 tests, 2 failures`

```
  1) test analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:250
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :mapped, 1})) == set([{B, :f, 1}])
     left:  :any
     right: {:ok, MapSet.new([{AnchorFixtures.CfaTest.B, :f, 1}])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:252: (test)
```
