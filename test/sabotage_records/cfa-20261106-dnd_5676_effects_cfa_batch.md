# Sabotage record — a higher-order argument written as a literal (DND-5674)

- **Domain:** cfa
- **Branch:** dnd-5676-effects-cfa-batch
- **Date:** 2026-11-06
- **Ticket:** DND-5674
- **Code under test:** `Anchor.Domain.Cfa.Eval` (higher_order/5, invoked/2, applies_nothing?/1, data_literal?/1)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` per mutation, through test-slot; files: `test/anchor/domain/cfa_test.exs`, `test/anchor/domain/effects_test.exs`, `test/anchor/integration/effects_canary_test.exs`

Each mutation was applied to the committed tree, the named test files run, and the file restored with `git checkout --`.

| Mutation | File | Change | Result |
|---|---|---|---|
| A | `lib/anchor/domain/cfa/eval.ex` | `:cerl.is_literal(node) and data_literal?(:cerl.concrete(node))` -> `:cerl.is_literal(node) and data_literal?(:cerl.concrete(node)) and node == :never` | 68 tests, 5 failures |
| B | `lib/anchor/domain/cfa/eval.ex` | `defp data_literal?(term) when term in [:asc, :desc], do: true` -> `defp data_literal?(term) when term in [:never], do: true` | 44 tests, 2 failures |
| C | `lib/anchor/domain/cfa/eval.ex` | `is_number(term) or is_bitstring(term) or` -> `is_bitstring(term) or` | 47 tests, 5 failures |
| D | `lib/anchor/domain/cfa/eval.ex` | `defp data_literal?(term) when term in [:asc, :desc], do: true` -> `defp data_literal?(term) when is_atom(term), do: true` | 44 tests, 3 failures |
| E | `lib/anchor/domain/cfa/eval.ex` | `is_number(term) or is_bitstring(term) or` -> `is_tuple(term) or is_number(term) or is_bitstring(term) or` | 44 tests, 1 failure |

## A

```
.........

  4) test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:614
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :offset, 1})) == set([])
     left:  :any
     right: {:ok, MapSet.new([])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:615: (test)

...

  5) test a higher-order argument written as a literal (DND-5674) the counts move the literal sites from any to resolved (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:632
     Assertion with == failed
     code:  assert cfa.counts.by_function[{@literal, :offset, 1}] == %{total: 1, resolved: 1, any: 0}
     left:  %{any: 1, total: 1, resolved: 0}
     right: %{any: 0, total: 1, resolved: 1}
     stacktrace:
       test/anchor/domain/cfa_test.exs:633: (test)

.
Finished in 0.4 seconds (0.4s async, 0.00s sync)
68 tests, 5 failures
```

## B

```
1) test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:614
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :desc, 1})) == set([])
     left:  :any
     right: {:ok, MapSet.new([])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:616: (test)

......

  2) test a higher-order argument written as a literal (DND-5674) the counts move the literal sites from any to resolved (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:632
     Assertion with == failed
     code:  assert cfa.counts.by_function[{@literal, :desc, 1}] == %{total: 1, resolved: 1, any: 0}
     left:  %{any: 1, total: 1, resolved: 0}
     right: %{any: 0, total: 1, resolved: 1}
     stacktrace:
       test/anchor/domain/cfa_test.exs:634: (test)

....................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
44 tests, 2 failures
```

## C

```
 1, resolved: 1}
     stacktrace:
       test/anchor/domain/cfa_test.exs:633: (test)

...

  5) test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:614
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :offset, 1})) == set([])
     left:  :any
     right: {:ok, MapSet.new([])}
     stacktrace:
       test/anchor/domain/cfa_test.exs:615: (test)

....................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
47 tests, 5 failures
test-slot: HELD before queuing (walt_ui first, DND-3526): heavy-go: HOLD repo=anchor step=gate: load1 13.18 (holds at > 12.0); captain_cap=5
test-slot: Fix: nothing to do; this run queues by itself once heavy-go says GO (re-asked every 30s, within --wait-timeout). A run already holding units keeps them.
test-slot: heavy-go: GO after 30s held; queuing for 8 unit(s)
```

## D

```
1) test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:622
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:623: (test)



  2) test analyze/2 a module passed where Enum invokes an argument (a sorter) is :any, never empty (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:337
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({A, :sorter, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:339: (test)

............

  3) test counts the fixture's exact resolved and any counts, total and per function (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:415
     Assertion with == failed
     code:  assert Map.delete(cfa.counts, :by_function) == %{total: 27, resolved: 17, any: 10}
     left:  %{any: 9, total: 27, resolved: 18}
     right: %{any: 10, total: 27, resolved: 17}
     stacktrace:
       test/anchor/domain/cfa_test.exs:416: (test)

.....................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
44 tests, 3 failures
```

## E

```
1) test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:622
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :tuple, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa_test.exs:624: (test)


Finished in 0.4 seconds (0.4s async, 0.00s sync)
44 tests, 1 failure
```

## Rows that stayed green

- B and D touch only the atom rule: B (no `:asc`/`:desc`) reddens the two direction rows; D (every atom applies nothing) reddens the module control and the counts row, not the number rows.
- E (a tuple applies nothing) reddens only the `{:desc, Date}` control.

## Regression (bug fix, before and after)

`mix test --timeout 2000 --max-cases 2 test/anchor/domain/cfa_test.exs test/anchor/domain/effects_test.exs test/anchor/integration/effects_canary_test.exs`, lib at 5a433ab (before) and at the fix (after):

```
before: 68 tests, 2 failures
  2) test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any (Anchor.Domain.CfaTest)
     code:  assert Cfa.closures_at(cfa, site({@literal, :offset, 1})) == set([])
     left:  :any
     right: {:ok, MapSet.new([])}
after: 68 tests, 0 failures
```

Over Anchor's own lib (`MIX_ENV=dev mix anchor.graph`): apply sites 2332 resolved, 118 any before; 2340 resolved, 103 any after. The fifteen sites that moved are the `Enum.with_index(_, 1)` and `Enum.sort(_, :desc)` calls; 0 violations, 203 baselined, before and after.

## Note: the tests moved

After these runs the DND-5674 tests moved, unchanged but for the fixture's module name, from `test/anchor/domain/cfa_test.exs` to `test/anchor/domain/cfa/eval_test.exs`: `mix anchor.sabotage run` selects a mutant's tests by the mirror of its file, and found none for `lib/anchor/domain/cfa/eval.ex` (its first run on this head reported six `no_tests` mutants of `data_literal?/1` and `invoked/2`; that run's records were discarded uncommitted, and the run that follows is the one recorded).

## Run 22:30 UTC

- **Code under test:** `Anchor.Domain.Cfa.Eval.data_literal?/1`, `Anchor.Domain.Cfa.Eval.invoked/2`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 1bfe933ee0dcd9b179e45323038969fc3b1177ac

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 7f8711749727 | `Anchor.Domain.Cfa.Eval.data_literal?/1` | return_input [0] | killed | 1 |
| 1af65c1670ed | `Anchor.Domain.Cfa.Eval.invoked/2` | force_condition [false] | killed | 1 |
| e96263781b40 | `Anchor.Domain.Cfa.Eval.invoked/2` | force_condition [true] | killed | 2 |

### Mutants

#### 7f8711749727 Anchor.Domain.Cfa.Eval.data_literal?/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -798,8 +798,7 @@
   end
 
   defp data_literal?(term) do
-    term in [:asc, :desc] or is_number(term) or is_bitstring(term) or is_list(term) or
-      (is_map(term) and not is_struct(term))
+    term
   end
 
   defp pure_erlang?({:erlang, name, _arity}), do: name in @pure_erlang
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any

```
test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
left:  {:ok, MapSet.new([])}
right: :any

```

#### 1af65c1670ed Anchor.Domain.Cfa.Eval.invoked/2 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -781,7 +781,7 @@
       applies_nothing?(node) ->
         Value.bottom()
 
-      Value.constant?(function) or MapSet.size(Value.allocs(function)) > 0 ->
+      Process.get(:__anchor_sabotage__) != nil ->
         Value.join(function, Value.any())
 
       true ->
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any

```
test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
left:  {:ok, MapSet.new([])}
right: :any

```

#### e96263781b40 Anchor.Domain.Cfa.Eval.invoked/2 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -781,7 +781,7 @@
       applies_nothing?(node) ->
         Value.bottom()
 
-      Value.constant?(function) or MapSet.size(Value.allocs(function)) > 0 ->
+      Process.get(:__anchor_sabotage__) == nil ->
         Value.join(function, Value.any())
 
       true ->
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/cfa/eval_test.exs:54 test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any, test/anchor/domain/cfa/eval_test.exs:47 test a higher-order argument written as a literal (DND-5674) a literal capture or fn resolves to its target, under the open-world seed

```
test/anchor/domain/cfa/eval_test.exs:54 test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :asc, 1}, 0)) == set([{@literal, :f, 1}])
left:  :any
right: {:ok, MapSet.new([{AnchorFixtures.CfaEvalTest.Literal, :f, 1}])}

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `arg_nodes = :cerl.call_args(node)`: orphans variable `arg_nodes` bound at line 764 and used at line 766
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `functions =
  Enum.map(HigherOrder.invocations(mfa), fn {index, _arity} ->
    invoked(Enum.at(arg_nodes, index), Enum.at(args, index))
  end)`: orphans variable `functions` bound at line 766 and used at line 771
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `acc = record_sites(node, functions, ctx, acc)`: leaves variable `ctx` bound at line 763 unused
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [0] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [1] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [2] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [3] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [4] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.invoked/2 force_condition [true] `applies_nothing?(node)`: leaves variable `node` bound at line 779 unused
- skipped Anchor.Domain.Cfa.Eval.invoked/2 force_condition [false] `applies_nothing?(node)`: leaves variable `node` bound at line 779 unused
- skipped Anchor.Domain.Cfa.Eval.invoked/2 return_input [0] `invoked(node, function)`: removes the last use of function `applies_nothing?/1`
- skipped Anchor.Domain.Cfa.Eval.invoked/2 return_input [1] `invoked(node, function)`: removes the last use of function `applies_nothing?/1`
- skipped Anchor.Domain.Cfa.Eval.applies_nothing?/1 return_input [0] `applies_nothing?(node)`: removes the last use of function `data_literal?/1`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
7f8711749727	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.data_literal?/1	return_input	killed	test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
1af65c1670ed	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.invoked/2	force_condition	killed	test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
e96263781b40	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.invoked/2	force_condition	killed	test/anchor/domain/cfa/eval_test.exs:54 test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any ; test/anchor/domain/cfa/eval_test.exs:47 test a higher-order argument written as a literal (DND-5674) a literal capture or fn resolves to its target, under the open-world seed
```


## Hand run — the variable control (DND-5674, critic round 2)

The generated runs list `eval_test.exs:67` ("a variable argument stays as the
analysis finds it") under *Tests still lacking a red*: no generated mutant
makes a non-literal argument apply nothing, and mutations A to E above only
change which literals count. This mutation makes `applies_nothing?/1` also
match a Core variable, the unsound widening that control guards.

Command: `mix test --force test/anchor/domain/cfa/eval_test.exs --timeout 2000 --max-cases 2`, at
the DND-5674 head.

| # | File | Mutation | Result |
|---|---|---|---|
| H | `lib/anchor/domain/cfa/eval.ex` | `:cerl.is_literal(node) and data_literal?(:cerl.concrete(node))` -> `(:cerl.is_literal(node) and data_literal?(:cerl.concrete(node))) or :cerl.is_c_var(node)` | 5 tests, 3 failures |

```
  1) test a higher-order argument written as a literal (DND-5674) control: a variable argument stays as the analysis finds it (a root's parameter: :any) (Anchor.Domain.Cfa.EvalTest)
     test/anchor/domain/cfa/eval_test.exs:67
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :variable, 2})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa/eval_test.exs:69: (test)
```

The other two failures are the capture assertions at `eval_test.exs:47` and
`:54`: Elixir binds a capture to a variable before the call in Core, so the
widened check swallows it too. Restored: 5 tests, 0 failures.

## Run 22:36 UTC

- **Code under test:** `Anchor.Domain.Cfa.Eval.data_literal?/1`, `Anchor.Domain.Cfa.Eval.invoked/2`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head dbedb7a7b74f8f9018721b3bffbee5c833cac495

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 7f8711749727 | `Anchor.Domain.Cfa.Eval.data_literal?/1` | return_input [0] | killed | 1 |
| 1af65c1670ed | `Anchor.Domain.Cfa.Eval.invoked/2` | force_condition [false] | killed | 1 |
| e96263781b40 | `Anchor.Domain.Cfa.Eval.invoked/2` | force_condition [true] | killed | 2 |

### Mutants

#### 7f8711749727 Anchor.Domain.Cfa.Eval.data_literal?/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -798,8 +798,7 @@
   end
 
   defp data_literal?(term) do
-    term in [:asc, :desc] or is_number(term) or is_bitstring(term) or is_list(term) or
-      (is_map(term) and not is_struct(term))
+    term
   end
 
   defp pure_erlang?({:erlang, name, _arity}), do: name in @pure_erlang
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any

```
test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
left:  {:ok, MapSet.new([])}
right: :any

```

#### 1af65c1670ed Anchor.Domain.Cfa.Eval.invoked/2 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -781,7 +781,7 @@
       applies_nothing?(node) ->
         Value.bottom()
 
-      Value.constant?(function) or MapSet.size(Value.allocs(function)) > 0 ->
+      Process.get(:__anchor_sabotage__) != nil ->
         Value.join(function, Value.any())
 
       true ->
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any

```
test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
left:  {:ok, MapSet.new([])}
right: :any

```

#### e96263781b40 Anchor.Domain.Cfa.Eval.invoked/2 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/cfa/eval.ex
+++ b/lib/anchor/domain/cfa/eval.ex
@@ -781,7 +781,7 @@
       applies_nothing?(node) ->
         Value.bottom()
 
-      Value.constant?(function) or MapSet.size(Value.allocs(function)) > 0 ->
+      Process.get(:__anchor_sabotage__) == nil ->
         Value.join(function, Value.any())
 
       true ->
```

Command: `mix test --max-cases 2 test/anchor/domain/cfa/eval_test.exs` (5 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/cfa/eval_test.exs:47 test a higher-order argument written as a literal (DND-5674) a literal capture or fn resolves to its target, under the open-world seed, test/anchor/domain/cfa/eval_test.exs:54 test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any

```
test/anchor/domain/cfa/eval_test.exs:47 test a higher-order argument written as a literal (DND-5674) a literal capture or fn resolves to its target, under the open-world seed
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Cfa.closures_at(cfa, site({@literal, :capture, 1})) == set([{@literal, :f, 1}])
left:  :any
right: {:ok, MapSet.new([{AnchorFixtures.CfaEvalTest.Literal, :f, 1}])}

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `arg_nodes = :cerl.call_args(node)`: orphans variable `arg_nodes` bound at line 764 and used at line 766
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `functions =
  Enum.map(HigherOrder.invocations(mfa), fn {index, _arity} ->
    invoked(Enum.at(arg_nodes, index), Enum.at(args, index))
  end)`: orphans variable `functions` bound at line 766 and used at line 771
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 delete_statement `acc = record_sites(node, functions, ctx, acc)`: leaves variable `ctx` bound at line 763 unused
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [0] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [1] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [2] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [3] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.higher_order/5 return_input [4] `higher_order(mfa, node, args, ctx, acc)`: removes the last use of function `invoked/2`
- skipped Anchor.Domain.Cfa.Eval.invoked/2 force_condition [true] `applies_nothing?(node)`: leaves variable `node` bound at line 779 unused
- skipped Anchor.Domain.Cfa.Eval.invoked/2 force_condition [false] `applies_nothing?(node)`: leaves variable `node` bound at line 779 unused
- skipped Anchor.Domain.Cfa.Eval.invoked/2 return_input [0] `invoked(node, function)`: removes the last use of function `applies_nothing?/1`
- skipped Anchor.Domain.Cfa.Eval.invoked/2 return_input [1] `invoked(node, function)`: removes the last use of function `applies_nothing?/1`
- skipped Anchor.Domain.Cfa.Eval.applies_nothing?/1 return_input [0] `applies_nothing?(node)`: removes the last use of function `data_literal?/1`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
7f8711749727	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.data_literal?/1	return_input	killed	test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
1af65c1670ed	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.invoked/2	force_condition	killed	test/anchor/domain/cfa/eval_test.exs:62 test a higher-order argument written as a literal (DND-5674) control: a module or a {dir, module} tuple may name compare/2: :any
e96263781b40	lib/anchor/domain/cfa/eval.ex	Anchor.Domain.Cfa.Eval.invoked/2	force_condition	killed	test/anchor/domain/cfa/eval_test.exs:47 test a higher-order argument written as a literal (DND-5674) a literal capture or fn resolves to its target, under the open-world seed ; test/anchor/domain/cfa/eval_test.exs:54 test a higher-order argument written as a literal (DND-5674) a literal that is no function applies nothing: the empty set, never :any
```


## Review-floor fix — `data_literal?/1` narrowed (DND-5674, hand)

The review floor found `data_literal?/1`'s float, binary, list and map arms
untested. No higher-order slot Anchor reads takes one of them (Anchor's own run
has only `:desc` and the integer `1` at a literal site), so the arms are
removed rather than guessed at: the function is now `term in [:asc, :desc] or
is_integer(term)`. The `:asc`/`:desc` and integer arms are pinned by the tests
at `eval_test.exs:54` (generated kill map above). A new control pins that any
other literal stays with the analysis.

Command: `mix test --force test/anchor/domain/cfa/eval_test.exs --timeout 2000 --max-cases 2`

| # | File | Mutation | Result |
|---|---|---|---|
| F | `lib/anchor/domain/cfa/eval.ex` | `term in [:asc, :desc] or is_integer(term)` -> `term in [:asc, :desc] or is_integer(term) or is_list(term)` | 6 tests, 1 failure |

```
  1) test a higher-order argument written as a literal (DND-5674) control: a literal of a shape no slot takes (a list) is not guessed at: :any (Anchor.Domain.Cfa.EvalTest)
     test/anchor/domain/cfa/eval_test.exs:68
     Assertion with == failed
     code:  assert Cfa.closures_at(cfa, site({@literal, :list, 1})) == :any
     left:  {:ok, MapSet.new([])}
     right: :any
     stacktrace:
       test/anchor/domain/cfa/eval_test.exs:70: (test)
```

Restored: 6 tests, 0 failures. A first try of the control with
`[&Mod.f/1]` stayed green under F: an external capture compiles to a
`make_fun` call, so that list is not a Core literal and never reached
`data_literal?/1`. The control uses the literal `[:a]`.
