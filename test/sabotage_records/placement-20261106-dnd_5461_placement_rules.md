# Sabotage record: the batch's placement rules (DND-5461 no_inert_hop, DND-5462 directory_placement)

- **Domain:** placement
- **Branch:** dnd-5461-placement-rules
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Placement.Forwarders` and `Anchor.Domain.GraphRules.NoInertHop` (DND-5461); `Anchor.Domain.Placement.Directories`, `.TieBreak` and `Anchor.Domain.GraphRules.DirectoryPlacement` (DND-5462); and the `Placement` render, proposal and violation clauses each adds. Each later ticket of the batch adds its own section.

One record for the batch, one section per ticket, as each ticket's QA plan asks (`placement-YYYYMMDD-<branch>.md`). Each mutation replaced one exact text (the driver refuses a text found zero or two times), set the file's mtime two seconds ahead so no beam was stale, ran the group's tests, and restored the file from its in-memory copy, again with its mtime moved ahead.

Traps seen:

- A mutation written as `<condition> and false` or `if false` does not compile: the type checker proves the clause can never match, and warnings are errors. The rows below that need a false use `Application.get_env(:anchor, :sabotage_never_set, false)`, which the checker cannot see through. Each row below compiled and ran.
- Five first forms survived (DND-5461). Three were equivalent mutants. The distinct-parameter check was dead (Elixir compiles a repeated parameter to two variables and a guard, which the guard check already refuses), so it was removed. The callers' self-call filter was dead (a forwarder never calls itself), so it was removed, and HOP-R now drops the callers instead. "Read a pattern as no variable" still failed to match the call's arguments, so HOP-K now reads an alias pattern as its variable, the mutation a real bug would be. Two were real gaps, and tests were added: a first clause that forwards, followed by a second clause (`shadowed/1`), and a remote call into the forwarder's own module (`self_remote/1`). The rows below are the second run, after those changes.

## DND-5461: no_inert_hop (Placement.Forwarders, GraphRules.NoInertHop)

Group H: `mix test --timeout 2000 --max-cases 2 test/anchor/domain/placement/forwarders_test.exs test/anchor/domain/graph_rules/no_inert_hop_test.exs test/anchor/domain/placement_render_test.exs test/anchor/integration/placement_invariant_test.exs`, through `test-slot`.

| # | Mutation | File | Result | Failing tests |
|---|---|---|---|---|
| HOP-A | drop the interface test (QA named) | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 6 failures` (red) | the selector limits the subjects; a generated module's forwarder is not judged; an inert forwarder is one violation naming both callers; its Fix is the render; legal forwarders are not reported: bucket, interface and dependency crossings; a forwarder no call names is still inert: dynamic callers only; boundary/3 an interface forwarding to a module that is not one |
| HOP-B | accept reordered arguments (QA named) | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 reordered arguments are not a forwarder |
| HOP-C | treat a dependency as in the project (QA named) | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 a target outside the project is a dependency |
| HOP-D | drop the bucket test | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 10 failures` (red) | a forwarder no call names is still inert: dynamic callers only; a generated module's forwarder is not judged; legal forwarders are not reported: bucket, interface and dependency crossings; an inert forwarder is one violation naming both callers; its Fix is the render; boundary/3 a bucket crossing; no key carries a line number: every module shifted five lines gives the same keys; report mode never fails, and still prints each finding; every placement violation's Fix equals the render of the proposal with its key; positive control: the compliant half alone gives no finding; the canary yields exactly its listed findings |
| HOP-E | drop the context test | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 a context crossing |
| HOP-F | drop the app test | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 an app crossing |
| HOP-G | drop the aggregate test | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 different aggregates, when declared |
| HOP-H | drop the callback test | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 2 failures` (red) | boundary/3 an external behaviour's callback the inference was given; boundary/3 a project behaviour's callback |
| HOP-I | an unclassified module is judged | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 an unclassified target is not judged inert |
| HOP-J | accept a guard | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 a guard is not a forwarder |
| HOP-K | read an alias pattern (%S{} = v) as its variable | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 a pattern in the head is not a forwarder |
| HOP-M | take the first of several clauses | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 a forwarding first clause with a second clause is not a forwarder |
| HOP-N | a call into the same module is a forwarder | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 a remote call into its own module is not this rule's either |
| HOP-O | a renaming let is not peeled | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | forwarder/1 a let that only renames a variable is peeled |
| HOP-P | default-argument functions are judged | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | a function with a default argument is no forwarder |
| HOP-Q | generated functions are judged | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | a generated module's forwarder is not judged |
| HOP-R | the evidence drops the static callers | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | an inert forwarder is one violation naming both callers; its Fix is the render |
| HOP-S | the render drops the callers | `lib/anchor/domain/placement.ex` | `54 tests, 2 failures` (red) | inert hop text names the callers and the target (DND-5461); an inert forwarder is one violation naming both callers; its Fix is the render |
| HOP-T | the rule ignores its selector | `lib/anchor/domain/graph_rules/no_inert_hop.ex` | `54 tests, 1 failure` (red) | the selector limits the subjects |
| HOP-U | placement.build omits the hops | `lib/anchor/domain/placement.ex` | `54 tests, 11 failures` (red) | legal forwarders are not reported: bucket, interface and dependency crossings; a function with a default argument is no forwarder; a generated module's forwarder is not judged; an inert forwarder is one violation naming both callers; its Fix is the render; a forwarder no call names is still inert: dynamic callers only; every placement violation's Fix equals the render of the proposal with its key; report mode never fails, and still prints each finding; every reason the canary emits renders one non-empty line, and each is there; the canary yields exactly its listed findings; no key carries a line number: every module shifted five lines gives the same keys; each finding carries the acceptance criteria's reason and target |
| HOP-V | an external callback map is ignored | `lib/anchor/domain/placement/forwarders.ex` | `54 tests, 1 failure` (red) | boundary/3 an external behaviour's callback the inference was given |

### HOP-A: drop the interface test (QA named)

Mutation:

```elixir
# before
      from_class.interface? and not to_class.interface? ->
# after
      from_class.interface? and not to_class.interface? and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test the selector limits the subjects (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:177
     Assertion with == failed
     code:  assert NoInertHop.check(model, rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Invoices.list/1",
                message: "AnchorFixtures.NoInertHopTest.Invoices.list/1 only forwards to AnchorFixtures.NoInertHopTest.Query.list/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Invoices.list/1: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Query.list/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/managers/Invoices.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Invoices.list/1|AnchorFixtures.NoInertHopTest.Query.list/1",
                rule_id: "hops",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "AnchorFixtures.NoInertHopTest.Invoices.show/2",
                message: "AnchorFixtures.NoInertHopTest.Invoices.show/2 only forwards to AnchorFixtures.NoInertHopTest.Query.show/2, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Invoices.show/2: its callers (AnchorFixtures.NoInertHopTest.Web.run/2) call AnchorFixtures.NoInertHopTest.Query.show/2 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/managers/Invoices.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Invoices.show/2|AnchorFixtures.NoInertHopTest.Query.show/2",
                rule_id: "hops",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:181: (test)
54 tests, 6 failures
```

### HOP-B: accept reordered arguments (QA named)

Mutation:

```elixir
# before
args -> if Enum.map(args, &Map.get(renames, &1, &1)) == params, do: literal_mfa(call)
# after
args -> if Enum.sort(Enum.map(args, &Map.get(renames, &1, &1))) == Enum.sort(params), do: literal_mfa(call)
```

First failure, verbatim:

```text
  1) test forwarder/1 reordered arguments are not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:79
     Assertion with == failed
     code:  assert forwarder(binary, {:reordered, 2}) == :no
     left:  {:forwards, {N, :g, 2}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:80: (test)
....................................
54 tests, 1 failure
```

### HOP-C: treat a dependency as in the project (QA named)

Mutation:

```elixir
# before
      not Map.has_key?(model.graph.modules, to_module) -> {:crosses, :dependency}
# after
      Application.get_env(:anchor, :sabotage_never_set, false) -> {:crosses, :dependency}
```

First failure, verbatim:

```text
  1) test boundary/3 a target outside the project is a dependency (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:157
     Assertion with == failed
     code:  assert Forwarders.boundary(model, {Totals, :get, 1}, {Req, :get, 1}) == {:crosses, :dependency}
     left:  {:crosses, :unclassified}
     right: {:crosses, :dependency}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:160: (test)
...................................
54 tests, 1 failure
```

### HOP-D: drop the bucket test

Mutation:

```elixir
# before
      from_class.bucket != to_class.bucket ->
# after
      from_class.bucket != to_class.bucket and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test a forwarder no call names is still inert: dynamic callers only (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:133
     match (=) failed
     code:  assert [violation] = NoInertHop.check(model, @rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Totals.sum/1",
                message: "AnchorFixtures.NoInertHopTest.Totals.sum/1 only forwards to AnchorFixtures.NoInertHopTest.Math.sum/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/domain/Totals.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Totals.sum/1|AnchorFixtures.NoInertHopTest.Math.sum/1",
                rule_id: "hops",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Web.list/1",
                message: "AnchorFixtures.NoInertHopTest.Web.list/1 only forwards to AnchorFixtures.NoInertHopTest.Totals.sum/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Web.list/1: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Totals.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/framework/Web.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Web.list/1|AnchorFixtures.NoInertHopTest.Totals.sum/1",
                rule_id: "hops",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "AnchorFixtures.NoInertHopTest.Web.run/2",
                message: "AnchorFixtures.NoInertHopTest.Web.run/2 only forwards to AnchorFixtures.NoInertHopTest.Invoices.show/2, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Web.run/2: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Invoices.show/2 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/framework/Web.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Web.run/2|AnchorFixtures.NoInertHopTest.Invoices.show/2",
                rule_id: "hops",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Web.show/1",
                message: "AnchorFixtures.NoInertHopTest.Web.show/1 only forwards to AnchorFixtures.NoInertHopTest.Totals.sum/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Web.show/1: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Totals.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/framework/Web.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Web.show/1|AnchorFixtures.NoInertHopTest.Totals.sum/1",
                rule_id: "hops",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:138: (test)
.
54 tests, 10 failures
```

### HOP-E: drop the context test

Mutation:

```elixir
# before
      from_class.context != to_class.context ->
# after
      from_class.context != to_class.context and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test boundary/3 a context crossing (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:153
     Assertion with == failed
     code:  assert boundary([context: "Billing"], context: "Shipping") == {:crosses, :context}
     left:  :none
     right: {:crosses, :context}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:154: (test)
.....................
54 tests, 1 failure
```

### HOP-F: drop the app test

Mutation:

```elixir
# before
      app(model, from_class) != app(model, to_class) ->
# after
      app(model, from_class) != app(model, to_class) and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test boundary/3 an app crossing (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:169
     Assertion with == failed
     code:  assert boundary([], [], adjust: adjust) == {:crosses, :app}
     left:  :none
     right: {:crosses, :app}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:171: (test)
......................
54 tests, 1 failure
```

### HOP-G: drop the aggregate test

Mutation:

```elixir
# before
      aggregates(model, from_class.module) != aggregates(model, to_class.module) ->
# after
      aggregates(model, from_class.module) != aggregates(model, to_class.module) and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test boundary/3 different aggregates, when declared (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:202
     Assertion with == failed
     code:  assert boundary([], [], adjust: adjust) == {:crosses, :aggregate}
     left:  :none
     right: {:crosses, :aggregate}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:207: (test)
.....................................
54 tests, 1 failure
```

### HOP-H: drop the callback test

Mutation:

```elixir
# before
      callback?(model, from) ->
# after
      callback?(model, from) and Application.get_env(:anchor, :sabotage_never_set, false) ->
```

First failure, verbatim:

```text
  1) test boundary/3 an external behaviour's callback the inference was given (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:180
     Assertion with == failed
     code:  assert boundary([], [], adjust: adjust, from: {Totals, :handle_call, 3}) == {:crosses, :callback}
     left:  :none
     right: {:crosses, :callback}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:186: (test)
....
54 tests, 2 failures
```

### HOP-I: an unclassified module is judged

Mutation:

```elixir
# before
      from_class == nil or to_class == nil -> {:crosses, :unclassified}
# after
      Application.get_env(:anchor, :sabotage_never_set, false) -> {:crosses, :unclassified}
```

First failure, verbatim:

```text
  1) test boundary/3 an unclassified target is not judged inert (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:164
     ** (BadMapError) expected a map, got:
         nil
     code: assert boundary([], [], adjust: adjust) == {:crosses, :unclassified}
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/placement/forwarders.ex:207: Anchor.Domain.Placement.Forwarders.classified_boundary/4
       test/anchor/domain/placement/forwarders_test.exs:166: (test)
...................
54 tests, 1 failure
```

### HOP-J: accept a guard

Mutation:

```elixir
# before
         true <- true_guard?(:cerl.clause_guard(clause)) do
# after
         true <- true_guard?(:cerl.clause_guard(clause)) or Application.get_env(:anchor, :sabotage_never_set, false) == false do
```

First failure, verbatim:

```text
  1) test forwarder/1 a guard is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:91
     Assertion with == failed
     code:  assert forwarder(binary, {:guarded, 1}) == :no
     left:  {:forwards, {N, :g, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:92: (test)
.........................
54 tests, 1 failure
```

### HOP-K: read an alias pattern (%S{} = v) as its variable

Mutation:

```elixir
# before
    if Enum.all?(nodes, &(:cerl.type(&1) == :var)),
      do: Enum.map(nodes, &:cerl.var_name/1),
# after
    if Enum.all?(nodes, &(:cerl.type(&1) in [:var, :alias])),
      do: Enum.map(nodes, &:cerl.var_name(if(:cerl.type(&1) == :alias, do: :cerl.alias_var(&1), else: &1))),
```

First failure, verbatim:

```text
  1) test forwarder/1 a pattern in the head is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:87
     Assertion with == failed
     code:  assert forwarder(binary, {:pattern, 1}) == :no
     left:  {:forwards, {N, :g, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:88: (test)
.............
54 tests, 1 failure
```

### HOP-M: take the first of several clauses

Mutation:

```elixir
# before
         [clause] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1),
# after
         [clause | _] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1),
```

First failure, verbatim:

```text
  1) test forwarder/1 a forwarding first clause with a second clause is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:113
     Assertion with == failed
     code:  assert forwarder(binary, {:shadowed, 1}) == :no
     left:  {:forwards, {N, :g, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:114: (test)
...........................
54 tests, 1 failure
```

### HOP-N: a call into the same module is a forwarder

Mutation:

```elixir
# before
      {^module, _name, _arity} -> :no
# after
      {^module, _name, _arity} = mfa -> {:forwards, mfa}
```

First failure, verbatim:

```text
  1) test forwarder/1 a remote call into its own module is not this rule's either (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:109
     Assertion with == failed
     code:  assert forwarder(binary, {:self_remote, 1}) == :no
     left:  {:forwards, {AnchorFixtures.ForwardersTest.F, :pub, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:110: (test)
.............
54 tests, 1 failure
```

### HOP-O: a renaming let is not peeled

Mutation:

```elixir
# before
      :let -> renaming_let(body, params, renames)
# after
      :let -> if Application.get_env(:anchor, :sabotage_never_set, false), do: renaming_let(body, params, renames)
```

First failure, verbatim:

```text
  1) test forwarder/1 a let that only renames a variable is peeled (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:75
     Assertion with == failed
     code:  assert forwarder(binary, {:renamed, 1}) == {:forwards, {N, :g, 1}}
     left:  :no
     right: {:forwards, {N, :g, 1}}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:76: (test)
..................................
54 tests, 1 failure
```

### HOP-P: default-argument functions are judged

Mutation:

```elixir
# before
        not defaults?(node, name, arity),
# after
        not (defaults?(node, name, arity) and Application.get_env(:anchor, :sabotage_never_set, false)),
```

First failure, verbatim:

```text
  1) test a function with a default argument is no forwarder (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:142
     Assertion with == failed
     code:  assert NoInertHop.check(with_default, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "AnchorFixtures.NoInertHopTest.Defaults.k/2",
                message: "AnchorFixtures.NoInertHopTest.Defaults.k/2 only forwards to AnchorFixtures.NoInertHopTest.Math.pair/2, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Defaults.k/2: its callers (AnchorFixtures.NoInertHopTest.Defaults.k/1) call AnchorFixtures.NoInertHopTest.Math.pair/2 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/domain/Defaults.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Defaults.k/2|AnchorFixtures.NoInertHopTest.Math.pair/2",
                rule_id: "hops",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:163: (test)
............................................
54 tests, 1 failure
```

### HOP-Q: generated functions are judged

Mutation:

```elixir
# before
        not Placement.generated_function?(function, node),
# after
        not (Placement.generated_function?(function, node) and Application.get_env(:anchor, :sabotage_never_set, false)),
```

First failure, verbatim:

```text
  1) test a generated module's forwarder is not judged (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:169
     Assertion with == failed
     code:  assert NoInertHop.check(generated, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Totals.sum/1",
                message: "AnchorFixtures.NoInertHopTest.Totals.sum/1 only forwards to AnchorFixtures.NoInertHopTest.Math.sum/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers (AnchorFixtures.NoInertHopTest.Web.list/1, AnchorFixtures.NoInertHopTest.Web.show/1) call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/domain/Totals.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Totals.sum/1|AnchorFixtures.NoInertHopTest.Math.sum/1",
                rule_id: "hops",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:173: (test)
.........................................
54 tests, 1 failure
```

### HOP-R: the evidence drops the static callers

Mutation:

```elixir
# before
    callers = static_callers(graph.calls)
# after
    callers = Map.take(static_callers(graph.calls), [])
```

First failure, verbatim:

```text
  1) test an inert forwarder is one violation naming both callers; its Fix is the render (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:89
     Assertion with == failed
     code:  assert Placement.render(proposal) ==
              "inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers " <>
                "(AnchorFixtures.NoInertHopTest.Web.list/1, AnchorFixtures.NoInertHopTest.Web.show/1) " <>
                "call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without " <>
                "crossing a bucket, context, app, aggregate, interface or callback boundary)"
     left:  "inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers (dynamic callers only) call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)"
     right: "inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers (AnchorFixtures.NoInertHopTest.Web.list/1, AnchorFixtures.NoInertHopTest.Web.show/1) call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)"
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:106: (test)
.........................................
54 tests, 1 failure
```

### HOP-S: the render drops the callers

Mutation:

```elixir
# before
"inline #{subject(p)}: its callers (#{String.replace_prefix(callers, "callers: ", "")}) " <>
# after
"inline #{subject(p)}: its callers (#{callers}) " <>
```

First failure, verbatim:

```text
  1) test inert hop text names the callers and the target (DND-5461) (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:56
     Assertion with == failed
     code:  assert Placement.render(hop.("callers: A.x/1, B.y/2")) ==
              "inline F.line/1: its callers (A.x/1, B.y/2) call N.g/1 directly (it forwards " <>
                "without crossing a bucket, context, app, aggregate, interface or callback boundary)"
     left:  "inline F.line/1: its callers (callers: A.x/1, B.y/2) call N.g/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)"
     right: "inline F.line/1: its callers (A.x/1, B.y/2) call N.g/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)"
     stacktrace:
       test/anchor/domain/placement_render_test.exs:64: (test)
.
54 tests, 2 failures
```

### HOP-T: the rule ignores its selector

Mutation:

```elixir
# before
        MapSet.member?(selected, elem(proposal.subject, 0)),
# after
        MapSet.member?(selected, elem(proposal.subject, 0)) or true,
```

First failure, verbatim:

```text
  1) test the selector limits the subjects (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:177
     Assertion with == failed
     code:  assert NoInertHop.check(model, rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "AnchorFixtures.NoInertHopTest.Totals.sum/1",
                message: "AnchorFixtures.NoInertHopTest.Totals.sum/1 only forwards to AnchorFixtures.NoInertHopTest.Math.sum/1, and the hop crosses no boundary. Fix: inline AnchorFixtures.NoInertHopTest.Totals.sum/1: its callers (AnchorFixtures.NoInertHopTest.Web.list/1, AnchorFixtures.NoInertHopTest.Web.show/1) call AnchorFixtures.NoInertHopTest.Math.sum/1 directly (it forwards without crossing a bucket, context, app, aggregate, interface or callback boundary)",
                filename: "lib/domain/Totals.ex",
                kind: :rule,
                key: "hops|function|AnchorFixtures.NoInertHopTest.Totals.sum/1|AnchorFixtures.NoInertHopTest.Math.sum/1",
                rule_id: "hops",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:181: (test)
.........................................
54 tests, 1 failure
```

### HOP-U: placement.build omits the hops

Mutation:

```elixir
# before
    Enum.sort_by(function_rules ++ unreachable ++ hops, & &1.key)
# after
    Enum.sort_by(function_rules ++ unreachable ++ Enum.take(hops, 0), & &1.key)
```

First failure, verbatim:

```text
  1) test legal forwarders are not reported: bucket, interface and dependency crossings (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:113
     Assertion with == failed
     code:  assert triggers == ["AnchorFixtures.NoInertHopTest.Totals.sum/1"]
     left:  []
     right: ["AnchorFixtures.NoInertHopTest.Totals.sum/1"]
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:121: (test)
54 tests, 11 failures
```

### HOP-V: an external callback map is ignored

Mutation:

```elixir
# before
    external = if model.effects, do: model.effects.callbacks, else: %{}
# after
    external = if model.effects, do: %{}, else: %{}
```

First failure, verbatim:

```text
  1) test boundary/3 an external behaviour's callback the inference was given (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:180
     Assertion with == failed
     code:  assert boundary([], [], adjust: adjust, from: {Totals, :handle_call, 3}) == {:crosses, :callback}
     left:  :none
     right: {:crosses, :callback}
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:186: (test)
.............................
54 tests, 1 failure
```


Off the group (the effect inference keeps the callbacks the hop's callback test reads, `lib/anchor/domain/effects.ex`):

Group W: `mix test --timeout 2000 --max-cases 2 test/anchor/domain/effects_test.exs`, through `test-slot`.

| # | Mutation | File | Result | Failing tests |
|---|---|---|---|---|
| HOP-W | the inference drops the callbacks it was given | `lib/anchor/domain/effects.ex` | `14 tests, 1 failure` (red) | the callbacks it was given are kept on the result (DND-5461) |

### HOP-W: the inference drops the callbacks it was given

Mutation:

```elixir
# before
      roots: roots,
      callbacks: callbacks
# after
      roots: roots,
      callbacks: Map.take(callbacks, [])
```

First failure, verbatim:

```text
  1) test the callbacks it was given are kept on the result (DND-5461) (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:162
     Assertion with == failed
     code:  assert Effects.infer(model, callbacks: callbacks).callbacks == callbacks
     left:  %{}
     right: %{GenServer => [init: 1]}
     stacktrace:
       test/anchor/domain/effects_test.exs:166: (test)
........
14 tests, 1 failure
```

## DND-5462: directory_placement (Placement.Directories, .TieBreak, GraphRules.DirectoryPlacement)

Group D: `mix test --timeout 2000 --max-cases 2 test/anchor/domain/placement/directories_test.exs test/anchor/domain/placement/tie_break_test.exs test/anchor/domain/graph_rules/directory_placement_test.exs test/anchor/domain/placement_test.exs test/anchor/integration/placement_invariant_test.exs test/anchor/domain/graph_report_test.exs`, through `test-slot`.

| # | Mutation | File | Result | Failing tests |
|---|---|---|---|---|
| DIR-A | drop the same-bucket-and-context guard (QA named) | `lib/anchor/domain/placement/directories.ex` | `135 tests, 20 failures` (red) | the selector limits the subjects, a directory by the modules in it; a shared module's message says it had no tie-break evidence; one violation per proposal: a module's at its defmodule, a directory's on its first file; proposals/3 the bucket root itself is never flattened; proposals/3 a dominator in another context gives nothing; proposals/3 a module already in its dominator's directory gives nothing; proposals/3 an inert directory is flattened; proposals/3 a directory with a member dominated by another is not inert; proposals/3 a directory whose companion module dominates its members is not inert; proposals/3 a generated module is not placed, and is counted; proposals/3 a shared module within one context goes to the bucket root, with no tie-break; proposals/3 a dominator in another bucket gives nothing; proposals/3 a directory whose modules no root reaches is not judged; proposals/3 a dominated module moves under its dominator's companion directory; report mode never fails, and still prints each finding; each finding carries the acceptance criteria's reason and target; every placement violation's Fix equals the render of the proposal with its key; positive control: the compliant half alone gives no finding; no key carries a line number: every module shifted five lines gives the same keys; the canary yields exactly its listed findings |
| DIR-B | take the dominator's dominator instead of the immediate one (QA named) | `lib/anchor/domain/placement/directories.ex` | `135 tests, 14 failures` (red) | one violation per proposal: a module's at its defmodule, a directory's on its first file; the selector limits the subjects, a directory by the modules in it; proposals/3 length never triggers anything: a dominated module already in place stays; proposals/3 a directory with a member dominated by another is not inert; proposals/3 an inert directory is flattened; proposals/3 a dominated module moves under its dominator's companion directory; module_dominators/1 a chain: the dominated module's immediate dominator is the module above it; proposals/3 a directory whose companion module dominates its members is not inert; no key carries a line number: every module shifted five lines gives the same keys; each finding carries the acceptance criteria's reason and target; report mode never fails, and still prints each finding; every reason the canary emits renders one non-empty line, and each is there; the canary yields exactly its listed findings; positive control: the compliant half alone gives no finding |
| DIR-C | make every directory inert (QA named) | `lib/anchor/domain/placement/directories.ex` | `135 tests, 3 failures` (red) | proposals/3 a directory whose companion module dominates its members is not inert; proposals/3 a directory with a member dominated by another is not inert; proposals/3 length never triggers anything: a dominated module already in place stays |
| DIR-D | a shared proposal drops the no-tie-break note | `lib/anchor/domain/placement/directories.ex` | `135 tests, 2 failures` (red) | a shared module's message says it had no tie-break evidence; proposals/3 a shared module within one context goes to the bucket root, with no tie-break |
| DIR-E | callers in several contexts read as the first context | `lib/anchor/domain/placement/directories.ex` | `135 tests, 2 failures` (red) | a library-context proposal names the contexts; proposals/3 a module shared across contexts goes to a library context naming them |
| DIR-F | a module already at its bucket root still moves | `lib/anchor/domain/placement/directories.ex` | `135 tests, 1 failure` (red) | proposals/3 a shared module within one context goes to the bucket root, with no tie-break |
| DIR-G | the bucket root itself can be flattened | `lib/anchor/domain/placement/directories.ex` | `135 tests, 10 failures` (red) | a shared module's message says it had no tie-break evidence; proposals/3 a shared module within one context goes to the bucket root, with no tie-break; proposals/3 the bucket root itself is never flattened; proposals/3 a module shared by callers of one other context is the context rule's question; the canary yields exactly its listed findings; every placement violation's Fix equals the render of the proposal with its key; no key carries a line number: every module shifted five lines gives the same keys; every reason the canary emits renders one non-empty line, and each is there; each finding carries the acceptance criteria's reason and target; report mode never fails, and still prints each finding |
| DIR-H | the companion module does not count as inside | `lib/anchor/domain/placement/directories.ex` | `135 tests, 2 failures` (red) | proposals/3 length never triggers anything: a dominated module already in place stays; proposals/3 a directory whose companion module dominates its members is not inert |
| DIR-I | generated modules are placed | `lib/anchor/domain/placement/directories.ex` | `135 tests, 2 failures` (red) | proposals/3 a generated module is not placed, and is counted; proposals/3 a generated dominator has no companion directory to move into |
| DIR-J | not_placed counts nothing | `lib/anchor/domain/placement/directories.ex` | `135 tests, 1 failure` (red) | proposals/3 a generated module is not placed, and is counted |
| DIR-K | a one-module directory can be flattened | `lib/anchor/domain/placement/directories.ex` | `135 tests, 9 failures` (red) | a shared module's message says it had no tie-break evidence; proposals/3 a shared module within one context goes to the bucket root, with no tie-break; the canary yields exactly its listed findings; each finding carries the acceptance criteria's reason and target; every placement violation's Fix equals the render of the proposal with its key; positive control: the compliant half alone gives no finding; report mode never fails, and still prints each finding; no key carries a line number: every module shifted five lines gives the same keys; every reason the canary emits renders one non-empty line, and each is there |
| DIR-L | a directory no root reaches is judged | `lib/anchor/domain/placement/directories.ex` | `135 tests, 1 failure` (red) | proposals/3 a directory whose modules no root reaches is not judged |
| DIR-M | no roots passes silently | `lib/anchor/domain/graph_rules/directory_placement.ex` | `135 tests, 1 failure` (red) | no roots: one fail-closed issue, and no finding |
| DIR-N | the rule ignores its selector | `lib/anchor/domain/graph_rules/directory_placement.ex` | `135 tests, 1 failure` (red) | the selector limits the subjects, a directory by the modules in it |
| DIR-O | a directory's violation goes on its last file | `lib/anchor/domain/placement.ex` | `135 tests, 2 failures` (red) | one violation per proposal: a module's at its defmodule, a directory's on its first file; to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462) |
| DIR-P | the shared render drops its notes | `lib/anchor/domain/placement.ex` | `135 tests, 2 failures` (red) | a shared module's message says it had no tie-break evidence; render/1 directory texts (DND-5462) |
| DIR-Q | placement.build omits the directory proposals | `lib/anchor/domain/placement.ex` | `135 tests, 10 failures` (red) | a library-context proposal names the contexts; one violation per proposal: a module's at its defmodule, a directory's on its first file; the selector limits the subjects, a directory by the modules in it; a shared module's message says it had no tie-break evidence; each finding carries the acceptance criteria's reason and target; report mode never fails, and still prints each finding; the canary yields exactly its listed findings; every placement violation's Fix equals the render of the proposal with its key; no key carries a line number: every module shifted five lines gives the same keys; every reason the canary emits renders one non-empty line, and each is there |
| DIR-R | the summary drops the not-placed count | `lib/anchor/domain/graph_report.ex` | `135 tests, 1 failure` (red) | placement precision (DND-5448) the placement precision: counts, and each reachability answer |
| DIR-S | a generated dominator still gives a companion directory | `lib/anchor/domain/placement/directories.ex` | `135 tests, 1 failure` (red) | proposals/3 a generated dominator has no companion directory to move into |

### DIR-A: drop the same-bucket-and-context guard (QA named)

Mutation:

```elixir
# before
         true <- bucket == class.bucket and context == class.context do
# after
         true <- (bucket == class.bucket and context == class.context) or Application.get_env(:anchor, :sabotage_never_set, true) do
```

First failure, verbatim:

```text
  1) test the selector limits the subjects, a directory by the modules in it (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:96
     match (=) failed
     code:  assert [%{trigger: "lib/b/domain/util"}] =
              DirectoryPlacement.check(model, %{@rule | paths: ["lib/b/domain/util/u2.ex"]})
     left:  [%{trigger: "lib/b/domain/util"}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "U2",
                message: "U2 sits in lib/b/domain/util, but only W reaches it. Fix: move U2 from lib/b/domain/util to lib/b/web/w (only W reaches it; W is the directory's public module)",
                filename: "lib/b/domain/util/u2.ex",
                kind: :rule,
                key: "dirs|directory|U2|lib/b/web/w",
                rule_id: "dirs",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "lib/b/domain/util",
                message: "lib/b/domain/util encapsulates nothing: no module in it is reached only through it. Fix: flatten lib/b/domain/util into lib/b/domain (no module in it is reached only through it)",
                filename: "lib/b/domain/util/u1.ex",
                kind: :rule,
                key: "dirs|directory|lib/b/domain/util|lib/b/domain",
                rule_id: "dirs",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:99: (test)
135 tests, 20 failures
```

### DIR-B: take the dominator's dominator instead of the immediate one (QA named)

Mutation:

```elixir
# before
      else: GraphAlgorithms.dominators(Digraph.new(nodes, edges), root_modules).idom
# after
      else: GraphAlgorithms.dominators(Digraph.new(nodes, edges), root_modules).idom |> then(fn idom -> Map.new(idom, fn {k, v} -> {k, Map.get(idom, v, v)} end) end)
```

First failure, verbatim:

```text
  1) test one violation per proposal: a module's at its defmodule, a directory's on its first file (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:33
     Assertion with == failed
     code:  assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
              {"Rnd", "lib/b/domain/rounding.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
            ]
     left:  [
              {"U1", "lib/b/domain/util/u1.ex", 3},
              {"U2", "lib/b/domain/util/u2.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
            ]
     right: [
              {"Rnd", "lib/b/domain/rounding.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:38: (test)
135 tests, 14 failures
```

### DIR-C: make every directory inert (QA named)

Mutation:

```elixir
# before
         false <- Enum.any?(modules, &dominated_inside?(model, idom[&1], dir)) do
# after
         false <- Enum.any?(modules, &dominated_inside?(model, idom[&1], dir)) and Application.get_env(:anchor, :sabotage_never_set, false) do
```

First failure, verbatim:

```text
  1) test proposals/3 a directory whose companion module dominates its members is not inert (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:189
     Assertion with == failed
     code:  assert proposals(modules, [{W, Util}, {Util, U1}, {Util, U2}], files) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: "lib/b/domain/util",
                current: "lib/b/domain/util",
                proposed: "lib/b/domain",
                rule: :directory_placement,
                reason: :inert_directory,
                evidence: ["holds U1, U2"],
                key: "directory_placement|directory|lib/b/domain/util|lib/b/domain"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:204: (test)
..........
135 tests, 3 failures
```

### DIR-D: a shared proposal drops the no-tie-break note

Mutation:

```elixir
# before
proposal(module, current, dir, :shared_module, [reached, "no tie-break evidence"])
# after
proposal(module, current, dir, :shared_module, [reached])
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     Assertion with == failed
     code:  assert violation.message ==
              "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from " <>
                "2 unrelated callers: shared, not a private helper); no tie-break evidence"
     left:  "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper)"
     right: "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper); no tie-break evidence"
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:81: (test)
.........
135 tests, 2 failures
```

### DIR-E: callers in several contexts read as the first context

Mutation:

```elixir
# before
      [context] when context == class.context ->
# after
      [context | _] when context == class.context ->
```

First failure, verbatim:

```text
  1) test a library-context proposal names the contexts (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:86
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(directory_model(modules, [{W1, K}, {W2, K}], files), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:90: (test)
.................
135 tests, 2 failures
```

### DIR-F: a module already at its bucket root still moves

Mutation:

```elixir
# before
          {:none, ^current} ->
            nil
# after
          {:none, ^current} ->
            proposal(module, current, current, :shared_module, [reached, "no tie-break evidence"])
```

First failure, verbatim:

```text
  1) test proposals/3 a shared module within one context goes to the bucket root, with no tie-break (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:102
     Assertion with == failed
     code:  assert proposals(modules, [{W1, Inv}, {W1, K}, {W2, K}], %{files | K => "lib/b/domain/k.ex"}) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: K,
                current: "lib/b/domain",
                proposed: "lib/b/domain",
                rule: :directory_placement,
                reason: :shared_module,
                evidence: ["reached from 2 unrelated callers: W1, W2",
                 "no tie-break evidence"],
                key: "directory_placement|directory|K|lib/b/domain"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:128: (test)
...........................................................................................................
135 tests, 1 failure
```

### DIR-G: the bucket root itself can be flattened

Mutation:

```elixir
# before
         true <- String.starts_with?(dir, root <> "/"),
# after
         true <- String.starts_with?(dir, root),
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(model, @rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "K",
                message: "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper); no tie-break evidence",
                filename: "lib/b/domain/x/k.ex",
                kind: :rule,
                key: "dirs|directory|K|lib/b/domain",
                rule_id: "dirs",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "lib/b/web",
                message: "lib/b/web encapsulates nothing: no module in it is reached only through it. Fix: flatten lib/b/web into lib/b (no module in it is reached only through it)",
                filename: "lib/b/web/w1.ex",
                kind: :rule,
                key: "dirs|directory|lib/b/web|lib/b",
                rule_id: "dirs",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:79: (test)
.......
135 tests, 10 failures
```

### DIR-H: the companion module does not count as inside

Mutation:

```elixir
# before
        Path.dirname(file) == dir or file == dir <> ".ex"
# after
        Path.dirname(file) == dir
```

First failure, verbatim:

```text
  1) test proposals/3 length never triggers anything: a dominated module already in place stays (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:246
     Assertion with == failed
     code:  assert proposals(@chain ++ many, [{Inv, Rnd} | calls], Map.merge(@chain_files, files)) ==
              proposals(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files)
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: Rnd,
                current: "lib/b/domain",
                proposed: "lib/b/domain/invoice",
                rule: :directory_placement,
                reason: :dominator_subtree,
                evidence: ["dominated by Inv"],
                key: "directory_placement|directory|Rnd|lib/b/domain/invoice"
              },
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: "lib/b/domain/invoice",
                current: "lib/b/domain/invoice",
                proposed: "lib/b/domain",
                rule: :directory_placement,
                reason: :inert_directory,
                evidence: ["holds Inv.M1, Inv.M10, Inv.M11, Inv.M12, Inv.M13, Inv.M14, Inv.M15, Inv.M16, Inv.M17, Inv.M18, Inv.M19, Inv.M2, Inv.M20, Inv.M21, Inv.M22, Inv.M23, Inv.M24, Inv.M25, Inv.M26, Inv.M27, Inv.M28, Inv.M29, Inv.M3, Inv.M30, Inv.M31, Inv.M32, Inv.M33, Inv.M34, Inv.M35, Inv.M36, Inv.M37, Inv.M38, Inv.M39, Inv.M4, Inv.M40, Inv.M5, Inv.M6, Inv.M7, Inv.M8, Inv.M9"],
                key: "directory_placement|directory|lib/b/domain/invoice|lib/b/domain"
              }
            ]
     right: [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: Rnd,
                current: "lib/b/domain",
                proposed: "lib/b/domain/invoice",
                rule: :directory_placement,
                reason: :dominator_subtree,
                evidence: ["dominated by Inv"],
                key: "directory_placement|directory|Rnd|lib/b/domain/invoice"
              }
            ]
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:251: (test)
..........
135 tests, 2 failures
```

### DIR-I: generated modules are placed

Mutation:

```elixir
# before
    match?(%ModuleNode{generated?: false}, Map.get(graph.modules, module)) and
# after
    match?(%ModuleNode{}, Map.get(graph.modules, module)) and
```

First failure, verbatim:

```text
  1) test proposals/3 a generated module is not placed, and is counted (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:236
     Assertion with == failed
     code:  assert proposals(@chain, calls, @chain_files, [Rnd]) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: Rnd,
                current: "lib/b/domain",
                proposed: "lib/b/domain/invoice",
                rule: :directory_placement,
                reason: :dominator_subtree,
                evidence: ["dominated by Inv"],
                key: "directory_placement|directory|Rnd|lib/b/domain/invoice"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:238: (test)
................
135 tests, 2 failures
```

### DIR-J: not_placed counts nothing

Mutation:

```elixir
# before
    do: Enum.count(Map.keys(graph.modules), &(not placed?(model, &1)))
# after
    do: Enum.count(Map.keys(graph.modules), &(not placed?(model, &1) and Application.get_env(:anchor, :sabotage_never_set, false)))
```

First failure, verbatim:

```text
  1) test proposals/3 a generated module is not placed, and is counted (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:236
     Assertion with == failed
     code:  assert Directories.not_placed(model) == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:241: (test)
............................................................................................................................
135 tests, 1 failure
```

### DIR-K: a one-module directory can be flattened

Mutation:

```elixir
# before
    with [_, _ | _] <- modules,
# after
    with [_ | _] <- modules,
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(model, @rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "K",
                message: "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper); no tie-break evidence",
                filename: "lib/b/domain/x/k.ex",
                kind: :rule,
                key: "dirs|directory|K|lib/b/domain",
                rule_id: "dirs",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "lib/b/domain/x",
                message: "lib/b/domain/x encapsulates nothing: no module in it is reached only through it. Fix: flatten lib/b/domain/x into lib/b/domain (no module in it is reached only through it)",
                filename: "lib/b/domain/x/k.ex",
                kind: :rule,
                key: "dirs|directory|lib/b/domain/x|lib/b/domain",
                rule_id: "dirs",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:79: (test)
.........
135 tests, 9 failures
```

### DIR-L: a directory no root reaches is judged

Mutation:

```elixir
# before
         true <- Enum.all?(modules, &Map.has_key?(idom, &1)),
# after
         true <- Enum.all?(modules, &Map.has_key?(idom, &1)) or Application.get_env(:anchor, :sabotage_never_set, true),
```

First failure, verbatim:

```text
  1) test proposals/3 a directory whose modules no root reaches is not judged (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:207
     Assertion with == failed
     code:  assert proposals(modules, [{W, Inv}], files) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: "lib/b/domain/util",
                current: "lib/b/domain/util",
                proposed: "lib/b/domain",
                rule: :directory_placement,
                reason: :inert_directory,
                evidence: ["holds U1, U2"],
                key: "directory_placement|directory|lib/b/domain/util|lib/b/domain"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:222: (test)
.......................................................................................................................
135 tests, 1 failure
```

### DIR-M: no roots passes silently

Mutation:

```elixir
# before
    if placement.precision.reachability == :no_roots,
# after
    if placement.precision.reachability == :no_roots and Application.get_env(:anchor, :sabotage_never_set, false),
```

First failure, verbatim:

```text
  1) test no roots: one fail-closed issue, and no finding (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:105
     match (=) failed
     code:  assert [issue] = DirectoryPlacement.check(model, @rule)
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:109: (test)
....................................................................................................................................
135 tests, 1 failure
```

### DIR-N: the rule ignores its selector

Mutation:

```elixir
# before
        Enum.any?(Placement.subject_modules(proposal, model), &MapSet.member?(selected, &1)),
# after
        Enum.any?(Placement.subject_modules(proposal, model), &MapSet.member?(selected, &1)) or true,
```

First failure, verbatim:

```text
  1) test the selector limits the subjects, a directory by the modules in it (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:96
     match (=) failed
     code:  assert [%{trigger: "lib/b/domain/util"}] =
              DirectoryPlacement.check(model, %{@rule | paths: ["lib/b/domain/util/u2.ex"]})
     left:  [%{trigger: "lib/b/domain/util"}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "Rnd",
                message: "Rnd sits in lib/b/domain, but only Inv reaches it. Fix: move Rnd from lib/b/domain to lib/b/domain/invoice (only Inv reaches it; Inv is the directory's public module)",
                filename: "lib/b/domain/rounding.ex",
                kind: :rule,
                key: "dirs|directory|Rnd|lib/b/domain/invoice",
                rule_id: "dirs",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "lib/b/domain/util",
                message: "lib/b/domain/util encapsulates nothing: no module in it is reached only through it. Fix: flatten lib/b/domain/util into lib/b/domain (no module in it is reached only through it)",
                filename: "lib/b/domain/util/u1.ex",
                kind: :rule,
                key: "dirs|directory|lib/b/domain/util|lib/b/domain",
                rule_id: "dirs",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:99: (test)
................................................................................................................................
135 tests, 1 failure
```

### DIR-O: a directory's violation goes on its last file

Mutation:

```elixir
# before
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
# after
    |> Enum.sort(:desc)
    |> Enum.map(&elem(&1, 1))
```

First failure, verbatim:

```text
  1) test one violation per proposal: a module's at its defmodule, a directory's on its first file (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:33
     Assertion with == failed
     code:  assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
              {"Rnd", "lib/b/domain/rounding.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
            ]
     left:  [
              {"Rnd", "lib/b/domain/rounding.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u2.ex", 3}
            ]
     right: [
              {"Rnd", "lib/b/domain/rounding.ex", 3},
              {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:38: (test)
..................................................................................
135 tests, 2 failures
```

### DIR-P: the shared render drops its notes

Mutation:

```elixir
# before
      "not a private helper)" <> Enum.map_join(notes, &"; #{&1}")
# after
      "not a private helper)" <> Enum.map_join(Enum.take(notes, 0), &"; #{&1}")
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     Assertion with == failed
     code:  assert violation.message ==
              "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from " <>
                "2 unrelated callers: shared, not a private helper); no tie-break evidence"
     left:  "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper)"
     right: "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from 2 unrelated callers: shared, not a private helper); no tie-break evidence"
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:81: (test)
.........................................................................................................
135 tests, 2 failures
```

### DIR-Q: placement.build omits the directory proposals

Mutation:

```elixir
# before
hops ++ directories, & &1.key)
# after
hops ++ Enum.take(directories, 0), & &1.key)
```

First failure, verbatim:

```text
  1) test a library-context proposal names the contexts (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:86
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(directory_model(modules, [{W1, K}, {W2, K}], files), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:90: (test)
.
135 tests, 10 failures
```

### DIR-R: the summary drops the not-placed count

Mutation:

```elixir
# before
", #{placement.modules_not_placed} modules not placed (no source)"
# after
", modules not placed (no source)"
```

First failure, verbatim:

```text
  1) test placement precision (DND-5448) the placement precision: counts, and each reachability answer (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:234
     Assertion with =~ failed
     code:  assert summary.(placement) =~
              "; placement: 9 functions placed, 2 with no @spec (ownership unknown), " <>
                "1 ambiguous owner, 3 with no clause to slice, 4 calls of a computed name, " <>
                "reachability precise, 5 modules not placed (no source)"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); placement: 9 functions placed, 2 with no @spec (ownership unknown), 1 ambiguous owner, 3 with no clause to slice, 4 calls of a computed name, reachability precise, modules not placed (no source)"
     right: "; placement: 9 functions placed, 2 with no @spec (ownership unknown), 1 ambiguous owner, 3 with no clause to slice, 4 calls of a computed name, reachability precise, 5 modules not placed (no source)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:250: (test)
...............................................................................................
135 tests, 1 failure
```

### DIR-S: a generated dominator still gives a companion directory

Mutation:

```elixir
# before
    with true <- placed?(model, dominator),
# after
    with true <- placed?(model, dominator) or Application.get_env(:anchor, :sabotage_never_set, true),
```

First failure, verbatim:

```text
  1) test proposals/3 a generated dominator has no companion directory to move into (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:225
     Assertion with == failed
     code:  assert proposals(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files, [Inv]) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :directory,
                subject: Rnd,
                current: "lib/b/domain",
                proposed: "lib/b/domain/invoice",
                rule: :directory_placement,
                reason: :dominator_subtree,
                evidence: ["dominated by Inv"],
                key: "directory_placement|directory|Rnd|lib/b/domain/invoice"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:226: (test)
..........................................................................................................................
135 tests, 1 failure
```

DIR-F first form put `Application.get_env/3` in a guard, which does not compile; the row is the second form, which proposes the module's own directory.

## Sweep after the DND-5462 critic: every test the generated runs list as lacking a red

The DND-5462 critic found new tests the generated runs list under *Tests still lacking a red* that no hand row above had failed. This sweep breaks the code each one guards. SWP-Q to SWP-T re-see the DND-5448 `render/1` tests, which moved into `placement_test.exs` (the mirror file the generated run selects) from `placement_render_test.exs`; their first reds are in `placement-20261106-dnd_5448_placement_core.md`. The DND-5461 test "a repeated parameter is not a forwarder" was deleted, not swept: no edit to `forwarder/1` makes it accept a repeated parameter without also accepting a guard (HOP-J), because Elixir compiles `f(a, a)` to two variables and an `=:=` guard. SWP-G and SWP-K first forms did not compile (the type checker saw `boundary/3` never answer `:none`, and `common_prefix/2` go unused); the rows are the second forms.


Each row ran its own files through `test-slot`, `mix test --timeout 2000 --max-cases 2`: SWP-A to SWP-I `test/anchor/domain/placement/forwarders_test.exs test/anchor/domain/graph_rules/no_inert_hop_test.exs`; SWP-J to SWP-P `test/anchor/domain/placement/directories_test.exs test/anchor/domain/placement/tie_break_test.exs test/anchor/domain/graph_rules/directory_placement_test.exs`; SWP-Q to SWP-T `test/anchor/domain/placement_test.exs`.

| # | Mutation | File | Result | Failing tests |
|---|---|---|---|---|
| SWP-A | a forwarder reads as none (the positive forwarder tests) | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 9 failures` (red) | a forwarder no call names is still inert: dynamic callers only; legal forwarders are not reported: bucket, interface and dependency crossings; a generated module's forwarder is not judged; an inert forwarder is one violation naming both callers; its Fix is the render; a function with a default argument is no forwarder; forwarder/1 a zero-arity forwarder; forwarder/1 defdelegate reads the same; forwarder/1 a plain forwarder; forwarder/1 a let that only renames a variable is peeled |
| SWP-B | literal arguments are dropped before the comparison | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 1 failure` (red) | forwarder/1 an extra literal argument is not a forwarder |
| SWP-C | the last clause is read | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 2 failures` (red) | forwarder/1 two clauses are not a forwarder; forwarder/1 a forwarding first clause with a second clause is not a forwarder |
| SWP-D | a local apply reads as a forwarder | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 1 failure` (red) | forwarder/1 a call into the same module is not this rule's (no_forwarding_function) |
| SWP-E | any let is peeled as a rename of the first parameter | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 1 failure` (red) | forwarder/1 a transforming pipe is not a forwarder |
| SWP-F | a function with no Core forwards | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 1 failure` (red) | forwarder/1 a function with no Core is not a forwarder |
| SWP-G | a hop that crosses nothing reads as a bucket crossing | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 10 failures` (red) | an inert forwarder is one violation naming both callers; its Fix is the render; a generated module's forwarder is not judged; a function with a default argument is no forwarder; a forwarder no call names is still inert: dynamic callers only; legal forwarders are not reported: bucket, interface and dependency crossings; boundary/3 an external behaviour's callback the inference was given; boundary/3 no aggregates declared: the aggregate test is not judged; boundary/3 different aggregates, when declared; boundary/3 an interface forwarding to a module that is not one; boundary/3 same bucket, context and app, no interface and no callback: none |
| SWP-H | a module in no aggregate counts as its own | `lib/anchor/domain/placement/forwarders.ex` | `32 tests, 11 failures` (red) | an inert forwarder is one violation naming both callers; its Fix is the render; legal forwarders are not reported: bucket, interface and dependency crossings; a forwarder no call names is still inert: dynamic callers only; a generated module's forwarder is not judged; a function with a default argument is no forwarder; boundary/3 an interface forwarding to a module that is not one; boundary/3 an external behaviour's callback the inference was given; boundary/3 no aggregates declared: the aggregate test is not judged; boundary/3 a project behaviour's callback; boundary/3 different aggregates, when declared; boundary/3 same bucket, context and app, no interface and no callback: none |
| SWP-I | no_inert_hop's shape text changes | `lib/anchor/domain/graph_rules/no_inert_hop.ex` | `32 tests, 1 failure` (red) | shape/1, needs/0 and narrows?/2 |
| SWP-J | only the first root module seeds the dominators | `lib/anchor/domain/placement/directories.ex` | `28 tests, 5 failures` (red) | a shared module's message says it had no tie-break evidence; a library-context proposal names the contexts; proposals/3 a module shared across contexts goes to a library context naming them; module_dominators/1 two root modules calling one module make the virtual root its dominator; proposals/3 a shared module within one context goes to the bucket root, with no tie-break |
| SWP-K | the bucket root is the first module's directory | `lib/anchor/domain/placement/directories.ex` | `28 tests, 1 failure` (red) | bucket_root/3 the deepest directory holding every module of the bucket in the context |
| SWP-L | the bucket root is one level up | `lib/anchor/domain/placement/directories.ex` | `28 tests, 6 failures` (red) | a shared module's message says it had no tie-break evidence; proposals/3 a module shared by callers of one other context is the context rule's question; proposals/3 the bucket root itself is never flattened; proposals/3 a shared module within one context goes to the bucket root, with no tie-break; bucket_root/3 one module: its own directory; bucket_root/3 the deepest directory holding every module of the bucket in the context |
| SWP-M | no module gives an empty bucket root, not nil | `lib/anchor/domain/placement/directories.ex` | `28 tests, 1 failure` (red) | bucket_root/3 no module of that bucket in that context |
| SWP-N | the tie-break keeps the last candidate | `lib/anchor/domain/placement/tie_break.ex` | `28 tests, 3 failures` (red) | no evidence keeps the bucket root, and says it had none; a shared module's message says it had no tie-break evidence; proposals/3 a shared module within one context goes to the bucket root, with no tie-break |
| SWP-O | the tie-break ignores evidence it cannot read | `lib/anchor/domain/placement/tie_break.ex` | `28 tests, 1 failure` (red) | evidence it cannot read yet is refused, never ignored |
| SWP-P | directory_placement's shape text changes | `lib/anchor/domain/graph_rules/directory_placement.ex` | `28 tests, 1 failure` (red) | shape/1, needs/0 and narrows?/2 |
| SWP-Q | the output-owner text changes | `lib/anchor/domain/placement.ex` | `58 tests, 1 failure` (red) | render/1 output owner text |
| SWP-R | the dominated text changes | `lib/anchor/domain/placement.ex` | `58 tests, 1 failure` (red) | render/1 dominated text |
| SWP-S | the bucket text drops the context | `lib/anchor/domain/placement.ex` | `58 tests, 1 failure` (red) | render/1 bucket text names the context and module when known, and the evidence |
| SWP-T | an unknown reason gets a default text | `lib/anchor/domain/placement.ex` | `58 tests, 1 failure` (red) | render/1 an unknown reason raises: there is no default text |

### SWP-A: a forwarder reads as none (the positive forwarder tests)

Mutation:

```elixir
# before
      {_other, _name, _arity} = mfa -> {:forwards, mfa}
# after
      {_other, _name, _arity} -> :no
```

First failure, verbatim:

```text
  1) test a forwarder no call names is still inert: dynamic callers only (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:133
     match (=) failed
     code:  assert [violation] = NoInertHop.check(model, @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:138: (test)
32 tests, 9 failures
```

### SWP-B: literal arguments are dropped before the comparison

Mutation:

```elixir
# before
    case vars(:cerl.call_args(call)) do
# after
    case vars(Enum.filter(:cerl.call_args(call), &(:cerl.type(&1) == :var))) do
```

First failure, verbatim:

```text
  1) test forwarder/1 an extra literal argument is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:82
     Assertion with == failed
     code:  assert forwarder(binary, {:literal, 1}) == :no
     left:  {:forwards, {N, :g, 2}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:83: (test)
....
32 tests, 1 failure
```

### SWP-C: the last clause is read

Mutation:

```elixir
# before
         [clause] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1),
# after
         clause when clause != nil <- List.last(Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1)),
```

First failure, verbatim:

```text
  1) test forwarder/1 two clauses are not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:94
     Assertion with == failed
     code:  assert forwarder(binary, {:two, 1}) == :no
     left:  {:forwards, {N, :g, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:95: (test)
......
32 tests, 2 failures
```

### SWP-D: a local apply reads as a forwarder

Mutation:

```elixir
# before
      :call -> forwarding_call(body, params, renames)
# after
      :call -> forwarding_call(body, params, renames)
      :apply -> {:sabotaged, :f, 1}
```

First failure, verbatim:

```text
  1) test forwarder/1 a call into the same module is not this rule's (no_forwarding_function) (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:98
     Assertion with == failed
     code:  assert forwarder(binary, {:local, 1}) == :no
     left:  {:forwards, {:sabotaged, :f, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:101: (test)
......
32 tests, 1 failure
```

### SWP-E: any let is peeled as a rename of the first parameter

Mutation:

```elixir
# before
         [name] <- vars(case_values(:cerl.let_arg(body))) do
# after
         [name] <- vars(case_values(:cerl.let_arg(body))) || [hd(params)] do
```

First failure, verbatim:

```text
  1) test forwarder/1 a transforming pipe is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:112
     Assertion with == failed
     code:  assert forwarder(binary, {:piped, 1}) == :no
     left:  {:forwards, {N, :g, 1}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:113: (test)
..................
32 tests, 1 failure
```

### SWP-F: a function with no Core forwards

Mutation:

```elixir
# before
  def forwarder(%FunctionNode{core: nil}), do: :no
# after
  def forwarder(%FunctionNode{core: nil}), do: {:forwards, {nil, nil, 0}}
```

First failure, verbatim:

```text
  1) test forwarder/1 a function with no Core is not a forwarder (Anchor.Domain.Placement.ForwardersTest)
     test/anchor/domain/placement/forwarders_test.exs:116
     Assertion with == failed
     code:  assert Forwarders.forwarder(node) == :no
     left:  {:forwards, {nil, nil, 0}}
     right: :no
     stacktrace:
       test/anchor/domain/placement/forwarders_test.exs:118: (test)
.....
32 tests, 1 failure
```

### SWP-G: a hop that crosses nothing reads as a bucket crossing

Mutation:

```elixir
# before
      true ->
        :none
# after
      true ->
        Application.get_env(:anchor, :sabotage_never_set, {:crosses, :bucket})
```

First failure, verbatim:

```text
  1) test an inert forwarder is one violation naming both callers; its Fix is the render (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:89
     match (=) failed
     code:  assert [violation] = NoInertHop.check(model, @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:94: (test)
32 tests, 10 failures
```

### SWP-H: a module in no aggregate counts as its own

Mutation:

```elixir
# before
    Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [])))
# after
    Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [module])))
```

First failure, verbatim:

```text
  1) test an inert forwarder is one violation naming both callers; its Fix is the render (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:89
     match (=) failed
     code:  assert [violation] = NoInertHop.check(model, @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:94: (test)
..
32 tests, 11 failures
```

### SWP-I: no_inert_hop's shape text changes

Mutation:

```elixir
# before
    "a function that only forwards to another module crosses
# after
    "a function that forwards to another module crosses
```

First failure, verbatim:

```text
  1) test shape/1, needs/0 and narrows?/2 (Anchor.Domain.GraphRules.NoInertHopTest)
     test/anchor/domain/graph_rules/no_inert_hop_test.exs:184
     Assertion with =~ failed
     code:  assert NoInertHop.shape(@rule) =~ "only forwards to another module"
     left:  "a function that forwards to another module crosses a bucket, context, app, aggregate, interface or callback boundary; otherwise its callers call the target"
     right: "only forwards to another module"
     stacktrace:
       test/anchor/domain/graph_rules/no_inert_hop_test.exs:185: (test)
............................
32 tests, 1 failure
```

### SWP-J: only the first root module seeds the dominators

Mutation:

```elixir
# before
      else: GraphAlgorithms.dominators(Digraph.new(nodes, edges), root_modules).idom
# after
      else: GraphAlgorithms.dominators(Digraph.new(nodes, edges), Enum.take(root_modules, 1)).idom
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(model, @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:79: (test)
..
28 tests, 5 failures
```

### SWP-K: the bucket root is the first module's directory

Mutation:

```elixir
# before
      [first | rest] -> rest |> Enum.reduce(first, &common_prefix/2) |> Path.join()
# after
      [first | rest] -> rest |> Enum.reduce(first, fn parts, acc -> if Application.get_env(:anchor, :sabotage_never_set, false), do: common_prefix(parts, acc), else: acc end) |> Path.join()
```

First failure, verbatim:

```text
  1) test bucket_root/3 the deepest directory holding every module of the bucket in the context (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:48
     Assertion with == failed
     code:  assert Directories.bucket_root(directory_model(modules, [], deeper), "domain", "b") == "lib/b/domain"
     left:  "lib/b/domain/y"
     right: "lib/b/domain"
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:58: (test)
..........
28 tests, 1 failure
```

### SWP-L: the bucket root is one level up

Mutation:

```elixir
# before
      [first | rest] -> rest |> Enum.reduce(first, &common_prefix/2) |> Path.join()
# after
      [first | rest] -> rest |> Enum.reduce(first, &common_prefix/2) |> Path.join() |> Path.dirname()
```

First failure, verbatim:

```text
  1) test a shared module's message says it had no tie-break evidence (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:62
     match (=) failed
     code:  assert [violation] = DirectoryPlacement.check(model, @rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "K",
                message: "K is shared: no one module reaches it. Fix: move K to lib/b (reached from 2 unrelated callers: shared, not a private helper); no tie-break evidence",
                filename: "lib/b/domain/x/k.ex",
                kind: :rule,
                key: "dirs|directory|K|lib/b",
                rule_id: "dirs",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "lib/b/web",
                message: "lib/b/web encapsulates nothing: no module in it is reached only through it. Fix: flatten lib/b/web into lib/b (no module in it is reached only through it)",
                filename: "lib/b/web/w1.ex",
                kind: :rule,
                key: "dirs|directory|lib/b/web|lib/b",
                rule_id: "dirs",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:79: (test)
.......
28 tests, 6 failures
```

### SWP-M: no module gives an empty bucket root, not nil

Mutation:

```elixir
# before
      [] -> nil
      [first | rest]
# after
      [] -> ""
      [first | rest]
```

First failure, verbatim:

```text
  1) test bucket_root/3 no module of that bucket in that context (Anchor.Domain.Placement.DirectoriesTest)
     test/anchor/domain/placement/directories_test.exs:67
     Assertion with == failed
     code:  assert Directories.bucket_root(model, "domain", "c") == nil
     left:  ""
     right: nil
     stacktrace:
       test/anchor/domain/placement/directories_test.exs:69: (test)
...............
28 tests, 1 failure
```

### SWP-N: the tie-break keeps the last candidate

Mutation:

```elixir
# before
  def choose([root | _others], nil), do: {:none, root}
# after
  def choose(candidates, nil), do: {:none, List.last(candidates)}
```

First failure, verbatim:

```text
  1) test no evidence keeps the bucket root, and says it had none (Anchor.Domain.Placement.TieBreakTest)
     test/anchor/domain/placement/tie_break_test.exs:9
     Assertion with == failed
     code:  assert TieBreak.choose(["lib/b/domain", "lib/b/domain/d1", "lib/b/domain/d2"], nil) ==
              {:none, "lib/b/domain"}
     left:  {:none, "lib/b/domain/d2"}
     right: {:none, "lib/b/domain"}
     stacktrace:
       test/anchor/domain/placement/tie_break_test.exs:10: (test)
28 tests, 3 failures
```

### SWP-O: the tie-break ignores evidence it cannot read

Mutation:

```elixir
# before
  def choose([root | _others], nil), do: {:none, root}
# after
  def choose([root | _others], _evidence), do: {:none, root}
```

First failure, verbatim:

```text
  1) test evidence it cannot read yet is refused, never ignored (Anchor.Domain.Placement.TieBreakTest)
     test/anchor/domain/placement/tie_break_test.exs:14
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn ->
     stacktrace:
       test/anchor/domain/placement/tie_break_test.exs:15: (test)
...........................
28 tests, 1 failure
```

### SWP-P: directory_placement's shape text changes

Mutation:

```elixir
# before
    "a directory is a dominator subtree within one bucket of one context, under its "
# after
    "a directory is a subtree within one bucket of one context, under its "
```

First failure, verbatim:

```text
  1) test shape/1, needs/0 and narrows?/2 (Anchor.Domain.GraphRules.DirectoryPlacementTest)
     test/anchor/domain/graph_rules/directory_placement_test.exs:114
     Assertion with =~ failed
     code:  assert DirectoryPlacement.shape(@rule) =~ "dominator subtree"
     left:  "a directory is a subtree within one bucket of one context, under its public module; a module reached from unrelated places sits at its bucket root"
     right: "dominator subtree"
     stacktrace:
       test/anchor/domain/graph_rules/directory_placement_test.exs:115: (test)
......................
28 tests, 1 failure
```

### SWP-Q: the output-owner text changes

Mutation:

```elixir
# before
(it returns %#{inspect(owner)}{}; the "
# after
(it builds %#{inspect(owner)}{}; the "
```

First failure, verbatim:

```text
  1) test render/1 output owner text (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:563
     Assertion with == failed
     code:  assert Placement.render(render_proposal(:output_type_owner, Inv.Line)) ==
              "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its " <>
                "transitions)"
     left:  "move F.line/1 to Inv.Line (it builds %Inv.Line{}; the owner of a type holds its transitions)"
     right: "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its transitions)"
     stacktrace:
       test/anchor/domain/placement_test.exs:564: (test)
.............
58 tests, 1 failure
```

### SWP-R: the dominated text changes

Mutation:

```elixir
# before
"move #{subject(proposal)} into #{inspect(owner)} as a private function (only "
# after
"move #{subject(proposal)} into #{inspect(owner)} (only "
```

First failure, verbatim:

```text
  1) test render/1 dominated text (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:574
     Assertion with == failed
     code:  assert Placement.render(render_proposal(:dominated_by, Inv)) ==
              "move F.line/1 into Inv as a private function (only Inv calls it)"
     left:  "move F.line/1 into Inv (only Inv calls it)"
     right: "move F.line/1 into Inv as a private function (only Inv calls it)"
     stacktrace:
       test/anchor/domain/placement_test.exs:575: (test)
.......
58 tests, 1 failure
```

### SWP-S: the bucket text drops the context

Mutation:

```elixir
# before
"move #{subject(p)} to the #{role} bucket#{of_context(context)}#{named(module)}: "
# after
"move #{subject(p)} to the #{role} bucket#{of_context(if(context, do: nil, else: nil))}#{named(module)}: "
```

First failure, verbatim:

```text
  1) test render/1 bucket text names the context and module when known, and the evidence (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:584
     Assertion with == failed
     code:  assert Placement.render(
              render_proposal(:bucket_from_effects, {:bucket, :managers, "App.B", App.B.Inv}, ["a -> b"])
            ) == "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"
     left:  "move F.line/1 to the managers bucket (App.B.Inv): a -> b"
     right: "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"
     stacktrace:
       test/anchor/domain/placement_test.exs:585: (test)
.........
58 tests, 1 failure
```

### SWP-T: an unknown reason gets a default text

Mutation:

```elixir
# before
  def render(%Proposal{reason: :inert_hop,
# after
  def render(%Proposal{reason: reason} = p) when reason not in [:bucket_from_effects, :output_type_owner, :input_type_owner, :dominated_by, :unreachable, :dominator_subtree, :shared_module, :inert_directory, :inert_hop], do: subject(p)

  def render(%Proposal{reason: :inert_hop,
```

First failure, verbatim:

```text
  1) test render/1 an unknown reason raises: there is no default text (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:650
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn -> Placement.render(render_proposal(:nope, F)) end
     stacktrace:
       test/anchor/domain/placement_test.exs:651: (test)
..............................
58 tests, 1 failure
```

## Run 23:09 UTC

- **Code under test:** `Anchor.Domain.Placement.all_proposals/3`, `Anchor.Domain.Placement.facts_for_ownership/3`, `Anchor.Domain.Placement.headline/2`, `Anchor.Domain.Placement.proposals/3`, `Anchor.Domain.Placement.render/1`, `Anchor.Domain.Placement.Forwarders.aggregates/2`, `Anchor.Domain.Placement.Forwarders.app/2`, `Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3`, `Anchor.Domain.Placement.Forwarders.boundary/3`, `Anchor.Domain.Placement.Forwarders.call_of/3`, `Anchor.Domain.Placement.Forwarders.callback?/2`, `Anchor.Domain.Placement.Forwarders.callers_text/1`, `Anchor.Domain.Placement.Forwarders.case_forward/2`, `Anchor.Domain.Placement.Forwarders.case_values/1`, `Anchor.Domain.Placement.Forwarders.classified_boundary/4`, `Anchor.Domain.Placement.Forwarders.compiler_generated?/1`, `Anchor.Domain.Placement.Forwarders.default_clause?/2`, `Anchor.Domain.Placement.Forwarders.forwarded_call/2`, `Anchor.Domain.Placement.Forwarders.forwarder/1`, `Anchor.Domain.Placement.Forwarders.forwarding_call/3`, `Anchor.Domain.Placement.Forwarders.literal_mfa/1`, `Anchor.Domain.Placement.Forwarders.renaming_let/3`, `Anchor.Domain.Placement.Forwarders.static_caller?/1`, `Anchor.Domain.Placement.Forwarders.true_guard?/1`, `Anchor.Domain.Placement.Forwarders.vars/1`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 6722a405b079dd08d8c786761c299c127bc82901

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 277b66ae1e69 | `Anchor.Domain.Placement.all_proposals/3` | force_condition [true] | killed | 11 |
| d333d0763127 | `Anchor.Domain.Placement.all_proposals/3` | force_condition [false] | killed | 1 |
| 85a08391315e | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [0] | killed | 39 |
| 949ab649ed66 | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [2] | killed | 39 |
| c5f6149da727 | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [1] | killed | 39 |
| 012f0816781c | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 55d61fedae64 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 5719f376c45a | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| dd25c0fd8b03 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 60f67d3721cc | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| fec197a5219c | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| 048b308e5ac9 | `Anchor.Domain.Placement.proposals/3` | narrow_clause | killed | 16 |
| 9747e354f3a9 | `Anchor.Domain.Placement.proposals/3` | narrow_clause | killed | 15 |
| 0a17e4bb26d8 | `Anchor.Domain.Placement.proposals/3` | return_input [2] | killed | 15 |
| afb75bf63ede | `Anchor.Domain.Placement.proposals/3` | return_input [2] | killed | 16 |
| 02d3e964ec8d | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 33f4c97ab9a1 | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 570c78f6807f | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| a6064585391e | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| c24c0c18145d | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| e55c9a9560d1 | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 12e27c584e24 | `Anchor.Domain.Placement.render/1` | return_input [0] | killed | 2 |
| 4b47690e7359 | `Anchor.Domain.Placement.render/1` | return_input [0] | invalid | 0 |
| 60147a00d689 | `Anchor.Domain.Placement.render/1` | return_input [0] | killed | 2 |
| 6fb9a585397d | `Anchor.Domain.Placement.render/1` | return_input [0] | killed | 2 |
| 8794eb1da0b5 | `Anchor.Domain.Placement.render/1` | return_input [0] | killed | 2 |
| 7aaebaffa5be | `Anchor.Domain.Placement.Forwarders.aggregates/2` | force_condition [true] | killed | 1 |
| 811c51c95883 | `Anchor.Domain.Placement.Forwarders.aggregates/2` | force_condition [false] | killed | 1 |
| f2693a19d1ad | `Anchor.Domain.Placement.Forwarders.aggregates/2` | return_input [1] | killed | 6 |
| 05059cf56d4d | `Anchor.Domain.Placement.Forwarders.app/2` | narrow_clause | killed | 7 |

### Mutants

#### 277b66ae1e69 Anchor.Domain.Placement.all_proposals/3 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -386,7 +386,7 @@
       end)
 
     unreachable =
-      if placement.precision.reachability == :precise,
+      if Process.get(:__anchor_sabotage__) == nil,
         do: Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap())),
         else: []
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 11 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal

```
test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [%{reason: :bucket_from_effects}] = proposals(modules, [])
left:  [%{reason: :bucket_from_effects}]
right: [%Anchor.Domain.Proposal{level: :function, subject: {Mgr, :new, 0}, current: {:bucket, :managers, "ctx", Mgr}, proposed: {:bucket, :domain, "ctx", nil}, rule: :effects_match_bucket, reason: :bucket_from_effects, evidence: ["no effect is reachable"], key: "effects_match_bucket|Mgr.new/0|domain"}, %Anchor.Domain.Proposal{level: :function, subject: {Mgr, :new, 0}, current: Mgr, proposed: :delete, rule: :reachable_from_root, reason: :unreachable, evidence: [], key: "reachable_from_root|function|Mgr.new/0|delete"}]

```

#### d333d0763127 Anchor.Domain.Placement.all_proposals/3 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -386,7 +386,7 @@
       end)
 
     unreachable =
-      if placement.precision.reachability == :precise,
+      if Process.get(:__anchor_sabotage__) != nil,
         do: Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap())),
         else: []
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged

```
test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [proposal] = proposals(modules, [], :reachable_from_root)
left:  [proposal]
right: []

```

#### 85a08391315e Anchor.Domain.Placement.facts_for_ownership/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -293,8 +293,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(mfa, _function, _node) do
+    mfa
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 39 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared, test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal

```
test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### 949ab649ed66 Anchor.Domain.Placement.facts_for_ownership/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -293,8 +293,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(_mfa, _function, node) do
+    node
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 39 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named

```
test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### c5f6149da727 Anchor.Domain.Placement.facts_for_ownership/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -293,8 +293,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(_mfa, function, _node) do
+    function
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 39 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared

```
test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### 012f0816781c Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -212,7 +212,7 @@
 
   # --- the sentence before the Fix ------------------------------------------------
 
-  defp headline(%Proposal{rule: :effects_match_bucket} = proposal, model) do
+  defp headline(%Proposal{rule: :effects_match_bucket} = proposal, model) when node() == :__anchor_sabotage_never__ do
     {module, _f, _a} = proposal.subject
     %Classification{bucket: name, role: bucket_role} = model.classification[module]
     prefix = "#{subject(proposal)} is in bucket #{name}"
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found

```
test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 55d61fedae64 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -222,7 +222,7 @@
   defp headline(%Proposal{reason: :unreachable} = proposal, _model),
     do: "#{subject(proposal)} is public and no root reaches it."
 
-  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
+  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do:
       "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)

```
test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 5719f376c45a Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -226,7 +226,7 @@
     do:
       "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
 
-  defp headline(%Proposal{reason: reason} = proposal, model) do
+  defp headline(%Proposal{reason: reason} = proposal, model) when node() == :__anchor_sabotage_never__ do
     {module, _f, _a} = proposal.subject
 
     "#{subject(proposal)} is in #{inspect(module)}#{bucket_note(module, model)}, but " <>
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.headline/2
```

#### dd25c0fd8b03 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -219,7 +219,7 @@
     prefix <> effects_clause(bucket_role, inferred(proposal), proposal)
   end
 
-  defp headline(%Proposal{reason: :unreachable} = proposal, _model),
+  defp headline(%Proposal{reason: :unreachable} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do: "#{subject(proposal)} is public and no root reaches it."
 
   defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 60f67d3721cc Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -222,9 +222,9 @@
   defp headline(%Proposal{reason: :unreachable} = proposal, _model),
     do: "#{subject(proposal)} is public and no root reaches it."
 
-  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
-    do:
-      "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
+  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, _to}} = proposal, _model),
+    do:
+      proposal
 
   defp headline(%Proposal{reason: reason} = proposal, model) do
     {module, _f, _a} = proposal.subject
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)

```
test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: {:inline, {N, :g, 1}}, rule: :function_placement, reason: :inert_hop, evidence: ["forwards to N.g/1", "callers: A.x/1"], key: "function_placement|function|x|y"}
```

#### fec197a5219c Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -220,7 +220,7 @@
   end
 
   defp headline(%Proposal{reason: :unreachable} = proposal, _model),
-    do: "#{subject(proposal)} is public and no root reaches it."
+    do: proposal
 
   defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
     do:
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: :delete, rule: :function_placement, reason: :unreachable, evidence: [], key: "function_placement|function|x|y"}
```

#### 048b308e5ac9 Anchor.Domain.Placement.proposals/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -129,7 +129,7 @@
   `:reachable_from_root` lists none.
   """
   @spec proposals(t(), Model.t(), selection()) :: [Proposal.t()]
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
+  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when (level in @levels) and node() == :__anchor_sabotage_never__,
     do: Enum.filter(proposals, &(&1.level == level))
 
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 16 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice

```
test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.proposals/3
```

#### 9747e354f3a9 Anchor.Domain.Placement.proposals/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -132,7 +132,7 @@
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
     do: Enum.filter(proposals, &(&1.level == level))
 
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
+  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when (rule in @rules) and node() == :__anchor_sabotage_never__,
     do: Enum.filter(proposals, &(&1.rule == rule))
 
   @doc "The one line a placement `Fix:` carries. An unknown reason raises: no default text."
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 15 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key

```
test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.proposals/3
```

#### 0a17e4bb26d8 Anchor.Domain.Placement.proposals/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -132,8 +132,8 @@
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
     do: Enum.filter(proposals, &(&1.level == level))
 
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
-    do: Enum.filter(proposals, &(&1.rule == rule))
+  def proposals(%__MODULE__{proposals: _proposals}, %Model{}, rule) when rule in @rules,
+    do: rule
 
   @doc "The one line a placement `Fix:` carries. An unknown reason raises: no default text."
   @spec render(Proposal.t()) :: String.t()
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 15 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved

```
test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert proposals(modules, calls, :function_placement) == []
left:  :function_placement
right: []

```

#### afb75bf63ede Anchor.Domain.Placement.proposals/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -129,8 +129,8 @@
   `:reachable_from_root` lists none.
   """
   @spec proposals(t(), Model.t(), selection()) :: [Proposal.t()]
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
-    do: Enum.filter(proposals, &(&1.level == level))
+  def proposals(%__MODULE__{proposals: _proposals}, %Model{}, level) when level in @levels,
+    do: level
 
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
     do: Enum.filter(proposals, &(&1.rule == rule))
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 16 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal

```
test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [%{reason: :bucket_from_effects}] = proposals(modules, [])
left:  [%{reason: :bucket_from_effects}]
right: :function

```

#### 02d3e964ec8d Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -159,7 +159,7 @@
       "#{inspect(owner)} calls it)"
   end
 
-  def render(%Proposal{reason: :unreachable} = proposal) do
+  def render(%Proposal{reason: :unreachable} = proposal) when node() == :__anchor_sabotage_never__ do
     "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
   end
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative, test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 33f4c97ab9a1 Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -149,7 +149,7 @@
       "owner of a type holds its transitions)"
   end
 
-  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) do
+  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) when node() == :__anchor_sabotage_never__ do
     "move #{subject(proposal)} to #{inspect(owner)} (its result is computed from " <>
       "%#{inspect(owner)}{})"
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:569 test render/1 input owner text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:569 test render/1 input owner text
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 570c78f6807f Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -163,7 +163,7 @@
     "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
   end
 
-  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
+  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) when node() == :__anchor_sabotage_never__ do
     "inline #{subject(p)}: its callers (#{String.replace_prefix(callers, "callers: ", "")}) " <>
       "call #{ViolationKey.mfa(to)} directly (it forwards without crossing a bucket, context, " <>
       "app, aggregate, interface or callback boundary)"
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:597 test render/1 inert hop text names the callers and the target (DND-5461), test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)

```
test/anchor/domain/placement_test.exs:597 test render/1 inert hop text names the callers and the target (DND-5461)
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### a6064585391e Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -139,7 +139,7 @@
   @spec render(Proposal.t()) :: String.t()
   def render(
         %Proposal{reason: :bucket_from_effects, proposed: {:bucket, role, context, module}} = p
-      ) do
+      ) when node() == :__anchor_sabotage_never__ do
     "move #{subject(p)} to the #{role} bucket#{of_context(context)}#{named(module)}: " <>
       Enum.join(p.evidence, "; ")
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found, test/anchor/domain/placement_test.exs:584 test render/1 bucket text names the context and module when known, and the evidence

```
test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### c24c0c18145d Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -144,7 +144,7 @@
       Enum.join(p.evidence, "; ")
   end
 
-  def render(%Proposal{reason: :output_type_owner, proposed: owner} = proposal) do
+  def render(%Proposal{reason: :output_type_owner, proposed: owner} = proposal) when node() == :__anchor_sabotage_never__ do
     "move #{subject(proposal)} to #{inspect(owner)} (it returns %#{inspect(owner)}{}; the " <>
       "owner of a type holds its transitions)"
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:563 test render/1 output owner text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:563 test render/1 output owner text
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### e55c9a9560d1 Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -154,7 +154,7 @@
       "%#{inspect(owner)}{})"
   end
 
-  def render(%Proposal{reason: :dominated_by, proposed: owner} = proposal) do
+  def render(%Proposal{reason: :dominated_by, proposed: owner} = proposal) when node() == :__anchor_sabotage_never__ do
     "move #{subject(proposal)} into #{inspect(owner)} as a private function (only " <>
       "#{inspect(owner)} calls it)"
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:574 test render/1 dominated text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:574 test render/1 dominated text
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 12e27c584e24 Anchor.Domain.Placement.render/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -149,9 +149,8 @@
       "owner of a type holds its transitions)"
   end
 
-  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) do
-    "move #{subject(proposal)} to #{inspect(owner)} (its result is computed from " <>
-      "%#{inspect(owner)}{})"
+  def render(%Proposal{reason: :input_type_owner, proposed: _owner} = proposal) do
+    proposal
   end
 
   def render(%Proposal{reason: :dominated_by, proposed: owner} = proposal) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:569 test render/1 input owner text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:569 test render/1 input owner text
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Placement.render(render_proposal(:input_type_owner, Lease)) ==
              "move F.line/1 to Lease (its result is computed from %Lease{})"
left:  %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: Lease, rule: :function_placement, reason: :input_type_owner, evidence: [], key: nil}
right: "move F.line/1 to Lease (its result is computed from %Lease{})"

```

#### 4b47690e7359 Anchor.Domain.Placement.render/1 return_input [0]: invalid

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -163,10 +163,8 @@
     "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
   end
 
-  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
-    "inline #{subject(p)}: its callers (#{String.replace_prefix(callers, "callers: ", "")}) " <>
-      "call #{ViolationKey.mfa(to)} directly (it forwards without crossing a bucket, context, " <>
-      "app, aggregate, interface or callback boundary)"
+  def render(%Proposal{reason: :inert_hop, proposed: {:inline, _to}, evidence: [_to, _callers]} = p) do
+    p
   end
 
   @doc """
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (0 tests, 0 failures; tests selected by mirror). Failed: none

```
did not compile: warning: the underscored variable "_to" appears more than once in a match. This means the pattern will only match if all "_to" bind to the same value. If this is the intended behaviour, please remove the leading underscore from the variable name, otherwise give the variables different names
```

#### 60147a00d689 Anchor.Domain.Placement.render/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -154,9 +154,8 @@
       "%#{inspect(owner)}{})"
   end
 
-  def render(%Proposal{reason: :dominated_by, proposed: owner} = proposal) do
-    "move #{subject(proposal)} into #{inspect(owner)} as a private function (only " <>
-      "#{inspect(owner)} calls it)"
+  def render(%Proposal{reason: :dominated_by, proposed: _owner} = proposal) do
+    proposal
   end
 
   def render(%Proposal{reason: :unreachable} = proposal) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:574 test render/1 dominated text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:574 test render/1 dominated text
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Placement.render(render_proposal(:dominated_by, Inv)) ==
              "move F.line/1 into Inv as a private function (only Inv calls it)"
left:  %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: Inv, rule: :function_placement, reason: :dominated_by, evidence: [], key: nil}
right: "move F.line/1 into Inv as a private function (only Inv calls it)"

```

#### 6fb9a585397d Anchor.Domain.Placement.render/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -160,7 +160,7 @@
   end
 
   def render(%Proposal{reason: :unreachable} = proposal) do
-    "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
+    proposal
   end
 
   def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence, test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative

```
test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
** (ArgumentError) construction of binary failed: segment 3 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: :delete, rule: :function_placement, reason: :unreachable, evidence: [], key: "function_placement|function|x|y"}
```

#### 8794eb1da0b5 Anchor.Domain.Placement.render/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -144,9 +144,8 @@
       Enum.join(p.evidence, "; ")
   end
 
-  def render(%Proposal{reason: :output_type_owner, proposed: owner} = proposal) do
-    "move #{subject(proposal)} to #{inspect(owner)} (it returns %#{inspect(owner)}{}; the " <>
-      "owner of a type holds its transitions)"
+  def render(%Proposal{reason: :output_type_owner, proposed: _owner} = proposal) do
+    proposal
   end
 
   def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (56 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/placement_test.exs:563 test render/1 output owner text, test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:563 test render/1 output owner text
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Placement.render(render_proposal(:output_type_owner, Inv.Line)) ==
              "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its " <>
                "transitions)"
left:  %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: Inv.Line, rule: :function_placement, reason: :output_type_owner, evidence: [], key: nil}
right: "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its transitions)"

```

#### 7aaebaffa5be Anchor.Domain.Placement.Forwarders.aggregates/2 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/placement/forwarders.ex
+++ b/lib/anchor/domain/placement/forwarders.ex
@@ -235,7 +235,7 @@
   end
 
   defp aggregates(%Model{aggregates: index}, module) do
-    schemas = if Map.has_key?(index.by_schema, module), do: [index.by_schema[module]], else: []
+    schemas = if Process.get(:__anchor_sabotage__) == nil, do: [index.by_schema[module]], else: []
     Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [])))
   end
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement/forwarders_test.exs` (26 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared

```
test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert boundary([], [], adjust: same) == :none
left:  {:crosses, :aggregate}
right: :none

```

#### 811c51c95883 Anchor.Domain.Placement.Forwarders.aggregates/2 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/placement/forwarders.ex
+++ b/lib/anchor/domain/placement/forwarders.ex
@@ -235,7 +235,7 @@
   end
 
   defp aggregates(%Model{aggregates: index}, module) do
-    schemas = if Map.has_key?(index.by_schema, module), do: [index.by_schema[module]], else: []
+    schemas = if Process.get(:__anchor_sabotage__) != nil, do: [index.by_schema[module]], else: []
     Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [])))
   end
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement/forwarders_test.exs` (26 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared

```
test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert boundary([], [], adjust: same) == :none
left:  {:crosses, :aggregate}
right: :none

```

#### f2693a19d1ad Anchor.Domain.Placement.Forwarders.aggregates/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/placement/forwarders.ex
+++ b/lib/anchor/domain/placement/forwarders.ex
@@ -234,9 +234,8 @@
     end
   end
 
-  defp aggregates(%Model{aggregates: index}, module) do
-    schemas = if Map.has_key?(index.by_schema, module), do: [index.by_schema[module]], else: []
-    Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [])))
+  defp aggregates(%Model{aggregates: _index}, module) do
+    module
   end
 
   defp callback?(%Model{graph: graph} = model, {module, name, arity}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement/forwarders_test.exs` (26 tests, 6 failures; tests selected by mirror). Failed: test/anchor/domain/placement/forwarders_test.exs:145 test boundary/3 same bucket, context and app, no interface and no callback: none, test/anchor/domain/placement/forwarders_test.exs:180 test boundary/3 an external behaviour's callback the inference was given, test/anchor/domain/placement/forwarders_test.exs:174 test boundary/3 an interface forwarding to a module that is not one, test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared, test/anchor/domain/placement/forwarders_test.exs:216 test boundary/3 no aggregates declared: the aggregate test is not judged, test/anchor/domain/placement/forwarders_test.exs:193 test boundary/3 a project behaviour's callback

```
test/anchor/domain/placement/forwarders_test.exs:145 test boundary/3 same bucket, context and app, no interface and no callback: none
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert boundary([], []) == :none
left:  {:crosses, :aggregate}
right: :none

```

#### 05059cf56d4d Anchor.Domain.Placement.Forwarders.app/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement/forwarders.ex
+++ b/lib/anchor/domain/placement/forwarders.ex
@@ -229,7 +229,7 @@
 
   defp app(%Model{graph: graph}, %Classification{module: module, app: app}) do
     case Map.get(graph.modules, module) do
-      %ModuleNode{app: node_app} -> node_app
+      %ModuleNode{app: node_app} when node() == :__anchor_sabotage_never__ -> node_app
       nil -> app
     end
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement/forwarders_test.exs` (26 tests, 7 failures; tests selected by mirror). Failed: test/anchor/domain/placement/forwarders_test.exs:216 test boundary/3 no aggregates declared: the aggregate test is not judged, test/anchor/domain/placement/forwarders_test.exs:169 test boundary/3 an app crossing, test/anchor/domain/placement/forwarders_test.exs:193 test boundary/3 a project behaviour's callback, test/anchor/domain/placement/forwarders_test.exs:174 test boundary/3 an interface forwarding to a module that is not one, test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared, test/anchor/domain/placement/forwarders_test.exs:180 test boundary/3 an external behaviour's callback the inference was given, test/anchor/domain/placement/forwarders_test.exs:145 test boundary/3 same bucket, context and app, no interface and no callback: none

```
test/anchor/domain/placement/forwarders_test.exs:216 test boundary/3 no aggregates declared: the aggregate test is not judged
** (CaseClauseError) no case clause matching:

    %Anchor.Domain.Graph.ModuleNode{
      module: Totals,
      app: :app,
      source_file: "lib/domain/Totals.ex",
      line: nil,
      struct_fields: nil,
      behaviours: [],
      attributes: [],
      specs: %{},
      types: %{},
      callbacks: [],
      functions: %{
        {:handle_call, 3} => %Anchor.Domain.Graph.FunctionNode{
          module: Totals,
          name: :handle_call,
          arity: 3,
          kind: :def,
          line: 13,
          core: nil,
          clauses: []
        },
        {:sum, 1} => %Anchor.Domain.Graph.FunctionNode{
          module: Totals,
          name: :sum,
          arity: 1,
          kind: :def,
          line: 11,
          core: nil,
          clauses: []
        }
      },
      generated?: false
    }

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- 4b47690e7359 Anchor.Domain.Placement.render/1 return_input [0]: invalid (did not compile: warning: the underscored variable "_to" appears more than once in a match. This means the pattern will only match if all "_to" bind to the same value. If this is the intended behaviour, please remove the leading underscore from the variable name, otherwise give the variables different names)
- skipped Anchor.Domain.Placement.render/1 return_input [0] `render(%Proposal{reason: :bucket_from_effects, proposed: {:bucket, role, context, module}} = p)`: removes the last use of function `named/1`
- skipped Anchor.Domain.Placement.headline/2 delete_statement `{module, _f, _a} = proposal.subject()`: orphans variable `module` bound at line 216 and used at line 217
- skipped Anchor.Domain.Placement.headline/2 delete_statement `%Classification{bucket: name, role: bucket_role} = model.classification()[module]`: orphans variable `bucket_role` bound at line 217 and used at line 219
- skipped Anchor.Domain.Placement.headline/2 delete_statement `prefix = "#{subject(proposal)} is in bucket #{name}"`: orphans variable `prefix` bound at line 218 and used at line 219
- skipped Anchor.Domain.Placement.headline/2 return_input [0] `headline(%Proposal{rule: :effects_match_bucket} = proposal, model)`: removes the last use of alias `Classification`
- skipped Anchor.Domain.Placement.headline/2 return_input [1] `headline(%Proposal{rule: :effects_match_bucket} = proposal, model)`: removes the last use of alias `Classification`
- skipped Anchor.Domain.Placement.headline/2 delete_statement `{module, _f, _a} = proposal.subject()`: orphans variable `module` bound at line 230 and used at line 232
- skipped Anchor.Domain.Placement.headline/2 return_input [0] `headline(%Proposal{reason: reason} = proposal, model)`: removes the last use of function `bucket_note/2`
- skipped Anchor.Domain.Placement.headline/2 return_input [1] `headline(%Proposal{reason: reason} = proposal, model)`: removes the last use of function `bucket_note/2`
- skipped Anchor.Domain.Placement.facts_of/7 delete_statement `idom = Map.get(dominators.idom(), mfa)`: orphans variable `idom` bound at line 320 and used at line 323
- skipped Anchor.Domain.Placement.facts_of/7 delete_statement `answer = Map.get(answers, mfa, %{output: :none, input: :none})`: orphans variable `answer` bound at line 321 and used at line 323
- skipped Anchor.Domain.Placement.facts_of/7 return_input [0] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [1] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [2] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [3] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [4] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [5] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [6] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `facts = functions |> Map.values() |> Enum.sort_by(& &1.mfa())`: orphans variable `facts` bound at line 381 and used at line 383
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `function_rules =
  Enum.flat_map(facts, fn fact ->
    fact |> Rules.placement(placement, model, effects) |> List.wrap()
  end)`: orphans variable `function_rules` bound at line 383 and used at line 395
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `unreachable =
  if placement.precision().reachability() == :precise do
    Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap()))
  else
    []
  end`: orphans variable `unreachable` bound at line 388 and used at line 395
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `hops = Forwarders.proposals(%{model | effects: effects})`: orphans variable `hops` bound at line 393 and used at line 395
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [0] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [1] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [2] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.Forwarders.forwarder/1 delete_statement `params = Enum.map(:cerl.fun_vars(core), &:cerl.var_name/1)`: orphans variable `params` bound at line 80 and used at line 82
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 delete_statement `from_class = Map.get(model.classification(), from_module)`: orphans variable `from_class` bound at line 92 and used at line 95
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 delete_statement `to_class = Map.get(model.classification(), to_module)`: orphans variable `to_class` bound at line 93 and used at line 95
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 return_input [0] `boundary(%Model{} = model, {from_module, _f, _a} = from, {to_module, _g, _b})`: removes the last use of function `classified_boundary/4`
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 return_input [1] `boundary(%Model{} = model, {from_module, _f, _a} = from, {to_module, _g, _b})`: removes the last use of function `classified_boundary/4`
- skipped Anchor.Domain.Placement.Forwarders.proposals/1 delete_statement `callers = static_callers(graph.calls())`: orphans variable `callers` bound at line 105 and used at line 107
- skipped Anchor.Domain.Placement.Forwarders.proposals/1 return_input [0] `proposals(%Model{graph: graph} = model)`: removes the last use of alias `Placement`
- skipped Anchor.Domain.Placement.Forwarders.forwarded_call/2 return_input [0] `forwarded_call(body, params)`: removes the last use of function `case_forward/2`
- skipped Anchor.Domain.Placement.Forwarders.forwarded_call/2 return_input [1] `forwarded_call(body, params)`: removes the last use of function `case_forward/2`
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough `[clause] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1)`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 return_input [0] `case_forward(body, params)`: removes the last use of function `compiler_generated?/1`
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 return_input [1] `case_forward(body, params)`: removes the last use of function `compiler_generated?/1`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [0] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [1] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [2] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 delete_statement `renames = Map.put(renames, :cerl.var_name(var), Map.get(renames, name, name))`: leaves variable `name` bound at line 165 unused
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 with_passthrough `[var] <- :cerl.let_vars(body)`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 with_passthrough `[name] <- vars(case_values(:cerl.let_arg(body)))`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 force_condition [true] `Enum.map(args, &Map.get(renames, &1, &1)) == params`: leaves variable `args` bound at line 175 unused
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 force_condition [false] `Enum.map(args, &Map.get(renames, &1, &1)) == params`: leaves variable `args` bound at line 175 unused
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [0] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [1] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [2] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.literal_mfa/1 delete_statement `module = :cerl.call_module(call)`: orphans variable `module` bound at line 182 and used at line 185
- skipped Anchor.Domain.Placement.Forwarders.literal_mfa/1 delete_statement `name = :cerl.call_name(call)`: orphans variable `name` bound at line 183 and used at line 185
- skipped Anchor.Domain.Placement.Forwarders.defaults?/3 return_input [1] `defaults?(%ModuleNode{functions: functions}, name, arity)`: removes the last use of function `default_clause?/2`
- skipped Anchor.Domain.Placement.Forwarders.defaults?/3 return_input [2] `defaults?(%ModuleNode{functions: functions}, name, arity)`: removes the last use of function `default_clause?/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `app(model, from_class) != app(model, to_class)`: removes the last use of function `app/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `app(model, from_class) != app(model, to_class)`: removes the last use of function `app/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `aggregates(model, from_class.module()) != aggregates(model, to_class.module())`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `aggregates(model, from_class.module()) != aggregates(model, to_class.module())`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `callback?(model, from)`: leaves variable `from` bound at line 205 unused
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `callback?(model, from)`: leaves variable `from` bound at line 205 unused
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [0] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [1] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [2] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [3] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.aggregates/2 delete_statement `schemas =
  if Map.has_key?(index.by_schema(), module) do
    [index.by_schema()[module]]
  else
    []
  end`: orphans variable `schemas` bound at line 238 and used at line 239
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 delete_statement `%ModuleNode{behaviours: behaviours} = Map.fetch!(graph.modules(), module)`: orphans variable `behaviours` bound at line 243 and used at line 246
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 delete_statement `external =
  if model.effects() do
    model.effects().callbacks()
  else
    %{}
  end`: orphans variable `external` bound at line 244 and used at line 246
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 return_input [0] `callback?(%Model{graph: graph} = model, {module, name, arity})`: removes the last use of function `behaviour_callbacks/3`
- skipped Anchor.Domain.Placement.Forwarders.static_callers/1 return_input [0] `static_callers(calls)`: removes the last use of function `static_caller?/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [0] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [1] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [2] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- aeb4c410fe05 Anchor.Domain.Placement.Forwarders.app/2 narrow_clause: not run (cap)
- 06a5d24132a0 Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 narrow_clause: not run (cap)
- 25373e8e874a Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 narrow_clause: not run (cap)
- 0c1353a007f2 Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 return_input [1]: not run (cap)
- 5d31bfee15ac Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 return_input [2]: not run (cap)
- 04bdc10f5e4b Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [true]: not run (cap)
- 6af4ef5851eb Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [true]: not run (cap)
- 78cfe0bc7be3 Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [false]: not run (cap)
- b47abaf3e080 Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [false]: not run (cap)
- 05ca031f19ca Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- 1aaeb460d734 Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- 49f2c7077ba7 Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- d5f518bcdf51 Anchor.Domain.Placement.Forwarders.callback?/2 force_condition [false]: not run (cap)
- f548005317ed Anchor.Domain.Placement.Forwarders.callback?/2 force_condition [true]: not run (cap)
- 2727474bfb49 Anchor.Domain.Placement.Forwarders.callers_text/1 narrow_clause: not run (cap)
- d883636d550e Anchor.Domain.Placement.Forwarders.callers_text/1 narrow_clause: not run (cap)
- 70d1d7fb97c9 Anchor.Domain.Placement.Forwarders.callers_text/1 return_input [0]: not run (cap)
- 0652e7670ab6 Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- 1f58d44bc12b Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- 9ea2149a5a02 Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- bb9734d11bcb Anchor.Domain.Placement.Forwarders.case_values/1 force_condition [false]: not run (cap)
- d9db4da270e4 Anchor.Domain.Placement.Forwarders.case_values/1 force_condition [true]: not run (cap)
- 68dad3afd7af Anchor.Domain.Placement.Forwarders.case_values/1 return_input [0]: not run (cap)
- 1deb83654910 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- 6cf287a15072 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- 9ad4e6253053 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- bdc4f42b64f1 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- fb85f09c5834 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- fcea99d83d4f Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- 2933d35cea23 Anchor.Domain.Placement.Forwarders.compiler_generated?/1 return_input [0]: not run (cap)
- 146f7885df2d Anchor.Domain.Placement.Forwarders.default_clause?/2 narrow_clause: not run (cap)
- d10959400c8a Anchor.Domain.Placement.Forwarders.default_clause?/2 narrow_clause: not run (cap)
- cf0a8c539858 Anchor.Domain.Placement.Forwarders.default_clause?/2 return_input [1]: not run (cap)
- 0034ba660e7a Anchor.Domain.Placement.Forwarders.forwarded_call/2 narrow_clause: not run (cap)
- d64458d05282 Anchor.Domain.Placement.Forwarders.forwarded_call/2 narrow_clause: not run (cap)
- 09c8ef284a79 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 0de014dd0ca6 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 106351b05f6d Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 230325d611f8 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- a1c5f6c2642c Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 231079d02674 Anchor.Domain.Placement.Forwarders.forwarding_call/3 narrow_clause: not run (cap)
- aeff78808b15 Anchor.Domain.Placement.Forwarders.forwarding_call/3 narrow_clause: not run (cap)
- 09dcedb28646 Anchor.Domain.Placement.Forwarders.literal_mfa/1 force_condition [true]: not run (cap)
- 7cb3ed76b4d8 Anchor.Domain.Placement.Forwarders.literal_mfa/1 force_condition [false]: not run (cap)
- 420bdce8d0b4 Anchor.Domain.Placement.Forwarders.literal_mfa/1 return_input [0]: not run (cap)
- 6969ffdd6b4c Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [2]: not run (cap)
- 953e6a899baf Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [1]: not run (cap)
- badb0e17608c Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [0]: not run (cap)
- 22ba31f21f24 Anchor.Domain.Placement.Forwarders.static_caller?/1 narrow_clause: not run (cap)
- fb70e98b2a23 Anchor.Domain.Placement.Forwarders.static_caller?/1 narrow_clause: not run (cap)
- ed2135b199f1 Anchor.Domain.Placement.Forwarders.true_guard?/1 return_input [0]: not run (cap)
- 3ee930bef936 Anchor.Domain.Placement.Forwarders.vars/1 force_condition [false]: not run (cap)
- 671d3f46598d Anchor.Domain.Placement.Forwarders.vars/1 force_condition [true]: not run (cap)
- d3559a2cba20 Anchor.Domain.Placement.Forwarders.vars/1 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
277b66ae1e69	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.all_proposals/3	force_condition	killed	test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2 ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal
d333d0763127	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.all_proposals/3	force_condition	killed	test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged
85a08391315e	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared ; test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal
949ab649ed66	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named
c5f6149da727	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared
012f0816781c	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found
55d61fedae64	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)
5719f376c45a	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
dd25c0fd8b03	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
60f67d3721cc	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)
fec197a5219c	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
048b308e5ac9	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	narrow_clause	killed	test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2 ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice
9747e354f3a9	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	narrow_clause	killed	test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key
0a17e4bb26d8	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	return_input	killed	test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved
afb75bf63ede	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	return_input	killed	test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:617 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2 ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal
02d3e964ec8d	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative ; test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence
33f4c97ab9a1	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:569 test render/1 input owner text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
570c78f6807f	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:597 test render/1 inert hop text names the callers and the target (DND-5461) ; test/anchor/domain/placement_test.exs:691 test to_violation/3 an inert hop's sentence names the target (DND-5461)
a6064585391e	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:703 test to_violation/3 each effects sentence names the bucket and what the inference found ; test/anchor/domain/placement_test.exs:584 test render/1 bucket text names the context and module when known, and the evidence
c24c0c18145d	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:563 test render/1 output owner text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
e55c9a9560d1	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:574 test render/1 dominated text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
12e27c584e24	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	return_input	killed	test/anchor/domain/placement_test.exs:569 test render/1 input owner text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
4b47690e7359	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	return_input	invalid	
60147a00d689	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	return_input	killed	test/anchor/domain/placement_test.exs:574 test render/1 dominated text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
6fb9a585397d	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	return_input	killed	test/anchor/domain/placement_test.exs:686 test to_violation/3 an unreachable function's sentence ; test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative
8794eb1da0b5	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	return_input	killed	test/anchor/domain/placement_test.exs:563 test render/1 output owner text ; test/anchor/domain/placement_test.exs:674 test to_violation/3 each owner reason says why before the Fix
7aaebaffa5be	lib/anchor/domain/placement/forwarders.ex	Anchor.Domain.Placement.Forwarders.aggregates/2	force_condition	killed	test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared
811c51c95883	lib/anchor/domain/placement/forwarders.ex	Anchor.Domain.Placement.Forwarders.aggregates/2	force_condition	killed	test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared
f2693a19d1ad	lib/anchor/domain/placement/forwarders.ex	Anchor.Domain.Placement.Forwarders.aggregates/2	return_input	killed	test/anchor/domain/placement/forwarders_test.exs:145 test boundary/3 same bucket, context and app, no interface and no callback: none ; test/anchor/domain/placement/forwarders_test.exs:180 test boundary/3 an external behaviour's callback the inference was given ; test/anchor/domain/placement/forwarders_test.exs:174 test boundary/3 an interface forwarding to a module that is not one ; test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared ; test/anchor/domain/placement/forwarders_test.exs:216 test boundary/3 no aggregates declared: the aggregate test is not judged ; test/anchor/domain/placement/forwarders_test.exs:193 test boundary/3 a project behaviour's callback
05059cf56d4d	lib/anchor/domain/placement/forwarders.ex	Anchor.Domain.Placement.Forwarders.app/2	narrow_clause	killed	test/anchor/domain/placement/forwarders_test.exs:216 test boundary/3 no aggregates declared: the aggregate test is not judged ; test/anchor/domain/placement/forwarders_test.exs:169 test boundary/3 an app crossing ; test/anchor/domain/placement/forwarders_test.exs:193 test boundary/3 a project behaviour's callback ; test/anchor/domain/placement/forwarders_test.exs:174 test boundary/3 an interface forwarding to a module that is not one ; test/anchor/domain/placement/forwarders_test.exs:202 test boundary/3 different aggregates, when declared ; test/anchor/domain/placement/forwarders_test.exs:180 test boundary/3 an external behaviour's callback the inference was given ; test/anchor/domain/placement/forwarders_test.exs:145 test boundary/3 same bucket, context and app, no interface and no callback: none
```

## Run 23:27 UTC

- **Code under test:** `Anchor.Domain.Placement.all_proposals/3`, `Anchor.Domain.Placement.facts_for_ownership/3`, `Anchor.Domain.Placement.headline/2`, `Anchor.Domain.Placement.proposals/3`, `Anchor.Domain.Placement.render/1`, `Anchor.Domain.Placement.subject/1`, `Anchor.Domain.Placement.subject_modules/2`, `Anchor.Domain.Placement.to_violation/3`, `Anchor.Domain.Placement.Directories.bucket_root/3`, `Anchor.Domain.Placement.Directories.caller_dir/2`, `Anchor.Domain.Placement.Directories.common_prefix/2`, `Anchor.Domain.Placement.Directories.dominated_inside?/3`, `Anchor.Domain.Placement.Directories.flatten/4`, `Anchor.Domain.Placement.Directories.interior/3`, `Anchor.Domain.Placement.Directories.key/2`, `Anchor.Domain.Placement.Directories.module_dominators/1`, `Anchor.Domain.Placement.Directories.module_proposal/6`, `Anchor.Domain.Placement.Directories.not_placed/1`, `Anchor.Domain.Placement.Directories.proposal/5`, `Anchor.Domain.Placement.Directories.shared/4`, `Anchor.Domain.Placement.Forwarders.aggregates/2`, `Anchor.Domain.Placement.Forwarders.app/2`, `Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3`, `Anchor.Domain.Placement.Forwarders.boundary/3`, `Anchor.Domain.Placement.Forwarders.call_of/3`, `Anchor.Domain.Placement.Forwarders.callback?/2`, `Anchor.Domain.Placement.Forwarders.callers_text/1`, `Anchor.Domain.Placement.Forwarders.case_forward/2`, `Anchor.Domain.Placement.Forwarders.case_values/1`, `Anchor.Domain.Placement.Forwarders.classified_boundary/4`, `Anchor.Domain.Placement.Forwarders.compiler_generated?/1`, `Anchor.Domain.Placement.Forwarders.default_clause?/2`, `Anchor.Domain.Placement.Forwarders.forwarded_call/2`, `Anchor.Domain.Placement.Forwarders.forwarder/1`, `Anchor.Domain.Placement.Forwarders.forwarding_call/3`, `Anchor.Domain.Placement.Forwarders.literal_mfa/1`, `Anchor.Domain.Placement.Forwarders.renaming_let/3`, `Anchor.Domain.Placement.Forwarders.static_caller?/1`, `Anchor.Domain.Placement.Forwarders.true_guard?/1`, `Anchor.Domain.Placement.Forwarders.vars/1`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 16b2de97c482ac0f929b6af890e88a0feb0d7cbe

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 277b66ae1e69 | `Anchor.Domain.Placement.all_proposals/3` | force_condition [true] | killed | 11 |
| d333d0763127 | `Anchor.Domain.Placement.all_proposals/3` | force_condition [false] | killed | 1 |
| 85a08391315e | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [0] | killed | 39 |
| 949ab649ed66 | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [2] | killed | 39 |
| c5f6149da727 | `Anchor.Domain.Placement.facts_for_ownership/3` | return_input [1] | killed | 39 |
| 012f0816781c | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 077f40d4c88d | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 55d61fedae64 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 5719f376c45a | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 63b28b7d77e9 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 949017d334f5 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| dd25c0fd8b03 | `Anchor.Domain.Placement.headline/2` | narrow_clause | killed | 1 |
| 428d87b5fe63 | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| 60f67d3721cc | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| cf56795bbaaa | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| e90b6eb0799b | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| fec197a5219c | `Anchor.Domain.Placement.headline/2` | return_input [0] | killed | 1 |
| 048b308e5ac9 | `Anchor.Domain.Placement.proposals/3` | narrow_clause | killed | 16 |
| 9747e354f3a9 | `Anchor.Domain.Placement.proposals/3` | narrow_clause | killed | 15 |
| 0a17e4bb26d8 | `Anchor.Domain.Placement.proposals/3` | return_input [2] | killed | 15 |
| afb75bf63ede | `Anchor.Domain.Placement.proposals/3` | return_input [2] | killed | 16 |
| 02d3e964ec8d | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 33f4c97ab9a1 | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 42eaacb5daf7 | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 1 |
| 570c78f6807f | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |
| 5f1d835448f1 | `Anchor.Domain.Placement.render/1` | narrow_clause | killed | 2 |

### Mutants

#### 277b66ae1e69 Anchor.Domain.Placement.all_proposals/3 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -468,7 +468,7 @@
       end)
 
     unreachable =
-      if placement.precision.reachability == :precise,
+      if Process.get(:__anchor_sabotage__) == nil,
         do: Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap())),
         else: []
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 11 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2

```
test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [proposal] = proposals(modules, [])
left:  [proposal]
right: [%Anchor.Domain.Proposal{level: :function, subject: {Fmt, :line, 1}, current: Fmt, proposed: Inv.Line, rule: :function_placement, reason: :output_type_owner, evidence: ["it returns %Inv.Line{}"], key: "function_placement|function|Fmt.line/1|Inv.Line"}, %Anchor.Domain.Proposal{level: :function, subject: {Fmt, :line, 1}, current: Fmt, proposed: :delete, rule: :reachable_from_root, reason: :unreachable, evidence: [], key: "reachable_from_root|function|Fmt.line/1|delete"}]

```

#### d333d0763127 Anchor.Domain.Placement.all_proposals/3 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -468,7 +468,7 @@
       end)
 
     unreachable =
-      if placement.precision.reachability == :precise,
+      if Process.get(:__anchor_sabotage__) != nil,
         do: Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap())),
         else: []
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged

```
test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [proposal] = proposals(modules, [], :reachable_from_root)
left:  [proposal]
right: []

```

#### 85a08391315e Anchor.Domain.Placement.facts_for_ownership/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -374,8 +374,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(mfa, _function, _node) do
+    mfa
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 39 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key

```
test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### 949ab649ed66 Anchor.Domain.Placement.facts_for_ownership/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -374,8 +374,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(_mfa, _function, node) do
+    node
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 39 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal

```
test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### c5f6149da727 Anchor.Domain.Placement.facts_for_ownership/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -374,8 +374,8 @@
     end
   end
 
-  defp facts_for_ownership(mfa, function, node) do
-    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
+  defp facts_for_ownership(_mfa, function, _node) do
+    function
   end
 
   defp answers(graph, mfa, function) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 39 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots, test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:111 test build/1 no roots, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named, test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown, test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated; unknown reads as generated

```
test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.Rules.movable?/3
```

#### 012f0816781c Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -281,7 +281,7 @@
 
   # --- the sentence before the Fix ------------------------------------------------
 
-  defp headline(%Proposal{rule: :effects_match_bucket} = proposal, model) do
+  defp headline(%Proposal{rule: :effects_match_bucket} = proposal, model) when node() == :__anchor_sabotage_never__ do
     {module, _f, _a} = proposal.subject
     %Classification{bucket: name, role: bucket_role} = model.classification[module]
     prefix = "#{subject(proposal)} is in bucket #{name}"
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:797 test to_violation/3 each effects sentence names the bucket and what the inference found

```
test/anchor/domain/placement_test.exs:797 test to_violation/3 each effects sentence names the bucket and what the inference found
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 077f40d4c88d Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -294,7 +294,7 @@
   defp headline(
          %Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> owner]} = p,
          _model
-       ),
+       ) when node() == :__anchor_sabotage_never__,
        do: "#{subject(p)} sits in #{p.current}, but only #{owner} reaches it."
 
   defp headline(%Proposal{reason: :shared_module} = proposal, _model),
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (MatchError) no match of right hand side value:

    U2

```

#### 55d61fedae64 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -303,7 +303,7 @@
   defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
     do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."
 
-  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
+  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do:
       "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)

```
test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 5719f376c45a Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -307,7 +307,7 @@
     do:
       "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
 
-  defp headline(%Proposal{reason: reason} = proposal, model) do
+  defp headline(%Proposal{reason: reason} = proposal, model) when node() == :__anchor_sabotage_never__ do
     {module, _f, _a} = proposal.subject
 
     "#{subject(proposal)} is in #{inspect(module)}#{bucket_note(module, model)}, but " <>
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix

```
test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.headline/2
```

#### 63b28b7d77e9 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -300,7 +300,7 @@
   defp headline(%Proposal{reason: :shared_module} = proposal, _model),
     do: "#{subject(proposal)} is shared: no one module reaches it."
 
-  defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
+  defp headline(%Proposal{reason: :inert_directory} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."
 
   defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (MatchError) no match of right hand side value:

    "lib/b/domain/util"

```

#### 949017d334f5 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -297,7 +297,7 @@
        ),
        do: "#{subject(p)} sits in #{p.current}, but only #{owner} reaches it."
 
-  defp headline(%Proposal{reason: :shared_module} = proposal, _model),
+  defp headline(%Proposal{reason: :shared_module} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do: "#{subject(proposal)} is shared: no one module reaches it."
 
   defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (MatchError) no match of right hand side value:

    U1

```

#### dd25c0fd8b03 Anchor.Domain.Placement.headline/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -288,7 +288,7 @@
     prefix <> effects_clause(bucket_role, inferred(proposal), proposal)
   end
 
-  defp headline(%Proposal{reason: :unreachable} = proposal, _model),
+  defp headline(%Proposal{reason: :unreachable} = proposal, _model) when node() == :__anchor_sabotage_never__,
     do: "#{subject(proposal)} is public and no root reaches it."
 
   defp headline(
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.owner_clause/2
```

#### 428d87b5fe63 Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -301,7 +301,7 @@
     do: "#{subject(proposal)} is shared: no one module reaches it."
 
   defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
-    do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."
+    do: proposal
 
   defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
     do:
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :directory, subject: "lib/b/domain/util", current: "lib/b/domain/util", proposed: "lib/b/domain", rule: :directory_placement, reason: :inert_directory, evidence: ["dominated by U1"], key: "directory_placement|directory|lib/b/domain/util|lib/b/domain"}
```

#### 60f67d3721cc Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -303,9 +303,9 @@
   defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
     do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."
 
-  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
-    do:
-      "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."
+  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, _to}} = proposal, _model),
+    do:
+      proposal
 
   defp headline(%Proposal{reason: reason} = proposal, model) do
     {module, _f, _a} = proposal.subject
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)

```
test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: {:inline, {N, :g, 1}}, rule: :function_placement, reason: :inert_hop, evidence: ["forwards to N.g/1", "callers: A.x/1"], key: "function_placement|function|x|y"}
```

#### cf56795bbaaa Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -292,10 +292,10 @@
     do: "#{subject(proposal)} is public and no root reaches it."
 
   defp headline(
-         %Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> owner]} = p,
-         _model
-       ),
-       do: "#{subject(p)} sits in #{p.current}, but only #{owner} reaches it."
+         %Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> _owner]} = p,
+         _model
+       ),
+       do: p
 
   defp headline(%Proposal{reason: :shared_module} = proposal, _model),
     do: "#{subject(proposal)} is shared: no one module reaches it."
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :directory, subject: U2, current: "lib/b/domain/util", proposed: "lib/b/domain/util/u1", rule: :directory_placement, reason: :dominator_subtree, evidence: ["dominated by U1"], key: "directory_placement|directory|U2|lib/b/domain/util/u1"}
```

#### e90b6eb0799b Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -298,7 +298,7 @@
        do: "#{subject(p)} sits in #{p.current}, but only #{owner} reaches it."
 
   defp headline(%Proposal{reason: :shared_module} = proposal, _model),
-    do: "#{subject(proposal)} is shared: no one module reaches it."
+    do: proposal
 
   defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
     do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :directory, subject: U1, current: "lib/b/domain/util", proposed: "lib/b/domain/util/u1", rule: :directory_placement, reason: :shared_module, evidence: ["reached from 2 x"], key: "directory_placement|directory|U2|lib/b/domain/util/u1"}
```

#### fec197a5219c Anchor.Domain.Placement.headline/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -289,7 +289,7 @@
   end
 
   defp headline(%Proposal{reason: :unreachable} = proposal, _model),
-    do: "#{subject(proposal)} is public and no root reaches it."
+    do: proposal
 
   defp headline(
          %Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> owner]} = p,
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence
** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: %Anchor.Domain.Proposal{level: :function, subject: {F, :line, 1}, current: F, proposed: :delete, rule: :function_placement, reason: :unreachable, evidence: [], key: "function_placement|function|x|y"}
```

#### 048b308e5ac9 Anchor.Domain.Placement.proposals/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -144,7 +144,7 @@
   `:reachable_from_root` lists none.
   """
   @spec proposals(t(), Model.t(), selection()) :: [Proposal.t()]
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
+  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when (level in @levels) and node() == :__anchor_sabotage_never__,
     do: Enum.filter(proposals, &(&1.level == level))
 
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 16 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4

```
test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.proposals/3
```

#### 9747e354f3a9 Anchor.Domain.Placement.proposals/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -147,7 +147,7 @@
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
     do: Enum.filter(proposals, &(&1.level == level))
 
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
+  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when (rule in @rules) and node() == :__anchor_sabotage_never__,
     do: Enum.filter(proposals, &(&1.rule == rule))
 
   @doc "The one line a placement `Fix:` carries. An unknown reason raises: no default text."
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 15 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved

```
test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.proposals/3
```

#### 0a17e4bb26d8 Anchor.Domain.Placement.proposals/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -147,8 +147,8 @@
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
     do: Enum.filter(proposals, &(&1.level == level))
 
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
-    do: Enum.filter(proposals, &(&1.rule == rule))
+  def proposals(%__MODULE__{proposals: _proposals}, %Model{}, rule) when rule in @rules,
+    do: rule
 
   @doc "The one line a placement `Fix:` carries. An unknown reason raises: no default text."
   @spec render(Proposal.t()) :: String.t()
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 15 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key, test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4, test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3, test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete; a private one is not judged, test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved, test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved, test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved, test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module, test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved, test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it, test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable, test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved, test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private, test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision, test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed

```
test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [%{reason: :output_type_owner}] = Placement.proposals(placement, model, :function_placement)
left:  [%{reason: :output_type_owner}]
right: :function_placement

```

#### afb75bf63ede Anchor.Domain.Placement.proposals/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -144,8 +144,8 @@
   `:reachable_from_root` lists none.
   """
   @spec proposals(t(), Model.t(), selection()) :: [Proposal.t()]
-  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
-    do: Enum.filter(proposals, &(&1.level == level))
+  def proposals(%__MODULE__{proposals: _proposals}, %Model{}, level) when level in @levels,
+    do: level
 
   def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
     do: Enum.filter(proposals, &(&1.rule == rule))
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 16 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice, test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has, test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift, test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4, test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2, test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket, test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket, test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there, test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal, test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4, test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal, test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name, test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner, test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal, test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own; :function lists every one, sorted by key

```
test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [proposal] = proposals(modules, [])
left:  [proposal]
right: :function

```

#### 02d3e964ec8d Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -174,7 +174,7 @@
       "#{inspect(owner)} calls it)"
   end
 
-  def render(%Proposal{reason: :unreachable} = proposal) do
+  def render(%Proposal{reason: :unreachable} = proposal) when node() == :__anchor_sabotage_never__ do
     "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
   end
 
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative, test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence

```
test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 33f4c97ab9a1 Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -164,7 +164,7 @@
       "owner of a type holds its transitions)"
   end
 
-  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) do
+  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) when node() == :__anchor_sabotage_never__ do
     "move #{subject(proposal)} to #{inspect(owner)} (its result is computed from " <>
       "%#{inspect(owner)}{})"
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix, test/anchor/domain/placement_test.exs:569 test render/1 input owner text

```
test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 42eaacb5daf7 Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -183,7 +183,7 @@
       "#{owner} is the directory's public module)"
   end
 
-  def render(%Proposal{reason: :shared_module, proposed: {:library_context, contexts}} = p),
+  def render(%Proposal{reason: :shared_module, proposed: {:library_context, contexts}} = p) when node() == :__anchor_sabotage_never__,
     do: "move #{subject(p)} to a library context used by #{Enum.join(contexts, ", ")}"
 
   def render(%Proposal{reason: :shared_module, evidence: [reached | notes]} = p) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:613 test render/1 directory texts (DND-5462)

```
test/anchor/domain/placement_test.exs:613 test render/1 directory texts (DND-5462)
** (Protocol.UndefinedError) protocol String.Chars not implemented for Tuple. This protocol is implemented for: Atom, BitString, Date, DateTime, Decimal, Float, Integer, List, NaiveDateTime, Time, URI, Version, Version.Requirement

Got value:

    {:library_context, ["b", "c"]}

```

#### 570c78f6807f Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -196,7 +196,7 @@
   def render(%Proposal{reason: :inert_directory} = p),
     do: "flatten #{p.subject} into #{p.proposed} (no module in it is reached only through it)"
 
-  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
+  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) when node() == :__anchor_sabotage_never__ do
     "inline #{subject(p)}: its callers (#{String.replace_prefix(callers, "callers: ", "")}) " <>
       "call #{ViolationKey.mfa(to)} directly (it forwards without crossing a bucket, context, " <>
       "app, aggregate, interface or callback boundary)"
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461), test/anchor/domain/placement_test.exs:597 test render/1 inert hop text names the callers and the target (DND-5461)

```
test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

#### 5f1d835448f1 Anchor.Domain.Placement.render/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/placement.ex
+++ b/lib/anchor/domain/placement.ex
@@ -193,7 +193,7 @@
       "not a private helper)" <> Enum.map_join(notes, &"; #{&1}")
   end
 
-  def render(%Proposal{reason: :inert_directory} = p),
+  def render(%Proposal{reason: :inert_directory} = p) when node() == :__anchor_sabotage_never__,
     do: "flatten #{p.subject} into #{p.proposed} (no module in it is reached only through it)"
 
   def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
```

Command: `mix test --max-cases 2 test/anchor/domain/placement_test.exs` (58 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462), test/anchor/domain/placement_test.exs:613 test render/1 directory texts (DND-5462)

```
test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule; a directory's on its first file (DND-5462)
** (FunctionClauseError) no function clause matching in Anchor.Domain.Placement.render/1
```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Placement.build/1 delete_statement `effects = model.effects() || Effects.infer(model)`: orphans variable `effects` bound at line 117 and used at line 118
- skipped Anchor.Domain.Placement.build/1 delete_statement `roots = MapSet.union(effects.roots(), public_macros(model))`: orphans variable `roots` bound at line 118 and used at line 120
- skipped Anchor.Domain.Placement.build/1 delete_statement `calls = CallGraph.build(model.graph())`: orphans variable `calls` bound at line 119 and used at line 120
- skipped Anchor.Domain.Placement.build/1 delete_statement `dominators = dominators(calls.digraph(), roots)`: orphans variable `dominators` bound at line 120 and used at line 121
- skipped Anchor.Domain.Placement.build/1 delete_statement `reachable = dominators.idom() |> Map.keys() |> MapSet.new()`: orphans variable `reachable` bound at line 121 and used at line 126
- skipped Anchor.Domain.Placement.build/1 delete_statement `answers = ownership(model, effects, roots)`: orphans variable `answers` bound at line 123 and used at line 124
- skipped Anchor.Domain.Placement.build/1 delete_statement `functions = facts(model, effects, calls, dominators, answers)`: orphans variable `functions` bound at line 124 and used at line 126
- skipped Anchor.Domain.Placement.build/1 delete_statement `placement = %__MODULE__{
  functions: functions,
  roots: roots,
  idom: dominators.idom(),
  reachable: reachable,
  precision: precision(model, functions, answers, calls, reachable, effects.roots())
}`: orphans variable `placement` bound at line 126 and used at line 134
- skipped Anchor.Domain.Placement.build/1 return_input [0] `build(%Model{} = model)`: removes the last use of function `all_proposals/3`
- skipped Anchor.Domain.Placement.render/1 return_input [0] `render(%Proposal{reason: :bucket_from_effects, proposed: {:bucket, role, context, module}} = p)`: removes the last use of function `named/1`
- skipped Anchor.Domain.Placement.render/1 delete_statement `count = reached |> String.split(" ") |> Enum.at(2)`: orphans variable `count` bound at line 190 and used at line 192
- skipped Anchor.Domain.Placement.to_violation/3 delete_statement `module = proposal |> subject_modules(model) |> hd()`: orphans variable `module` bound at line 213 and used at line 215
- skipped Anchor.Domain.Placement.to_violation/3 return_input [0] `to_violation(%Proposal{subject: subject} = proposal, %Model{} = model, rule)
when is_atom(subject) or is_binary(subject)`: the guard reads `subject`, which the mutant renames `_subject`
- skipped Anchor.Domain.Placement.to_violation/3 return_input [1] `to_violation(%Proposal{subject: subject} = proposal, %Model{} = model, rule)
when is_atom(subject) or is_binary(subject)`: the guard reads `subject`, which the mutant renames `_subject`
- skipped Anchor.Domain.Placement.to_violation/3 return_input [2] `to_violation(%Proposal{subject: subject} = proposal, %Model{} = model, rule)
when is_atom(subject) or is_binary(subject)`: the guard reads `subject`, which the mutant renames `_subject`
- skipped Anchor.Domain.Placement.to_violation/3 return_input [0] `to_violation(%Proposal{subject: {module, name, arity} = mfa} = proposal, %Model{} = model, rule)`: removes the last use of function `line/3`
- skipped Anchor.Domain.Placement.to_violation/3 return_input [1] `to_violation(%Proposal{subject: {module, name, arity} = mfa} = proposal, %Model{} = model, rule)`: removes the last use of function `line/3`
- skipped Anchor.Domain.Placement.to_violation/3 return_input [2] `to_violation(%Proposal{subject: {module, name, arity} = mfa} = proposal, %Model{} = model, rule)`: removes the last use of function `line/3`
- skipped Anchor.Domain.Placement.headline/2 delete_statement `{module, _f, _a} = proposal.subject()`: orphans variable `module` bound at line 285 and used at line 286
- skipped Anchor.Domain.Placement.headline/2 delete_statement `%Classification{bucket: name, role: bucket_role} = model.classification()[module]`: orphans variable `bucket_role` bound at line 286 and used at line 288
- skipped Anchor.Domain.Placement.headline/2 delete_statement `prefix = "#{subject(proposal)} is in bucket #{name}"`: orphans variable `prefix` bound at line 287 and used at line 288
- skipped Anchor.Domain.Placement.headline/2 return_input [0] `headline(%Proposal{rule: :effects_match_bucket} = proposal, model)`: removes the last use of function `effects_clause/3`
- skipped Anchor.Domain.Placement.headline/2 return_input [1] `headline(%Proposal{rule: :effects_match_bucket} = proposal, model)`: removes the last use of function `effects_clause/3`
- skipped Anchor.Domain.Placement.headline/2 delete_statement `{module, _f, _a} = proposal.subject()`: orphans variable `module` bound at line 311 and used at line 313
- skipped Anchor.Domain.Placement.headline/2 return_input [0] `headline(%Proposal{reason: reason} = proposal, model)`: removes the last use of function `bucket_note/2`
- skipped Anchor.Domain.Placement.headline/2 return_input [1] `headline(%Proposal{reason: reason} = proposal, model)`: removes the last use of function `bucket_note/2`
- skipped Anchor.Domain.Placement.facts_of/7 delete_statement `idom = Map.get(dominators.idom(), mfa)`: orphans variable `idom` bound at line 401 and used at line 404
- skipped Anchor.Domain.Placement.facts_of/7 delete_statement `answer = Map.get(answers, mfa, %{output: :none, input: :none})`: orphans variable `answer` bound at line 402 and used at line 404
- skipped Anchor.Domain.Placement.facts_of/7 return_input [0] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [1] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [2] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [3] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [4] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [5] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.facts_of/7 return_input [6] `facts_of(mfa, function, node, effects, calls, dominators, answers)`: removes the last use of function `owner_of/1`
- skipped Anchor.Domain.Placement.precision/6 delete_statement `outcomes = answers |> Map.values() |> Enum.flat_map(&[&1.output(), &1.input()])`: orphans variable `outcomes` bound at line 437 and used at line 439
- skipped Anchor.Domain.Placement.precision/6 return_input [0] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.precision/6 return_input [1] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.precision/6 return_input [2] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.precision/6 return_input [3] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.precision/6 return_input [4] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.precision/6 return_input [5] `precision(model, functions, answers, calls, reachable, roots)`: removes the last use of function `reachability/3`
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `facts = functions |> Map.values() |> Enum.sort_by(& &1.mfa())`: orphans variable `facts` bound at line 463 and used at line 465
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `function_rules =
  Enum.flat_map(facts, fn fact ->
    fact |> Rules.placement(placement, model, effects) |> List.wrap()
  end)`: orphans variable `function_rules` bound at line 465 and used at line 478
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `unreachable =
  if placement.precision().reachability() == :precise do
    Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap()))
  else
    []
  end`: orphans variable `unreachable` bound at line 470 and used at line 478
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `hops = Forwarders.proposals(%{model | effects: effects})`: orphans variable `hops` bound at line 475 and used at line 478
- skipped Anchor.Domain.Placement.all_proposals/3 delete_statement `directories = Directories.proposals(placement, model, nil)`: orphans variable `directories` bound at line 476 and used at line 478
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [0] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [1] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.all_proposals/3 return_input [2] `all_proposals(%__MODULE__{functions: functions} = placement, model, effects)`: removes the last use of alias `Forwarders`
- skipped Anchor.Domain.Placement.Directories.module_dominators/1 delete_statement `root_modules = roots |> Enum.map(&elem(&1, 0)) |> Enum.uniq()`: orphans variable `root_modules` bound at line 56 and used at line 65
- skipped Anchor.Domain.Placement.Directories.module_dominators/1 delete_statement `edges =
  for {{to, _f, _a}, facts} <- functions,
      {from, _g, _b} <- facts.callers(),
      from != to,
      uniq: true,
      do: {from, to}`: orphans variable `edges` bound at line 58 and used at line 65
- skipped Anchor.Domain.Placement.Directories.module_dominators/1 delete_statement `nodes =
  Enum.uniq(
    Enum.map(Map.keys(functions), &elem(&1, 0)) ++
      root_modules ++ Enum.flat_map(edges, &Tuple.to_list/1)
  )`: orphans variable `nodes` bound at line 65 and used at line 73
- skipped Anchor.Domain.Placement.Directories.bucket_root/3 delete_statement `dirs =
  for {_module, %Classification{bucket: ^bucket, context: ^context, source_file: file}} <-
        classification,
      is_binary(file) do
    file |> Path.dirname() |> Path.split()
  end`: orphans variable `dirs` bound at line 82 and used at line 88
- skipped Anchor.Domain.Placement.Directories.bucket_root/3 return_input [1] `bucket_root(%Model{classification: classification}, bucket, context)`: removes the last use of function `common_prefix/2`
- skipped Anchor.Domain.Placement.Directories.bucket_root/3 return_input [2] `bucket_root(%Model{classification: classification}, bucket, context)`: removes the last use of function `common_prefix/2`
- skipped Anchor.Domain.Placement.Directories.proposals/3 delete_statement `idom = module_dominators(placement)`: orphans variable `idom` bound at line 102 and used at line 106
- skipped Anchor.Domain.Placement.Directories.proposals/3 delete_statement `root_modules = placement.roots() |> Enum.map(&elem(&1, 0)) |> MapSet.new()`: orphans variable `root_modules` bound at line 103 and used at line 106
- skipped Anchor.Domain.Placement.Directories.proposals/3 delete_statement `callers = module_callers(placement)`: orphans variable `callers` bound at line 104 and used at line 106
- skipped Anchor.Domain.Placement.Directories.proposals/3 delete_statement `moves =
  for {module, dominator} <- idom,
      placed?(model, module),
      proposal <-
        List.wrap(module_proposal(model, module, dominator, root_modules, callers, evidence)) do
    proposal
  end`: orphans variable `moves` bound at line 106 and used at line 113
- skipped Anchor.Domain.Placement.Directories.proposals/3 return_input [0] `proposals(%Placement{} = placement, %Model{} = model, evidence)`: removes the last use of function `flattens/2`
- skipped Anchor.Domain.Placement.Directories.proposals/3 return_input [1] `proposals(%Placement{} = placement, %Model{} = model, evidence)`: removes the last use of function `flattens/2`
- skipped Anchor.Domain.Placement.Directories.proposals/3 return_input [2] `proposals(%Placement{} = placement, %Model{} = model, evidence)`: removes the last use of function `flattens/2`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 force_condition [true] `dominator == Digraph.virtual_root() and not MapSet.member?(root_modules, module)`: leaves variable `root_modules` bound at line 118 unused
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 force_condition [false] `dominator == Digraph.virtual_root() and not MapSet.member?(root_modules, module)`: leaves variable `root_modules` bound at line 118 unused
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [0] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [1] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [2] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [3] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [4] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.module_proposal/6 return_input [5] `module_proposal(model, module, dominator, root_modules, callers, evidence)`: removes the last use of function `interior/3`
- skipped Anchor.Domain.Placement.Directories.interior/3 delete_statement `class = model.classification()[module]`: orphans variable `class` bound at line 132 and used at line 134
- skipped Anchor.Domain.Placement.Directories.interior/3 delete_statement `companion = Path.rootname(owner.source_file())`: orphans variable `companion` bound at line 138 and used at line 141
- skipped Anchor.Domain.Placement.Directories.interior/3 delete_statement `current = Path.dirname(class.source_file())`: orphans variable `current` bound at line 139 and used at line 141
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `class = model.classification()[module]`: orphans variable `class` bound at line 152 and used at line 153
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `current = Path.dirname(class.source_file())`: orphans variable `current` bound at line 153 and used at line 179
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `contexts =
  callers
  |> Enum.map(&Map.get(model.classification(), &1))
  |> Enum.reject(&is_nil/1)
  |> Enum.map(& &1.context())
  |> Enum.uniq()
  |> Enum.sort()`: orphans variable `contexts` bound at line 155 and used at line 166
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `reached =
  "reached from #{length(callers)} unrelated callers: #{Enum.map_join(callers, ", ", &inspect/1)}"`: orphans variable `reached` bound at line 163 and used at line 184
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `root = bucket_root(model, class.bucket(), context)`: orphans variable `root` bound at line 168 and used at line 170
- skipped Anchor.Domain.Placement.Directories.shared/4 delete_statement `candidates = [
  root
  | callers
    |> Enum.map(&caller_dir(model, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
]`: orphans variable `candidates` bound at line 170 and used at line 179
- skipped Anchor.Domain.Placement.Directories.shared/4 return_input [0] `shared(model, module, callers, evidence)`: removes the last use of alias `TieBreak`
- skipped Anchor.Domain.Placement.Directories.shared/4 return_input [1] `shared(model, module, callers, evidence)`: removes the last use of alias `TieBreak`
- skipped Anchor.Domain.Placement.Directories.shared/4 return_input [2] `shared(model, module, callers, evidence)`: removes the last use of alias `TieBreak`
- skipped Anchor.Domain.Placement.Directories.shared/4 return_input [3] `shared(model, module, callers, evidence)`: removes the last use of alias `TieBreak`
- skipped Anchor.Domain.Placement.Directories.module_callers/1 delete_statement `edges =
  for {{to, _f, _a}, facts} <- functions,
      {from, _g, _b} <- facts.callers(),
      from != to,
      uniq: true,
      do: {to, from}`: orphans variable `edges` bound at line 205 and used at line 212
- skipped Anchor.Domain.Placement.Directories.flattens/2 return_input [0] `flattens(model, idom)`: removes the last use of function `flatten/4`
- skipped Anchor.Domain.Placement.Directories.flattens/2 return_input [1] `flattens(model, idom)`: removes the last use of function `flatten/4`
- skipped Anchor.Domain.Placement.Directories.flatten/4 delete_statement `classes = Enum.map(modules, &model.classification()[&1])`: orphans variable `classes` bound at line 230 and used at line 231
- skipped Anchor.Domain.Placement.Directories.flatten/4 delete_statement `places = classes |> Enum.map(&{&1.bucket(), &1.context()}) |> Enum.uniq()`: orphans variable `places` bound at line 231 and used at line 233
- skipped Anchor.Domain.Placement.Directories.flatten/4 with_passthrough `[_, _ | _] <- modules`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Directories.flatten/4 with_passthrough `[{bucket, context}] <- places`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Directories.flatten/4 return_input [0] `flatten(model, idom, dir, modules)`: removes the last use of function `dominated_inside?/3`
- skipped Anchor.Domain.Placement.Directories.flatten/4 return_input [1] `flatten(model, idom, dir, modules)`: removes the last use of function `dominated_inside?/3`
- skipped Anchor.Domain.Placement.Directories.flatten/4 return_input [2] `flatten(model, idom, dir, modules)`: removes the last use of function `dominated_inside?/3`
- skipped Anchor.Domain.Placement.Directories.flatten/4 return_input [3] `flatten(model, idom, dir, modules)`: removes the last use of function `dominated_inside?/3`
- skipped Anchor.Domain.Placement.Directories.placed?/2 return_input [1] `placed?(%Model{graph: graph, classification: classification}, module)`: removes the last use of alias `ModuleNode`
- skipped Anchor.Domain.Placement.Forwarders.forwarder/1 delete_statement `params = Enum.map(:cerl.fun_vars(core), &:cerl.var_name/1)`: orphans variable `params` bound at line 80 and used at line 82
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 delete_statement `from_class = Map.get(model.classification(), from_module)`: orphans variable `from_class` bound at line 92 and used at line 95
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 delete_statement `to_class = Map.get(model.classification(), to_module)`: orphans variable `to_class` bound at line 93 and used at line 95
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 return_input [0] `boundary(%Model{} = model, {from_module, _f, _a} = from, {to_module, _g, _b})`: removes the last use of function `classified_boundary/4`
- skipped Anchor.Domain.Placement.Forwarders.boundary/3 return_input [1] `boundary(%Model{} = model, {from_module, _f, _a} = from, {to_module, _g, _b})`: removes the last use of function `classified_boundary/4`
- skipped Anchor.Domain.Placement.Forwarders.proposals/1 delete_statement `callers = static_callers(graph.calls())`: orphans variable `callers` bound at line 105 and used at line 107
- skipped Anchor.Domain.Placement.Forwarders.proposals/1 return_input [0] `proposals(%Model{graph: graph} = model)`: removes the last use of alias `Placement`
- skipped Anchor.Domain.Placement.Forwarders.forwarded_call/2 return_input [0] `forwarded_call(body, params)`: removes the last use of function `case_forward/2`
- skipped Anchor.Domain.Placement.Forwarders.forwarded_call/2 return_input [1] `forwarded_call(body, params)`: removes the last use of function `case_forward/2`
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough `[clause] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1)`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 return_input [0] `case_forward(body, params)`: removes the last use of function `compiler_generated?/1`
- skipped Anchor.Domain.Placement.Forwarders.case_forward/2 return_input [1] `case_forward(body, params)`: removes the last use of function `compiler_generated?/1`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [0] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [1] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.call_of/3 return_input [2] `call_of(body, params, renames)`: removes the last use of function `forwarding_call/3`
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 delete_statement `renames = Map.put(renames, :cerl.var_name(var), Map.get(renames, name, name))`: leaves variable `name` bound at line 165 unused
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 with_passthrough `[var] <- :cerl.let_vars(body)`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.renaming_let/3 with_passthrough `[name] <- vars(case_values(:cerl.let_arg(body)))`: the pattern has nothing to relax
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 force_condition [true] `Enum.map(args, &Map.get(renames, &1, &1)) == params`: leaves variable `args` bound at line 175 unused
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 force_condition [false] `Enum.map(args, &Map.get(renames, &1, &1)) == params`: leaves variable `args` bound at line 175 unused
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [0] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [1] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.forwarding_call/3 return_input [2] `forwarding_call(call, params, renames)`: removes the last use of function `literal_mfa/1`
- skipped Anchor.Domain.Placement.Forwarders.literal_mfa/1 delete_statement `module = :cerl.call_module(call)`: orphans variable `module` bound at line 182 and used at line 185
- skipped Anchor.Domain.Placement.Forwarders.literal_mfa/1 delete_statement `name = :cerl.call_name(call)`: orphans variable `name` bound at line 183 and used at line 185
- skipped Anchor.Domain.Placement.Forwarders.defaults?/3 return_input [1] `defaults?(%ModuleNode{functions: functions}, name, arity)`: removes the last use of function `default_clause?/2`
- skipped Anchor.Domain.Placement.Forwarders.defaults?/3 return_input [2] `defaults?(%ModuleNode{functions: functions}, name, arity)`: removes the last use of function `default_clause?/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `app(model, from_class) != app(model, to_class)`: removes the last use of function `app/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `app(model, from_class) != app(model, to_class)`: removes the last use of function `app/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `aggregates(model, from_class.module()) != aggregates(model, to_class.module())`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `aggregates(model, from_class.module()) != aggregates(model, to_class.module())`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true] `callback?(model, from)`: leaves variable `from` bound at line 205 unused
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false] `callback?(model, from)`: leaves variable `from` bound at line 205 unused
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [0] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [1] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [2] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.classified_boundary/4 return_input [3] `classified_boundary(model, from, %Classification{} = from_class, to_class)`: removes the last use of function `aggregates/2`
- skipped Anchor.Domain.Placement.Forwarders.aggregates/2 delete_statement `schemas =
  if Map.has_key?(index.by_schema(), module) do
    [index.by_schema()[module]]
  else
    []
  end`: orphans variable `schemas` bound at line 238 and used at line 239
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 delete_statement `%ModuleNode{behaviours: behaviours} = Map.fetch!(graph.modules(), module)`: orphans variable `behaviours` bound at line 243 and used at line 246
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 delete_statement `external =
  if model.effects() do
    model.effects().callbacks()
  else
    %{}
  end`: orphans variable `external` bound at line 244 and used at line 246
- skipped Anchor.Domain.Placement.Forwarders.callback?/2 return_input [0] `callback?(%Model{graph: graph} = model, {module, name, arity})`: removes the last use of function `behaviour_callbacks/3`
- skipped Anchor.Domain.Placement.Forwarders.static_callers/1 return_input [0] `static_callers(calls)`: removes the last use of function `static_caller?/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [0] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [1] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- skipped Anchor.Domain.Placement.Forwarders.proposal/3 return_input [2] `proposal({module, _name, _arity} = subject, to, callers)`: removes the last use of function `callers_text/1`
- a6064585391e Anchor.Domain.Placement.render/1 narrow_clause: not run (cap)
- b7334a94d76d Anchor.Domain.Placement.render/1 narrow_clause: not run (cap)
- c24c0c18145d Anchor.Domain.Placement.render/1 narrow_clause: not run (cap)
- c8a2eba1999e Anchor.Domain.Placement.render/1 narrow_clause: not run (cap)
- e55c9a9560d1 Anchor.Domain.Placement.render/1 narrow_clause: not run (cap)
- 12e27c584e24 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 25219facae5a Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 2f49b6f02818 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 4b47690e7359 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 60147a00d689 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 6fb9a585397d Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 8794eb1da0b5 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- cf0d4c05971f Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- f0d904411d65 Anchor.Domain.Placement.render/1 return_input [0]: not run (cap)
- 06e1729589eb Anchor.Domain.Placement.subject/1 narrow_clause: not run (cap)
- c7d73be627ea Anchor.Domain.Placement.subject/1 narrow_clause: not run (cap)
- fb4d1df3d63d Anchor.Domain.Placement.subject/1 narrow_clause: not run (cap)
- 7bd10b38434e Anchor.Domain.Placement.subject_modules/2 narrow_clause: not run (cap)
- c642db42e66c Anchor.Domain.Placement.subject_modules/2 narrow_clause: not run (cap)
- cdefefef1d3f Anchor.Domain.Placement.subject_modules/2 narrow_clause: not run (cap)
- 1086ecc8ff3f Anchor.Domain.Placement.to_violation/3 narrow_clause: not run (cap)
- 8eee31629aab Anchor.Domain.Placement.to_violation/3 narrow_clause: not run (cap)
- 8ea8ca365c6a Anchor.Domain.Placement.Directories.bucket_root/3 narrow_clause: not run (cap)
- fc67171e72f2 Anchor.Domain.Placement.Directories.bucket_root/3 narrow_clause: not run (cap)
- 1acbaa997ad6 Anchor.Domain.Placement.Directories.caller_dir/2 narrow_clause: not run (cap)
- 3ba99e5d8832 Anchor.Domain.Placement.Directories.caller_dir/2 narrow_clause: not run (cap)
- 0a8f5896b004 Anchor.Domain.Placement.Directories.caller_dir/2 return_input [1]: not run (cap)
- fd75614202a7 Anchor.Domain.Placement.Directories.caller_dir/2 return_input [0]: not run (cap)
- 04271084449f Anchor.Domain.Placement.Directories.common_prefix/2 return_input [0]: not run (cap)
- 0f8fc6156c0a Anchor.Domain.Placement.Directories.common_prefix/2 return_input [1]: not run (cap)
- 82b8a6dede0d Anchor.Domain.Placement.Directories.dominated_inside?/3 narrow_clause: not run (cap)
- d0ea866991fc Anchor.Domain.Placement.Directories.dominated_inside?/3 narrow_clause: not run (cap)
- 7dee3ffcd6b5 Anchor.Domain.Placement.Directories.dominated_inside?/3 return_input [1]: not run (cap)
- 8120aa86bf3b Anchor.Domain.Placement.Directories.dominated_inside?/3 return_input [0]: not run (cap)
- ee1340e9e614 Anchor.Domain.Placement.Directories.dominated_inside?/3 return_input [2]: not run (cap)
- aa10879d1cfc Anchor.Domain.Placement.Directories.flatten/4 with_passthrough: not run (cap)
- af452778c5e3 Anchor.Domain.Placement.Directories.flatten/4 with_passthrough: not run (cap)
- bd615eb61ecf Anchor.Domain.Placement.Directories.flatten/4 with_passthrough: not run (cap)
- c3656d69f8b0 Anchor.Domain.Placement.Directories.flatten/4 with_passthrough: not run (cap)
- 59ec9bf350a8 Anchor.Domain.Placement.Directories.interior/3 force_condition [false]: not run (cap)
- f90adebaddfc Anchor.Domain.Placement.Directories.interior/3 force_condition [true]: not run (cap)
- 994b120ecad0 Anchor.Domain.Placement.Directories.interior/3 return_input [1]: not run (cap)
- bf305aa6efc4 Anchor.Domain.Placement.Directories.interior/3 return_input [0]: not run (cap)
- ee9dbeb63905 Anchor.Domain.Placement.Directories.interior/3 return_input [2]: not run (cap)
- d9a665e8429c Anchor.Domain.Placement.Directories.interior/3 with_passthrough: not run (cap)
- e7d589ad2e86 Anchor.Domain.Placement.Directories.interior/3 with_passthrough: not run (cap)
- ebd734c8453a Anchor.Domain.Placement.Directories.interior/3 with_passthrough: not run (cap)
- 5bab70d5b21d Anchor.Domain.Placement.Directories.key/2 narrow_clause: not run (cap)
- 9d137fef258c Anchor.Domain.Placement.Directories.key/2 narrow_clause: not run (cap)
- 02dbf8e66d4d Anchor.Domain.Placement.Directories.key/2 return_input [0]: not run (cap)
- 200d9eeec2f9 Anchor.Domain.Placement.Directories.key/2 return_input [1]: not run (cap)
- 32d0d1fe3389 Anchor.Domain.Placement.Directories.key/2 return_input [0]: not run (cap)
- 731b8220b744 Anchor.Domain.Placement.Directories.module_dominators/1 force_condition [false]: not run (cap)
- d16b02160157 Anchor.Domain.Placement.Directories.module_dominators/1 force_condition [true]: not run (cap)
- 60c439c82268 Anchor.Domain.Placement.Directories.module_proposal/6 force_condition [false]: not run (cap)
- d7ec446ff7ca Anchor.Domain.Placement.Directories.module_proposal/6 force_condition [true]: not run (cap)
- 6028e29c4409 Anchor.Domain.Placement.Directories.not_placed/1 return_input [0]: not run (cap)
- 4c21f3082bc6 Anchor.Domain.Placement.Directories.proposal/5 return_input [1]: not run (cap)
- 8eed5249ba72 Anchor.Domain.Placement.Directories.proposal/5 return_input [4]: not run (cap)
- 9240721049e0 Anchor.Domain.Placement.Directories.proposal/5 return_input [2]: not run (cap)
- a53336b80cb6 Anchor.Domain.Placement.Directories.proposal/5 return_input [3]: not run (cap)
- a700410be138 Anchor.Domain.Placement.Directories.proposal/5 return_input [0]: not run (cap)
- 231bce985f11 Anchor.Domain.Placement.Directories.shared/4 narrow_clause: not run (cap)
- 3d75e5dcd523 Anchor.Domain.Placement.Directories.shared/4 narrow_clause: not run (cap)
- 786bb5e011b9 Anchor.Domain.Placement.Directories.shared/4 narrow_clause: not run (cap)
- 7962b943c5d4 Anchor.Domain.Placement.Directories.shared/4 narrow_clause: not run (cap)
- 825874c04480 Anchor.Domain.Placement.Directories.shared/4 narrow_clause: not run (cap)
- 7aaebaffa5be Anchor.Domain.Placement.Forwarders.aggregates/2 force_condition [true]: not run (cap)
- 811c51c95883 Anchor.Domain.Placement.Forwarders.aggregates/2 force_condition [false]: not run (cap)
- f2693a19d1ad Anchor.Domain.Placement.Forwarders.aggregates/2 return_input [1]: not run (cap)
- 05059cf56d4d Anchor.Domain.Placement.Forwarders.app/2 narrow_clause: not run (cap)
- aeb4c410fe05 Anchor.Domain.Placement.Forwarders.app/2 narrow_clause: not run (cap)
- 06a5d24132a0 Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 narrow_clause: not run (cap)
- 25373e8e874a Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 narrow_clause: not run (cap)
- 0c1353a007f2 Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 return_input [1]: not run (cap)
- 5d31bfee15ac Anchor.Domain.Placement.Forwarders.behaviour_callbacks/3 return_input [2]: not run (cap)
- 04bdc10f5e4b Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [true]: not run (cap)
- 6af4ef5851eb Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [true]: not run (cap)
- 78cfe0bc7be3 Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [false]: not run (cap)
- b47abaf3e080 Anchor.Domain.Placement.Forwarders.boundary/3 force_condition [false]: not run (cap)
- 05ca031f19ca Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- 1aaeb460d734 Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- 49f2c7077ba7 Anchor.Domain.Placement.Forwarders.call_of/3 narrow_clause: not run (cap)
- d5f518bcdf51 Anchor.Domain.Placement.Forwarders.callback?/2 force_condition [false]: not run (cap)
- f548005317ed Anchor.Domain.Placement.Forwarders.callback?/2 force_condition [true]: not run (cap)
- 2727474bfb49 Anchor.Domain.Placement.Forwarders.callers_text/1 narrow_clause: not run (cap)
- d883636d550e Anchor.Domain.Placement.Forwarders.callers_text/1 narrow_clause: not run (cap)
- 70d1d7fb97c9 Anchor.Domain.Placement.Forwarders.callers_text/1 return_input [0]: not run (cap)
- 0652e7670ab6 Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- 1f58d44bc12b Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- 9ea2149a5a02 Anchor.Domain.Placement.Forwarders.case_forward/2 with_passthrough: not run (cap)
- bb9734d11bcb Anchor.Domain.Placement.Forwarders.case_values/1 force_condition [false]: not run (cap)
- d9db4da270e4 Anchor.Domain.Placement.Forwarders.case_values/1 force_condition [true]: not run (cap)
- 68dad3afd7af Anchor.Domain.Placement.Forwarders.case_values/1 return_input [0]: not run (cap)
- 1deb83654910 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- 6cf287a15072 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- 9ad4e6253053 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- bdc4f42b64f1 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [true]: not run (cap)
- fb85f09c5834 Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- fcea99d83d4f Anchor.Domain.Placement.Forwarders.classified_boundary/4 force_condition [false]: not run (cap)
- 2933d35cea23 Anchor.Domain.Placement.Forwarders.compiler_generated?/1 return_input [0]: not run (cap)
- 146f7885df2d Anchor.Domain.Placement.Forwarders.default_clause?/2 narrow_clause: not run (cap)
- d10959400c8a Anchor.Domain.Placement.Forwarders.default_clause?/2 narrow_clause: not run (cap)
- cf0a8c539858 Anchor.Domain.Placement.Forwarders.default_clause?/2 return_input [1]: not run (cap)
- 0034ba660e7a Anchor.Domain.Placement.Forwarders.forwarded_call/2 narrow_clause: not run (cap)
- d64458d05282 Anchor.Domain.Placement.Forwarders.forwarded_call/2 narrow_clause: not run (cap)
- 09c8ef284a79 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 0de014dd0ca6 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 106351b05f6d Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 230325d611f8 Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- a1c5f6c2642c Anchor.Domain.Placement.Forwarders.forwarder/1 narrow_clause: not run (cap)
- 231079d02674 Anchor.Domain.Placement.Forwarders.forwarding_call/3 narrow_clause: not run (cap)
- aeff78808b15 Anchor.Domain.Placement.Forwarders.forwarding_call/3 narrow_clause: not run (cap)
- 09dcedb28646 Anchor.Domain.Placement.Forwarders.literal_mfa/1 force_condition [true]: not run (cap)
- 7cb3ed76b4d8 Anchor.Domain.Placement.Forwarders.literal_mfa/1 force_condition [false]: not run (cap)
- 420bdce8d0b4 Anchor.Domain.Placement.Forwarders.literal_mfa/1 return_input [0]: not run (cap)
- 6969ffdd6b4c Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [2]: not run (cap)
- 953e6a899baf Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [1]: not run (cap)
- badb0e17608c Anchor.Domain.Placement.Forwarders.renaming_let/3 return_input [0]: not run (cap)
- 22ba31f21f24 Anchor.Domain.Placement.Forwarders.static_caller?/1 narrow_clause: not run (cap)
- fb70e98b2a23 Anchor.Domain.Placement.Forwarders.static_caller?/1 narrow_clause: not run (cap)
- ed2135b199f1 Anchor.Domain.Placement.Forwarders.true_guard?/1 return_input [0]: not run (cap)
- 3ee930bef936 Anchor.Domain.Placement.Forwarders.vars/1 force_condition [false]: not run (cap)
- 671d3f46598d Anchor.Domain.Placement.Forwarders.vars/1 force_condition [true]: not run (cap)
- d3559a2cba20 Anchor.Domain.Placement.Forwarders.vars/1 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
277b66ae1e69	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.all_proposals/3	force_condition	killed	test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2
d333d0763127	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.all_proposals/3	force_condition	killed	test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged
85a08391315e	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key
949ab649ed66	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal
c5f6149da727	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.facts_for_ownership/3	return_input	killed	test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:116 test build/1 a macro alone is no root the inference found: still no roots ; test/anchor/domain/placement_test.exs:40 test build/1 a function two roots reach by unrelated paths is shared ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:29 test build/1 an immediate dominator inside a chain ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:111 test build/1 no roots ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:72 test build/1 a macro counts as a root ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:148 test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:56 test build/1 a capture makes its target reachable ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:63 test build/1 a dynamic call reaches the implementations, and marks them named ; test/anchor/domain/placement_test.exs:135 test build/1 precision counts the public functions whose ownership is unknown ; test/anchor/domain/placement_test.exs:122 test build/1 generated modules and macro clauses are flagged generated\; unknown reads as generated
012f0816781c	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:797 test to_violation/3 each effects sentence names the bucket and what the inference found
077f40d4c88d	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
55d61fedae64	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)
5719f376c45a	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix
63b28b7d77e9	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
949017d334f5	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
dd25c0fd8b03	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	narrow_clause	killed	test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence
428d87b5fe63	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
60f67d3721cc	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461)
cf56795bbaaa	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
e90b6eb0799b	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462)
fec197a5219c	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.headline/2	return_input	killed	test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence
048b308e5ac9	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	narrow_clause	killed	test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2 ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4
9747e354f3a9	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	narrow_clause	killed	test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved
0a17e4bb26d8	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	return_input	killed	test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key ; test/anchor/domain/placement_test.exs:378 test proposals/3 a shared function gets no move from rule 4 ; test/anchor/domain/placement_test.exs:366 test proposals/3 a shared function gets no move from rules 2 or 3 ; test/anchor/domain/placement_test.exs:489 test proposals/3 unreachable: a public function, with delete\; a private one is not judged ; test/anchor/domain/placement_test.exs:281 test proposals/3 dominated across buckets is not moved ; test/anchor/domain/placement_test.exs:353 test proposals/3 a project behaviour's callback is not moved ; test/anchor/domain/placement_test.exs:321 test proposals/3 a function its own module also calls is not moved ; test/anchor/domain/placement_test.exs:267 test proposals/3 dominated by one module ; test/anchor/domain/placement_test.exs:300 test proposals/3 dominated but called from two modules is not moved ; test/anchor/domain/placement_test.exs:437 test proposals/3 a function in its owner stays, though only another module of its bucket calls it ; test/anchor/domain/placement_test.exs:505 test proposals/3 child_spec/1 and compiler names are not unreachable ; test/anchor/domain/placement_test.exs:288 test proposals/3 dominated across contexts is not moved ; test/anchor/domain/placement_test.exs:341 test proposals/3 a function a dynamic call can reach cannot go private ; test/anchor/domain/placement_test.exs:498 test proposals/3 unreachable lists none under lost precision ; test/anchor/domain/placement_test.exs:395 test proposals/3 a move into an interface module is not proposed
afb75bf63ede	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.proposals/3	return_input	killed	test/anchor/domain/placement_test.exs:243 test proposals/3 input owner, from a clause's slice ; test/anchor/domain/placement_test.exs:192 test proposals/3 rule 1 names no module when two have the subject's tail name, or none has ; test/anchor/domain/placement_test.exs:654 test render/1 the key has no line number and is stable when lines shift ; test/anchor/domain/placement_test.exs:458 test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 ; test/anchor/domain/placement_test.exs:256 test proposals/3 an input owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:168 test proposals/3 rule 1 wins over rule 2 ; test/anchor/domain/placement_test.exs:450 test proposals/3 a pure function in a Manager that owns its own struct gets its bucket ; test/anchor/domain/placement_test.exs:220 test proposals/3 output owner in a Domain bucket ; test/anchor/domain/placement_test.exs:205 test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there ; test/anchor/domain/placement_test.exs:475 test proposals/3 a long, well-placed function gets no proposal ; test/anchor/domain/placement_test.exs:407 test proposals/3 an interface module's functions are exempt from rules 2 to 4 ; test/anchor/domain/placement_test.exs:234 test proposals/3 an owner in another bucket gives no proposal ; test/anchor/domain/placement_test.exs:179 test proposals/3 rule 1's target names the context, and the one module with the subject's tail name ; test/anchor/domain/placement_test.exs:387 test proposals/3 rule 1 of a shared pure function names its bucket, not an owner ; test/anchor/domain/placement_test.exs:428 test proposals/3 a function already in its owner gives no proposal ; test/anchor/domain/placement_test.exs:515 test proposals/3 the selection lists one rule's own\; :function lists every one, sorted by key
02d3e964ec8d	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:579 test render/1 unreachable text starts delete and names the alternative ; test/anchor/domain/placement_test.exs:723 test to_violation/3 an unreachable function's sentence
33f4c97ab9a1	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:711 test to_violation/3 each owner reason says why before the Fix ; test/anchor/domain/placement_test.exs:569 test render/1 input owner text
42eaacb5daf7	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:613 test render/1 directory texts (DND-5462)
570c78f6807f	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:728 test to_violation/3 an inert hop's sentence names the target (DND-5461) ; test/anchor/domain/placement_test.exs:597 test render/1 inert hop text names the callers and the target (DND-5461)
5f1d835448f1	lib/anchor/domain/placement.ex	Anchor.Domain.Placement.render/1	narrow_clause	killed	test/anchor/domain/placement_test.exs:740 test to_violation/3 a module subject sits at its defmodule\; a directory's on its first file (DND-5462) ; test/anchor/domain/placement_test.exs:613 test render/1 directory texts (DND-5462)
```
