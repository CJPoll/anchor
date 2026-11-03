# Sabotage records: layering (branch dnd-5648-graph-followups)

- **Domain:** layering (dynamic calls, and the baselines they feed)
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Off-domain mutations filed here (the run spans them): BeamReader and Builder callbacks (beam_reader, builder), Enforcement and the Manager (baseline), GraphReport (graph_runner).

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
| DY-J | the judgement ignores the rule's narrows? (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 2 failures` (red) | judge/4 an added entry narrowing a removed one is a report NOTE, not GREW; run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |
| DY-K | the Manager does not hand the rule's narrows? over (`lib/anchor/managers/graph.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 1 failure` (red) | run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 |
| DY-L | an equal cycle narrows (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_rules_test.exs` | `27 tests, 1 failure` (red) | narrows?/2 the same set, a superset, another rule's or a disjoint cycle does not |
| DY-M | the summary drops the dynamic-call counts (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `24 tests, 1 failure` (red) | dynamic calls (DND-5633) the summary ends with the fanned-out and narrowed counts |
| DY-N | the reader drops the callbacks (`lib/anchor/adapters/beam_reader.ex`) | `beam_reader_test.exs` | `21 tests, 1 failure` (red) | decode/2 reads the callbacks a behaviour declares, sorted; none is [] |
| DY-O | the builder drops the callbacks (`lib/anchor/domain/graph/builder.ex`) | `builder_test.exs`, `behaviour_receiver_test.exs` | `34 tests, 5 failures` (red) | behaviour/2 and DynamicCalls.targets/2 a function of several clauses narrows too (its parameters are a case's patterns); behaviour/2 and DynamicCalls.targets/2 a parameter the @spec types as a behaviour's t() reaches its implementers only; DynamicCalls.tally/1 counts each dynamic call as narrowed or fanned out; the layering rule over the narrowed call a typed receiver gives no finding; an untyped one reaches the Mix task; build/2 module facts a behaviour's node carries its callbacks |
| DY-P | an entry still in the base file can be narrowed (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `39 tests, 1 failure` (red) | judge/4 a narrowing of an entry still there is GREW (it replaced nothing) |

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

### DY-J: the judgement ignores the rule's narrows?

Run summary: `39 tests, 2 failures`

```text


  1) test judge/4 an added entry narrowing a removed one is a report NOTE, not GREW (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:129
     Assertion with == failed
     code:  assert note.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/enforcement_test.exs:136: (test)

..............................



  2) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

.
```

### DY-K: the Manager does not hand the rule's narrows? over

Run summary: `39 tests, 1 failure`

```text


  1) test run/2 --base REF (GREW) an entry narrowing one removed since REF is a NOTE, by the rule's narrows?/2 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:281
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:292: (test)

........
```

### DY-L: an equal cycle narrows

Run summary: `27 tests, 1 failure`

```text


  1) test narrows?/2 the same set, a superset, another rule's or a disjoint cycle does not (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:186
     Expected false or nil, got true
     code: refute ContextAcyclic.narrows?("c|A,B", "c|A,B")
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:187: (test)

...
```

### DY-M: the summary drops the dynamic-call counts

Run summary: `24 tests, 1 failure`

```text


  1) test dynamic calls (DND-5633) the summary ends with the fanned-out and narrowed counts (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:207
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                "(0 report-only, 0 baselined); dynamic calls: 2 fanned out to every " <>
                "exporter, 1 narrowed by behaviour"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); dynamic calls: 2 fanned out to every exporter, 1 narrowed by behaviour"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:210: (test)

....
```

### DY-N: the reader drops the callbacks

Run summary: `21 tests, 1 failure`

```text


  1) test decode/2 reads the callbacks a behaviour declares, sorted; none is [] (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:52
     Assertion with == failed
     code:  assert callbacks == ["MACRO-expand": 2, check: 2, run: 1]
     left:  []
     right: ["MACRO-expand": 2, check: 2, run: 1]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:63: (test)

...
```

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

### DY-P: an entry still in the base file can be narrowed

Run summary: `39 tests, 1 failure`

```text


  1) test judge/4 a narrowing of an entry still there is GREW (it replaced nothing) (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:153
     match (=) failed
     code:  assert [%{enforcement: :enforce, message: message}] = standing
     left:  [%{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :report,
                key: "r|A,B",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "NOTE: r|A,B in .anchor/baselines/r.txt narrows r|A,B,C, the entry it replaced since main; a narrower entry is not growth. Fix: review the narrowing in this change."
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_test.exs:165: (test)

...................................
```

