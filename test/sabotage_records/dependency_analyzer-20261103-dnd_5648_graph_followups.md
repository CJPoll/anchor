# Sabotage records: dependency_analyzer (branch dnd-5648-graph-followups)

- **Domain:** dependency_analyzer
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5491: AST/graph parity (the engine split) (PA-A)

**Run with:** the `## DND-5491: AST/graph parity (the engine split)` section of `parity-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-A | alias resolution removed from DependencyAnalyzer (an aliased call unseen by the AST) (`lib/anchor/domain/dependency_analyzer.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 2 failures` (red) | both engines flag the same pairs, apart from the listed divergences; the pairs each engine flags, named (so a change in either is read here) |

### PA-A: alias resolution removed from DependencyAnalyzer (an aliased call unseen by the AST)

Run summary: `50 tests, 2 failures`

```text
  1) test both engines flag the same pairs, apart from the listed divergences (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:114
     the engines disagree on: AnchorFixtures.Parity.Orders.Ui.Badge -> AnchorFixtures.Parity.Orders.Managers.Checkout (only the graph engine flags it)
     code: assert found -- listed == [],
     stacktrace:
       test/anchor/integration/layering_parity_test.exs:130: (test)

  2) test the pairs each engine flags, named (so a change in either is read here) (Anchor.Integration.LayeringParityTest)
     test/anchor/integration/layering_parity_test.exs:143
     Assertion with == failed
     code:  assert context |> then(&ast_results(NoDependency, &1)) |> Parity.pairs_from_ast() |> Enum.sort() ==
              expected_direct
     left:  [
              {"AnchorFixtures.Parity.Orders.Adapters.Store",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Calc",
               "AnchorFixtures.Parity.Orders.Managers.Checkout"},
              {"AnchorFixtures.Parity.Orders.Domain.Rules",
               "AnchorFixtures.Parity.Orders.Adapters.Store"}
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
```
