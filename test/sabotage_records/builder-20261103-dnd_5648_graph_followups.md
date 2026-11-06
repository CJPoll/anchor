# Sabotage records: builder (branch dnd-5648-graph-followups)

- **Domain:** builder
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers (DY-O)

**Run with:** the `## DND-5633: a dynamic call narrowed to a declared behaviour's implementers` section of `layering-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-O | the builder drops the callbacks (`lib/anchor/domain/graph/builder.ex`) | `builder_test.exs`, `behaviour_receiver_test.exs` | `34 tests, 5 failures` (red) | behaviour/2 and DynamicCalls.targets/2 a function of several clauses narrows too (its parameters are a case's patterns); behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only; DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out; the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task; build/2 module facts a behaviour's node carries its callbacks |

### DY-O: the builder drops the callbacks

Run summary: `34 tests, 5 failures`

```text






  1) test behaviour/2 and DynamicCalls.targets/2 a function of several clauses narrows too (its parameters are a case's patterns) (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:151
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call(graph, :two_clauses, 2)) == {:ok, mod(Port)}
     left:  :none
     right: {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:154: (test)

..



  2) test behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:143
     Assertion with == failed
     code:  assert BehaviourReceiver.behaviour(graph, call) == {:ok, mod(Port)}
     left:  :none
     right: {:ok, AnchorFixtures.BehaviourReceiverTest.Port}
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:147: (test)







  3) test DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out (Anchor.Domain.BehaviourReceiverTest)
     test/anchor/domain/behaviour_receiver_test.exs:202
     Assertion with in failed
     code:  assert {{mod(Manager), :typed, 2}, :run, 1} in narrowed
     left:  {{AnchorFixtures.BehaviourReceiverTest.Manager, :typed, 2}, :run, 1}
     right: []
     stacktrace:
       test/anchor/domain/behaviour_receiver_test.exs:205: (test)

.....



  4) test the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task (Anchor.Domain.BehaviourReceiverTest)
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



  5) test build/2 module facts a behaviour's node carries its callbacks (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:103
     Assertion with == failed
     code:  assert Graph.module(graph, module).callbacks == [run: 1]
     left:  []
     right: [run: 1]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:114: (test)

..................
```
