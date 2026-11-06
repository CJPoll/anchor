# Sabotage records: context_acyclic (branch dnd-5648-graph-followups)

- **Domain:** context_acyclic
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers (DY-L)

**Run with:** the `## DND-5633: a dynamic call narrowed to a declared behaviour's implementers` section of `layering-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-L | an equal cycle narrows (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_rules_test.exs` | `27 tests, 1 failure` (red) | narrows?/2 the same set, a superset, another rule's or a disjoint cycle does not |

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
