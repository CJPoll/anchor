# Sabotage record — mix anchor.explain after merging main at 07aef9f

- **Domain:** explain
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Managers.Graph` (`rule_findings/3`, `artifact_inputs/2`), `Anchor.Managers.Explain`, `Anchor.Domain.Explain`, `Mix.Tasks.Anchor.Explain`
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

RF-A and RF-B are regression tests of explain's missing analyses and floors. AI-A restores the absolute-apps_path crash, EX-M the re-classification with no source facts, EX-N the beam facts of a compiled module called unknown. TX-A and TX-B cover the task's umbrella wiring, TX-C its exit 3. Each red is the regression red in its fix commit. A first AI-A dropped the `with` altogether: Elixir type-checked the result, warned that Explain's refusal clause could never match, and the run did not compile, so the row is the `with` over the raw request.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| RF-A | rule_findings gives the rules no analyses (`lib/anchor/managers/graph.ex`) | `explain_test.exs` | `13 tests, 1 failure` (red) | explain/2 a rule that needs the flow analysis and the effects is given them |
| RF-B | rule_findings skips a rule's floor (`lib/anchor/managers/graph.ex`) | `explain_test.exs` | `13 tests, 1 failure` (red) | explain/2 a rule that selects nothing is named among the findings, as in a graph run |
| RF-C | a crashed analysis or rule gives no finding (`lib/anchor/managers/graph.ex`) | `explain_test.exs` | `13 tests, 3 failures` (red) | explain/2 an inference that crashes is named among the findings; its rule does not run; explain/2 a flow analysis that crashes is named among the findings; its rule does not run; explain/2 a rule that raises or throws is named among the findings, never dropped |
| MX-J | another file's findings are kept (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `13 tests, 3 failures` (red) | explain/2 a rule that needs the flow analysis and the effects is given them; explain/2 a rule that raises or throws is named among the findings, never dropped; explain/2 findings are the subject file's only: another file's finding is not shown |
| MX-K | a fail-closed finding on another file is dropped (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `13 tests, 4 failures` (red) | explain/2 a flow analysis that crashes is named among the findings; its rule does not run; explain/2 a rule that raises or throws is named among the findings, never dropped; explain/2 an inference that crashes is named among the findings; its rule does not run; explain/2 a rule that selects nothing is named among the findings, as in a graph run |
| AI-A | artifact_inputs reads the request's raw apps_paths (`lib/anchor/managers/graph.ex`) | `explain_test.exs` | `15 tests, 2 failures` (red) | explain/2 an apps_path outside the root is could-not-check, as in a graph run; explain/2 an absolute apps_path under the root: the graph run's own key, and no crash |
| AI-B | Explain reads an outside apps_path as no model (`lib/anchor/managers/explain.ex`) | `explain_test.exs` | `15 tests, 1 failure` (red) | explain/2 an apps_path outside the root is could-not-check, as in a graph run |
| EX-K | text findings name the wrong field (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `10 tests, 1 failure` (red) | build/3 with the model the findings it was given are kept |
| EX-L | JSON findings carry the label as their file (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `10 tests, 1 failure` (red) | build/3 with the model the findings it was given are kept |
| EX-M | an unplaced module is re-classified with no source facts (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `12 tests, 2 failures` (red) | build/3 with the model a module in two buckets, both through its source's `use`, is ambiguous; build/3 with the model a module in two buckets, one through its source's `use`, is ambiguous |
| EX-N | a compiled but unplaced module's beam facts are called unknown (`lib/anchor/domain/explain.ex`) | `explain_test.exs` | `12 tests, 2 failures` (red) | build/3 with the model a module in two buckets, one through its source's `use`, is ambiguous; build/3 with the model a module in the graph but in no bucket is unclassified, with every bucket's selectors and the Fix |
| TX-A | the task gathers no umbrella ebins (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `10 tests, 1 failure` (red) | an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote |
| TX-B | the task drops the apps' directories (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `10 tests, 2 failures` (red) | an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal; an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote |
| TX-C | a refusal exits 0 (`lib/mix/tasks/anchor.explain.ex`) | `anchor_explain_test.exs` | `10 tests, 2 failures` (red) | an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal; no config is could-not-check: exit 3 |

## RF-A — rule_findings gives the rules no analyses

Run summary: `13 tests, 1 failure`

```text
  1) test explain/2 a rule that needs the flow analysis and the effects is given them (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:292
     Assertion with == failed
     code:  assert message == "cfa given: true; effects given: true."
     left:  "cfa given: false; effects given: false."
     right: "cfa given: true; effects given: true."
     stacktrace:
       test/anchor/managers/explain_test.exs:296: (test)

.
```

## RF-B — rule_findings skips a rule's floor

Run summary: `13 tests, 1 failure`

```text
  1) test explain/2 a rule that selects nothing is named among the findings, as in a graph run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:323
     match (=) failed
     code:  assert [finding] = findings_with(beams, rule, [NeedsAnalyses])
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:328: (test)

..
```

## RF-C — a crashed analysis or rule gives no finding

Run summary: `13 tests, 3 failures`

```text
  1) test explain/2 an inference that crashes is named among the findings; its rule does not run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:311
     match (=) failed
     code:  assert [finding] =
              findings_with(beams, @effects_rule, [NeedsAnalyses],
                effects: fn _model, _opts -> raise "inference blew up" end
              )
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:314: (test)

.

  2) test explain/2 a flow analysis that crashes is named among the findings; its rule does not run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:299
     match (=) failed
     code:  assert [finding] =
              findings_with(beams, @effects_rule, [NeedsAnalyses],
                cfa: fn _graph -> raise "analysis blew up" end
              )
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:302: (test)

.

  3) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:277
     match (=) failed
     code:  assert [%Finding{file: @manager_file}, crashed] = crashed_findings(beams, crashing)
     left:  [%Anchor.Domain.GraphReport.Finding{file: "lib/my_app/managers/orders.ex"}, crashed]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                file: "lib/my_app/managers/orders.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:284: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:280: (test)

........
```

## MX-J — another file's findings are kept

Run summary: `13 tests, 3 failures`

```text
  1) test explain/2 a rule that needs the flow analysis and the effects is given them (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:292
     match (=) failed
     code:  assert [%Finding{file: @manager_file, message: message}] =
              findings_with(beams, @effects_rule, [NeedsAnalyses])
     left:  [%Anchor.Domain.GraphReport.Finding{file: "lib/my_app/managers/orders.ex", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "effects",
                type: :effects_match_bucket,
                label: "rule 2 (id: \"effects\", effects_match_bucket)",
                enforcement: :enforce,
                key: nil,
                file: "lib/my_app/domain/order.ex",
                line: nil,
                message: "cfa given: true; effects given: true."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "effects",
                type: :effects_match_bucket,
                label: "rule 2 (id: \"effects\", effects_match_bucket)",
                enforcement: :enforce,
                key: nil,
                file: "lib/my_app/managers/orders.ex",
                line: nil,
                message: "cfa given: true; effects given: true."
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:293: (test)

......

  2) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:277
     match (=) failed
     code:  assert [%Finding{file: @manager_file}, crashed] = crashed_findings(beams, crashing)
     left:  [%Anchor.Domain.GraphReport.Finding{file: "lib/my_app/managers/orders.ex"}, crashed]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Order|found",
                file: "lib/my_app/domain/order.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Order was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                file: "lib/my_app/managers/orders.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 2 (id: \"acyclic\", context_acyclic) could not run: RuntimeError: rule blew up (raised at test/anchor/managers/explain_test.exs:55: Anchor.Managers.ExplainTest.Crashes.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:284: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:280: (test)

..

  3) test explain/2 findings are the subject file's only: another file's finding is not shown (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:257
     match (=) failed
     code:  assert [%Finding{file: @manager_file, message: message}] = explain.findings
     left:  [%Anchor.Domain.GraphReport.Finding{file: "lib/my_app/managers/orders.ex", message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Order|found",
                file: "lib/my_app/domain/order.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Order was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                file: "lib/my_app/managers/orders.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:273: (test)

..
```

## MX-K — a fail-closed finding on another file is dropped

Run summary: `13 tests, 4 failures`

```text
  1) test explain/2 a flow analysis that crashes is named among the findings; its rule does not run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:299
     match (=) failed
     code:  assert [finding] =
              findings_with(beams, @effects_rule, [NeedsAnalyses],
                cfa: fn _graph -> raise "analysis blew up" end
              )
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:302: (test)

.

  2) test explain/2 a rule that raises or throws is named among the findings, never dropped (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:277
     match (=) failed
     code:  assert [%Finding{file: @manager_file}, crashed] = crashed_findings(beams, crashing)
     left:  [%Anchor.Domain.GraphReport.Finding{file: "lib/my_app/managers/orders.ex"}, crashed]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.ExplainManagerTest.Orders|found",
                file: "lib/my_app/managers/orders.ex",
                line: 2,
                message: "AnchorFixtures.ExplainManagerTest.Orders was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/explain_test.exs:284: anonymous fn/3 in Anchor.Managers.ExplainTest."test explain/2 a rule that raises or throws is named among the findings, never dropped"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/explain_test.exs:280: (test)

....

  3) test explain/2 an inference that crashes is named among the findings; its rule does not run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:311
     match (=) failed
     code:  assert [finding] =
              findings_with(beams, @effects_rule, [NeedsAnalyses],
                effects: fn _model, _opts -> raise "inference blew up" end
              )
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:314: (test)

...

  4) test explain/2 a rule that selects nothing is named among the findings, as in a graph run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:323
     match (=) failed
     code:  assert [finding] = findings_with(beams, rule, [NeedsAnalyses])
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/managers/explain_test.exs:328: (test)

.
```

## AI-A — artifact_inputs reads the request's raw apps_paths

Run summary: `15 tests, 2 failures`

```text
  1) test explain/2 an apps_path outside the root is could-not-check, as in a graph run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:395
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.1444.0>
     code: ExplainManager.explain(
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:228: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:741: Anchor.Managers.Graph.read_artifact_inputs/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:128: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:75: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:403: (test)

..

  2) test explain/2 an absolute apps_path under the root: the graph run's own key, and no crash (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:370
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/my_app"
     code: ExplainManager.explain(
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:99: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:418: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:415: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:743: Anchor.Managers.Graph.read_artifact_inputs/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:128: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:75: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:389: (test)

...........
```

## AI-B — Explain reads an outside apps_path as no model

Run summary: `15 tests, 1 failure`

```text
  1) test explain/2 an apps_path outside the root is could-not-check, as in a graph run (Anchor.Managers.ExplainTest)
     test/anchor/managers/explain_test.exs:395
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceSourceMock.read/2 in process #PID<0.1455.0> with args ["/proj", ["lib/my_app/managers/orders.ex"]]
     code: ExplainManager.explain(
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/explain.ex:167: Anchor.Managers.Explain.read_source/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:77: Anchor.Managers.Explain.explain/2
       test/anchor/managers/explain_test.exs:403: (test)

.........
```

## EX-K — text findings name the wrong field

Run summary: `10 tests, 1 failure`

```text
  1) test build/3 with the model the findings it was given are kept (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:196
     Assertion with =~ failed
     code:  assert Explain.render(explain, :text) =~ "findings:\n  lib/app/managers/orders.ex:1: x. Fix: y"
     left:  "anchor.explain: lib/app/managers/orders.ex\n  module: App.Orders.Manager\n  path: lib/app/managers/orders.ex (exists)\nclassification:\n  status: classified\n  bucket: managers (role managers)\n  context: App.Orders\n  app: app\n  interface: yes\n  aggregate: unknown (no aggregates declared)\nmay call:\n  managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager\n  domain (any): same context: App.Orders.Order; other contexts (interface only): none\nmust not call: framework\nrules:\n  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call\n  [enforce] single_control_flow (ast): one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function\nfindings:\n  layering:1: x. Fix: y"
     right: "findings:\n  lib/app/managers/orders.ex:1: x. Fix: y"
     stacktrace:
       test/anchor/domain/explain_test.exs:210: (test)

......
```

## EX-L — JSON findings carry the label as their file

Run summary: `10 tests, 1 failure`

```text
  1) test build/3 with the model the findings it was given are kept (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:196
     match (=) failed
     code:  assert [%{"file" => "lib/app/managers/orders.ex", "message" => "x. Fix: y"}] =
              JSON.decode!(Explain.render(explain, :json))["findings"]
     left:  [%{"file" => "lib/app/managers/orders.ex", "message" => "x. Fix: y"}]
     right: [
              %{
                "file" => "layering",
                "key" => nil,
                "line" => nil,
                "message" => "x. Fix: y",
                "rule_id" => nil
              }
            ]
     stacktrace:
       test/anchor/domain/explain_test.exs:213: (test)

..
```

## EX-M — an unplaced module is re-classified with no source facts

Run summary: `12 tests, 2 failures`

```text
  1) test build/3 with the model a module in two buckets, both through its source's `use`, is ambiguous (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:269
     Assertion with == failed
     code:  assert explain.classification["status"] == "ambiguous"
     left:  "unclassified"
     right: "ambiguous"
     stacktrace:
       test/anchor/domain/explain_test.exs:285: (test)

....

  2) test build/3 with the model a module in two buckets, one through its source's `use`, is ambiguous (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:256
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Explain.graph_issue/3

     The following arguments were given to Anchor.Domain.Explain.graph_issue/3:

         # 1
         {:ok, %Anchor.Domain.Classification{module: App.Worker, bucket: "domain", role: :domain, context: "App.Worker", app: :app, source_file: "lib/app/domain/worker.ex", interface?: false}}

         # 2
         %{exports: [], line: nil, module: App.Worker, behaviours: [], uses: [], app: :app, source_file: "lib/app/domain/worker.ex"}

         # 3
         %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{name: "managers", role: :managers, selectors: [paths: ["lib/**/managers/**/*.ex"]], min_modules: 1, infer: true}, %Anchor.Domain.Architecture.Bucket{name: "domain", role: :domain, selectors: [paths: ["lib/**/domain/**/*.ex"]], min_modules: 1, infer: true}, %Anchor.Domain.Architecture.Bucket{name: "framework", role: :framework, selectors: [uses_module: GenServer], min_modules: 1, infer: true}], calls: %{"domain" => [{"domain", :any}], "framework" => [{"framework", :any}, {"managers", :any}], "managers" => [{"managers", :any}, {"domain", :any}]}, interface_buckets: ["managers"], interface_exports: [], effects: [], roots: [], extract_pure_regions_from: [:managers, :framework]}

     Attempted function clauses (showing 2 out of 2):

         defp graph_issue(-{:error, {:unclassified, _module}}-, facts, _arch)
         defp graph_issue(-{:error, {:ambiguous, _module, _names}}-, facts, arch)

     code: explain = explain_of_worker(config())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/explain.ex:204: Anchor.Domain.Explain.graph_issue/3
       (anchor 0.1.0) lib/anchor/domain/explain.ex:189: Anchor.Domain.Explain.unplaced/3
       (anchor 0.1.0) lib/anchor/domain/explain.ex:93: Anchor.Domain.Explain.build/3
       test/anchor/domain/explain_test.exs:257: (test)

......
```

## EX-N — a compiled but unplaced module's beam facts are called unknown

Run summary: `12 tests, 2 failures`

```text
  1) test build/3 with the model a module in two buckets, one through its source's `use`, is ambiguous (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:258
     Assertion with == failed
     code:  assert explain.unknown == []
     left:  ["app", "behaviours", "exports_function", "uses_module"]
     right: []
     stacktrace:
       test/anchor/domain/explain_test.exs:262: (test)

....

  2) test build/3 with the model a module in the graph but in no bucket is unclassified, with every bucket's selectors and the Fix (Anchor.Domain.ExplainTest)
     test/anchor/domain/explain_test.exs:239
     Assertion with == failed
     code:  assert explain.unknown == []
     left:  ["app", "behaviours", "exports_function", "uses_module"]
     right: []
     stacktrace:
       test/anchor/domain/explain_test.exs:250: (test)

.
```

## TX-A — the task gathers no umbrella ebins

Run summary: `10 tests, 1 failure`

```text
  1) test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:114
     ** (FunctionClauseError) no function clause matching in anonymous fn/1 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1

     The following arguments were given to anonymous fn/1 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1:

         # 1
         [anchor: "<worktree>/_build/test/lib/anchor/ebin"]

     code: capture_io(fn ->
     stacktrace:
       anonymous fn/1 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1
       (anchor 0.1.0) lib/anchor/managers/graph.ex:228: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:741: Anchor.Managers.Graph.read_artifact_inputs/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:128: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:75: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:97: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:145: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_explain_test.exs:144: (test)

........
```

## TX-B — the task drops the apps' directories

Run summary: `10 tests, 2 failures`

```text
  1) test an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:155
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.1437.0>
     code: capture_io(:stderr, fn ->
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:228: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:741: Anchor.Managers.Graph.read_artifact_inputs/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:128: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:75: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:97: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:162: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:160: (test)

  2) test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:114
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1

     The following arguments were given to anonymous fn/2 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1:

         # 1
         "<worktree>/_build/test/anchor"

         # 2
         "23436d60cbc9e074916b580dafa52a30aa8105c7f7995e9c31666852c08cc3ff"

     code: capture_io(fn ->
     stacktrace:
       anonymous fn/2 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:130: Anchor.Managers.Explain.model/3
       (anchor 0.1.0) lib/anchor/managers/explain.ex:75: Anchor.Managers.Explain.explain/2
       (anchor 0.1.0) lib/mix/tasks/anchor.explain.ex:97: Mix.Tasks.Anchor.Explain.run_parsed/3
       test/mix/tasks/anchor_explain_test.exs:145: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) explain reads the artifact the graph run of the same apps wrote"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_explain_test.exs:144: (test)

.....
```

## TX-C — a refusal exits 0

Run summary: `10 tests, 2 failures`

```text
  1) test an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:155
     Expected to catch exit, got nothing
     code: capture_io(:stderr, fn ->
     stacktrace:
       test/mix/tasks/anchor_explain_test.exs:161: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test an umbrella (apps_paths injected: this test runs inside Anchor) an app directory outside the root exits 3 with the refusal"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:160: (test)

.....

  2) test no config is could-not-check: exit 3 (Mix.Tasks.Anchor.ExplainTest)
     test/mix/tasks/anchor_explain_test.exs:286
     Expected to catch exit, got nothing
     code: capture_io(:stderr, fn ->
     stacktrace:
       test/mix/tasks/anchor_explain_test.exs:291: anonymous fn/0 in Mix.Tasks.Anchor.ExplainTest."test no config is could-not-check: exit 3"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_explain_test.exs:290: (test)

...
```
