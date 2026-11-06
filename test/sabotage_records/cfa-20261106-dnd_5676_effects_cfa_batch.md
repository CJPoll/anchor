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
