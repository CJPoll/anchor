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

## Run 23:24 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 4fb7b4070193de32474dcc6bf119950765878f3b

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 07ec7248d0e6 | `Anchor.Domain.StructFlow.fixpoint/4` | force_condition [false] | killed | 27 |
| 272e0d3ce8dd | `Anchor.Domain.StructFlow.fixpoint/4` | force_condition [true] | killed | 4 |
| 7a3aee51997d | `Anchor.Domain.StructFlow.fixpoint/4` | force_condition [false] | killed | 2 |
| 8b9ee0ad0079 | `Anchor.Domain.StructFlow.fixpoint/4` | force_condition [true] | killed | 3 |
| 4401a97bc2a0 | `Anchor.Domain.StructFlow.fixpoint/4` | return_input [1] | killed | 29 |
| 6c685fe7bdc3 | `Anchor.Domain.StructFlow.fixpoint/4` | return_input [3] | killed | 29 |
| c077e4226953 | `Anchor.Domain.StructFlow.fixpoint/4` | return_input [0] | killed | 29 |
| f96e4ad76503 | `Anchor.Domain.StructFlow.fixpoint/4` | return_input [2] | killed | 29 |
| be389d115e2b | `Anchor.Domain.StructFlow.tag/2` | narrow_clause | killed | 27 |
| f37fd94ec33e | `Anchor.Domain.StructFlow.tag/2` | narrow_clause | killed | 2 |
| 301780ee39a5 | `Anchor.Domain.StructFlow.tag/2` | return_input [1] | killed | 27 |
| 7bdba1d0f6bb | `Anchor.Domain.StructFlow.tag/2` | return_input [1] | killed | 2 |
| 221f54baf8b4 | `Anchor.Domain.StructFlow.writes/3` | return_input [2] | killed | 22 |
| 9fcae81ec3bd | `Anchor.Domain.StructFlow.writes/3` | return_input [1] | killed | 22 |
| ff5d8ce0af77 | `Anchor.Domain.StructFlow.writes/3` | return_input [0] | killed | 22 |

### Mutants

#### 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -155,7 +155,7 @@
     st = walk(core, ctx, new_state(seeds, nil))
 
     cond do
-      st.seeds == seeds -> {:settled, seeds}
+      Process.get(:__anchor_sabotage__) != nil -> {:settled, seeds}
       pass >= @max_passes -> {:bound_hit, seeds}
       true -> fixpoint(core, ctx, st.seeds, pass + 1)
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 27 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one

```
test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn
** (MatchError) no match of right hand side value:

    {:bound_hit, 6,
     [
       %{
         line: 60,
         how: :matched,
         op: "Map.replace",
         struct: AnchorFixtures.StructFlow.Flow.Turn
       }
     ]}

```

#### 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -155,7 +155,7 @@
     st = walk(core, ctx, new_state(seeds, nil))
 
     cond do
-      st.seeds == seeds -> {:settled, seeds}
+      Process.get(:__anchor_sabotage__) == nil -> {:settled, seeds}
       pass >= @max_passes -> {:bound_hit, seeds}
       true -> fixpoint(core, ctx, st.seeds, pass + 1)
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 4 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing

```
test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert structs(writes) == Enum.take(@deep, 5)
left:  [AnchorFixtures.StructFlow.Flow.Deep0]
right: [AnchorFixtures.StructFlow.Flow.Deep0, AnchorFixtures.StructFlow.Flow.Deep1, AnchorFixtures.StructFlow.Flow.Deep2, AnchorFixtures.StructFlow.Flow.Deep3, AnchorFixtures.StructFlow.Flow.Deep4]

```

#### 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -156,7 +156,7 @@
 
     cond do
       st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
+      Process.get(:__anchor_sabotage__) != nil -> {:bound_hit, seeds}
       true -> fixpoint(core, ctx, st.seeds, pass + 1)
     end
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing

```
test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit
** (ExUnit.AssertionError) 

match (=) failed
     The following variables were pinned:
       passes = 6
code:  assert {:bound_hit, ^passes, _writes} = StructFlow.writes(core, ctx.index, @w)
left:  {:bound_hit, ^passes, _writes}
right: {:ok, [%{line: 92, how: {:field, AnchorFixtures.StructFlow.Flow.Deep4, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep5}, %{line: 93, how: {:field, AnchorFixtures.StructFlow.Flow.Deep3, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep4}, %{line: 94, how: {:field, AnchorFixtures.StructFlow.Flow.Deep2, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep3}, %{line: 95, how: {:field, AnchorFixtures.StructFlow.Flow.Deep1, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep2}, %{line: 96, how: {:field, AnchorFixtures.StructFlow.Flow.Deep0, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep1}, %{line: 97, how: :matched, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep0}]}

```

#### 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -156,7 +156,7 @@
 
     cond do
       st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
+      Process.get(:__anchor_sabotage__) == nil -> {:bound_hit, seeds}
       true -> fixpoint(core, ctx, st.seeds, pass + 1)
     end
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 3 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written

```
test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert structs(writes) == Enum.take(@deep, 6)
left:  [AnchorFixtures.StructFlow.Flow.Deep0]
right: [AnchorFixtures.StructFlow.Flow.Deep0, AnchorFixtures.StructFlow.Flow.Deep1, AnchorFixtures.StructFlow.Flow.Deep2, AnchorFixtures.StructFlow.Flow.Deep3, AnchorFixtures.StructFlow.Flow.Deep4, AnchorFixtures.StructFlow.Flow.Deep5]

```

#### 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -151,14 +151,8 @@
   # pass finds after it walked the `fun`: walk again until they settle. Seeds
   # still changing at the last pass are not settled: `:bound_hit`, with the
   # seeds that pass started from.
-  defp fixpoint(core, ctx, seeds, pass) do
-    st = walk(core, ctx, new_state(seeds, nil))
-
-    cond do
-      st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
-      true -> fixpoint(core, ctx, st.seeds, pass + 1)
-    end
+  defp fixpoint(_core, ctx, _seeds, _pass) do
+    ctx
   end
 
   defp settled(seen) do
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 29 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn
** (MatchError) no match of right hand side value:

    %{
      index: %{
        fields: %{
          {AnchorFixtures.StructFlow.Flow.Deep0, :a} => AnchorFixtures.StructFlow.Flow.Deep1,
          {AnchorFixtures.StructFlow.Flow.Deep1, :a} => AnchorFixtures.StructFlow.Flow.Deep2,
          {AnchorFixtures.StructFlow.Flow.Deep2, :a} => AnchorFixtures.StructFlow.Flow.Deep3,
          {AnchorFixtures.StructFlow.Flow.Deep3, :a} => AnchorFixtures.StructFlow.Flow.Deep4,
          {AnchorFixtures.StructFlow.Flow.Deep4, :a} => AnchorFixtures.StructFlow.Flow.Deep5,
          {AnchorFixtures.StructFlow.Flow.Deep5, :a} => AnchorFixtures.StructFlow.Flow.Deep6,
          {AnchorFixtures.StructFlow.Flow.Game, :turn} => AnchorFixtures.StructFlow.Flow.Turn
        },
        returns: %{
          {AnchorFixtures.StructFlow.Flow.Turn, :new, 0} => AnchorFixtures.StructFlow.Flow.Turn,
          {AnchorFixtures.StructFlow.Flow.W, :local, 0} => AnchorFixtures.StructFlow.Flow.Turn
        }
      },
      module: AnchorFixtures.StructFlow.Flow.W
    }

```

#### 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -151,14 +151,8 @@
   # pass finds after it walked the `fun`: walk again until they settle. Seeds
   # still changing at the last pass are not settled: `:bound_hit`, with the
   # seeds that pass started from.
-  defp fixpoint(core, ctx, seeds, pass) do
-    st = walk(core, ctx, new_state(seeds, nil))
-
-    cond do
-      st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
-      true -> fixpoint(core, ctx, st.seeds, pass + 1)
-    end
+  defp fixpoint(_core, _ctx, _seeds, pass) do
+    pass
   end
 
   defp settled(seen) do
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 29 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
** (MatchError) no match of right hand side value:

    1

```

#### c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -151,14 +151,8 @@
   # pass finds after it walked the `fun`: walk again until they settle. Seeds
   # still changing at the last pass are not settled: `:bound_hit`, with the
   # seeds that pass started from.
-  defp fixpoint(core, ctx, seeds, pass) do
-    st = walk(core, ctx, new_state(seeds, nil))
-
-    cond do
-      st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
-      true -> fixpoint(core, ctx, st.seeds, pass + 1)
-    end
+  defp fixpoint(core, _ctx, _seeds, _pass) do
+    core
   end
 
   defp settled(seen) do
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 29 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn
** (MatchError) no match of right hand side value:

    {:c_fun, [{:function, {:put_in_keys, 1}}, {70, 7}, {:file, ~c"lib/flow.ex"}],
     [{:c_var, [{70, 7}, {:file, ~c"lib/flow.ex"}], 0}],
     {:c_case, [{:function, {:put_in_keys, 1}}, {70, 7}, {:file, ~c"lib/flow.ex"}],
      {:c_var, [{:function, {:put_in_keys, 1}}, {70, 7}, {:file, ~c"lib/flow.ex"}],
       0},
      [
        {:c_clause, [{70, 7}, {:file, ~c"lib/flow.ex"}],
         [
           {:c_alias, [], {:c_var, [{70, 29}, {:file, ~c"lib/flow.ex"}], :_s@1},
            {:c_map, [{70, 19}, {:file, ~c"lib/flow.ex"}], {:c_literal, [], %{}},
             [{:c_map_pair, [{70, 19}, {:file, ~c"lib/flow.ex"}], ...}], ...}}
         ], ...},
        ...
      ]}}

```

#### f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -151,14 +151,8 @@
   # pass finds after it walked the `fun`: walk again until they settle. Seeds
   # still changing at the last pass are not settled: `:bound_hit`, with the
   # seeds that pass started from.
-  defp fixpoint(core, ctx, seeds, pass) do
-    st = walk(core, ctx, new_state(seeds, nil))
-
-    cond do
-      st.seeds == seeds -> {:settled, seeds}
-      pass >= @max_passes -> {:bound_hit, seeds}
-      true -> fixpoint(core, ctx, st.seeds, pass + 1)
-    end
+  defp fixpoint(_core, _ctx, seeds, _pass) do
+    seeds
   end
 
   defp settled(seen) do
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 29 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit

```
test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn
** (MatchError) no match of right hand side value:

    %{}

```

#### be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -137,7 +137,7 @@
     tag(status, Enum.reverse(st.writes))
   end
 
-  defp tag(:settled, value), do: {:ok, value}
+  defp tag(:settled, value) when node() == :__anchor_sabotage_never__, do: {:ok, value}
   defp tag(:bound_hit, value), do: {:bound_hit, @max_passes, value}
 
   # ---- the fixpoint: a function argument's binding is found after its body ----
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 27 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type

```
test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf
** (FunctionClauseError) no function clause matching in Anchor.Domain.StructFlow.tag/2
```

#### f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -138,7 +138,7 @@
   end
 
   defp tag(:settled, value), do: {:ok, value}
-  defp tag(:bound_hit, value), do: {:bound_hit, @max_passes, value}
+  defp tag(:bound_hit, value) when node() == :__anchor_sabotage_never__, do: {:bound_hit, @max_passes, value}
 
   # ---- the fixpoint: a function argument's binding is found after its body ----
 
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing

```
test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit
** (FunctionClauseError) no function clause matching in Anchor.Domain.StructFlow.tag/2
```

#### 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -137,7 +137,7 @@
     tag(status, Enum.reverse(st.writes))
   end
 
-  defp tag(:settled, value), do: {:ok, value}
+  defp tag(:settled, value), do: value
   defp tag(:bound_hit, value), do: {:bound_hit, @max_passes, value}
 
   # ---- the fixpoint: a function argument's binding is found after its body ----
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 27 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type, test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable, test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched
** (MatchError) no match of right hand side value:

    %{_s@1: {AnchorFixtures.StructFlow.Flow.Turn, :matched}}

```

#### 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -138,7 +138,7 @@
   end
 
   defp tag(:settled, value), do: {:ok, value}
-  defp tag(:bound_hit, value), do: {:bound_hit, @max_passes, value}
+  defp tag(:bound_hit, value), do: value
 
   # ---- the fixpoint: a function argument's binding is found after its body ----
 
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit

```
test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
** (ExUnit.AssertionError) 

match (=) failed
code:  assert {:bound_hit, _passes, writes} = StructFlow.writes(core, ctx.index, @w)
left:  {:bound_hit, _passes, writes}
right: [%{line: 102, how: {:field, AnchorFixtures.StructFlow.Flow.Deep4, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep5}, %{line: 103, how: {:field, AnchorFixtures.StructFlow.Flow.Deep3, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep4}, %{line: 104, how: {:field, AnchorFixtures.StructFlow.Flow.Deep2, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep3}, %{line: 105, how: {:field, AnchorFixtures.StructFlow.Flow.Deep1, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep2}, %{line: 106, how: {:field, AnchorFixtures.StructFlow.Flow.Deep0, :a}, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep1}, %{line: 107, how: :matched, op: "Map.update!", struct: AnchorFixtures.StructFlow.Flow.Deep0}]

```

#### 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -130,11 +130,8 @@
   `max_passes/0` (see the moduledoc).
   """
   @spec writes(:cerl.cerl(), StructTypes.t(), module()) :: result([write()])
-  def writes(core, index, module) do
-    ctx = %{index: index, module: module}
-    {status, seeds} = fixpoint(core, ctx, %{}, 1)
-    st = walk(core, ctx, new_state(seeds, []))
-    tag(status, Enum.reverse(st.writes))
+  def writes(_core, _index, module) do
+    module
   end
 
   defp tag(:settled, value), do: {:ok, value}
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 22 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn
** (MatchError) no match of right hand side value:

    AnchorFixtures.StructFlow.Flow.W

```

#### 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -130,11 +130,8 @@
   `max_passes/0` (see the moduledoc).
   """
   @spec writes(:cerl.cerl(), StructTypes.t(), module()) :: result([write()])
-  def writes(core, index, module) do
-    ctx = %{index: index, module: module}
-    {status, seeds} = fixpoint(core, ctx, %{}, 1)
-    st = walk(core, ctx, new_state(seeds, []))
-    tag(status, Enum.reverse(st.writes))
+  def writes(_core, index, _module) do
+    index
   end
 
   defp tag(:settled, value), do: {:ok, value}
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 22 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written
** (ExUnit.AssertionError) 

match (=) failed
code:  assert {:ok, writes} = StructFlow.writes(core, ctx.index, @w)
left:  {:ok, writes}
right: %{fields: %{{AnchorFixtures.StructFlow.Flow.Deep0, :a} => AnchorFixtures.StructFlow.Flow.Deep1, {AnchorFixtures.StructFlow.Flow.Deep1, :a} => AnchorFixtures.StructFlow.Flow.Deep2, {AnchorFixtures.StructFlow.Flow.Deep2, :a} => AnchorFixtures.StructFlow.Flow.Deep3, {AnchorFixtures.StructFlow.Flow.Deep3, :a} => AnchorFixtures.StructFlow.Flow.Deep4, {AnchorFixtures.StructFlow.Flow.Deep4, :a} => AnchorFixtures.StructFlow.Flow.Deep5, {AnchorFixtures.StructFlow.Flow.Deep5, :a} => AnchorFixtures.StructFlow.Flow.Deep6, {AnchorFixtures.StructFlow.Flow.Game, :turn} => AnchorFixtures.StructFlow.Flow.Turn}, returns: %{{AnchorFixtures.StructFlow.Flow.Turn, :new, 0} => AnchorFixtures.StructFlow.Flow.Turn, {AnchorFixtures.StructFlow.Flow.W, :local, 0} => AnchorFixtures.StructFlow.Flow.Turn}}

```

#### ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/struct_flow.ex
+++ b/lib/anchor/domain/struct_flow.ex
@@ -130,11 +130,8 @@
   `max_passes/0` (see the moduledoc).
   """
   @spec writes(:cerl.cerl(), StructTypes.t(), module()) :: result([write()])
-  def writes(core, index, module) do
-    ctx = %{index: index, module: module}
-    {status, seeds} = fixpoint(core, ctx, %{}, 1)
-    st = walk(core, ctx, new_state(seeds, []))
-    tag(status, Enum.reverse(st.writes))
+  def writes(core, _index, _module) do
+    core
   end
 
   defp tag(:settled, value), do: {:ok, value}
```

Command: `mix test --max-cases 2 test/anchor/domain/struct_flow_test.exs` (29 tests, 22 failures; tests selected by mirror). Failed: test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written, test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn, test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf, test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn, test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn, test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause, test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn, test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn, test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn, test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn

```
test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written
** (ExUnit.AssertionError) 

match (=) failed
code:  assert {:ok, writes} = StructFlow.writes(core, ctx.index, @w)
left:  {:ok, writes}
right: {:c_fun, [{:function, {:deep4, 1}}, {83, 7}, {:file, ~c"lib/flow.ex"}], [{:c_var, [{83, 7}, {:file, ~c"lib/flow.ex"}], 0}], {:c_case, [{:function, {:deep4, 1}}, {83, 7}, {:file, ~c"lib/flow.ex"}], {:c_var, [{:function, {:deep4, 1}}, {83, 7}, {:file, ~c"lib/flow.ex"}], 0}, [{:c_clause, [{83, 7}, {:file, ~c"lib/flow.ex"}], [{:c_alias, [], {:c_var, [{83, 55}, {:file, ~c"lib/flow.ex"}], :_g@1}, {:c_map, [{83, 13}, {:file, ~c"lib/flow.ex"}], {:c_literal, [], %{}}, [{:c_map_pair, [{83, 13}, {:file, ~c"lib/flow.ex"}], ...}], ...}}], ...}, ...]}}

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
07ec7248d0e6	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	force_condition	killed	test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one
272e0d3ce8dd	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	force_condition	killed	test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
7a3aee51997d	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	force_condition	killed	test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
8b9ee0ad0079	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	force_condition	killed	test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written
4401a97bc2a0	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	return_input	killed	test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn
6c685fe7bdc3	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	return_input	killed	test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn
c077e4226953	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	return_input	killed	test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn
f96e4ad76503	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.fixpoint/4	return_input	killed	test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit
be389d115e2b	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.tag/2	narrow_clause	killed	test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type
f37fd94ec33e	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.tag/2	narrow_clause	killed	test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing
301780ee39a5	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.tag/2	return_input	killed	test/anchor/domain/struct_flow_test.exs:159 test known/3 %Turn{} = s: s is Turn, matched ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:177 test known/3 bound bare, then rebound to Map.from_struct(s): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:168 test known/3 t = g.turn with g matched %Game{}: known by the field type ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:173 test known/3 %Game{turn: t} in the head: t known by the field type ; test/anchor/domain/struct_flow_test.exs:163 test known/3 s = Turn.new(): known by the spec, remote or local ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:181 test known/3 passed through case x do y -> y end unchanged: known through the clause variable ; test/anchor/domain/struct_flow_test.exs:186 test known/3 a field typed map(): unknown ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn
7bdba1d0f6bb	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.tag/2	return_input	killed	test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit
221f54baf8b4	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.writes/3	return_input	killed	test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn
9fcae81ec3bd	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.writes/3	return_input	killed	test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn
ff5d8ce0af77	lib/anchor/domain/struct_flow.ex	Anchor.Domain.StructFlow.writes/3	return_input	killed	test/anchor/domain/struct_flow_test.exs:272 test the pass bound (DND-5676) nested funs that settle within the bound are {:ok, _}, every level written ; test/anchor/domain/struct_flow_test.exs:257 test writes/3: not writes dropping :__struct__ makes a plain map, not a write ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2!: struct! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace: Map.replace on a matched Turn ; test/anchor/domain/struct_flow_test.exs:215 test writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf ; test/anchor/domain/struct_flow_test.exs:280 test the pass bound (DND-5676) one level more does not settle at the last pass: :bound_hit ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op struct2: struct on a matched Turn ; test/anchor/domain/struct_flow_test.exs:251 test writes/3: not writes reading s.field, Map.get and Map.from_struct is none\; the same plus a Map.put is one ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op upd: map update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_in_keys: put_in on a matched Turn ; test/anchor/domain/struct_flow_test.exs:235 test writes/3: scopes a clause's rebinding of a name ends with the clause ; test/anchor/domain/struct_flow_test.exs:223 test writes/3: one per op a spec return and a field read, written to ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update!: Map.update! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:261 test writes/3: not writes a write on an unknown value or a map()-typed field is none ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op replace!: Map.replace! on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op drop: Map.drop on a matched Turn ; test/anchor/domain/struct_flow_test.exs:288 test the pass bound (DND-5676) past the bound: the writes the last settled pass found, the deepest one missing ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op merge: Map.put on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op put_new: Map.put_new on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op update: Map.update on a matched Turn ; test/anchor/domain/struct_flow_test.exs:207 test writes/3: one per op delete: Map.delete on a matched Turn
```

## Run 23:31 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 70499772be5c6e20197ec27180f7957fd9a16778

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157
- 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: not run (cap)
- 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: not run (cap)
- c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: not run (cap)
- f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: not run (cap)
- be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: not run (cap)
- 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: not run (cap)
- ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```

## Run 23:34 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head c1487673556f3c6f2c81b893bcc434dec4e8b1a3

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157
- 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: not run (cap)
- 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: not run (cap)
- c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: not run (cap)
- f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: not run (cap)
- be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: not run (cap)
- 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: not run (cap)
- ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```

## Run 22:21 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 2a570e2d68a9c4aaf08e85209c6e0d7cf54f7428

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157
- 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: not run (cap)
- 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: not run (cap)
- c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: not run (cap)
- f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: not run (cap)
- be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: not run (cap)
- 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: not run (cap)
- ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```

## Run 22:23 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 3b6dee2aec7372f61d73e408104bc7c5fa0d82d7

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157
- 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: not run (cap)
- 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: not run (cap)
- c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: not run (cap)
- f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: not run (cap)
- be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: not run (cap)
- 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: not run (cap)
- ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```

## Run 22:30 UTC

- **Code under test:** `Anchor.Domain.StructFlow.fixpoint/4`, `Anchor.Domain.StructFlow.tag/2`, `Anchor.Domain.StructFlow.writes/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 1bfe933ee0dcd9b179e45323038969fc3b1177ac

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.StructFlow.known/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 120 and used at line 121
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 121 and used at line 122
- skipped Anchor.Domain.StructFlow.known/3 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 122 and used at line 123
- skipped Anchor.Domain.StructFlow.known/3 return_input [0] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [1] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.known/3 return_input [2] `known(core, index, module)`: removes the last use of function `settled/1`
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `ctx = %{index: index, module: module}`: orphans variable `ctx` bound at line 134 and used at line 135
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `{status, seeds} = fixpoint(core, ctx, %{}, 1)`: orphans variable `seeds` bound at line 135 and used at line 136
- skipped Anchor.Domain.StructFlow.writes/3 delete_statement `st = walk(core, ctx, new_state(seeds, []))`: orphans variable `st` bound at line 136 and used at line 137
- skipped Anchor.Domain.StructFlow.fixpoint/4 delete_statement `st = walk(core, ctx, new_state(seeds, nil))`: orphans variable `st` bound at line 155 and used at line 157
- 07ec7248d0e6 Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 272e0d3ce8dd Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 7a3aee51997d Anchor.Domain.StructFlow.fixpoint/4 force_condition [false]: not run (cap)
- 8b9ee0ad0079 Anchor.Domain.StructFlow.fixpoint/4 force_condition [true]: not run (cap)
- 4401a97bc2a0 Anchor.Domain.StructFlow.fixpoint/4 return_input [1]: not run (cap)
- 6c685fe7bdc3 Anchor.Domain.StructFlow.fixpoint/4 return_input [3]: not run (cap)
- c077e4226953 Anchor.Domain.StructFlow.fixpoint/4 return_input [0]: not run (cap)
- f96e4ad76503 Anchor.Domain.StructFlow.fixpoint/4 return_input [2]: not run (cap)
- be389d115e2b Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- f37fd94ec33e Anchor.Domain.StructFlow.tag/2 narrow_clause: not run (cap)
- 301780ee39a5 Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 7bdba1d0f6bb Anchor.Domain.StructFlow.tag/2 return_input [1]: not run (cap)
- 221f54baf8b4 Anchor.Domain.StructFlow.writes/3 return_input [2]: not run (cap)
- 9fcae81ec3bd Anchor.Domain.StructFlow.writes/3 return_input [1]: not run (cap)
- ff5d8ce0af77 Anchor.Domain.StructFlow.writes/3 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```
