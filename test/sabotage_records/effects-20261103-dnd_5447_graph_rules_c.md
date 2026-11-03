# Sabotage record — effect inference and the effects_match_bucket rule (DND-5447)

- **Domain:** effects
- **Branch:** dnd-5447-graph-rules-c
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.EffectPrimitives` (`inference_defaults/0`, `build/2`, `primitive?/2`), `Anchor.Domain.Roots`, `Anchor.Domain.Effects` (`infer/2`, `role/2`, `evidence/2`), `Anchor.Domain.GraphRules.EffectsMatchBucket`, the effect wiring in `Anchor.Managers.Graph` and the summary in `Anchor.Domain.GraphReport`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/effect_primitives_test.exs test/anchor/domain/roots_test.exs test/anchor/domain/effects_test.exs test/anchor/domain/graph_rules/effects_match_bucket_test.exs test/anchor/integration/effects_canary_test.exs test/anchor/managers/graph_effects_test.exs`, through `test-slot`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy. The QA plan's four named sabotages are EF-A (local closure), EF-B (unresolved calls pure), EF-C (judge private functions) and EF-D (drop the root override).

Traps seen:

- EF-D's first form (`MapSet.member?(roots, mfa) and false -> :framework`) and EF-F's first form (`[mfa] |> Enum.any?(...)`, leaving the `Inlines` alias unused) did not compile under warnings-as-errors; the rows are the second forms (`MapSet.member?(roots, {mfa})`, and only the last candidate name matched).
- EF-H and EF-I were measured against canary functions added for them (`Pricing.numbered/1`, `Enum.with_index(lines, 1)`; `Pricing.skus/1`, a comprehension `into: MapSet.new()`), added after the dogfood run showed both as false unresolved calls.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| EF-A | drop the local closure: only a direct primitive call is adapters (`lib/anchor/domain/effects.ex`) | 5 | a primitive reached through the module's own private helper is adapters; counts per role are reported; the footer counts the functions per role and the unresolved calls; the violating modules give one finding per bad function, the compliant none; positive control: the compliant modules alone give no finding |
| EF-B | an unresolved call is pure (`lib/anchor/domain/effects.ex`) | 3 | a call on a computed module that no project module can receive is unresolved; an unresolved dynamic call counts as an effect; an unresolved call in the chain is named, and its Fix offers a behaviour |
| EF-C | the rule judges private functions too (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | 2 | private functions are not judged; a judged bucket with no public function analysed is below the floor |
| EF-D | drop the root override in the inference (`lib/anchor/domain/effects.ex`) | 1 | a root is framework even when it reaches effects |
| EF-E | the rule judges roots (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | 1 | roots are not judged |
| EF-F | primitive?/2 matches the Core name only, not its source names (`lib/anchor/domain/effect_primitives.ex`) | 2 | primitive?/2 (DND-5447) a call Elixir inlined matches through its source name; an effect several Elixir functions compile to is named with every candidate |
| EF-G | an Ecto.Repo module is no primitive (`lib/anchor/domain/effect_primitives.ex`) | 3 | a manager with a direct effect is an issue; build/2 (DND-5447) a module declaring the Ecto.Repo behaviour is a primitive; a domain function that reaches an effect is one issue naming the chain |
| EF-H | a literal argument of a higher-order call is read as an unknown closure (`lib/anchor/domain/effects.ex`) | 3 | the violating modules give one finding per bad function, the compliant none; positive control: the compliant modules alone give no finding; the footer counts the functions per role and the unresolved calls |
| EF-I | a comprehension's collector application is unresolved (`lib/anchor/domain/effects.ex`) | 3 | the footer counts the functions per role and the unresolved calls; positive control: the compliant modules alone give no finding; the violating modules give one finding per bad function, the compliant none |
| EF-J | a judged bucket with nothing analysed is no issue (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | 1 | a judged bucket with no public function analysed is below the floor |
| EF-K | a crashed inference runs the rule anyway (`lib/anchor/managers/graph.ex`) | 2 | an inference that raises: the rule that needs it is one issue and is not run; the others run; an inference that returns no %Effects{}: the rule that needs it is one issue and is not run; the others run |
| EF-L | the summary drops the effect counts (`lib/anchor/domain/graph_report.ex`) | 2 | the rule that needs it runs on Model.effects, and the summary counts it; the footer counts the functions per role and the unresolved calls |
| EF-M | an effect is named by its Core name only, not every candidate (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | 1 | an effect several Elixir functions compile to is named with every candidate |
| EF-N | an external behaviour callback is no root (`lib/anchor/domain/roots.ex`) | 2 | an external behaviour callback is a root, its other public functions are not; roots are not judged |
| EF-O | architecture.roots selectors add no root (`lib/anchor/domain/roots.ex`) | 1 | architecture.roots selectors add roots |
| EF-P | a dynamic call no project module can receive is resolved to nothing (`lib/anchor/domain/effects.ex`) | 1 | a call on a computed module that no project module can receive is unresolved |

## EF-A — drop the local closure: only a direct primitive call is adapters

Run summary: `56 tests, 5 failures`

```

  1) test a primitive reached through the module's own private helper is adapters (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:43
     Assertion with == failed
     code:  assert Effects.role(effects, {A, :get, 1}) == :adapters
     left:  :managers
     right: :adapters
     stacktrace:
       test/anchor/domain/effects_test.exs:46: (test)

..
```

## EF-B — an unresolved call is pure

Run summary: `56 tests, 3 failures`

```

  1) test a call on a computed module that no project module can receive is unresolved (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:97
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:101: (test)

....
```

## EF-C — the rule judges private functions too

Run summary: `56 tests, 2 failures`

```

  1) test private functions are not judged (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:100
     Assertion with == failed
     code:  assert check([{A, "adapters", [get: 1], []} | modules], calls) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "M.helper/1",
                message: "M.helper/1 is in bucket managers but reaches no effect. Fix: move it to a Domain module of this context (it is pure).",
                filename: "lib/managers/M.ex",
                kind: :rule,
                key: "effects|M.helper/1|domain",
                rule_id: "effects",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:104: (test)

........
```

## EF-D — drop the root override in the inference

Run summary: `56 tests, 1 failure`

```

  1) test a root is framework even when it reaches effects (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:60
     Assertion with == failed
     code:  assert Effects.role(effects, {W, :show, 2}) == :framework
     left:  :managers
     right: :framework
     stacktrace:
       test/anchor/domain/effects_test.exs:68: (test)

.........................................
```

## EF-E — the rule judges roots

Run summary: `56 tests, 1 failure`

```

  1) test roots are not judged (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:91
     Assertion with == failed
     code:  assert check(modules, calls) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 13,
                trigger: "A.handle_call/3",
                message: "A.handle_call/3 is in bucket adapters (adapters) but infers framework: no effect is reachable. Fix: a public function's bucket matches what it causes: domain reaches no effect, adapters performs an effect (itself or through its own module), managers orchestrates effects through other modules",
                filename: "lib/adapters/A.ex",
                kind: :rule,
                key: "effects|A.handle_call/3|framework",
                rule_id: "effects",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:94: (test)

.............
```

## EF-F — primitive?/2 matches the Core name only, not its source names

Run summary: `56 tests, 2 failures`

```

  1) test primitive?/2 (DND-5447) a call Elixir inlined matches through its source name (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:108
     Expected truthy, got false
     code: assert EffectPrimitives.primitive?(primitives(), {:erlang, :unique_integer, 0})
     arguments:

         # 1
         %{extra: [], repos: MapSet.new([])}

         # 2
         {:erlang, :unique_integer, 0}

     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:110: (test)

................
```

## EF-G — an Ecto.Repo module is no primitive

Run summary: `56 tests, 3 failures`

```

  1) test a manager with a direct effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:45
     Assertion with =~ failed
     code:  assert violation.message =~ "calls an effect itself: M.run/1 -> App.Repo.insert/1"
     left:  "M.run/1 is in bucket managers but reaches no effect. Fix: move it to a Domain module of this context (it is pure)."
     right: "calls an effect itself: M.run/1 -> App.Repo.insert/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:52: (test)

....
```

## EF-H — a literal argument of a higher-order call is read as an unknown closure

Run summary: `56 tests, 3 failures`

```

  1) test the violating modules give one finding per bad function, the compliant none (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:71
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
              "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"
            ]
     left:  ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Pricing.numbered/1|managers",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     right: ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     stacktrace:
       test/anchor/integration/effects_canary_test.exs:79: (test)

.
```

## EF-I — a comprehension's collector application is unresolved

Run summary: `56 tests, 3 failures`

```

  1) test the footer counts the functions per role and the unresolved calls (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:92
     Assertion with =~ failed
     code:  assert summary =~
              "; effects: 6 functions (domain 3, managers 1, adapters 2, framework 0), " <>
                "0 unresolved dynamic calls"
     left:  "anchor.graph: 3 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 4 any; effects: 6 functions (domain 2, managers 2, adapters 2, framework 0), 1 unresolved dynamic calls"
     right: "; effects: 6 functions (domain 3, managers 1, adapters 2, framework 0), 0 unresolved dynamic calls"
     stacktrace:
       test/anchor/integration/effects_canary_test.exs:95: (test)

.
```

## EF-J — a judged bucket with nothing analysed is no issue

Run summary: `56 tests, 1 failure`

```

  1) test a judged bucket with no public function analysed is below the floor (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:134
     ** (MatchError) no match of right hand side value:

         []

     code: [issue] = check([{A, "adapters", [{:__struct__, 1}, {:load, 1, :defp}], []}], [])
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:135: (test)

.......
```

## EF-K — a crashed inference runs the rule anyway

Run summary: `56 tests, 2 failures`

```

  1) test an inference that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphEffectsTest)
     test/anchor/managers/graph_effects_test.exs:127
     Assertion with =~ failed
     code:  assert issue.message =~ "the effect inference it needs (Anchor.Domain.Effects) crashed"
     left:  "AnchorFixtures.GraphEffectsTest.Reader.read/1 is in bucket domain (domain) but reaches an effect: AnchorFixtures.GraphEffectsTest.Reader.read/1 -> File.read/1. Fix: move the effect into an adapter and have a Manager call it; AnchorFixtures.GraphEffectsTest.Reader.read/1 then returns the data the Manager needs."
     right: "the effect inference it needs (Anchor.Domain.Effects) crashed"
     stacktrace:
       test/anchor/managers/graph_effects_test.exs:135: (test)

...
```

## EF-L — the summary drops the effect counts

Run summary: `56 tests, 2 failures`

```

  1) test the rule that needs it runs on Model.effects, and the summary counts it (Anchor.Managers.GraphEffectsTest)
     test/anchor/managers/graph_effects_test.exs:99
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; effects: 2 functions (domain 1, managers 0, adapters 1, framework 0), " <>
                "0 unresolved dynamic calls"
     left:  "anchor.graph: 1 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 0 any; 2 functions (domain 1, managers 0, adapters 1, framework 0), 0 unresolved dynamic calls"
     right: "; effects: 2 functions (domain 1, managers 0, adapters 1, framework 0), 0 unresolved dynamic calls"
     stacktrace:
       test/anchor/managers/graph_effects_test.exs:114: (test)

.
```

## EF-M — an effect is named by its Core name only, not every candidate

Run summary: `56 tests, 1 failure`

```

  1) test an effect several Elixir functions compile to is named with every candidate (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:84
     Assertion with =~ failed
     code:  assert violation.message =~ "Port.demonitor/1"
     left:  "D.f/1 is in bucket domain (domain) but reaches an effect: D.f/1 -> :erlang.demonitor/1. Fix: move the effect into an adapter and have a Manager call it; D.f/1 then returns the data the Manager needs."
     right: "Port.demonitor/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:87: (test)

..
```

## EF-N — an external behaviour callback is no root

Run summary: `56 tests, 2 failures`

```

  1) test an external behaviour callback is a root, its other public functions are not (Anchor.Domain.RootsTest)
     test/anchor/domain/roots_test.exs:29
     Expected truthy, got false
     code: assert Roots.root?(roots, {Store.Server, :handle_call, 3})
     arguments:

         # 1
         MapSet.new([])

         # 2
         {Store.Server, :handle_call, 3}

     stacktrace:
       test/anchor/domain/roots_test.exs:35: (test)

....................................
```

## EF-O — architecture.roots selectors add no root

Run summary: `56 tests, 1 failure`

```

  1) test architecture.roots selectors add roots (Anchor.Domain.RootsTest)
     test/anchor/domain/roots_test.exs:49
     Expected truthy, got false
     code: assert Roots.root?(
             roots(modules, roots: [%{"pattern" => "Mix.Tasks.*"}]),
             {Mix.Tasks.Foo, :run, 1}
           )
     arguments:

         # 1
         MapSet.new([])

         # 2
         {Mix.Tasks.Foo, :run, 1}

     stacktrace:
       test/anchor/domain/roots_test.exs:52: (test)

...........................................
```

## EF-P — a dynamic call no project module can receive is resolved to nothing

Run summary: `56 tests, 1 failure`

```

  1) test a call on a computed module that no project module can receive is unresolved (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:97
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:101: (test)

...........................................
```

## Regression: a comprehension into a caller's collectable read as pure (whole-MR critic, 2026-11-03)

The whole-MR critic found that `Effects` skipped the collector of every
`for ..., into: target`, so `def dump(lines, sink), do: for(line <- lines,
into: sink, do: line)` (a `sink` that may be an `IO.stream/0`) inferred
`:domain`: an effect read as pure. The fix skips the collector only when the
target is a literal or a `Map.new`/`MapSet.new` the function builds itself
(`Effects.collectors/1`, `@pure_collections`).

Regression test: canary `Notifier.dump/2` in
`test/fixtures/graph_canary/effects/lib/effects/domain/notifier.ex`, expected
as `effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers` by
`test/anchor/integration/effects_canary_test.exs`. Before the fix (the
unfixed `collectors/1`), through `test-slot`:

```
  1) test the violating modules give one finding per bad function, the compliant none (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:71
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
              "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
              "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"
            ]
     left:  ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     right: ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     stacktrace:
       test/anchor/integration/effects_canary_test.exs:79: (test)

.
Finished in 0.2 seconds (0.2s async, 0.00s sync)
3 tests, 1 failure
```

After the fix: `15 tests, 0 failures` (`effects_canary_test.exs`,
`effects_test.exs`). `Pricing.skus/1` (`into: MapSet.new()`) stays pure, so
EF-I still holds its row; Anchor's own `mix anchor.graph` is unchanged
(0 violations, 128 baselined).

## Regression: a comprehension into a struct literal read as pure (whole-MR critic round 2, 2026-11-03)

Round 2 noted that the first fix still read every Core literal target as
pure, and `into: %IO.Stream{...}` compiles to a literal. Regression test:
canary `Notifier.echo/1`, expected as
`effects|AnchorFixtures.EffectsCanary.Notifier.echo/1|managers`. Before the
fix, through `test-slot`:

```
  1) test the violating modules give one finding per bad function, the compliant none (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:71
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
              "effects|AnchorFixtures.EffectsCanary.Notifier.echo/1|managers",
              "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
              "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
              "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"
            ]
     left:  ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     right: ["effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.echo/1|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"]
     stacktrace:
       test/anchor/integration/effects_canary_test.exs:79: (test)

..
Finished in 0.1 seconds (0.1s async, 0.00s sync)
3 tests, 1 failure
```

The fix: a literal target is pure only when it is no struct, or a `MapSet`
(`MapSet.new()` compiles to the literal `%MapSet{}`, which is how
`Pricing.skus/1` stays pure). After: `15 tests, 0 failures`.

## Review-floor fixes (2026-11-03)

The review floor found that `Roots` read behaviours through the code server
from Domain (now the `Anchor.Adapters.BehaviourSource` port, read by the
runner), that a dynamic call's candidate skipped the primitive check, and
that the two new `Failures` cases had no table rows. Suite run: `mix test
--timeout 2000 --max-cases 2 test/anchor/managers/graph_effects_test.exs
test/anchor/adapters/behaviour_reader_test.exs test/anchor/domain/effects_test.exs
test/anchor/domain/failures_graph_test.exs test/anchor/domain/roots_test.exs
test/anchor/integration/effects_canary_test.exs
test/anchor/domain/graph_rules/effects_match_bucket_test.exs`.

Traps seen: EF-Q first survived (0 failures of 58): no test checked that the
runner hands the port's callbacks to the inference. The test "the inference
gets the callbacks the behaviour port read, as :callbacks" was added; the row
below is EF-Q's run after it (59 tests).

The dynamic-candidate fix's regression test ("a dynamic call whose candidate
is a declared effect reaches that effect"), on the unfixed code:

```
  1) test a dynamic call whose candidate is a declared effect reaches that effect (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:131
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 2}) == :adapters
     left:  :domain
     right: :adapters
     stacktrace:
       test/anchor/domain/effects_test.exs:137: (test)

..........
Finished in 0.1 seconds (0.1s async, 0.00s sync)
13 tests, 1 failure
```

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| EF-Q | the runner never asks the behaviour port: the inference gets no callbacks (`lib/anchor/managers/graph.ex`) | 1 | the inference gets the callbacks the behaviour port read, as :callbacks |
| EF-R | BehaviourReader reads no callbacks (`lib/anchor/adapters/behaviour_reader.ex`) | 1 | a stdlib behaviour's callbacks, and [] for one that cannot be loaded or is no behaviour |
| EF-S | a dynamic call's candidate is only its body, never a declared effect (`lib/anchor/domain/effects.ex`) | 1 | a dynamic call whose candidate is a declared effect reaches that effect |
| EF-T | the crashed-inference issue names the flow analysis (`lib/anchor/domain/failures.ex`) | 3 | an inference that raises: the rule that needs it is one issue and is not run; the others run; an inference that returns no %Effects{}: the rule that needs it is one issue and is not run; the others run; every graph message is fail-closed, on its file, with its subject and a Fix: line |
| EF-U | the unanalysed-bucket issue drops its Fix (`lib/anchor/domain/failures.ex`) | 2 | a judged bucket with no public function analysed is below the floor; every graph message is fail-closed, on its file, with its subject and a Fix: line |
| EF-V | external_behaviours/1 asks for project behaviours too (`lib/anchor/domain/roots.ex`) | 1 | external_behaviours/1: the behaviours declared that the graph does not hold, once |

## EF-Q — the runner never asks the behaviour port: the inference gets no callbacks

Run summary: `59 tests, 1 failure`

```

  1) test the inference gets the callbacks the behaviour port read, as :callbacks (Anchor.Managers.GraphEffectsTest)
     test/anchor/managers/graph_effects_test.exs:127
     Assertion failed, no matching message after 0ms
     The following variables were pinned:
       callbacks = %{GenServer => [init: 1]}
     Showing 1 of 1 message in the mailbox
     code: assert_received {:inferred_with, callbacks: ^callbacks}
     mailbox:
       pattern: {:inferred_with, callbacks: ^callbacks}
       value:   {:inferred_with, [callbacks: %{}]}
     stacktrace:
       test/anchor/managers/graph_effects_test.exs:141: (test)

...................................
```

## EF-R — BehaviourReader reads no callbacks

Run summary: `58 tests, 1 failure`

```



  1) test a stdlib behaviour's callbacks, and [] for one that cannot be loaded or is no behaviour (Anchor.Adapters.BehaviourReaderTest)
     test/anchor/adapters/behaviour_reader_test.exs:11
     Assertion with in failed
     code:  assert {:handle_call, 3} in callbacks[GenServer]
     left:  {:handle_call, 3}
     right: []
     stacktrace:
       test/anchor/adapters/behaviour_reader_test.exs:15: (test)

.........................................................
```

## EF-S — a dynamic call's candidate is only its body, never a declared effect

Run summary: `58 tests, 1 failure`

```

  1) test a dynamic call whose candidate is a declared effect reaches that effect (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:131
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 2}) == :adapters
     left:  :domain
     right: :adapters
     stacktrace:
       test/anchor/domain/effects_test.exs:137: (test)

.............................................
```

## EF-T — the crashed-inference issue names the flow analysis

Run summary: `58 tests, 3 failures`

```

  1) test an inference that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphEffectsTest)
     test/anchor/managers/graph_effects_test.exs:131
     Assertion with =~ failed
     code:  assert issue.message =~ "the effect inference it needs (Anchor.Domain.Effects) crashed"
     left:  "rule 1 (id: \"effects\", effects_match_bucket) could not run: the analysis it needs (Anchor.Domain.Effects) crashed: RuntimeError: effects blew up (raised at anonymous fn/2 in Anchor.Managers.GraphEffectsTest.\"test an inference that raises: the rule that needs it is one issue and is not run; the others run\"/1), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the effect inference it needs (Anchor.Domain.Effects) crashed"
     stacktrace:
       test/anchor/managers/graph_effects_test.exs:140: (test)

.
```

## EF-U — the unanalysed-bucket issue drops its Fix

Run summary: `58 tests, 2 failures`

```

  1) test a judged bucket with no public function analysed is below the floor (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:147
     Assertion with =~ failed
     code:  assert issue.message =~ "Fix:"
     left:  "rule (id: \"effects\", effects_match_bucket) judged no public function of bucket adapters: the modules it selects there have none that was analysed (every one is a root, generated, or has no Core body), so the bucket is below the rule's floor. Select modules of adapters with public functions, or set infer: false on adapters in a reviewed change."
     right: "Fix:"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:152: (test)
```

## EF-V — external_behaviours/1 asks for project behaviours too

Run summary: `58 tests, 1 failure`

```

  1) test external_behaviours/1: the behaviours declared that the graph does not hold, once (Anchor.Domain.RootsTest)
     test/anchor/domain/roots_test.exs:65
     Assertion with == failed
     code:  assert Roots.external_behaviours(graph) == [GenServer, Supervisor]
     left:  [App.Port, GenServer, Supervisor]
     right: [GenServer, Supervisor]
     stacktrace:
       test/anchor/domain/roots_test.exs:76: (test)

....................................................
```
