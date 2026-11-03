# Sabotage record — the context_acyclic graph rule (DND-5445)

- **Domain:** context_acyclic
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.ContextGraph`, `Anchor.Domain.GraphRules.ContextAcyclic`, `Anchor.Domain.ViolationKey.graph_key/2`, and the registration in `Anchor.Domain.GraphRules`
- **Suite run:** each mutation ran `mix test --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red on the first pass.

The RuleSchema registration (`context_acyclic: :graph`) is held by
`rule_schema_test.exs`'s check that the graph types are exactly the graph rule
modules' (GR-B breaks the module side of that pair), and the config load of a
`context_acyclic` rule by its table in `rule_checks_nothing_test.exs`, the
same `graph_common_rows/0` the layering record exercises (CF-A there).

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CG-A | the caller set is ignored (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `14 tests, 2 failures` (red) | build/2 only the given callers' calls are read; check/2 the rule reads the calls of the modules it selects |
| CG-B | witnesses are not sorted (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `14 tests, 1 failure` (red) | build/1 two calls A -> B from different functions are one edge with two witnesses, sorted |
| CG-C | a call within one context is an edge (a self-loop) (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `14 tests, 1 failure` (red) | build/1 a call within one context, to a non-project module, or with a nil context: no edge |
| CG-D | a nil caller context is an edge (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs` | `5 tests, 1 failure` (red) | build/1 a call within one context, to a non-project module, or with a nil context: no edge |
| CG-E | a dynamic call's candidates give no edge (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs` | `5 tests, 1 failure` (red) | build/1 a dynamic call with candidates in B and C is an edge to each |
| CA-A | a one-context component is reported (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_canary_test.exs` | `15 tests, 5 failures` (red) | check/2 a context calling itself is not a cycle; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it; check/2 an acyclic chain is none; closing it is one; check/2 the rule reads the calls of the modules it selects; context_acyclic: CycleB without its call back is none |
| CA-B | the edge with the most calls is inverted (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `9 tests, 3 failures` (red) | check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted; check/2 a tie on calls inverts the lexically first edge; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-C | a tie is broken by the last edge, not the first (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `9 tests, 2 failures` (red) | check/2 a tie on calls inverts the lexically first edge; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-D | edges outside the component are listed (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `9 tests, 1 failure` (red) | check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-E | the key's contexts are not joined in order (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_canary_test.exs` | `15 tests, 5 failures` (red) | check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it; check/2 two disjoint cycles are two violations, in context order; check/2 with an id, the key starts with it; context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding |
| CA-F | violations are not sorted (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `9 tests, 1 failure` (red) | check/2 two disjoint cycles are two violations, in context order |
| VK-C | graph_key/2 lets a newline through (`lib/anchor/domain/violation_key.ex`) | `violation_key_test.exs` | `6 tests, 1 failure` (red) | graph_key/2 <id>\|<subject>, for a finding with no target; a newline raises |
| GR-B | context_acyclic is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_canary_test.exs` | `14 tests, 3 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding; the compliant canary modules give no findings, and the summary counts the tree |
