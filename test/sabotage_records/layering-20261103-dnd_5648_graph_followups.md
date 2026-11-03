# Sabotage records: layering (branch dnd-5648-graph-followups)

- **Domain:** layering (dynamic calls, and the baselines they feed)
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers

**Code under test:** `Anchor.Domain.BehaviourReceiver`, `Anchor.Domain.DynamicCalls.targets/2` and `tally/1`, the callbacks read by `Anchor.Adapters.BeamReader` and carried by `Anchor.Domain.Graph.Builder`, `Anchor.Domain.Enforcement`'s narrowed entries with `ContextAcyclic.narrows?/2` and `GraphRules.narrows/1`, the Manager's wiring, and the summary in `Anchor.Domain.GraphReport`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). DY-R is the regression: `targets/2` back to the old fan-out, under which the layering test sees the Manager's typed call reach the Mix task. With every source restored: `1634 tests, 0 failures` over `test/anchor/domain`, the graph Manager, BeamReader, task and integration tests.

**Dogfood (Anchor's own tree):** before the fix, `MIX_ENV=dev mix anchor.graph` held the two `layering|Anchor.Managers.Sabotage.Coverage.traced_suite/3|-> Mix.Tasks.Anchor.{Graph,Sabotage}.run/1` entries; after it, both read STALE (`matches no finding (it was fixed)`), and so did the seven-context `context_acyclic` entry, the cycle being back to five contexts. With those lines deleted: `0 violations (0 report-only, 80 baselined); dynamic calls: 79 fanned out to every exporter, 1 narrowed by behaviour`, and under `--base 5fb4aab` the narrowed cycle is a report-only NOTE.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-R | the old fan-out: targets never narrows (`lib/anchor/domain/dynamic_calls.ex`) | `behaviour_receiver_test.exs` | `11 tests, 2 failures` (red) | the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task; behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only |
| DY-A | a function's clause patterns are not read as its parameters (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 4 failures` (red) | behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only; the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task; DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out; behaviour/2 and DynamicCalls.targets/2 a function of several clauses narrows too (its parameters are a case's patterns) |
| DY-B | a name bound inside a later clause's pattern is read as the parameter (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 a name a later clause binds in a pattern or its body is no parameter: it fans out |
| DY-C | a name bound again in a body is read as the parameter (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 a name a later clause binds in a pattern or its body is no parameter: it fans out |
| DY-D | the callback is not required (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out |
| DY-E | any t() reads as module() (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out |
| DY-F | one typed receiver narrows a function with an untyped one too (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 one untyped receiver among the function's run/1 calls keeps them all fanned out |
| DY-G | implementers are every exporter, @behaviour or not (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `11 tests, 3 failures` (red) | behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only; the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task; behaviour/2 and DynamicCalls.targets/2 implementers/3: the modules declaring the behaviour that export the function |
| DY-H | tally swaps narrowed and fanned out (`lib/anchor/domain/dynamic_calls.ex`) | `behaviour_receiver_test.exs` | `11 tests, 1 failure` (red) | DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out |

Filed under their own domain word (ADR 003): DY-J, DY-K, DY-P in `baseline-20261103-dnd_5648_graph_followups.md`; DY-L in `context_acyclic-20261103-dnd_5648_graph_followups.md`; DY-M in `graph_runner-20261103-dnd_5648_graph_followups.md`; DY-N in `beam_reader-20261103-dnd_5648_graph_followups.md`; DY-O in `builder-20261103-dnd_5648_graph_followups.md`.

### DY-R: the old fan-out: targets never narrows

Run summary: `11 tests, 2 failures`

```text


  1) test the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:244
     Refute with in failed
     code:  refute "#{@ns}.Manager.typed/2" in callers
     left:  "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2"
     right: MapSet.new(["AnchorFixtures.BehaviourReceiverTest.Manager.as_module/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.from_options/1",
             "AnchorFixtures.BehaviourReceiverTest.Manager.inner/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.mixed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.nested/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.no_callback/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.not_module_type/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.rebound/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.two_clauses/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.untyped/2"])
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:252: (test)

......



  2) test behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:143
     Assertion with == failed
     code:  assert DynamicCalls.targets(graph, call) == [mod(Impl)]
     left:  [AnchorFixtures.BehaviourReceiverTest.Impl,
             Mix.Tasks.AnchorFixturesBehaviourReceiverTest.Go]
     right: [AnchorFixtures.BehaviourReceiverTest.Impl]
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:148: (test)
```

### DY-A: a function's clause patterns are not read as its parameters

Run summary: `11 tests, 4 failures`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:143
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == {:ok, mod(Port)}
     left:  :none
     right: {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:147: (test)







  2) test the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:244
     Refute with in failed
     code:  refute "#{@ns}.Manager.typed/2" in callers
     left:  "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2"
     right: MapSet.new(["AnchorFixtures.BehaviourReceiverTest.Manager.as_module/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.from_options/1",
             "AnchorFixtures.BehaviourReceiverTest.Manager.inner/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.mixed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.nested/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.no_callback/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.not_module_type/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.rebound/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.two_clauses/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.untyped/2"])
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:252: (test)

....



  3) test DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:202
     Assertion with in failed
     code:  assert {{mod(Manager), :typed, 2}, :run, 1} in narrowed
     left:  {{AnchorFixtures.BehaviourReceiverTest.Manager, :typed, 2}, :run, 1}
     right: []
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:205: (test)

.



  4) test behaviour/2 and DynamicCalls.targets/2 a function of several clauses narrows too (its parameters are a case's patterns) (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:151
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call(graph, :two_clauses, 2)) == {:ok, mod(Port)}
     left:  :none
     right: {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:154: (test)

.
```

### DY-B: a name bound inside a later clause's pattern is read as the parameter

Run summary: `11 tests, 1 failure`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 a name a later clause binds in a pattern or its body is no parameter: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:180
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call(graph, :nested, 2)) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:183: (test)

.
```

### DY-C: a name bound again in a body is read as the parameter

Run summary: `11 tests, 1 failure`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 a name a later clause binds in a pattern or its body is no parameter: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:180
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call(graph, :nested, 2)) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:183: (test)

..
```

### DY-D: the callback is not required

Run summary: `11 tests, 1 failure`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:164
     :no_callback
     code: for name <- [:as_module, :not_module_type, :no_callback] do
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:168: anonymous fn/3 in Anchor.Domain.BehaviourReceiverTest."test behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/behaviour_receiver_test.exs:166: (test)

.......
```

### DY-E: any t() reads as module()

Run summary: `11 tests, 1 failure`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:164
     :not_module_type
     code: for name <- [:as_module, :not_module_type, :no_callback] do
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:168: anonymous fn/3 in Anchor.Domain.BehaviourReceiverTest."test behaviour/2 and DynamicCalls.targets/2 module(), a t() that is not module(), and a behaviour without the callback fan out"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/behaviour_receiver_test.exs:166: (test)
```

### DY-F: one typed receiver narrows a function with an untyped one too

Run summary: `11 tests, 1 failure`

```text






  1) test behaviour/2 and DynamicCalls.targets/2 one untyped receiver among the function's run/1 calls keeps them all fanned out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:187
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call(graph, :mixed, 2)) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:190: (test)

..........
```

### DY-G: implementers are every exporter, @behaviour or not

Run summary: `11 tests, 3 failures`

```text


  1) test behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:143
     Assertion with == failed
     code:  assert DynamicCalls.targets(graph, call) == [mod(Impl)]
     left:  [AnchorFixtures.BehaviourReceiverTest.Impl,
             Mix.Tasks.AnchorFixturesBehaviourReceiverTest.Go]
     right: [AnchorFixtures.BehaviourReceiverTest.Impl]
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:148: (test)

..



  2) test the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:244
     Refute with in failed
     code:  refute "#{@ns}.Manager.typed/2" in callers
     left:  "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2"
     right: MapSet.new(["AnchorFixtures.BehaviourReceiverTest.Manager.as_module/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.from_options/1",
             "AnchorFixtures.BehaviourReceiverTest.Manager.inner/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.mixed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.nested/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.no_callback/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.not_module_type/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.rebound/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.two_clauses/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.typed/2",
             "AnchorFixtures.BehaviourReceiverTest.Manager.untyped/2"])
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:252: (test)

.....



  3) test behaviour/2 and DynamicCalls.targets/2 implementers/3: the modules declaring the behaviour that export the function (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:193
     Assertion with == failed
     code:  assert BehaviourReceiver.implementers(graph, mod(Port), {:run, 1}) == [mod(Impl)]
     left:  [AnchorFixtures.BehaviourReceiverTest.Impl,
             Mix.Tasks.AnchorFixturesBehaviourReceiverTest.Go]
     right: [AnchorFixtures.BehaviourReceiverTest.Impl]
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:196: (test)
```

### DY-H: tally swaps narrowed and fanned out

Run summary: `11 tests, 1 failure`

```text


  1) test DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:202
     Assertion with in failed
     code:  assert {{mod(Manager), :typed, 2}, :run, 1} in narrowed
     left:  {{AnchorFixtures.BehaviourReceiverTest.Manager, :typed, 2}, :run, 1}
     right: [
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :as_module, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :from_options, 1}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :inner, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :mixed, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :nested, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :no_callback, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :not_module_type, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :rebound, 2}, :run, 1},
              {{AnchorFixtures.BehaviourReceiverTest.Manager,
                :untyped, 2}, :run, 1}
            ]
```

## DND-5491: AST/graph parity (the engine split) (PA-B)

**Run with:** the `## DND-5491: AST/graph parity (the engine split)` section of `parity-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-B | CallMatrix's other_context scope ignores the contexts (`lib/anchor/domain/call_matrix.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 2 failures` (red) | the pairs each engine flags, named (so a change in either is read here); both engines flag the same pairs, apart from the listed divergences |

### PA-B: CallMatrix's other_context scope ignores the contexts

Run summary: `50 tests, 2 failures`

```text
  1) test the pairs each engine flags, named (so a change in either is read here) (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:143
     Assertion with == failed
     code:  assert context |> graph_pairs() |> Enum.sort() == Enum.sort([{@fee, @store} | expected_direct])
     left:  [
              {"AnchorFixtures.Parity.Billing.Domain.Fee",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Domain.Calc",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Rules",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Ui.Badge",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"}
            ]
     right: [
              {"AnchorFixtures.Parity.Billing.Domain.Fee",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Adapters.Store",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Calc",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Rules",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Ui.Badge",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"}

  2) test both engines flag the same pairs, apart from the listed divergences (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:114
     the engines disagree on: AnchorFixtures.Parity.Orders.Adapters.Store -> AnchorFixtures.Parity.Orders.Managers.Checkout (only the ast engine flags it)
     code: assert found -- listed == [],
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:130: (test)
```

## Review floor (DND-5633): narrowing only on evidence that holds

**Code under test:** `Anchor.Domain.BehaviourReceiver.behaviour/2`: its parameter-position map (`parameters/1`) and the new requirement that the behaviour has a project implementer; `Anchor.Domain.DynamicCalls.targets/2` and `tally/1` follow it.

**Found by:** the review floor's code reviewer (2026-11-03): (1) the name-to-position map was built over every clause with the last clause winning, so a name at position 1 in one clause and 0 in another read as position 0 and narrowed on the wrong parameter's type; (2) a behaviour with no project implementer narrowed the call to `[]`, judged against nothing, and `tally/1` counted it narrowed.

**Suite run:** FL-R is the two new tests on the unfixed code (`mix test --timeout 2000 --max-cases 2 test/anchor/domain/behaviour_receiver_test.exs` in `test-slot`). FL-A and FL-B were run by `sab.py` (wait 1.1 s, write, run, restore, wait 1.1 s), each undoing one half of the fix. With every source restored: `18 tests, 0 failures` over `behaviour_receiver_test.exs` and `dynamic_calls_test.exs`.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| FL-R | regression: the unfixed code, with the two new tests (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `13 tests, 2 failures` (red) | behaviour/2 and DynamicCalls.targets/2 a name at a different position in each clause is no one parameter: it fans out; behaviour/2 and DynamicCalls.targets/2 a behaviour no project module implements is no evidence: it fans out |
| FL-A | a name at several positions keeps its first (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `13 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 a name at a different position in each clause is no one parameter: it fans out |
| FL-B | no implementer is required (`lib/anchor/domain/behaviour_receiver.ex`) | `behaviour_receiver_test.exs` | `13 tests, 1 failure` (red) | behaviour/2 and DynamicCalls.targets/2 a behaviour no project module implements is no evidence: it fans out |

### FL-R: regression: the unfixed code, with the two new tests

Run summary: `13 tests, 2 failures`

```text
  1) test behaviour/2 and DynamicCalls.targets/2 a name at a different position in each clause is no one parameter: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:215
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:219: (test)

..

  2) test behaviour/2 and DynamicCalls.targets/2 a behaviour no project module implements is no evidence: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:225
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Lonely}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:227: (test)

.
```

### FL-A: a name at several positions keeps its first

Run summary: `13 tests, 1 failure`

```text
  1) test behaviour/2 and DynamicCalls.targets/2 a name at a different position in each clause is no one parameter: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:215
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:219: (test)

....
```

### FL-B: no implementer is required

Run summary: `13 tests, 1 failure`

```text
  1) test behaviour/2 and DynamicCalls.targets/2 a behaviour no project module implements is no evidence: it fans out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:225
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == :none
     left:  {:ok, AnchorFixtures.BehaviourReceiverTest.Lonely}
     right: :none
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:227: (test)
```

