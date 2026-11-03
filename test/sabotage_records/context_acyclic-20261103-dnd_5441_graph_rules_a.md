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

## Review-floor re-run (2026-11-03, on 637a6b7)

The review floor (ADR 003) found that the rows below gave only counts and test
names. Every mutation was re-run on 637a6b7, the head after the review-floor
fixes, by a driver that keeps each failing test's ExUnit block verbatim; the
table and the sections after it are that run. A mutation whose source text the
fixes changed was re-anchored to the same defect in the new code. A row marked
"regression" is the unfixed code itself, not a mutation: its block is quoted
from the run that showed it red before the fix, as the fix commit records it.
The checkout's absolute path in the output reads `<worktree>`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CG-A | the caller set is ignored (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 2 failures` (red) | build/2 only the given callers' calls are read; check/2 the rule reads the calls of the modules it selects |
| CG-B | witnesses are not sorted (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 1 failure` (red) | build/1 two calls A -> B from different functions are one edge with two witnesses, sorted |
| CG-C | a call within one context is an edge (a self-loop) (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 1 failure` (red) | build/1 a call within one context, to a non-project module, or with a nil context: no edge |
| CG-D | a nil caller context is an edge (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs` | `6 tests, 1 failure` (red) | build/1 a call within one context, to a non-project module, or with a nil context: no edge |
| CG-E | a dynamic call's candidates give no edge (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs` | `6 tests, 1 failure` (red) | build/1 a dynamic call with candidates in B and C is an edge to each |
| CA-A | a one-context component is reported (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_canary_test.exs` | `16 tests, 5 failures` (red) | check/2 a context calling itself is not a cycle; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it; check/2 an acyclic chain is none; closing it is one; check/2 the rule reads the calls of the modules it selects; context_acyclic: CycleB without its call back is none |
| CA-B | the edge with the most calls is inverted (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 3 failures` (red) | check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted; check/2 a tie on calls inverts the lexically first edge; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-C | a tie is broken by the last edge, not the first (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 2 failures` (red) | check/2 a tie on calls inverts the lexically first edge; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-D | edges outside the component are listed (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 1 failure` (red) | check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it |
| CA-E | the key's contexts are not joined in order (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs`, `graph_canary_test.exs` | `16 tests, 5 failures` (red) | check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted; check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it; check/2 two disjoint cycles are two violations, in context order; check/2 with an id, the key starts with it; context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding |
| CA-F | violations are not sorted (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 1 failure` (red) | check/2 two disjoint cycles are two violations, in context order |
| VK-C | graph_key/2 lets a newline through (`lib/anchor/domain/violation_key.ex`) | `violation_key_test.exs` | `6 tests, 1 failure` (red) | graph_key/2 <id>\|<subject>, for a finding with no target; a newline raises |
| GR-B | context_acyclic is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_canary_test.exs` | `14 tests, 3 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding; the compliant canary modules give no findings, and the summary counts the tree |
| CG-F | a closure application is listed as unresolved (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 2 failures` (red) | build/1 a computed function name is unresolved, with its caller and line; a closure is not; check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none |
| CG-G | computed-name calls are dropped (`lib/anchor/domain/context_graph.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 2 failures` (red) | build/1 a computed function name is unresolved, with its caller and line; a closure is not; check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none |
| CA-G | the rule does not report what it could not see (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 1 failure` (red) | check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none |
| CA-H | one unresolved violation per call, not per (caller, arity) (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_acyclic_test.exs` | `10 tests, 1 failure` (red) | check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none |
| CA-R | regression (review floor on d9a61de): a computed function name was dropped, never reported (`lib/anchor/domain/graph_rules/context_acyclic.ex`) | `context_graph_test.exs`, `context_acyclic_test.exs` | `16 tests, 6 failures` (red) | build/1 a computed function name is unresolved, with its caller and line; a closure is not; check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none |

## CG-A — the caller set is ignored

Run summary: `16 tests, 2 failures`

```text
  1) test build/2 only the given callers' calls are read (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:140
     Assertion with == failed
     code:  assert Map.keys(ContextGraph.build(model(calls), [B.One]).edges) == [{"B", "C"}]
     left:  [{"A", "B"}, {"B", "C"}]
     right: [{"B", "C"}]
     stacktrace:
       test/anchor/domain/context_graph_test.exs:143: (test)

  2) test check/2 the rule reads the calls of the modules it selects (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:117
     Assertion with == failed
     code:  assert ContextAcyclic.check(cycle, %{@rule | paths: ["lib/a.ex"]}) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "A.M.f/0",
                message: "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert A -> B (its 1 call is the fewest): have A publish an event B subscribes to, or declare the function A needs in an interface A owns and have B implement it.",
                filename: "lib/a.ex",
                kind: :rule,
                key: "context_acyclic|A,B",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:120: (test)
```

## CG-B — witnesses are not sorted

Run summary: `16 tests, 1 failure`

```text
  1) test build/1 two calls A -> B from different functions are one edge with two witnesses, sorted (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:70
     Assertion with == failed
     code:  assert graph.edges == %{
              {"A", "B"} => [
                {{A.One, :f, 0}, {B.One, :h, 1}, "lib/A.One.ex", 4},
                {{A.Two, :g, 0}, {B.One, :h, 1}, "lib/A.Two.ex", 9}
              ]
            }
     left:  %{
              {"A", "B"} => [
                {{A.Two, :g, 0}, {B.One, :h, 1}, "lib/A.Two.ex", 9},
                {{A.One, :f, 0}, {B.One, :h, 1}, "lib/A.One.ex", 4}
              ]
            }
     right: %{
              {"A", "B"} => [
                {{A.One, :f, 0}, {B.One, :h, 1}, "lib/A.One.ex", 4},
                {{A.Two, :g, 0}, {B.One, :h, 1}, "lib/A.Two.ex", 9}
              ]
            }
     stacktrace:
       test/anchor/domain/context_graph_test.exs:79: (test)
```

## CG-C — a call within one context is an edge (a self-loop)

Run summary: `16 tests, 1 failure`

```text
  1) test build/1 a call within one context, to a non-project module, or with a nil context: no edge (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:87
     Assertion with == failed
     code:  assert ContextGraph.build(model(calls)) == %{nodes: [], edges: %{}, unresolved: []}
     left:  %{
              nodes: ["A"],
              edges: %{
                {"A", "A"} => [
                  {{A.One, :f, 0}, {A.Two, :g, 0}, "lib/A.One.ex",
                   1}
                ]
              },
              unresolved: []
            }
     right: %{nodes: [], edges: %{}, unresolved: []}
     stacktrace:
       test/anchor/domain/context_graph_test.exs:95: (test)
```

## CG-D — a nil caller context is an edge

Run summary: `6 tests, 1 failure`

```text
  1) test build/1 a call within one context, to a non-project module, or with a nil context: no edge (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:87
     Assertion with == failed
     code:  assert ContextGraph.build(model(calls)) == %{nodes: [], edges: %{}, unresolved: []}
     left:  %{
              nodes: [nil, "B"],
              edges: %{
                {nil, "B"} => [
                  {{Nil.One, :g, 0}, {B.One, :h, 1},
                   "lib/Nil.One.ex", 4}
                ]
              },
              unresolved: []
            }
     right: %{nodes: [], edges: %{}, unresolved: []}
     stacktrace:
       test/anchor/domain/context_graph_test.exs:95: (test)
```

## CG-E — a dynamic call's candidates give no edge

Run summary: `6 tests, 1 failure`

```text
  1) test build/1 a dynamic call with candidates in B and C is an edge to each (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:102
     Assertion with == failed
     code:  assert graph.edges == %{
              {"A", "B"} => [{{A.One, :f, 0}, {B.One, :fetch, 1}, "lib/A.One.ex", 7}],
              {"A", "C"} => [{{A.One, :f, 0}, {C.One, :fetch, 1}, "lib/A.One.ex", 7}]
            }
     left:  %{}
     right: %{
              {"A", "B"} => [
                {{A.One, :f, 0}, {B.One, :fetch, 1}, "lib/A.One.ex",
                 7}
              ],
              {"A", "C"} => [
                {{A.One, :f, 0}, {C.One, :fetch, 1}, "lib/A.One.ex",
                 7}
              ]
            }
     stacktrace:
       test/anchor/domain/context_graph_test.exs:111: (test)
```

## CA-A — a one-context component is reported

Run summary: `16 tests, 5 failures`

```text
  1) test check/2 the rule reads the calls of the modules it selects (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:117
     ** (Enum.EmptyError) empty error
     code: assert ContextAcyclic.check(cycle, %{@rule | paths: ["lib/a.ex"]}) == []
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:2139: anonymous fn/0 in Enum.min_by/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:97: Anchor.Domain.GraphRules.ContextAcyclic.violation/3
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:58: Anchor.Domain.GraphRules.ContextAcyclic.check/2
       test/anchor/domain/graph_rules/context_acyclic_test.exs:120: (test)

  2) test check/2 an acyclic chain is none; closing it is one (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:81
     ** (Enum.EmptyError) empty error
     code: assert ContextAcyclic.check(model(chain), @rule) == []
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:2139: anonymous fn/0 in Enum.min_by/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:97: Anchor.Domain.GraphRules.ContextAcyclic.violation/3
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:58: Anchor.Domain.GraphRules.ContextAcyclic.check/2
       test/anchor/domain/graph_rules/context_acyclic_test.exs:84: (test)

  3) test check/2 a context calling itself is not a cycle (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:101
     ** (Enum.EmptyError) empty error
     code: assert ContextAcyclic.check(model, @rule) == []
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:2139: anonymous fn/0 in Enum.min_by/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:97: Anchor.Domain.GraphRules.ContextAcyclic.violation/3
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:58: Anchor.Domain.GraphRules.ContextAcyclic.check/2
       test/anchor/domain/graph_rules/context_acyclic_test.exs:114: (test)

  4) test check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:71
     ** (Enum.EmptyError) empty error
     code: assert [v] = ContextAcyclic.check(model(edges), @rule)
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:2139: anonymous fn/0 in Enum.min_by/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:97: Anchor.Domain.GraphRules.ContextAcyclic.violation/3
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/context_acyclic.ex:58: Anchor.Domain.GraphRules.ContextAcyclic.check/2
       test/anchor/domain/graph_rules/context_acyclic_test.exs:74: (test)

  5) test context_acyclic: CycleB without its call back is none (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:175
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "<worktree>/test/fixtures/graph_canary/.anchor.yml",
                  line: nil,
                  message: "rule 2 (id: \"context_acyclic\", context_acyclic) could not run: Enum.EmptyError: empty error (raised at lib/enum.ex:2139: anonymous fn/0 in Enum.min_by/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 7, opaque: 0, apps: 1, rules: 2},
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:190: (test)
```

## CA-B — the edge with the most calls is inverted

Run summary: `10 tests, 3 failures`

```text
  1) test check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:71
     Assertion with =~ failed
     code:  assert v.message =~ "invert A -> B (its 2 calls are the fewest)"
     left:  "contexts A, B, C form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> C (B.M.f/0 calls C.M.g/0), C -> A (C.M.f/0 calls A.M.g/0). Fix: invert C -> A (its 2 calls are the fewest): have C publish an event A subscribes to, or declare the function C needs in an interface C owns and have A implement it."
     right: "invert A -> B (its 2 calls are the fewest)"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:78: (test)

  2) test check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:56
     Assertion with == failed
     code:  assert v.filename == "lib/b.ex"
     left:  "lib/a.ex"
     right: "lib/b.ex"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:60: (test)

  3) test check/2 a tie on calls inverts the lexically first edge (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:95
     Assertion with =~ failed
     code:  assert v.message =~ "Fix: invert A -> B (its 2 calls are the fewest)"
     left:  "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert B -> A (its 2 calls are the fewest): have B publish an event A subscribes to, or declare the function B needs in an interface B owns and have A implement it."
     right: "Fix: invert A -> B (its 2 calls are the fewest)"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:97: (test)
```

## CA-C — a tie is broken by the last edge, not the first

Run summary: `10 tests, 2 failures`

```text
  1) test check/2 a tie on calls inverts the lexically first edge (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:95
     Assertion with =~ failed
     code:  assert v.message =~ "Fix: invert A -> B (its 2 calls are the fewest)"
     left:  "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert B -> A (its 2 calls are the fewest): have B publish an event A subscribes to, or declare the function B needs in an interface B owns and have A implement it."
     right: "Fix: invert A -> B (its 2 calls are the fewest)"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:97: (test)

  2) test check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:71
     Assertion with =~ failed
     code:  assert v.message =~ "invert A -> B (its 2 calls are the fewest)"
     left:  "contexts A, B, C form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> C (B.M.f/0 calls C.M.g/0), C -> A (C.M.f/0 calls A.M.g/0). Fix: invert C -> A (its 2 calls are the fewest): have C publish an event A subscribes to, or declare the function C needs in an interface C owns and have A implement it."
     right: "invert A -> B (its 2 calls are the fewest)"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:78: (test)
```

## CA-D — edges outside the component are listed

Run summary: `10 tests, 1 failure`

```text
  1) test check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:71
     Refute with =~ failed
     code:  refute v.message =~ "D"
     left:  "contexts A, B, C form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> C (B.M.f/0 calls C.M.g/0), C -> A (C.M.f/0 calls A.M.g/0), D -> A (D.M.f/0 calls A.M.g/0). Fix: invert D -> A (its 1 call is the fewest): have D publish an event A subscribes to, or declare the function D needs in an interface D owns and have A implement it."
     right: "D"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:77: (test)
```

## CA-E — the key's contexts are not joined in order

Run summary: `16 tests, 5 failures`

```text
  1) test check/2 A <-> B is one violation listing both edges; the edge with fewer calls is inverted (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:56
     Assertion with == failed
     code:  assert v.key == "context_acyclic|A,B"
     left:  "context_acyclic|B,A"
     right: "context_acyclic|A,B"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:59: (test)

  2) test check/2 two disjoint cycles are two violations, in context order (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:88
     match (=) failed
     code:  assert [%{key: "context_acyclic|A,B"}, %{key: "context_acyclic|E,F"}] =
              ContextAcyclic.check(model(edges), @rule)
     left:  [%{key: "context_acyclic|A,B"}, %{key: "context_acyclic|E,F"}]
     right: [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "A.M.f/0",
                message: "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert A -> B (its 1 call is the fewest): have A publish an event B subscribes to, or declare the function A needs in an interface A owns and have B implement it.",
                filename: "lib/a.ex",
                kind: :rule,
                key: "context_acyclic|B,A",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "E.M.f/0",
                message: "contexts E, F form a cycle: E -> F (E.M.f/0 calls F.M.g/0), F -> E (F.M.f/0 calls E.M.g/0). Fix: invert E -> F (its 1 call is the fewest): have E publish an event F subscribes to, or declare the function E needs in an interface E owns and have F implement it.",
                filename: "lib/e.ex",
                kind: :rule,
                key: "context_acyclic|F,E",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:91: (test)

  3) test check/2 a triangle with a tail D -> A is one violation on A, B, C; D is not in it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:71
     Assertion with == failed
     code:  assert v.key == "context_acyclic|A,B,C"
     left:  "context_acyclic|C,B,A"
     right: "context_acyclic|A,B,C"
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:75: (test)

  4) test check/2 with an id, the key starts with it (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:124
     match (=) failed
     code:  assert [%{key: "ctx|A,B", rule_id: "ctx"}] =
              ContextAcyclic.check(
                model([{"A", "B", 1}, {"B", "A", 1}]),
                Map.put(@rule, :id, "ctx")
              )
     left:  [%{key: "ctx|A,B", rule_id: "ctx"}]
     right: [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "A.M.f/0",
                message: "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert A -> B (its 1 call is the fewest): have A publish an event B subscribes to, or declare the function A needs in an interface A owns and have B implement it.",
                filename: "lib/a.ex",
                kind: :rule,
                key: "ctx|B,A",
                rule_id: "ctx",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:125: (test)

  5) test context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:159
     Assertion with == failed
     code:  assert finding.key == "context_acyclic|AnchorFixtures.CycleA,AnchorFixtures.CycleB"
     left:  "context_acyclic|AnchorFixtures.CycleB,AnchorFixtures.CycleA"
     right: "context_acyclic|AnchorFixtures.CycleA,AnchorFixtures.CycleB"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:167: (test)
```

## CA-F — violations are not sorted

Run summary: `10 tests, 1 failure`

```text
  1) test check/2 two disjoint cycles are two violations, in context order (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:88
     match (=) failed
     code:  assert [%{key: "context_acyclic|A,B"}, %{key: "context_acyclic|E,F"}] =
              ContextAcyclic.check(model(edges), @rule)
     left:  [%{key: "context_acyclic|A,B"}, %{key: "context_acyclic|E,F"}]
     right: [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "E.M.f/0",
                message: "contexts E, F form a cycle: E -> F (E.M.f/0 calls F.M.g/0), F -> E (F.M.f/0 calls E.M.g/0). Fix: invert E -> F (its 1 call is the fewest): have E publish an event F subscribes to, or declare the function E needs in an interface E owns and have F implement it.",
                filename: "lib/e.ex",
                kind: :rule,
                key: "context_acyclic|E,F",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "A.M.f/0",
                message: "contexts A, B form a cycle: A -> B (A.M.f/0 calls B.M.g/0), B -> A (B.M.f/0 calls A.M.g/0). Fix: invert A -> B (its 1 call is the fewest): have A publish an event B subscribes to, or declare the function A needs in an interface A owns and have B implement it.",
                filename: "lib/a.ex",
                kind: :rule,
                key: "context_acyclic|A,B",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:91: (test)
```

## VK-C — graph_key/2 lets a newline through

Run summary: `6 tests, 1 failure`

```text
  1) test graph_key/2 <id>|<subject>, for a finding with no target; a newline raises (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:48
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn -> ViolationKey.graph_key(%{type: :t}, "A\nB") end
     stacktrace:
       test/anchor/domain/violation_key_test.exs:51: (test)
```

## GR-B — context_acyclic is not registered as a graph rule

Run summary: `14 tests, 3 failures`

```text
  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:33
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:layering]
     right: [:context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:36: (test)

  2) test context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:159
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:164: (test)

  3) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:76
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 6 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
     left:  "anchor.graph: 6 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 6 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:83: (test)
```

## CG-F — a closure application is listed as unresolved

Run summary: `16 tests, 2 failures`

```text
  1) test build/1 a computed function name is unresolved, with its caller and line; a closure is not (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:125
     Assertion with == failed
     code:  assert ContextGraph.build(model(calls)).unresolved == [
              {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
              {{A.One, :g, 0}, 2, "lib/A.One.ex", 3}
            ]
     left:  [
              {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
              {{A.One, :g, 0}, 2, "lib/A.One.ex", 3},
              {{A.One, :h, 0}, 1, "lib/A.One.ex", 4}
            ]
     right: [
              {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
              {{A.One, :g, 0}, 2, "lib/A.One.ex", 3}
            ]
     stacktrace:
       test/anchor/domain/context_graph_test.exs:132: (test)

  2) test check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:135
     match (=) failed
     code:  assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "A.M.f/0",
                message: "A.M.f/0 calls a function it computes (?/1), so its target cannot be checked. Fix: call the module's function by name (a call on a computed module, mod.fetch(x), is judged against every module exporting it); apply a closure as fun.(args).",
                filename: "lib/a.ex",
                kind: :rule,
                key: "ctx|A.M.f/0|-> dynamic ?/1",
                rule_id: "ctx",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "A.M.g/0",
                message: "A.M.g/0 calls a function it computes (?/1), so its target cannot be checked. Fix: call the module's function by name (a call on a computed module, mod.fetch(x), is judged against every module exporting it); apply a closure as fun.(args).",
                filename: "lib/a.ex",
                kind: :rule,
                key: "ctx|A.M.g/0|-> dynamic ?/1",
                rule_id: "ctx",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:162: (test)
```

## CG-G — computed-name calls are dropped

Run summary: `16 tests, 2 failures`

```text
  1) test build/1 a computed function name is unresolved, with its caller and line; a closure is not (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:125
     Assertion with == failed
     code:  assert ContextGraph.build(model(calls)).unresolved == [
              {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
              {{A.One, :g, 0}, 2, "lib/A.One.ex", 3}
            ]
     left:  []
     right: [
              {{A.One, :f, 0}, 1, "lib/A.One.ex", 2},
              {{A.One, :g, 0}, 2, "lib/A.One.ex", 3}
            ]
     stacktrace:
       test/anchor/domain/context_graph_test.exs:132: (test)

  2) test check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:135
     match (=) failed
     code:  assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:162: (test)
```

## CA-G — the rule does not report what it could not see

Run summary: `10 tests, 1 failure`

```text
  1) test check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:135
     match (=) failed
     code:  assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:162: (test)
```

## CA-H — one unresolved violation per call, not per (caller, arity)

Run summary: `10 tests, 1 failure`

```text
  1) test check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:135
     match (=) failed
     code:  assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "A.M.f/0",
                message: "A.M.f/0 calls a function it computes (?/1), so its target cannot be checked. Fix: call the module's function by name (a call on a computed module, mod.fetch(x), is judged against every module exporting it); apply a closure as fun.(args).",
                filename: "lib/a.ex",
                kind: :rule,
                key: "ctx|A.M.f/0|-> dynamic ?/1",
                rule_id: "ctx",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 6,
                trigger: "A.M.f/0",
                message: "A.M.f/0 calls a function it computes (?/1), so its target cannot be checked. Fix: call the module's function by name (a call on a computed module, mod.fetch(x), is judged against every module exporting it); apply a closure as fun.(args).",
                filename: "lib/a.ex",
                kind: :rule,
                key: "ctx|A.M.f/0|-> dynamic ?/1",
                rule_id: "ctx",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:162: (test)
```

## CA-R — regression (review floor on d9a61de): a computed function name was dropped, never reported

Run summary: `16 tests, 6 failures`

```text
  4) test build/1 a computed function name is unresolved, with its caller and line; a closure is not (Anchor.Domain.ContextGraphTest)
     test/anchor/domain/context_graph_test.exs:125
     ** (KeyError) key :unresolved not found in:

         %{nodes: [], edges: %{}}

     code: assert ContextGraph.build(model(calls)).unresolved == [
     stacktrace:
       test/anchor/domain/context_graph_test.exs:132: (test)

  6) test check/2 calls it cannot see a computed function name is one unresolved violation; a closure is none (Anchor.Domain.GraphRules.ContextAcyclicTest)
     test/anchor/domain/graph_rules/context_acyclic_test.exs:135
     match (=) failed
     code:  assert [v] = ContextAcyclic.check(model, Map.put(@rule, :id, "ctx"))
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/context_acyclic_test.exs:162: (test)

....    warning: comparison between distinct types found:

        left == right

    given types:

        dynamic(%{edges: term(), nodes: term()}) == %{
          edges: empty_map(),
          nodes: empty_list(),
          unresolved: empty_list()
        }

    where "left" (context ExUnit.Assertions) was given the type:

        # type: dynamic(%{edges: term(), nodes: term()})
        # from: test/anchor/domain/context_graph_test.exs:95
        left = Anchor.Domain.ContextGraph.build(model(calls))

    where "right" (context ExUnit.Assertions) was given the type:

        # type: %{edges: empty_map(), nodes: empty_list(), unresolved: empty_list()}
        # from: test/anchor/domain/context_graph_test.exs:95
        right = %{nodes: [], edges: %{}, unresolved: []}

    While Elixir can compare across all types, you are comparing across types which are always disjoint, and the result is either always true or always false

    typing violation found at:
    │
 95 │       assert ContextGraph.build(model(calls)) == %{nodes: [], edges: %{}, unresolved: []}
    │                                               ~
    │
```
