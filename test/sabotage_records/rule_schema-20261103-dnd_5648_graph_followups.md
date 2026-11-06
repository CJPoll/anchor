# Sabotage records: rule_schema (branch dnd-5648-graph-followups)

- **Domain:** rule_schema
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5491: AST/graph parity (the engine split) (PA-H)

**Run with:** the `## DND-5491: AST/graph parity (the engine split)` section of `parity-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-H | no_direct_dependency warns of another graph type (`lib/anchor/domain/rule_schema.ex`) | `parity_test.exs`, `layering_parity_test.exs`, `rule_schema_test.exs` | `50 tests, 1 failure` (red) | early_warning_of/1 the AST dependency rules are layering's early warnings |

### PA-H: no_direct_dependency warns of another graph type

Run summary: `50 tests, 1 failure`

```text
  1) test early_warning_of/1 the AST dependency rules are layering's early warnings (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:240
     Assertion with == failed
     code:  assert RuleSchema.early_warning_of(:no_direct_dependency) == :layering
     left:  :context_acyclic
     right: :layering
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:241: (test)

.......................
```
