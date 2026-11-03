# Sabotage record — the layering graph rule (DND-5442)

- **Domain:** layering
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphRules.Layering`, `Anchor.Domain.CallMatrix`, `Anchor.Domain.DynamicCalls`, the `@callback` reading in `Anchor.Adapters.BeamReader` and `Anchor.Domain.Graph.Builder`, the registration in `Anchor.Domain.GraphRules`, and `Anchor.Config`'s architecture check of graph rules
- **Suite run:** each mutation ran `mix test --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red.

## Earlier driver pass, and what changed

Three mutations of the first pass proved nothing. CM-B (a bucket with no row
may call anything) and LA-C (a call within one module is judged) were green:
no test had a bucket without a row, and every test row listed its own bucket,
so a same-module call passed the matrix anyway. A test was added for each.
DC-A did not compile under `--warnings-as-errors` (the type checker saw that
`:unresolved` could no longer match), so it was re-shaped. The LA-C test then
found a real defect, CM-G below: `route/3` answered `[b]` for a bucket to
itself, and Layering's Fix text crashed on it. It was fixed with its
regression test first.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CM-A | a row's scope is ignored (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `23 tests, 3 failures` (red) | allowed?/3 other_context: different known contexts only; allowed?/3 same_context: equal contexts only; nil never matches; check/2 static calls a scope the call breaks: the Fix names the row's scope |
| CM-B | a bucket with no row may call anything (permissive default) (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | allowed?/3 a bucket with no row may call nothing, not even itself |
| CM-C | same_context allows a nil context (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `9 tests, 1 failure` (red) | allowed?/3 same_context: equal contexts only; nil never matches |
| CM-D | other_context allows equal contexts (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `23 tests, 2 failures` (red) | allowed?/3 other_context: different known contexts only; check/2 static calls a scope the call breaks: the Fix names the row's scope |
| CM-E | route drops its destination (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `23 tests, 5 failures` (red) | check/2 static calls a scope the call breaks: the Fix names the row's scope; check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix; route/3 a scoped entry is an edge for routing; route/3 equal-length routes: the first by row order; route/3 framework to adapters through managers |
| CM-F | route explores depth-first, not shortest (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `9 tests, 1 failure` (red) | route/3 equal-length routes: the first by row order |
| DC-A | no declaring behaviour resolves to no candidates instead of unresolved (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `20 tests, 2 failures` (red) | check/2 dynamic calls no behaviour declaring the callback: one unresolved violation; no behaviour declares it: :unresolved (an arity mismatch included) |
| DC-B | a callback's arity is ignored (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs` | `5 tests, 1 failure` (red) | no behaviour declares it: :unresolved (an arity mismatch included) |
| DC-C | every module is a candidate, implementer or not (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `19 tests, 4 failures` (red) | a declared callback no module implements resolves to no candidate; an unknown arity matches the callback's name at any arity; the implementations of the behaviour declaring the callback, sorted; two behaviours declaring it: the union of their implementations |
| LA-A | a closure application is judged as a dynamic call (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `14 tests, 1 failure` (red) | check/2 dynamic calls a closure application names no function and is not judged |
| LA-B | an unresolved dynamic call is skipped (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `14 tests, 1 failure` (red) | check/2 dynamic calls no behaviour declaring the callback: one unresolved violation |
| LA-C | a call within one module is judged (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `15 tests, 1 failure` (red) | check/2 static calls a call within one module is allowed even when the bucket's row omits it |
| LA-D | one violation per call, not per (caller, callee) pair (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `14 tests, 1 failure` (red) | check/2 static calls one function calling the forbidden target three times is one violation, first line |
| LA-E | the last call's line is kept, not the first (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `14 tests, 1 failure` (red) | check/2 static calls one function calling the forbidden target three times is one violation, first line |
| LA-F | the rule's selector is ignored (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `14 tests, 1 failure` (red) | check/2 static calls a caller outside the rule's selector is not judged |
| LA-G | the Fix names no route (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs`, `graph_canary_test.exs` | `18 tests, 2 failures` (red) | check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix; layering (DND-5442): the violating module gives exactly one finding, with the route |
| BR-A | the reader reads specs, not callbacks (`lib/anchor/adapters/beam_reader.ex`) | `callbacks_test.exs` | `1 test, 1 failure` (red) | a behaviour's node lists its callbacks, sorted; an implementation's lists none |
| BU-A | the builder drops a beam's callbacks (`lib/anchor/domain/graph/builder.ex`) | `callbacks_test.exs` | `1 test, 1 failure` (red) | a behaviour's node lists its callbacks, sorted; an implementation's lists none |
| GR-A | layering is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_canary_test.exs`, `rule_schema_test.exs` | `45 tests, 5 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; layering (DND-5442): the violating module gives exactly one finding, with the route; layering baseline: written, then held, then STALE once the violation is fixed; the compliant canary modules give no findings, and the summary counts the tree |
| CF-A | Config skips the graph rules' architecture check (`lib/anchor/domain/config.ex`) | `rule_checks_nothing_test.exs` | `25 tests, 1 failure` (red) | layering: every rule that checks nothing is refused, and the positive rows load |
| CM-G | regression: `route/3` with its first clause `def route(%Architecture{}, bucket, bucket), do: [bucket]`, as first written; the unfixed code, not a mutation (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | route/3 a bucket to itself is searched like any other pair (left: `["s"]`, right: `:none`; through Layering the one-bucket route crashed `route_text/4` with a MatchError) |
