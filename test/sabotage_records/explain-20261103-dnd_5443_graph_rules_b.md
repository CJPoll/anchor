# Sabotage record — mix anchor.explain (DND-5446)

- **Domain:** explain
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Subject`, `Anchor.Domain.Classification.classify_planned/3`, `Anchor.Domain.Explain`, `Anchor.Managers.Explain`, `Mix.Tasks.Anchor.Explain`
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red. The checkout's absolute path in the output reads `<worktree>`.

A first pass found CL-B (dropping `classify_planned`'s guard for a `paths`
selector with no path) green: an equivalent mutant, since
`Selector.matches?/2` already answers false for a nil path. The redundant
clause was removed. CL-B now drops the guard that is needed, the `pattern`
selector with no module (nil would be read as the name "nil"), and a test
for it was added. This table is the final run: the CL rows from a re-run of
the four Classification mutations on the final code, the others from the
first run (their code did not change).

Critic round 2 found no test of the Manager's findings filter or of its
guard round a crashing rule. MX-F to MX-I were added with those tests. A first
run of MX-H (the rescue narrowed) was green: the guard's `catch kind, reason`
also caught a raise. The guard now catches only `:throw` and `:exit` after the
rescue, as `Managers.Graph`'s does, and a test for a throwing rule was added
(MX-I). The MX-F to MX-I rows are from the re-run on that code.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| SU-A | an absolute path outside the root is accepted (`lib/anchor/domain/subject.ex`) | `subject_test.exs` | `8 tests, 1 failure` (red) | parse/2 a path that leaves the root is refused |
| SU-B | implied module segments not camelized (`lib/anchor/domain/subject.ex`) | `subject_test.exs` | `8 tests, 3 failures` (red) | parse/2 an absolute path inside the root is made relative; parse/2 an umbrella app's path drops the app directory; parse/2 a path under lib/ implies its module by Elixir's naming convention |
| SU-C | implied module keeps the .ex extension (`lib/anchor/domain/subject.ex`) | `subject_test.exs` | `8 tests, 3 failures` (red) | parse/2 an absolute path inside the root is made relative; parse/2 a path under lib/ implies its module by Elixir's naming convention; parse/2 an umbrella app's path drops the app directory |
| SU-D | .exs accepted as a subject path (`lib/anchor/domain/subject.ex`) | `subject_test.exs` | `8 tests, 1 failure` (red) | parse/2 anything else is not a subject |
| CL-A | two path buckets matched: the first wins (a precedence) (`lib/anchor/domain/classification.ex`) | `classification_planned_test.exs` | `7 tests, 1 failure` (red) | classify_planned/3 two path selectors matching is ambiguous, never a precedence |
| CL-B | a nil module matched against pattern selectors (as "nil") (`lib/anchor/domain/classification.ex`) | `classification_planned_test.exs` | `7 tests, 1 failure` (red) | classify_planned/3 no module implied (a path with no lib/ segment): a pattern selector never matches |
| CL-C | unknown selector kinds never reported (`lib/anchor/domain/classification.ex`) | `classification_planned_test.exs` | `7 tests, 2 failures` (red) | classify_planned/3 a definite bucket still names a beam selector that could also match it (ambiguity); classify_planned/3 only a uses_module selector could match: no bucket, framework possible, unknown named |
| CL-D | uses_module not treated as a beam selector (`lib/anchor/domain/classification.ex`) | `classification_planned_test.exs` | `7 tests, 2 failures` (red) | classify_planned/3 a definite bucket still names a beam selector that could also match it (ambiguity); classify_planned/3 only a uses_module selector could match: no bucket, framework possible, unknown named |
| EX-A | another context's non-interface modules listed as callable (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `9 tests, 2 failures` (red) | render/2 text: one golden case; build/3 with the model a manager: classification, the modules it may call, what it must not, its rules |
| EX-B | must_not_call lists the allowed buckets (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `9 tests, 3 failures` (red) | build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown; build/3 with the model a manager: classification, the modules it may call, what it must not, its rules; render/2 text: one golden case |
| EX-C | beam facts never listed as unknown (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `9 tests, 1 failure` (red) | build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown |
| EX-D | a failed compile is not noted (`lib/anchor/domain/explain.ex`) | `explain_test.exs`, `explain_test.exs`, `anchor_explain_test.exs` | `22 tests, 3 failures` (red) | build/3 with no model a compile that failed is noted; explain/2 a project that did not compile reads no beam and still answers from paths; a path answers in text, and a compile failure is noted rather than fatal |
| EX-E | AST rules matched against no filename (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `9 tests, 3 failures` (red) | build/3 with the model a manager: classification, the modules it may call, what it must not, its rules; render/2 text: one golden case; build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown |
| EX-F | findings not computed renders as an empty list in JSON (`lib/anchor/domain/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `15 tests, 2 failures` (red) | render/2 json decodes and has the R5 keys; --format json prints the JSON answer |
| MX-A | a failed compile still reads beams and the artifact (`lib/anchor/managers/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `13 tests, 3 failures` (red) | explain/2 a project that did not compile reads no beam and still answers from paths; --format json prints the JSON answer; a path answers in text, and a compile failure is noted rather than fatal |
| MX-B | a module subject placed by naming convention, not by the graph (`lib/anchor/managers/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `13 tests, 1 failure` (red) | explain/2 a module subject is placed at its source file by the graph |
| MX-C | a missing file reported as existing (`lib/anchor/managers/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `13 tests, 1 failure` (red) | explain/2 a path that does not exist yet |
| MX-D | a config failure reported as usage (exit 2, not 3) (`lib/anchor/managers/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `13 tests, 2 failures` (red) | explain/2 a missing config is could-not-check (exit 3 in the task); no config is could-not-check: exit 3 |
| MX-E | the artifact is used whatever the store answers (stale graph) (`lib/anchor/managers/explain.ex`) | `explain_test.exs`, `anchor_explain_test.exs` | `13 tests, 2 failures` (red) | explain/2 a stale artifact (another key) is never used: findings not computed; a compiled project with no current graph artifact reads it under this build's key |
| TK-A | --format json prints text (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `6 tests, 1 failure` (red) | --format json prints the JSON answer |
| TK-B | two subjects accepted (the first used) (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `6 tests, 1 failure` (red) | no subject, two subjects, an unknown flag or a bad format is usage: exit 2 with Fix: |
| TK-C | could-not-check exits 1, not 3 (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `6 tests, 1 failure` (red) | no config is could-not-check: exit 3 |
| MX-F | findings on other files are kept (the subject filter dropped) (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `9 tests, 2 failures` (red) | explain/2 findings are the subject file's only: another file's finding is not shown; explain/2 a rule that raises or throws is named among the findings, never dropped |
| MX-G | a fail-closed finding (a crashed rule) is filtered out (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `9 tests, 1 failure` (red) | explain/2 a rule that raises or throws is named among the findings, never dropped |
| MX-H | a rule that raises is not rescued (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `9 tests, 1 failure` (red) | explain/2 a rule that raises or throws is named among the findings, never dropped |
| MX-I | a rule that throws is not caught (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `9 tests, 1 failure` (red) | explain/2 a rule that raises or throws is named among the findings, never dropped |

## SU-A — an absolute path outside the root is accepted

Run summary: `8 tests, 1 failure`

```text
  1) test parse/2 a path that leaves the root is refused (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:37
     Assertion with == failed
     code:  assert Subject.parse("../etc/passwd.ex", @root) == {:error, :outside_root}
     left:  {:path, "/etc/passwd.ex", nil}
     right: {:error, :outside_root}
     stacktrace:
       test/anchor/domain/subject_test.exs:38: (test)

.....
```

## SU-B — implied module segments not camelized

Run summary: `8 tests, 3 failures`

```text
  1) test parse/2 an absolute path inside the root is made relative (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:29
     Assertion with == failed
     code:  assert Subject.parse("/repo/lib/a/b_c.ex", @root) == {:path, "lib/a/b_c.ex", A.BC}
     left:  {:path, "lib/a/b_c.ex", :"Elixir.a.b_c"}
     right: {:path, "lib/a/b_c.ex", A.BC}
     stacktrace:
       test/anchor/domain/subject_test.exs:30: (test)

  2) test parse/2 an umbrella app's path drops the app directory (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:24
     Assertion with == failed
     code:  assert Subject.parse("apps/foo/lib/foo/bar.ex", @root) == {:path, "apps/foo/lib/foo/bar.ex", Foo.Bar}
     left:  {:path, "apps/foo/lib/foo/bar.ex", :"Elixir.foo.bar"}
     right: {:path, "apps/foo/lib/foo/bar.ex", Foo.Bar}
     stacktrace:
       test/anchor/domain/subject_test.exs:25: (test)

.....

  3) test parse/2 a path under lib/ implies its module by Elixir's naming convention (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:16
     Assertion with == failed
     code:  assert Subject.parse("lib/anchor/domain/graph.ex", @root) ==
              {:path, "lib/anchor/domain/graph.ex", Anchor.Domain.Graph}
     left:  {:path, "lib/anchor/domain/graph.ex", :"Elixir.anchor.domain.graph"}
     right: {:path, "lib/anchor/domain/graph.ex", Anchor.Domain.Graph}
     stacktrace:
       test/anchor/domain/subject_test.exs:17: (test)
```

## SU-C — implied module keeps the .ex extension

Run summary: `8 tests, 3 failures`

```text
  1) test parse/2 an absolute path inside the root is made relative (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:29
     Assertion with == failed
     code:  assert Subject.parse("/repo/lib/a/b_c.ex", @root) == {:path, "lib/a/b_c.ex", A.BC}
     left:  {:path, "lib/a/b_c.ex", :"Elixir.A.BC.ex"}
     right: {:path, "lib/a/b_c.ex", A.BC}
     stacktrace:
       test/anchor/domain/subject_test.exs:30: (test)

..

  2) test parse/2 a path under lib/ implies its module by Elixir's naming convention (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:16
     Assertion with == failed
     code:  assert Subject.parse("lib/anchor/domain/graph.ex", @root) ==
              {:path, "lib/anchor/domain/graph.ex", Anchor.Domain.Graph}
     left:  {:path, "lib/anchor/domain/graph.ex",
             :"Elixir.Anchor.Domain.Graph.ex"}
     right: {:path, "lib/anchor/domain/graph.ex", Anchor.Domain.Graph}
     stacktrace:
       test/anchor/domain/subject_test.exs:17: (test)

  3) test parse/2 an umbrella app's path drops the app directory (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:24
     Assertion with == failed
     code:  assert Subject.parse("apps/foo/lib/foo/bar.ex", @root) == {:path, "apps/foo/lib/foo/bar.ex", Foo.Bar}
     left:  {:path, "apps/foo/lib/foo/bar.ex", :"Elixir.Foo.Bar.ex"}
     right: {:path, "apps/foo/lib/foo/bar.ex", Foo.Bar}
     stacktrace:
       test/anchor/domain/subject_test.exs:25: (test)

.
```

## SU-D — .exs accepted as a subject path

Run summary: `8 tests, 1 failure`

```text
  1) test parse/2 anything else is not a subject (Anchor.Domain.SubjectTest)
     test/anchor/domain/subject_test.exs:43
     Assertion with == failed
     code:  assert Subject.parse("lib/a/b.exs", @root) == {:error, :not_a_subject}
     left:  {:path, "lib/a/b.exs", A.B}
     right: {:error, :not_a_subject}
     stacktrace:
       test/anchor/domain/subject_test.exs:45: (test)

.....
```

## CL-A — two path buckets matched: the first wins (a precedence)

Run summary: `7 tests, 1 failure`

```text
  1) test classify_planned/3 two path selectors matching is ambiguous, never a precedence (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:79
     match (=) failed
     code:  assert %{definite: nil, ambiguous: ["domain", "other"]} =
              Classification.classify_planned(
                "lib/app/domain/thing.ex",
                App.Domain.Thing,
                arch([@domain, other])
              )
     left:  %{definite: nil, ambiguous: ["domain", "other"]}
     right: %{
              unknown: [],
              ambiguous: ["domain", "other"],
              definite: "domain",
              possible: []
            }
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:86: (test)

.
```

## CL-B — a nil module matched against pattern selectors (as "nil")

Run summary: `7 tests, 1 failure`

```text
  1) test classify_planned/3 no module implied (a path with no lib/ segment): a pattern selector never matches (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:94
     match (=) failed
     code:  assert %{definite: nil} = Classification.classify_planned("scripts/run.ex", nil, arch([literal_nil]))
     left:  %{definite: nil}
     right: %{unknown: [], ambiguous: [], definite: "any", possible: []}
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:98: (test)

..
```

## CL-C — unknown selector kinds never reported

Run summary: `7 tests, 2 failures`

```text
  1) test classify_planned/3 a definite bucket still names a beam selector that could also match it (ambiguity) (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:42
     Assertion with == failed
     code:  assert Classification.classify_planned(
              "lib/app/domain/thing.ex",
              App.Domain.Thing,
              arch([@domain, @framework])
            ) == %{definite: "domain", ambiguous: [], possible: ["framework"], unknown: [:uses_module]}
     left:  %{
              unknown: [],
              ambiguous: [],
              definite: "domain",
              possible: ["framework"]
            }
     right: %{
              unknown: [:uses_module],
              ambiguous: [],
              definite: "domain",
              possible: ["framework"]
            }
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:43: (test)

  2) test classify_planned/3 only a uses_module selector could match: no bucket, framework possible, unknown named (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:66
     Assertion with == failed
     code:  assert Classification.classify_planned(
              "lib/app/server.ex",
              App.Server,
              arch([@domain, @framework])
            ) == %{definite: nil, ambiguous: [], possible: ["framework"], unknown: [:uses_module]}
     left:  %{
              unknown: [],
              ambiguous: [],
              definite: nil,
              possible: ["framework"]
            }
     right: %{
              unknown: [:uses_module],
              ambiguous: [],
              definite: nil,
              possible: ["framework"]
            }
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:67: (test)

..
```

## CL-D — uses_module not treated as a beam selector

Run summary: `7 tests, 2 failures`

```text
  1) test classify_planned/3 a definite bucket still names a beam selector that could also match it (ambiguity) (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:42
     Assertion with == failed
     code:  assert Classification.classify_planned(
              "lib/app/domain/thing.ex",
              App.Domain.Thing,
              arch([@domain, @framework])
            ) == %{definite: "domain", ambiguous: [], possible: ["framework"], unknown: [:uses_module]}
     left:  %{unknown: [], ambiguous: [], definite: "domain", possible: []}
     right: %{
              unknown: [:uses_module],
              ambiguous: [],
              definite: "domain",
              possible: ["framework"]
            }
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:43: (test)

.

  2) test classify_planned/3 only a uses_module selector could match: no bucket, framework possible, unknown named (Anchor.Domain.ClassificationPlannedTest)
     test/anchor/domain/classification_planned_test.exs:66
     Assertion with == failed
     code:  assert Classification.classify_planned(
              "lib/app/server.ex",
              App.Server,
              arch([@domain, @framework])
            ) == %{definite: nil, ambiguous: [], possible: ["framework"], unknown: [:uses_module]}
     left:  %{unknown: [], ambiguous: [], definite: nil, possible: []}
     right: %{
              unknown: [:uses_module],
              ambiguous: [],
              definite: nil,
              possible: ["framework"]
            }
     stacktrace:
       test/anchor/domain/classification_planned_test.exs:67: (test)

..
```

## EX-A — another context's non-interface modules listed as callable

Run summary: `9 tests, 2 failures`

```text
  1) test render/2 text: one golden case (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:232
     Assertion with == failed
     code:  assert text == "anchor.explain: lib/app/managers/orders.ex
              module: App.Orders.Manager
              path: lib/app/managers/orders.ex (exists)
            classification:
              status: classified
              bucket: managers (role managers)
              context: App.Orders
              app: app
              interface: yes
              aggregate: unknown (no aggregates configured)
            may call:
              managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager
              domain (any): same context: App.Orders.Order; other contexts (interface only): none
            must not call: framework
            rules:
              [enforce] layering (id: layering, graph): #{RuleShapes.for(%{type: :layering})}
              [enforce] single_control_flow (ast): #{RuleShapes.for(%{type: :single_control_flow})}
            findings: none"
     left:  "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): App.Billing: App.Billing.Invoice\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings: none"
     right: "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings: none"
     stacktrace:
       test/anchor/domain/explain_test.exs:235: (test)

.

  2) test build/3 with the model a manager: classification, the modules it may call, what it must not, its rules (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:116
     Assertion with == failed
     code:  assert domain["modules"] == %{"same_context" => ["App.Orders.Order"], "other_contexts" => %{}}
     left:  %{
              "other_contexts" => %{
                "App.Billing" => ["App.Billing.Invoice"]
              },
              "same_context" => ["App.Orders.Order"]
            }
     right: %{"other_contexts" => %{}, "same_context" => ["App.Orders.Order"]}
     stacktrace:
       test/anchor/domain/explain_test.exs:142: (test)
```

## EX-B — must_not_call lists the allowed buckets

Run summary: `9 tests, 3 failures`

```text
  1) test build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:185
     Assertion with == failed
     code:  assert explain.must_not_call == ["framework", "managers"]
     left:  ["domain"]
     right: ["framework", "managers"]
     stacktrace:
       test/anchor/domain/explain_test.exs:206: (test)

.

  2) test build/3 with the model a manager: classification, the modules it may call, what it must not, its rules (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:116
     Assertion with == failed
     code:  assert explain.must_not_call == ["framework"]
     left:  ["domain", "managers"]
     right: ["framework"]
     stacktrace:
       test/anchor/domain/explain_test.exs:147: (test)

..

  3) test render/2 text: one golden case (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:232
     Assertion with == failed
     code:  assert text == "anchor.explain: lib/app/managers/orders.ex
              module: App.Orders.Manager
              path: lib/app/managers/orders.ex (exists)
            classification:
              status: classified
              bucket: managers (role managers)
              context: App.Orders
              app: app
              interface: yes
              aggregate: unknown (no aggregates configured)
            may call:
              managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager
              domain (any): same context: App.Orders.Order; other contexts (interface only): none
            must not call: framework
            rules:
              [enforce] layering (id: layering, graph): #{RuleShapes.for(%{type: :layering})}
              [enforce] single_control_flow (ast): #{RuleShapes.for(%{type: :single_control_flow})}
            findings: none"
     left:  "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: domain, managers\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings: none"
     right: "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings: none"
     stacktrace:
       test/anchor/domain/explain_test.exs:235: (test)
```

## EX-C — beam facts never listed as unknown

Run summary: `9 tests, 1 failure`

```text
  1) test build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:185
     Assertion with == failed
     code:  assert explain.unknown == ~w(app behaviours exports_function uses_module)
     left:  []
     right: ["app", "behaviours", "exports_function", "uses_module"]
     stacktrace:
       test/anchor/domain/explain_test.exs:208: (test)

.....
```

## EX-D — a failed compile is not noted

Run summary: `22 tests, 3 failures`

```text
  1) test build/3 with no model a compile that failed is noted (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:224
     Assertion with == failed
     code:  assert explain.notes == ["compile failed; beam facts unknown"]
     left:  []
     right: ["compile failed; beam facts unknown"]
     stacktrace:
       test/anchor/domain/explain_test.exs:227: (test)

.....

  2) test explain/2 a project that did not compile reads no beam and still answers from paths (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:178
     Assertion with == failed
     code:  assert explain.notes == ["compile failed; beam facts unknown"]
     left:  []
     right: ["compile failed; beam facts unknown"]
     stacktrace:
       test/anchor/managers/explain_test.exs:186: (test)

...

  3) test a path answers in text, and a compile failure is noted rather than fatal (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:83
     Assertion with =~ failed
     code:  assert output =~ "compile failed; beam facts unknown"
     left:  "anchor.explain: lib/app/domain/thing.ex\n  module: App.Domain.Thing\n  path: lib/app/domain/thing.ex (does not exist yet)\nclassification:\n  status: classified by path\n  bucket: domain (role domain)\n  context: App.Domain\n  app: unknown until compiled\n  interface: no\n  aggregate: unknown (no aggregates configured)\n  bucket domain selects: paths [\"lib/**/domain/**/*.ex\"]\nmay call:\n  domain (any) (modules not computed: run mix anchor.graph)\nmust not call: nothing\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\nfindings: not computed (run mix anchor.graph)\nunknown until compiled: app, behaviours, exports_function, uses_module\n"
     right: "compile failed; beam facts unknown"
     stacktrace:
       test/mix/tasks/anchor_explain_test.exs:92: (test)

...
```

## EX-E — AST rules matched against no filename

Run summary: `9 tests, 3 failures`

```text
  1) test build/3 with the model a manager: classification, the modules it may call, what it must not, its rules (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:116
     match (=) failed
     code:  assert [
              %{"type" => "layering", "engine" => "graph", "id" => "layering"} = layering,
              %{"type" => "single_control_flow", "engine" => "ast"} = flow
            ] = explain.rules
     left:  [
              %{"type" => "layering", "engine" => "graph", "id" => "layering"} = layering,
              %{"type" => "single_control_flow", "engine" => "ast"} = flow
            ]
     right: [
              %{
                "enforcement" => "enforce",
                "engine" => "graph",
                "id" => "layering",
                "shape" => "every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call",
                "type" => "layering"
              }
            ]
     stacktrace:
       test/anchor/domain/explain_test.exs:149: (test)

  2) test render/2 text: one golden case (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:232
     Assertion with == failed
     code:  assert text == "anchor.explain: lib/app/managers/orders.ex
              module: App.Orders.Manager
              path: lib/app/managers/orders.ex (exists)
            classification:
              status: classified
              bucket: managers (role managers)
              context: App.Orders
              app: app
              interface: yes
              aggregate: unknown (no aggregates configured)
            may call:
              managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager
              domain (any): same context: App.Orders.Order; other contexts (interface only): none
            must not call: framework
            rules:
              [enforce] layering (id: layering, graph): #{RuleShapes.for(%{type: :layering})}
              [enforce] single_control_flow (ast): #{RuleShapes.for(%{type: :single_control_flow})}
            findings: none"
     left:  "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\nfindings: none"
     right: "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates configured)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings: none"
     stacktrace:
       test/anchor/domain/explain_test.exs:235: (test)

...

  3) test build/3 with no model a path that does not exist yet under domain/: domain by path, beam facts unknown (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:185
     Assertion with == failed
     code:  assert Enum.map(explain.rules, & &1["type"]) == ["layering", "case_on_bare_arg"]
     left:  ["layering"]
     right: ["layering", "case_on_bare_arg"]
     stacktrace:
       test/anchor/domain/explain_test.exs:209: (test)

..
```

## EX-F — findings not computed renders as an empty list in JSON

Run summary: `15 tests, 2 failures`

```text
  1) test render/2 json decodes and has the R5 keys (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:265
     Assertion with == failed
     code:  assert JSON.decode!(Explain.render(Explain.build(config(), nil, subject(%{findings: nil})), :json))[
              "findings"
            ] == nil
     left:  []
     right: nil
     stacktrace:
       test/anchor/domain/explain_test.exs:275: (test)

......

  2) test --format json prints the JSON answer (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:96
     match (=) failed
     code:  assert %{"subject" => @subject, "findings" => nil, "classification" => %{"bucket" => "domain"}} =
              JSON.decode!(output)
     left:  %{
              "subject" => "lib/app/domain/thing.ex",
              "findings" => nil,
              "classification" => %{"bucket" => "domain"}
            }
     right: %{
              "classification" => %{
                "aggregate" => "unknown (no aggregates configured)",
                "ambiguous" => [],
                "app" => "unknown until compiled",
                "bucket" => "domain",
                "context" => "App.Domain",
                "interface" => false,
                "possible" => [],
                "role" => "domain",
                "selectors" => [
                  %{
                    "bucket" => "domain",
                    "matched" => nil,
                    "select" => ["paths [\"lib/**/domain/**/*.ex\"]"]
                  }
                ],
                "status" => "classified by path",
                "unknown_selectors" => []
              },
              "exists" => false,
              "findings" => [],
              "may_call" => [
                %{
                  "bucket" => "domain",
                  "modules" => nil,
                  "scope" => "any"
                }
              ],
              "module" => "App.Domain.Thing",
              "must_not_call" => [],
              "notes" => ["compile failed; beam facts unknown"],
              "path" => "lib/app/domain/thing.ex",
              "rules" => [
                %{
                  "enforcement" => "enforce",
                  "engine" => "graph",
                  "id" => "layering",
                  "shape" => "every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call",
                  "type" => "layering"
                }
              ],
              "subject" => "lib/app/domain/thing.ex",
              "unknown" => ["app", "behaviours", "exports_function",
               "uses_module"]
            }
     stacktrace:
       test/mix/tasks/anchor_explain_test.exs:102: (test)

...
```

## MX-A — a failed compile still reads beams and the artifact

Run summary: `13 tests, 3 failures`

```text
  1) test explain/2 a project that did not compile reads no beam and still answers from paths (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:178
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BeamSourceMock.read_ebins/1 in process #PID<0.1287.0> with args [[my_app: "_build/test/lib/my_app/ebin"]]
     code: explain(@manager_file, beams, fn _dir, _key -> flunk("read") end, false)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:194: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:552: Anchor.Managers.Graph.artifact_inputs/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:122: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:70: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:184: (test)

.....

  2) test --format json prints the JSON answer (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:96
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BeamSourceMock.read_ebins/1 in process #PID<0.1307.0> with args [[anchor: "<worktree>/_build/test/lib/anchor/ebin"]]
     code: capture_io(fn -> assert Explain.run(["--format", "json", @subject], opts(false)) == :ok end)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:194: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:552: Anchor.Managers.Graph.artifact_inputs/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:122: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:70: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:84: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:100: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test --format json prints the JSON answer"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_explain_test.exs:100: (test)

.

  3) test a path answers in text, and a compile failure is noted rather than fatal (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:83
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BeamSourceMock.read_ebins/1 in process #PID<0.1316.0> with args [[anchor: "<worktree>/_build/test/lib/anchor/ebin"]]
     code: output = capture_io(fn -> assert Explain.run([@subject], opts(false)) == :ok end)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:194: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:552: Anchor.Managers.Graph.artifact_inputs/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:122: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:70: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:84: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:86: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test a path answers in text, and a compile failure is noted rather than fatal"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_explain_test.exs:86: (test)

...
```

## MX-B — a module subject placed by naming convention, not by the graph

Run summary: `13 tests, 1 failure`

```text
  1) test explain/2 a module subject is placed at its source file by the graph (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:152
     Assertion with == failed
     code:  assert explain.path == @domain_file
     left:  "lib/anchor_fixtures/explain_manager_test/order.ex"
     right: "lib/my_app/domain/order.ex"
     stacktrace:
       test/anchor/managers/explain_test.exs:163: (test)

......
```

## MX-C — a missing file reported as existing

Run summary: `13 tests, 1 failure`

```text
  1) test explain/2 a path that does not exist yet (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:190
     Assertion with == failed
     code:  assert explain.exists == false
     left:  true
     right: false
     stacktrace:
       test/anchor/managers/explain_test.exs:196: (test)

..........
```

## MX-D — a config failure reported as usage (exit 2, not 3)

Run summary: `13 tests, 2 failures`

```text
  1) test explain/2 a missing config is could-not-check (exit 3 in the task) (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:201
     match (=) failed
     code:  assert {:error, {:could_not_check, violation}} =
              ExplainManager.explain(
                %{argument: @manager_file, graph: graph_request(), compiled?: true},
                deps()
              )
     left:  {:error, {:could_not_check, violation}}
     right: {:error, {:usage, {:config_not_found, ["/proj/.anchor.yml"]}}}
     stacktrace:
       test/anchor/managers/explain_test.exs:206: (test)

......

  2) test no config is could-not-check: exit 3 (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:155
     Assertion with == failed
     code:  assert catch_exit(Explain.run([@subject], opts(false))) == {:shutdown, 3}
     left:  {:shutdown, 2}
     right: {:shutdown, 3}
     stacktrace:
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:159: (test)

.
```

## MX-E — the artifact is used whatever the store answers (stale graph)

Run summary: `13 tests, 2 failures`

```text
  1) test explain/2 a stale artifact (another key) is never used: findings not computed (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:167
     Assertion with == failed
     code:  assert explain.findings == nil
     left:  []
     right: nil
     stacktrace:
       test/anchor/managers/explain_test.exs:173: (test)

......

  2) test a compiled project with no current graph artifact reads it under this build's key (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:110
     Assertion with =~ failed
     code:  assert output =~ "findings: not computed (run mix anchor.graph)"
     left:  "anchor.explain: lib/app/domain/thing.ex\n  module: App.Domain.Thing\n  path: lib/app/domain/thing.ex (does not exist yet)\nclassification:\n  status: classified by path\n  bucket: domain (role domain)\n  context: App.Domain\n  app: unknown until compiled\n  interface: no\n  aggregate: unknown (no aggregates configured)\n  bucket domain selects: paths [\"lib/**/domain/**/*.ex\"]\nmay call:\n  domain (any): same context: none; other contexts (interface only): none\nmust not call: nothing\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\nfindings: none\nunknown until compiled: app, behaviours, exports_function, uses_module\n"
     right: "findings: not computed (run mix anchor.graph)"
     stacktrace:
       test/mix/tasks/anchor_explain_test.exs:126: (test)

..
```

## TK-A — --format json prints text

Run summary: `6 tests, 1 failure`

```text
  1) test --format json prints the JSON answer (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:96
     ** (JSON.DecodeError) invalid byte 97 at position (byte offset) 0
     code: JSON.decode!(output)
     stacktrace:
       (elixir 1.19.4) lib/json.ex:451: JSON.decode!/1
       test/mix/tasks/anchor_explain_test.exs:107: (test)

.....
```

## TK-B — two subjects accepted (the first used)

Run summary: `6 tests, 1 failure`

```text
  1) test no subject, two subjects, an unknown flag or a bad format is usage: exit 2 with Fix: (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:130
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load/0 in process #PID<0.1279.0> with args []
     code: for argv <- [[], [@subject, "lib/other.ex"], ["--bogus", @subject], ~w(--format xml x.ex)] do
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/explain.ex:99: Anchor.Managers.Explain.load_config/1
       (anchor 0.1.0) lib/anchor/managers/explain.ex:68: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:84: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:134: anonymous fn/1 in Mix.Tasks.Anchor.ExplainTest."test no subject, two subjects, an unknown flag or a bad format is usage: exit 2 with Fix:"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:133: anonymous fn/2 in Mix.Tasks.Anchor.ExplainTest."test no subject, two subjects, an unknown flag or a bad format is usage: exit 2 with Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/mix/tasks/anchor_explain_test.exs:131: (test)

...
```

## TK-C — could-not-check exits 1, not 3

Run summary: `6 tests, 1 failure`

```text
  1) test no config is could-not-check: exit 3 (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:155
     Assertion with == failed
     code:  assert catch_exit(Explain.run([@subject], opts(false))) == {:shutdown, 3}
     left:  {:shutdown, 1}
     right: {:shutdown, 3}
     stacktrace:
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:159: (test)

...
```

## MX-F — findings on other files are kept (the subject filter dropped)

Run summary: `9 tests, 2 failures`

```text
  1) test explain/2 findings are the subject file's only: another file's finding is not shown (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:227
     match (=) failed
     code:  assert [%{filename: @manager_file, message: message}] = explain.findings
     left:  [%{filename: "lib/my_app/managers/orders.ex", message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: nil,
                message: "AnchorFixtures.ExplainManagerTest.Order was found. Fix: do not be found.",
                filename: "lib/my_app/domain/order.ex",
                kind: :rule,
                key: "layering|AnchorFixtures.ExplainManagerTest.Order|found",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: nil,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found.",
                filename: "lib/my_app/managers/orders.ex",
                kind: :rule,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:243: (test)

.....

  2) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:247
     match (=) failed
     code:  assert [%{filename: @manager_file}, crashed] = crashed_findings(beams, crashing)
     left:  [%{filename: "lib/my_app/managers/orders.ex"}, crashed]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: nil,
                message: "AnchorFixtures.ExplainManagerTest.Order was found. Fix: do not be found.",
                filename: "lib/my_app/domain/order.ex",
                kind: :rule,
                key: "layering|AnchorFixtures.ExplainManagerTest.Order|found",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: nil,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found.",
                filename: "lib/my_app/managers/orders.ex",
                kind: :rule,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule 2 (id: \"acyclic\", context_acyclic) could not run: RuntimeError: rule blew up (raised at test/anchor/managers/explain_test.exs:52: Anchor.Managers.ExplainTest.Crashes.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:254: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:250: (test)

.
```

## MX-G — a fail-closed finding (a crashed rule) is filtered out

Run summary: `9 tests, 1 failure`

```text
  1) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:247
     match (=) failed
     code:  assert [%{filename: @manager_file}, crashed] = crashed_findings(beams, crashing)
     left:  [%{filename: "lib/my_app/managers/orders.ex"}, crashed]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: nil,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found.",
                filename: "lib/my_app/managers/orders.ex",
                kind: :rule,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:254: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:250: (test)

.....
```

## MX-H — a rule that raises is not rescued

Run summary: `9 tests, 1 failure`

```text
  1) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:247
     ** (RuntimeError) rule blew up
     code: for {crashing, text} <- [
     stacktrace:
       test/anchor/managers/explain_test.exs:52: Anchor.Managers.ExplainTest.Crashes.check/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:187: Anchor.Managers.Explain.guarded_check/4
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (elixir 1.19.4) lib/enum.ex:4501: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:177: Anchor.Managers.Explain.findings/4
       (anchor 0.1.0) lib/anchor/managers/explain.ex:81: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:186: Anchor.Managers.ExplainTest.crashed_findings/2
       test/anchor/managers/explain_test.exs:254: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:250: (test)

......
```

## MX-I — a rule that throws is not caught

Run summary: `9 tests, 1 failure`

```text
  1) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:247
     ** (throw) :thrown
     code: for {crashing, text} <- [
     stacktrace:
       test/anchor/managers/explain_test.exs:59: Anchor.Managers.ExplainTest.Throws.check/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:187: Anchor.Managers.Explain.guarded_check/4
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (elixir 1.19.4) lib/enum.ex:4501: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/explain.ex:177: Anchor.Managers.Explain.findings/4
       (anchor 0.1.0) lib/anchor/managers/explain.ex:81: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:186: Anchor.Managers.ExplainTest.crashed_findings/2
       test/anchor/managers/explain_test.exs:254: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:250: (test)

.....
```
