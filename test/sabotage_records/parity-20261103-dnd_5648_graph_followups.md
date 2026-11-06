# Sabotage records: parity (branch dnd-5648-graph-followups)

- **Domain:** parity
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- One section per ticket of the batch, in commit order.

## DND-5491: AST/graph parity (the engine split)

**Code under test:** `Anchor.Domain.Parity` (`ast_rules_for/1`, `pairs_from_ast/1`, `pairs_from_graph/1`, `diff/2`, `uncovered/3`), `Anchor.Domain.RuleSchema.early_warning_of/1` and its compile-time check, and, through `test/anchor/integration/layering_parity_test.exs` over `test/fixtures/parity/`, the two engines it holds equal: `Anchor.Domain.DependencyAnalyzer` + `Anchor.Domain.Checks.NoDependency`/`NoTransitiveDependency` (AST) and `Anchor.Domain.GraphRules.Layering` + `Anchor.Domain.CallMatrix` (graph).

**Suite run:** one `test-slot` per batch ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). PA-A first ran green (`50 tests, 0 failures`): the fixture's `alias Orders.Managers.Checkout` named the forbidden module itself, so alias resolution was never needed. That was a test that could not fail; the fixture now aliases the namespace (`alias ...Orders.Managers, as: M`, `M.Checkout.run/1`), and PA-A is red as recorded. PA-B to PA-H were rerun on that fixture. The two acceptance sabotages name the pair and the engine: PA-A `Ui.Badge -> Managers.Checkout (only the graph engine flags it)`, PA-B `Adapters.Store -> Managers.Checkout (only the ast engine flags it)`. PA-G was rerun, and PA-J added, after `module_name?/1` dropped its regex (`GlobPatternTest` holds GlobPattern to be lib/'s only regex compiler).

**PA-I (compile-time check):** mapping `no_transitive_dependency` to `:single_control_flow` (an ast type) in `@early_warning_of` makes `mix compile` fail with the CompileError quoted below; restored, the tree compiles.

With every source restored: the full suite, `mix credo --strict` and `MIX_ENV=dev mix anchor.graph` pass (counts in the commit message).

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-C | diff/2 never reports a graph-only pair (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 2 failures` (red) | diff/2 one extra on each side lands in the right field, sorted; both engines flag the same pairs, apart from the listed divergences |
| PA-D | uncovered/3 counts a flagged edge off the chain (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 2 failures` (red) | uncovered/3 (transitive findings) a flagged edge off the chain does not cover it; uncovered/3 (transitive findings) a chain with no flagged edge is uncovered |
| PA-E | ast_rules_for/1 writes no same_context rule for an other_context entry (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 4 failures` (red) | ast_rules_for/1 an other_context entry forbids that bucket within the caller's own context; the pairs each engine flags, named (so a change in either is read here); the derivation reads every bucket of the tree, and its matrix is closed; both engines flag the same pairs, apart from the listed divergences |
| PA-F | ast_rules_for/1 writes no transitive rule (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 4 failures` (red) | ast_rules_for/1 an other_context entry forbids that bucket within the caller's own context; ast_rules_for/1 a row forbids, directly and transitively, the buckets it omits; the derivation reads every bucket of the tree, and its matrix is closed; both engines flag the same pairs, apart from the listed divergences |
| PA-G | pairs_from_ast/1 reads any trigger as a callee (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 1 failure` (red) | pairs_from_ast/1 and pairs_from_graph/1 an AST finding's caller is its file's module, its callee the trigger |
| PA-J | a lower-case name reads as a module (module_name?/1 takes any first letter) (`lib/anchor/domain/parity.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 1 failure` (red) | pairs_from_ast/1 and pairs_from_graph/1 an AST finding's caller is its file's module, its callee the trigger |

Filed under their own domain word (ADR 003): PA-A in `dependency_analyzer-20261103-dnd_5648_graph_followups.md`; PA-B in `layering-20261103-dnd_5648_graph_followups.md`; PA-H in `rule_schema-20261103-dnd_5648_graph_followups.md`.

### PA-C: diff/2 never reports a graph-only pair

Run summary: `50 tests, 2 failures`

```text
  1) test diff/2 one extra on each side lands in the right field, sorted (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:154
     Assertion with == failed
     code:  assert Parity.diff(ast, graph) == %{ast_only: [{"C", "D"}], graph_only: [{"E", "F"}]}
     left:  %{ast_only: [{"C", "D"}], graph_only: []}
     right: %{ast_only: [{"C", "D"}], graph_only: [{"E", "F"}]}
     stacktrace:
       test/anchor/domain/parity_test.exs:157: (test)

.............................................

  2) test both engines flag the same pairs, apart from the listed divergences (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:114
     listed divergences that no longer diverge (delete them): [graph_only: {"AnchorFixtures.Parity.Billing.Domain.Fee", "AnchorFixtures.Parity.Orders.Adapters.Store"}]
     code: assert listed -- found == [],
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:136: (test)
```

### PA-D: uncovered/3 counts a flagged edge off the chain

Run summary: `50 tests, 2 failures`

```text
  1) test uncovered/3 (transitive findings) a flagged edge off the chain does not cover it (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:173
     Assertion with == failed
     code:  assert Parity.uncovered(MapSet.new([{"A", "C"}]), MapSet.new([{"A", "Z"}]), @deps) == [{"A", "C"}]
     left:  []
     right: [{"A", "C"}]
     stacktrace:
       test/anchor/domain/parity_test.exs:174: (test)

.....

  2) test uncovered/3 (transitive findings) a chain with no flagged edge is uncovered (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:168
     Assertion with == failed
     code:  assert Parity.uncovered(MapSet.new([{"A", "C"}]), MapSet.new([{"X", "C"}]), @deps) == [{"A", "C"}]
     left:  []
     right: [{"A", "C"}]
     stacktrace:
       test/anchor/domain/parity_test.exs:169: (test)

...........................................
```

### PA-E: ast_rules_for/1 writes no same_context rule for an other_context entry

Run summary: `50 tests, 4 failures`

```text
  1) test ast_rules_for/1 an other_context entry forbids that bucket within the caller's own context (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:59
     no rule parity:adapters:same_context
     code: } = rule(rules, "parity:adapters:same_context")
     stacktrace:
       test/anchor/domain/parity_test.exs:75: (test)

............

  2) test the pairs each engine flags, named (so a change in either is read here) (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:143
     Assertion with == failed
     code:  assert context |> then(&ast_results(NoDependency, &1)) |> Parity.pairs_from_ast() |> Enum.sort() ==
              expected_direct
     left:  [
              {"AnchorFixtures.Parity.Orders.Domain.Calc",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Rules",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Ui.Badge",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"}
            ]
     right: [
              {"AnchorFixtures.Parity.Orders.Adapters.Store",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Calc",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Rules",
               "AnchorFixtures.Parity.Orders.Adapters.Store"},
              {"AnchorFixtures.Parity.Orders.Ui.Badge",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"}
            ]
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:153: (test)

  3) test the derivation reads every bucket of the tree, and its matrix is closed (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:163
     Assertion with == failed
     code:  assert Enum.map(rules, & &1.id) |> Enum.sort() == Enum.sort(~w(
                           parity:adapters:direct parity:adapters:transitive parity:adapters:same_context
                           parity:domain:direct parity:domain:transitive
                           parity:managers:direct parity:managers:transitive
                           parity:ui:direct parity:ui:transitive
                         ))
     left:  ["parity:adapters:direct", "parity:adapters:transitive",
             "parity:domain:direct", "parity:domain:transitive",
             "parity:managers:direct", "parity:managers:transitive",
             "parity:ui:direct", "parity:ui:transitive"]
     right: ["parity:adapters:direct", "parity:adapters:same_context",
             "parity:adapters:transitive", "parity:domain:direct",
             "parity:domain:transitive", "parity:managers:direct",
             "parity:managers:transitive", "parity:ui:direct",
             "parity:ui:transitive"]
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:168: (test)

.................................
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### PA-F: ast_rules_for/1 writes no transitive rule

Run summary: `50 tests, 4 failures`

```text
  1) test ast_rules_for/1 an other_context entry forbids that bucket within the caller's own context (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:59
     no rule parity:adapters:transitive
     code: assert rule(rules, "parity:adapters:transitive").forbidden_patterns == ["App.*.framework.*"]
     stacktrace:
       test/anchor/domain/parity_test.exs:78: (test)

...

  2) test ast_rules_for/1 a row forbids, directly and transitively, the buckets it omits (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:29
     no rule parity:domain:transitive
     code: transitive = rule(rules, "parity:domain:transitive")
     stacktrace:
       test/anchor/domain/parity_test.exs:48: (test)

........................................

  3) test the derivation reads every bucket of the tree, and its matrix is closed (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:163
     Assertion with == failed
     code:  assert Enum.map(rules, & &1.id) |> Enum.sort() == Enum.sort(~w(
                           parity:adapters:direct parity:adapters:transitive parity:adapters:same_context
                           parity:domain:direct parity:domain:transitive
                           parity:managers:direct parity:managers:transitive
                           parity:ui:direct parity:ui:transitive
                         ))
     left:  ["parity:adapters:direct", "parity:adapters:same_context",
             "parity:domain:direct", "parity:managers:direct",
             "parity:ui:direct"]
     right: ["parity:adapters:direct", "parity:adapters:same_context",
             "parity:adapters:transitive", "parity:domain:direct",
             "parity:domain:transitive", "parity:managers:direct",
             "parity:managers:transitive", "parity:ui:direct",
             "parity:ui:transitive"]
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:168: (test)
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### PA-G: pairs_from_ast/1 reads any trigger as a callee

Run summary: `50 tests, 1 failure`

```text
  1) test pairs_from_ast/1 and pairs_from_graph/1 an AST finding's caller is its file's module, its callee the trigger (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:111
     Assertion with == failed
     code:  assert Parity.pairs_from_ast(results) ==
              MapSet.new([{"App.Orders.domain.Order", "App.Orders.adapters.Store"}])
     left:  MapSet.new([
              {"App.Orders.domain.Order",
               "App.Orders.adapters.Store"},
              {"App.Orders.domain.Order", "alias"}
            ])
     right: MapSet.new([
              {"App.Orders.domain.Order",
               "App.Orders.adapters.Store"}
            ])
     stacktrace:
       test/anchor/domain/parity_test.exs:125: (test)

.............................................
```

### PA-J: a lower-case name reads as a module (module_name?/1 takes any first letter)

Run summary: `50 tests, 1 failure`

```text
  1) test pairs_from_ast/1 and pairs_from_graph/1 an AST finding's caller is its file's module, its callee the trigger (Anchor.Domain.ParityTest)
     test/anchor/domain/parity_test.exs:111
     Assertion with == failed
     code:  assert Parity.pairs_from_ast(results) ==
              MapSet.new([{"App.Orders.domain.Order", "App.Orders.adapters.Store"}])
     left:  MapSet.new([
              {"App.Orders.domain.Order",
               "App.Orders.adapters.Store"},
              {"App.Orders.domain.Order", "alias"}
            ])
     right: MapSet.new([
              {"App.Orders.domain.Order",
               "App.Orders.adapters.Store"}
            ])
     stacktrace:
       test/anchor/domain/parity_test.exs:125: (test)

.............................................
```

### PA-I: an early warning that names an ast type (compile-time check)

Mutation: `no_transitive_dependency: :single_control_flow` in `@early_warning_of` (`lib/anchor/domain/rule_schema.ex`). Result: `mix compile` exit 1 (red).

```text
** (CompileError) Anchor.Domain.RuleSchema: @early_warning_of maps no_transitive_dependency to single_control_flow; an early warning is an :ast rule type of a :graph rule type (its authority)
```
