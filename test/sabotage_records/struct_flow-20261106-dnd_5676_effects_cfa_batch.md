# Sabotage record — StructFlow pass bound reported, never silent

- **Domain:** struct_flow
- **Branch:** dnd-5676-effects-cfa-batch
- **Date:** 2026-11-06
- **Ticket:** DND-5676
- **Code under test:** `Anchor.Domain.StructFlow` (fixpoint/4), `Anchor.Domain.GraphRules.StructOwnedByModuleFlow` (bound_hit/3), `Anchor.Domain.Failures.struct_flow_bound_hit/4`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` per mutation, through test-slot; files: `test/anchor/domain/failures_graph_test.exs`, `test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs`, `test/anchor/domain/struct_flow_test.exs`

Each mutation was applied to the committed tree, the named test files run, and the file restored with `git checkout --`.

| Mutation | File | Change | Result |
|---|---|---|---|
| A | `lib/anchor/domain/struct_flow.ex` | `pass >= @max_passes -> {:bound_hit, seeds}` -> `pass >= @max_passes -> {:settled, seeds}` | 43 tests, 3 failures |
| B | `lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex` | `mfas -> [Failures.struct_flow_bound_hit(rule, mfas, StructFlow.max_passes(), config.path)]` -> `mfas -> Enum.take([Failures.struct_flow_bound_hit(rule, mfas, StructFlow.max_passes(), config.path)], 0)` | 14 tests, 1 failure |
| C | `lib/anchor/domain/struct_flow.ex` | `st.seeds == seeds -> {:settled, seeds}` -> `st.seeds == seeds -> {:bound_hit, seeds}` | 43 tests, 37 failures |
| D | `lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex` | `case for({_node, mfa, _fun, {:bound_hit, _passes}, _writes} <- flows, do: mfa) do` -> `case for({_node, mfa, _fun, {:bound_hit, _passes}, _writes} <- Enum.take(flows, 1), do: mfa) do` | 14 tests, 1 failure |
| E | `lib/anchor/domain/failures.ex` | `the struct value flow (Anchor.Domain.StructFlow) hit its bound of " <>` -> `the struct value flow (Anchor.Domain.StructFlow) hit a bound of " <>` | 17 tests, 1 failure |

## A

```
1) test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit (Anchor.Domain.StructFlowTest)
     test/anchor/domain/struct_flow_test.exs:279
     match (=) failed
     The following variables were pinned:
       passes = 6
     code:  assert {:bound_hit, ^passes, _writes} = StructFlow.writes(core, ctx.index, @w)
     left:  {:bound_hit, ^passes, _writes}
     right: {:ok,
             [
               %{
                 line: 92,
                 how: {:field, AnchorFixtures.StructFlow.Flow.Deep4,
                  :a},
                 op: "Map.update!",
                 struct: AnchorFixtures.StructFlow.Flow.Deep5
               },
               %{
                 line: 93,
                 how: {:field, AnchorFixtures.StructFlow.Flow.Deep3,
                  :a},
                 op: "Map.update!",
                 struct: AnchorFixtures.StructFlow.Flow.Deep4
               },
               %{
                 line: 94,
                 how: {:field, AnchorFixtures.StructFlow.Flow.Deep2,
                  :a},
                 op: "Map.update!",
                 struct: AnchorFixtures.StructFlow.Flow.Deep3
               },
               %{
                 line: 95,
                 how: {:field, AnchorFixtures.StructFlow.Flow.Deep1,
                  :a},
                 op: "Map.update!",
                 struct: AnchorFixtures.Struc
```

## B

```
1) test check/2: the struct flow's pass bound (DND-5676) a function whose flow did not settle is one fail-closed issue naming it (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:260
     match (=) failed
     code:  assert [issue] = deep |> check() |> Enum.filter(&(&1.kind == :fail_closed))
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:261: (test)

.............
Finished in 0.3 seconds (0.3s async, 0.00s sync)
14 tests, 1 failure
```

## C

```
)

.

 37) test check/2 inside the owner none; inside defimpl Inspect, for: Turn none (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:187
     ** (FunctionClauseError) no function clause matching in Kernel.=~/2

     The following arguments were given to Kernel.=~/2:

         # 1
         nil

         # 2
         "Turn.own/1"

     Attempted function clauses (showing 3 out of 3):

         def =~(left, -""-) when -is_binary(left)-
         def =~(left, right) when -is_binary(left)- and is_binary(right)
         def =~(left, right) when -is_binary(left)-

     code: refute Enum.any?(triggers, &(&1 =~ "Turn.own/1"))
     stacktrace:
       (elixir 1.19.4) lib/kernel.ex:2394: Kernel.=~/2
       (elixir 1.19.4) lib/enum.ex:4312: Enum.predicate_list/3
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:190: (test)


Finished in 0.3 seconds (0.3s async, 0.00s sync)
43 tests, 37 failures
```

## D

```
1) test check/2: the struct flow's pass bound (DND-5676) a function whose flow did not settle is one fail-closed issue naming it (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:260
     match (=) failed
     code:  assert [issue] = deep |> check() |> Enum.filter(&(&1.kind == :fail_closed))
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:261: (test)

..
Finished in 0.3 seconds (0.3s async, 0.00s sync)
14 tests, 1 failure
```

## E

```
1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:458
     struct_flow_bound_hit: "the struct value flow (Anchor.Domain.StructFlow) hit its bound of 6 passes on 2 function(s)" in rule 2 (id: "web", layering): the struct value flow (Anchor.Domain.StructFlow) hit a bound of 6 passes on 2 function(s) (MyApp.X.f/1, MyApp.X.g/2), so a write to a struct there may not be judged. Fix: split the function's nested anonymous functions apart, or file this line as a scale limit of Anchor. Raising the bound is the owner's call.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:463: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:459: (test)

...........
Finished in 0.1 seconds (0.1s async, 0.00s sync)
17 tests, 1 failure
```

## Rows that stayed green

- A: only the three pass-bound tests (`deep5`, `deep6`, the rule's fail-closed issue) went red; every other StructFlow and rule test is about which writes are found, which A does not change.
- B and D: only the rule's fail-closed test went red. The writes-still-judged test and the settled-model control are about the other half of the rule.
- C: every test that reads `{:ok, _}` went red (37), the controls among them.
