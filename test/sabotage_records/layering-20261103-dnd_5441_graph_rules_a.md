# Sabotage record — the layering graph rule (DND-5442)

- **Domain:** layering
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphRules.Layering`, `Anchor.Domain.CallMatrix`, `Anchor.Domain.DynamicCalls`, `Anchor.Domain.ViolationKey.mfa/1`, the registration in `Anchor.Domain.GraphRules`, and `Anchor.Config`'s architecture check of graph rules
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

## Review-floor re-run (2026-11-03, on 637a6b7)

The review floor (ADR 003) found that the rows below gave only counts and test
names. Every mutation was re-run on 637a6b7, the head after the review-floor
fixes, by a driver that keeps each failing test's ExUnit block verbatim; the
table and the sections after it are that run. A mutation whose source text the
fixes changed was re-anchored to the same defect in the new code. A row marked
"regression" is the unfixed code itself, not a mutation: its block is quoted
from the run that showed it red before the fix, as the fix commit records it.
The checkout's absolute path in the output reads `<worktree>`. Each run
forced compilation (`mix test --force`, and a write never in the same second
as the last): a first pass of this re-run measured BL-C on BL-B's stale beam,
which the critic caught from its verbatim output.

The review floor replaced behaviour-based resolution of a dynamic call with
every module exporting the function, and removed the `@callback` plumbing:
the first pass's DC-A to DC-C, LA-B, BR-A and BU-A mutated code that no longer
exists and are not re-run. DC-D to DC-H, LA-J and CF-B are the new code's.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CM-A | a row's scope is ignored (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `29 tests, 3 failures` (red) | allowed?/3 other_context: different known contexts only; allowed?/3 same_context: equal contexts only; nil never matches; check/2 static calls a scope the call breaks: the Fix names the row's scope |
| CM-B | a bucket with no row may call anything (permissive default) (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | allowed?/3 a bucket with no row may call nothing, not even itself |
| CM-C | same_context allows a nil context (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | allowed?/3 same_context: equal contexts only; nil never matches |
| CM-D | other_context allows equal contexts (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `29 tests, 2 failures` (red) | allowed?/3 other_context: different known contexts only; check/2 static calls a scope the call breaks: the Fix names the row's scope |
| CM-E | route drops its destination (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs`, `layering_test.exs` | `29 tests, 6 failures` (red) | check/2 static calls a scope the call breaks: the Fix names the row's scope; check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix; route/3 a bucket to itself is searched like any other pair; route/3 a scoped entry is an edge for routing; route/3 equal-length routes: the first by row order; route/3 framework to adapters through managers |
| CM-F | route explores depth-first, not shortest (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | route/3 equal-length routes: the first by row order |
| LA-A | a closure application is judged as a dynamic call (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 dynamic calls a closure application (fun.(x)) names no function and is not judged |
| LA-C | a call within one module is judged (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 static calls a call within one module is allowed even when the bucket's row omits it |
| LA-D | one violation per call, not per (caller, callee) pair (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 static calls one function calling the forbidden target three times is one violation, first line |
| LA-E | the last call's line is kept, not the first (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 static calls one function calling the forbidden target three times is one violation, first line |
| LA-F | the rule's selector is ignored (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 static calls a caller outside the rule's selector is not judged |
| LA-G | the Fix names no route (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs`, `graph_canary_test.exs` | `24 tests, 2 failures` (red) | check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix; layering (DND-5442): the violating module gives exactly one finding, with the route |
| GR-A | layering is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_canary_test.exs`, `rule_schema_test.exs` | `47 tests, 5 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; layering (DND-5442): the violating module gives exactly one finding, with the route; layering baseline: written, then held, then STALE once the violation is fixed; the compliant canary modules give no findings, and the summary counts the tree |
| CF-A | Config skips the graph rules' architecture check (`lib/anchor/domain/config.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 2 failures` (red) | context_acyclic: every rule that checks nothing is refused, and the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load |
| DC-D | a private function or a macro is a candidate (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `23 tests, 1 failure` (red) | a private function, a macro and another arity are not candidates |
| DC-E | a known arity matches any arity (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `23 tests, 1 failure` (red) | a private function, a macro and another arity are not candidates |
| DC-F | an unknown arity matches nothing (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `23 tests, 2 failures` (red) | an unknown arity matches the name at any arity; check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? |
| DC-G | candidates are not sorted (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `23 tests, 2 failures` (red) | a module that exports it with no @behaviour is a candidate; every project module exporting name/arity, sorted |
| DC-H | a module exporting it with no @behaviour is not a candidate (`lib/anchor/domain/dynamic_calls.ex`) | `dynamic_calls_test.exs`, `layering_test.exs` | `23 tests, 6 failures` (red) | a module that exports it with no @behaviour is a candidate; a private function, a macro and another arity are not candidates; an unknown arity matches the name at any arity; check/2 dynamic calls a forbidden module exporting the function is one violation naming it; check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /?; every project module exporting name/arity, sorted |
| LA-J | a computed function name is skipped, not unresolved (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation |
| CF-B | the known types leave out the graph types (`lib/anchor/domain/config.ex`) | `config_fail_closed_test.exs` | `19 tests, 1 failure` (red) | parse_rule/1 rule type (A8) the known types are the rule types of Anchor.checks/0 and of the graph rules |
| CM-G | regression: route/3 answered [b] for a bucket to itself, crashing the Fix text (`lib/anchor/domain/call_matrix.ex`) | `call_matrix_test.exs` | `11 tests, 1 failure` (red) | route/3 a bucket to itself is searched like any other pair |
| LA-H | regression (critic on e92f4eb): an unknown arity printed as fetch/ in the key (`lib/anchor/domain/violation_key.ex`) | `layering_test.exs` | `16 tests, 1 failure` (red) | check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? |
| LA-I | regression (critic on f04064c): every nameless dynamic call was skipped as a closure (`lib/anchor/domain/graph_rules/layering.ex`) | `layering_test.exs` | `18 tests, 1 failure` (red) | check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation |
| DC-R | regression (review floor on d9a61de): a dynamic call resolved only to behaviour implementations (`lib/anchor/domain/dynamic_calls.ex`) | `layering_test.exs` | `18 tests, 4 failures` (red) | check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /?; check/2 dynamic calls no project module exports it (Mix.shell().info/1): it reaches no bucket, none; check/2 dynamic calls a forbidden module exporting the function is one violation naming it; check/2 dynamic calls only allowed modules export it: none |
| WK-A | regression (merge of origin/main 39f55e1): a fun a call returned, applied (`clock.()`), was tagged `:call` and read as a computed function name (`lib/anchor/domain/graph/core_walker.ex`) | `core_walker_test.exs` | `35 tests, 1 failure` (red) | walk/3 call edges (AC1) applying a fun a call returned is still :apply through a variable |

## CM-A — a row's scope is ignored

Run summary: `29 tests, 3 failures`

```text
  1) test allowed?/3 same_context: equal contexts only; nil never matches (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:36
     Expected false or nil, got true
     code: refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.B"))
     arguments:

         # 1
         %Anchor.Domain.Architecture{
           context_depth: 2,
           buckets: [
             %Anchor.Domain.Architecture.Bucket{
               name: "a",
               role: :domain,
               selectors: [pattern: "a.*"],
               min_modules: 1,
               infer: true
             },
             %Anchor.Domain.Architecture.Bucket{
               name: "m",
               role: :domain,
               selectors: [pattern: "m.*"],
               min_modules: 1,
               infer: true
             }
           ],
           calls: %{"a" => [{"m", :same_context}], "m" => []},
           interface_buckets: [],
           interface_exports: [],
           effects: [],
           roots: [],
           extract_pure_regions_from: [:managers, :framework]
         }

         # 2
         %{context: "X.A", bucket: "a"}

         # 3
         %{context: "X.B", bucket: "m"}

     ... (block cut at 40 lines)

  2) test allowed?/3 other_context: different known contexts only (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:44
     Expected false or nil, got true
     code: refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.A"))
     arguments:

         # 1
         %Anchor.Domain.Architecture{
           context_depth: 2,
           buckets: [
             %Anchor.Domain.Architecture.Bucket{
               name: "a",
               role: :domain,
               selectors: [pattern: "a.*"],
               min_modules: 1,
               infer: true
             },
             %Anchor.Domain.Architecture.Bucket{
               name: "m",
               role: :domain,
               selectors: [pattern: "m.*"],
               min_modules: 1,
               infer: true
             }
           ],
           calls: %{"a" => [{"m", :other_context}], "m" => []},
           interface_buckets: [],
           interface_exports: [],
           effects: [],
           roots: [],
           extract_pure_regions_from: [:managers, :framework]
         }

         # 2
         %{context: "X.A", bucket: "a"}

         # 3
     ... (block cut at 40 lines)

  3) test check/2 static calls a scope the call breaks: the Fix names the row's scope (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:126
     ** (MatchError) no match of right hand side value:

         []

     code: [v] =
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:127: (test)
```

## CM-B — a bucket with no row may call anything (permissive default)

Run summary: `11 tests, 1 failure`

```text
  1) test allowed?/3 a bucket with no row may call nothing, not even itself (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:58
     Expected false or nil, got true
     code: refute CallMatrix.allowed?(no_row, side("m", "X.A"), side("m", "X.A"))
     arguments:

         # 1
         %Anchor.Domain.Architecture{
           context_depth: 2,
           buckets: [
             %Anchor.Domain.Architecture.Bucket{
               name: "f",
               role: :domain,
               selectors: [pattern: "f.*"],
               min_modules: 1,
               infer: true
             },
             %Anchor.Domain.Architecture.Bucket{
               name: "m",
               role: :domain,
               selectors: [pattern: "m.*"],
               min_modules: 1,
               infer: true
             }
           ],
           calls: %{"f" => [{"m", :any}]},
           interface_buckets: [],
           interface_exports: [],
           effects: [],
           roots: [],
           extract_pure_regions_from: [:managers, :framework]
         }

         # 2
         %{context: "X.A", bucket: "m"}

         # 3
         %{context: "X.A", bucket: "m"}

     ... (block cut at 40 lines)
```

## CM-C — same_context allows a nil context

Run summary: `11 tests, 1 failure`

```text
  1) test allowed?/3 same_context: equal contexts only; nil never matches (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:36
     Expected false or nil, got true
     code: refute CallMatrix.allowed?(a, side("a", nil), side("m", nil))
     arguments:

         # 1
         %Anchor.Domain.Architecture{
           context_depth: 2,
           buckets: [
             %Anchor.Domain.Architecture.Bucket{
               name: "a",
               role: :domain,
               selectors: [pattern: "a.*"],
               min_modules: 1,
               infer: true
             },
             %Anchor.Domain.Architecture.Bucket{
               name: "m",
               role: :domain,
               selectors: [pattern: "m.*"],
               min_modules: 1,
               infer: true
             }
           ],
           calls: %{"a" => [{"m", :same_context}], "m" => []},
           interface_buckets: [],
           interface_exports: [],
           effects: [],
           roots: [],
           extract_pure_regions_from: [:managers, :framework]
         }

         # 2
         %{context: nil, bucket: "a"}

         # 3
     ... (block cut at 40 lines)
```

## CM-D — other_context allows equal contexts

Run summary: `29 tests, 2 failures`

```text
  1) test allowed?/3 other_context: different known contexts only (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:44
     Expected false or nil, got true
     code: refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.A"))
     arguments:

         # 1
         %Anchor.Domain.Architecture{
           context_depth: 2,
           buckets: [
             %Anchor.Domain.Architecture.Bucket{
               name: "a",
               role: :domain,
               selectors: [pattern: "a.*"],
               min_modules: 1,
               infer: true
             },
             %Anchor.Domain.Architecture.Bucket{
               name: "m",
               role: :domain,
               selectors: [pattern: "m.*"],
               min_modules: 1,
               infer: true
             }
           ],
           calls: %{"a" => [{"m", :other_context}], "m" => []},
           interface_buckets: [],
           interface_exports: [],
           effects: [],
           roots: [],
           extract_pure_regions_from: [:managers, :framework]
         }

         # 2
         %{context: "X.A", bucket: "a"}

         # 3
     ... (block cut at 40 lines)

  2) test check/2 static calls a scope the call breaks: the Fix names the row's scope (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:126
     ** (MatchError) no match of right hand side value:

         []

     code: [v] =
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:127: (test)
```

## CM-E — route drops its destination

Run summary: `29 tests, 6 failures`

```text
  1) test route/3 framework to adapters through managers (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:70
     Assertion with == failed
     code:  assert CallMatrix.route(a, "framework", "adapters") == ["framework", "managers", "adapters"]
     left:  ["framework", "managers"]
     right: ["framework", "managers", "adapters"]
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:72: (test)

  2) test route/3 a scoped entry is an edge for routing (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:88
     Assertion with == failed
     code:  assert CallMatrix.route(a, "a", "m") == ["a", "m"]
     left:  ["a"]
     right: ["a", "m"]
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:90: (test)

  3) test route/3 equal-length routes: the first by row order (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:80
     Assertion with == failed
     code:  assert CallMatrix.route(a, "f", "t") == ["f", "y", "t"]
     left:  ["f", "y"]
     right: ["f", "y", "t"]
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:82: (test)

  4) test route/3 a bucket to itself is searched like any other pair (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:96
     Assertion with == failed
     code:  assert CallMatrix.route(a, "x", "x") == ["x", "y", "x"]
     left:  ["x", "y"]
     right: ["x", "y", "x"]
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:99: (test)

  5) test check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:87
     Assertion with == failed
     code:  assert v.message ==
              "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 " <>
                "(adapters, App.Orders); framework may call: framework, managers, domain. Fix: " <>
                "route it through managers: framework -> managers -> adapters (call a managers " <>
                "module of the right context, which calls adapters); framework may not call " <>
                "adapters directly."
     left:  "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: framework may call: framework, managers, domain, so framework reaches managers only within the scope that row names; keep the call in that scope, or move the logic to a bucket framework may call."
     right: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly."
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:99: (test)

  6) test check/2 static calls a scope the call breaks: the Fix names the row's scope (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:126
     ** (MatchError) no match of right hand side value:

         []

     code: Layering.check(
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph_rules/layering.ex:146: Anchor.Domain.GraphRules.Layering.route_text/4
       (anchor 0.1.0) lib/anchor/domain/graph_rules/layering.ex:125: Anchor.Domain.GraphRules.Layering.message/5
       (anchor 0.1.0) lib/anchor/domain/graph_rules/layering.ex:109: Anchor.Domain.GraphRules.Layering.violation/3
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/graph_rules/layering_test.exs:128: (test)
```

## CM-F — route explores depth-first, not shortest

Run summary: `11 tests, 1 failure`

```text
  1) test route/3 equal-length routes: the first by row order (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:80
     Assertion with == failed
     code:  assert CallMatrix.route(a, "f", "t") == ["f", "y", "t"]
     left:  ["f", "x", "t"]
     right: ["f", "y", "t"]
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:82: (test)
```

## LA-A — a closure application is judged as a dynamic call

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 dynamic calls a closure application (fun.(x)) names no function and is not judged (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:237
     Assertion with == failed
     code:  assert Layering.check(model(call), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 calls a function it computes (?/1), so its target cannot be checked. Fix: call the module's function by name (a call on a computed module, mod.fetch(x), is judged against every module exporting it); apply a closure as fun.(args).",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> dynamic ?/1",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:239: (test)
```

## LA-C — a call within one module is judged

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 static calls a call within one module is allowed even when the bucket's row omits it (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:158
     Assertion with == failed
     code:  assert Layering.check(model(within, [], no_self), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 1,
                trigger: "App.Orders.Store.f/0",
                message: "App.Orders.Store.f/0 (adapters, App.Orders) calls App.Orders.Store.g/0 (adapters, App.Orders); adapters may call: domain. Fix: no route: the calls matrix forbids adapters reaching adapters; move the logic to a bucket adapters may call.",
                filename: "lib/adapters/Store.ex",
                kind: :rule,
                key: "layering|App.Orders.Store.f/0|-> App.Orders.Store.g/0",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:161: (test)
```

## LA-D — one violation per call, not per (caller, callee) pair

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 static calls one function calling the forbidden target three times is one violation, first line (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:142
     match (=) failed
     code:  assert [%{line: 4}] = Layering.check(model(calls), @rule)
     left:  [%{line: 4}]
     right: [
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.f/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> App.Orders.Store.f/0",
                rule_id: "layering",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 6,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.f/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> App.Orders.Store.f/0",
                rule_id: "layering",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 9,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.f/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> App.Orders.Store.f/0",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:146: (test)
     ... (block cut at 40 lines)
```

## LA-E — the last call's line is kept, not the first

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 static calls one function calling the forbidden target three times is one violation, first line (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:142
     match (=) failed
     code:  assert [%{line: 4}] = Layering.check(model(calls), @rule)
     left:  [%{line: 4}]
     right: [
              %Anchor.Domain.Violation{
                line: 9,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.f/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> App.Orders.Store.f/0",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:146: (test)
```

## LA-F — the rule's selector is ignored

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 static calls a caller outside the rule's selector is not judged (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:168
     Assertion with == failed
     code:  assert Layering.check(model(call), %{@rule | paths: ["lib/domain/**"]}) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.f/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> App.Orders.Store.f/0",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:171: (test)
```

## LA-G — the Fix names no route

Run summary: `24 tests, 2 failures`

```text
  1) test check/2 static calls framework -> adapters is one violation naming both buckets, with the route Fix (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:87
     Assertion with == failed
     code:  assert v.message ==
              "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 " <>
                "(adapters, App.Orders); framework may call: framework, managers, domain. Fix: " <>
                "route it through managers: framework -> managers -> adapters (call a managers " <>
                "module of the right context, which calls adapters); framework may not call " <>
                "adapters directly."
     left:  "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: (call a managers module of the right context, which calls adapters); framework may not call adapters directly."
     right: "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 (adapters, App.Orders); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly."
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:99: (test)

  2) test layering (DND-5442): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:100
     Assertion with =~ failed
     code:  assert finding.message =~ "Fix: route it through managers: framework -> managers -> adapters"
     left:  "AnchorFixtures.GraphCanary.Web.Violating.show/1 (framework, AnchorFixtures.GraphCanary) calls AnchorFixtures.GraphCanary.Orders.Store.fetch/1 (adapters, AnchorFixtures.GraphCanary); framework may call: framework, managers, domain. Fix: route it through managers: (call a managers module of the right context, which calls adapters); framework may not call adapters directly."
     right: "Fix: route it through managers: framework -> managers -> adapters"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:115: (test)
```

## GR-A — layering is not registered as a graph rule

Run summary: `47 tests, 5 failures`

```text
  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:33
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:context_acyclic]
     right: [:context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:36: (test)

  2) test engine/1 every shipped type has an engine; the graph types are the graph rule modules' (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:237
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:graph) ==
              Anchor.Domain.GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort()
     left:  [:context_acyclic, :layering]
     right: [:context_acyclic]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:245: (test)

  3) test layering (DND-5442): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:100
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:105: (test)

  4) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:76
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 6 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
     left:  "anchor.graph: 6 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 6 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:83: (test)

  5) test layering baseline: written, then held, then STALE once the violation is fixed (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:122
     Assertion with == failed
     code:  assert written.exit_code == 0
     left:  2
     right: 0
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:142: (test)
```

## CF-A — Config skips the graph rules' architecture check

Run summary: `26 tests, 2 failures`

```text
  1) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / a bucket naming no architecture bucket: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  2) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / a bucket naming no architecture bucket: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## DC-D — a private function or a macro is a candidate

Run summary: `23 tests, 1 failure`

```text
  1) test a private function, a macro and another arity are not candidates (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:57
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == []
     left:  [M, P]
     right: []
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:65: (test)
```

## DC-E — a known arity matches any arity

Run summary: `23 tests, 1 failure`

```text
  1) test a private function, a macro and another arity are not candidates (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:57
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == []
     left:  [A]
     right: []
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:65: (test)
```

## DC-F — an unknown arity matches nothing

Run summary: `23 tests, 2 failures`

```text
  1) test an unknown arity matches the name at any arity (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:70
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, nil}) == [X]
     left:  []
     right: [X]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:72: (test)

  2) test check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:219
     match (=) failed
     code:  assert [v] = Layering.check(model(call, [@adapter_impl]), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:222: (test)
```

## DC-G — candidates are not sorted

Run summary: `23 tests, 2 failures`

```text
  1) test a module that exports it with no @behaviour is a candidate (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:46
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == [Declared, Undeclared]
     left:  [Undeclared, Declared]
     right: [Declared, Undeclared]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:54: (test)

  2) test every project module exporting name/arity, sorted (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:31
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == [X, Y]
     left:  [Y, X]
     right: [X, Y]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:39: (test)
```

## DC-H — a module exporting it with no @behaviour is not a candidate

Run summary: `23 tests, 6 failures`

```text
  1) test a module that exports it with no @behaviour is a candidate (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:46
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == [Declared, Undeclared]
     left:  []
     right: [Declared, Undeclared]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:54: (test)

  2) test a private function, a macro and another arity are not candidates (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:57
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 2}) == [A]
     left:  []
     right: [A]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:67: (test)

  3) test every project module exporting name/arity, sorted (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:31
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, 1}) == [X, Y]
     left:  []
     right: [X, Y]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:39: (test)

  4) test an unknown arity matches the name at any arity (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:70
     Assertion with == failed
     code:  assert DynamicCalls.candidates(g, {:fetch, nil}) == [X]
     left:  []
     right: [X]
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:72: (test)

  5) test check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:219
     match (=) failed
     code:  assert [v] = Layering.check(model(call, [@adapter_impl]), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:222: (test)

  6) test check/2 dynamic calls a forbidden module exporting the function is one violation naming it (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:208
     match (=) failed
     code:  assert [v] = Layering.check(model(call, [@manager_impl, @adapter_impl]), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:211: (test)
```

## LA-J — a computed function name is skipped, not unresolved

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:245
     ** (MatchError) no match of right hand side value:

         []

     code: for {to, kind} <- [
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:253: anonymous fn/2 in Anchor.Domain.GraphRules.LayeringTest."test check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/layering_test.exs:246: (test)
```

## CF-B — the known types leave out the graph types

Run summary: `19 tests, 1 failure`

```text
  1) test parse_rule/1 rule type (A8) the known types are the rule types of Anchor.checks/0 and of the graph rules (Anchor.Domain.ConfigFailClosedTest)
     test/anchor/domain/config_fail_closed_test.exs:67
     Assertion with == failed
     code:  assert Enum.sort(Config.rule_types()) == Enum.sort(check_types ++ graph_types)
     left:  [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention,
             :struct_owned_by_module]
     right: [:alphabetized_functions, :case_on_bare_arg, :context_acyclic,
             :layering, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention,
             :struct_owned_by_module]
     stacktrace:
       test/anchor/domain/config_fail_closed_test.exs:71: (test)
```

## CM-G — regression: route/3 answered [b] for a bucket to itself, crashing the Fix text

Run summary: `11 tests, 1 failure`

```text
  1) test route/3 a bucket to itself is searched like any other pair (Anchor.Domain.CallMatrixTest)
     test/anchor/domain/call_matrix_test.exs:96
     Assertion with == failed
     code:  assert CallMatrix.route(a, "s", "s") == :none
     left:  ["s"]
     right: :none
     stacktrace:
       test/anchor/domain/call_matrix_test.exs:98: (test)
```

## LA-H — regression (critic on e92f4eb): an unknown arity printed as fetch/ in the key

Run summary: `16 tests, 1 failure`

```text
  1) test check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:187
     Assertion with == failed
     code:  assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/?"
     left:  "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/"
     right: "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/?"
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:191: (test)
```

## LA-I — regression (critic on f04064c): every nameless dynamic call was skipped as a closure

Run summary: `18 tests, 1 failure`

```text
  1) test check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:223
     ** (MatchError) no match of right hand side value:

         []

     code: for {to, kind} <- [
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:231: anonymous fn/2 in Anchor.Domain.GraphRules.LayeringTest."test check/2 dynamic calls a module dispatch whose function is computed is one unresolved violation"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/layering_test.exs:224: (test)
```

## DC-R — regression (review floor on d9a61de): a dynamic call resolved only to behaviour implementations

Run summary: `18 tests, 4 failures`

```text
  1) test check/2 dynamic calls an unknown arity resolved to a forbidden implementation prints /? (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:219
     Assertion with == failed
     code:  assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/?"
     left:  "layering|App.Web.Page.show/1|-> dynamic fetch/?"
     right: "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/?"
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:223: (test)

  2) test check/2 dynamic calls no project module exports it (Mix.shell().info/1): it reaches no bucket, none (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:232
     Assertion with == failed
     code:  assert Layering.check(model(call, [@manager_impl, @adapter_impl]), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 calls info/1 on a module it computes, and no behaviour in the project declares that callback, so its target cannot be checked. Fix: declare @callback info/1 in a behaviour and implement it in the target modules.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> dynamic info/1",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:234: (test)

  3) test check/2 dynamic calls a forbidden module exporting the function is one violation naming it (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:208
     Assertion with == failed
     code:  assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/1"
     left:  "layering|App.Web.Page.show/1|-> dynamic fetch/1"
     right: "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/1"
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:212: (test)

  4) test check/2 dynamic calls only allowed modules export it: none (Anchor.Domain.GraphRules.LayeringTest)
     test/anchor/domain/graph_rules/layering_test.exs:227
     Assertion with == failed
     code:  assert Layering.check(model(call, [@manager_impl]), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "App.Web.Page.show/1",
                message: "App.Web.Page.show/1 calls fetch/1 on a module it computes, and no behaviour in the project declares that callback, so its target cannot be checked. Fix: declare @callback fetch/1 in a behaviour and implement it in the target modules.",
                filename: "lib/framework/Page.ex",
                kind: :rule,
                key: "layering|App.Web.Page.show/1|-> dynamic fetch/1",
                rule_id: "layering",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/layering_test.exs:229: (test)
```

## WK-A — regression (merge of origin/main 39f55e1): a closure a call returned read as a computed function name

Merging main brought `Anchor.Adapters.TestRunner.execute/4`, which binds
`clock = Keyword.get(opts, :clock, ...)` and applies `clock.()`. The walker
tagged that apply `:call` (the variable was bound to a call), the tag apply/3
with a computed name carries, so `mix anchor.graph` on the merged tree gave
four findings, `TestRunner.execute/4 calls a function it computes (?/0)` and
`(?/3)`, under both rules. The regression test ran on the unfixed walker with
`mix test --force test/anchor/domain/graph/core_walker_test.exs`:

Run summary: `35 tests, 1 failure`

```text
  1) test walk/3 call edges (AC1) applying a fun a call returned is still :apply through a variable (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:169
     Assertion with == failed
     code:  assert call.to == {:dynamic, nil, 1, :variable}
     left:  {:dynamic, nil, 1, :call}
     right: {:dynamic, nil, 1, :variable}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:171: (test)
```

After the fix: `1808 tests, 0 failures`, and `mix anchor.graph` on the merged
tree reads `0 violations (0 report-only, 80 baselined)`.
