# Sabotage record — the placement model and its rules (DND-5448)

- **Domain:** placement
- **Branch:** dnd-5448-placement-core
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Placement` (`build/1`, `proposals/3`, `render/1`, `to_violation/3`), `Anchor.Domain.Placement.Rules`, `.Ownership`, `.CallGraph`, `Anchor.Domain.GraphRules.FunctionPlacement`, `.ReachableFromRoot`, `.EffectsMatchBucket`, the runner's `:placement` wiring in `Anchor.Managers.Graph`, `GraphReport.placement/1`, `DataFlow.result_nodes/1`, `StructTypes.struct_of/3`, `Core.partial_mfa_calls/1`, the `Failures` it adds, and the two rules' registration in `RuleSchema` and `GraphRules`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>`, through `test-slot`. Group U, the files of every row marked U: `test/anchor/domain/graph_rules/effects_match_bucket_test.exs`, `test/anchor/domain/graph_rules/function_placement_test.exs`, `test/anchor/domain/graph_rules/reachable_from_root_test.exs`, `test/anchor/domain/placement/ownership_test.exs`, `test/anchor/domain/placement_render_test.exs`, `test/anchor/domain/placement_test.exs`, `test/anchor/integration/placement_invariant_test.exs`, `test/anchor/managers/graph_placement_test.exs`. Any other row names its own files.

Each mutation replaced one exact text in the named file (PL-AX: two, the alias with its use), the named tests ran, and the file was restored from its saved copy, with more than a second between runs so no beam was stale. The QA plan's four named sabotages are PL-A (rule order), PL-B (same-bucket guard), PL-C (capture edges) and PL-D (silent lost precision).

The Mission's QA plan asks for this one record, `placement-YYYYMMDD-<branch>.md`, so the rows that break a helper or registration outside the placement domain are here too, marked **off-domain** with the module they break: they exist only for this rule set.

Traps seen:

- **PL-AI first survived.** "The manager builds the model for every run" passed all five runner tests: the only rule that needed nothing was a stub with no effect inference either, so the model stayed unbuilt for the wrong reason. The test "a rule that needs the inference only: no model is built" was added, and the row below is its red.
- Several first forms did not compile under warnings-as-errors (an unused alias, an unused variable, and the type checker seeing a `:ambiguous` clause that could no longer match), which proves nothing about the tests. Each row below is a form that compiled and ran. PL-AX takes the alias out with the entry, because the alias alone left unused holds the mutation at the compiler.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PL-A | swap the rule order: rule 2 before rule 1 (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 4 failures` (red) | proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there; the canary yields exactly its listed findings; no key carries a line number: every module shifted five lines gives the same keys; report mode never fails, and still prints each finding |
| PL-B | drop rule 4's same-bucket-and-context guard (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 13 failures` (red) | one violation per proposal, with the def's file and line; the key has no line number and is stable when lines shift; proposals/3 dominated across buckets is not moved; proposals/3 dominated across contexts is not moved; proposals/3 a function in its owner stays, though only another module of its bucket calls it; proposals/3 a function a dynamic call can reach cannot go private; proposals/3 dominated by one module; proposals/3 a project behaviour's callback is not moved; no key carries a line number: every module shifted five lines gives the same keys; positive control: the compliant half alone gives no finding; report mode never fails, and still prints each finding; every placement violation's Fix equals the render of the proposal with its key; the canary yields exactly its listed findings |
| PL-C | drop capture edges (`lib/anchor/domain/placement/call_graph.ex`) | U | `136 tests, 7 failures` (red) | a captured function passes; build/1 a capture makes its target reachable; no key carries a line number: every module shifted five lines gives the same keys; every placement violation's Fix equals the render of the proposal with its key; the same function captured by a reachable one is reachable; report mode never fails, and still prints each finding; the canary yields exactly its listed findings |
| PL-D | lost precision passes silently (`lib/anchor/domain/graph_rules/reachable_from_root.ex`) | U | `136 tests, 3 failures` (red) | lost precision fails closed, naming the site, with no finding; spawn with a computed name loses reachability, naming its line; the precision is printed, and a computed name turns reachability into one issue |
| PL-E | no roots passes silently (`lib/anchor/domain/graph_rules/reachable_from_root.ex`) | U | `136 tests, 1 failure` (red) | no roots fails closed |
| PL-F | a variable application loses precision too (`lib/anchor/domain/placement/call_graph.ex`) | U | `136 tests, 8 failures` (red) | build/1 a variable application is the closure form: it loses nothing; the canary yields exactly its listed findings; every reason the canary emits renders one non-empty line, and all five are there; the precision is printed, and a computed name turns reachability into one issue; every placement violation's Fix equals the render of the proposal with its key; report mode never fails, and still prints each finding; no key carries a line number: every module shifted five lines gives the same keys; each finding carries the acceptance criteria's reason and target |
| PL-G | a dynamic call adds no edge (`lib/anchor/domain/placement/call_graph.ex`) | U | `136 tests, 1 failure` (red) | build/1 a dynamic call reaches the implementations, and marks them named |
| PL-H | a dynamic call does not mark its target named (`lib/anchor/domain/placement/call_graph.ex`) | U | `136 tests, 2 failures` (red) | proposals/3 a function a dynamic call can reach cannot go private; build/1 a dynamic call reaches the implementations, and marks them named |
| PL-I | macros are not roots (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | build/1 a macro counts as a root |
| PL-J | interface modules are judged by rules 2 to 4 (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 2 failures` (red) | selected modules of which no function can be judged: it checked nothing; proposals/3 an interface module's functions are exempt from rules 2 to 4 |
| PL-K | a project behaviour's callback is judged (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 a project behaviour's callback is not moved |
| PL-L | an owner in any bucket is taken (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 2 failures` (red) | proposals/3 an input owner in another bucket gives no proposal; proposals/3 an owner in another bucket gives no proposal |
| PL-M | a function in its own owner still moves (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 8 failures` (red) | proposals/3 a function in its owner stays, though only another module of its bucket calls it; proposals/3 a function already in its owner gives no proposal; proposals/3 a long, well-placed function gets no proposal; positive control: the compliant half alone gives no finding; the canary yields exactly its listed findings; no key carries a line number: every module shifted five lines gives the same keys; report mode never fails, and still prints each finding; every placement violation's Fix equals the render of the proposal with its key |
| PL-BD | a function in its own owner falls through to rule 4 (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 a function in its owner stays, though only another module of its bucket calls it |
| PL-BE | rule 4 never fires (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 9 failures` (red) | the key has no line number and is stable when lines shift; one violation per proposal, with the def's file and line; proposals/3 dominated by one module; no key carries a line number: every module shifted five lines gives the same keys; every reason the canary emits renders one non-empty line, and all five are there; report mode never fails, and still prints each finding; the canary yields exactly its listed findings; every placement violation's Fix equals the render of the proposal with its key; each finding carries the acceptance criteria's reason and target |
| PL-BF | reachable_from_root proposes under lost precision (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 unreachable lists none under lost precision |
| PL-BG | rule 4 takes the virtual root's callers as its dominator (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 a shared function gets no move from rule 4 |
| PL-BH | a shared function still moves by rules 2 and 3 (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 2 failures` (red) | proposals/3 rule 1 of a shared pure function names its bucket, not an owner; proposals/3 a shared function gets no move from rules 2 or 3 |
| PL-BI | a macro alone counts as a root for no_roots (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | build/1 a macro alone is no root the inference found: still no roots |
| PL-BJ | rule 4 moves into an interface (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 a move into an interface module is not proposed |
| PL-BK | a spawn with a computed name loses nothing (`lib/anchor/domain/placement/call_graph.ex`) | U | `137 tests, 1 failure` (red) | spawn with a computed name loses reachability, naming its line |
| PL-BL | a known name with unknown arguments is no edge (`lib/anchor/domain/placement/call_graph.ex`) | U | `137 tests, 1 failure` (red) | a known name with arguments of unknown length reaches every arity, and stays public |
| PL-BM | partial_mfa_calls reads the triple from the wrong place (`lib/anchor/domain/core.ex`) **off-domain** | `test/anchor/domain/core_mfa_references_test.exs` | `41 tests, 1 failure` (red) | partial_mfa_calls/1 literal_args_var/1 reads as {M, :f} |
| PL-BN | partial_mfa_calls keeps a whole triple (`lib/anchor/domain/core.ex`) **off-domain** | `test/anchor/domain/core_mfa_references_test.exs` | `41 tests, 1 failure` (red) | partial_mfa_calls/1 a whole triple is mfa_references/1's, and nothing else is read |
| PL-N | rule 1 ignores a known owner (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 2 failures` (red) | proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there; each finding carries the acceptance criteria's reason and target |
| PL-O | rule 4 ignores other callers (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 dominated but called from two modules is not moved |
| PL-P | rule 4 moves a named function (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 a function a dynamic call can reach cannot go private |
| PL-Q | a private function can be unreachable (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 unreachable: a public function, with delete; a private one is not judged |
| PL-R | generated functions are judged (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 2 failures` (red) | generated functions are not reported; proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 |
| PL-S | child_spec/1 is judged (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 child_spec/1 and compiler names are not unreachable |
| PL-T | rule 1's named target takes the first of several (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 1 failure` (red) | proposals/3 rule 1 names no module when two have the subject's tail name, or none has |
| PL-U | the violation's Fix is not the render (`lib/anchor/domain/placement.ex`) | U | `136 tests, 8 failures` (red) | each message ends with Fix: and exactly render(proposal); an uncalled public function is one violation, and its Fix is the rendered proposal; a manager with a direct effect is an issue; the Fix is Placement.render/1 of its proposal, and the key is the landed one; an adapter that reaches effects only through another module names it; an adapter function with no effect is an issue; a domain function that reaches an effect is one issue naming the chain; every placement violation's Fix equals the render of the proposal with its key |
| PL-V | the violation's key keeps the type, not the rule's name (`lib/anchor/domain/placement.ex`) | U | `136 tests, 5 failures` (red) | each message ends with Fix: and exactly render(proposal); an uncalled public function is one violation, and its Fix is the rendered proposal; a domain function that reaches an effect is one issue naming the chain; an adapter function with no effect is an issue; the Fix is Placement.render/1 of its proposal, and the key is the landed one |
| PL-W | the key carries what moves (callers, evidence) (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 6 failures` (red) | the key has no line number and is stable when lines shift; an uncalled public function is one violation, and its Fix is the rendered proposal; proposals/3 output owner in a Domain bucket; the canary yields exactly its listed findings; no key carries a line number: every module shifted five lines gives the same keys; report mode never fails, and still prints each finding |
| PL-X | the effects key takes the design's form, breaking the landed baselines (`lib/anchor/domain/placement/rules.ex`) | U | `136 tests, 7 failures` (red) | a domain function that reaches an effect is one issue naming the chain; an adapter function with no effect is an issue; the Fix is Placement.render/1 of its proposal, and the key is the landed one; proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there; the canary yields exactly its listed findings; report mode never fails, and still prints each finding; no key carries a line number: every module shifted five lines gives the same keys |
| PL-Y | a guard's read is off the slice (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 1 failure` (red) | input_owner/3 a parameter only a guard reads decides the result: it is on the slice |
| PL-Z | on the slice in any clause is enough (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 1 failure` (red) | input_owner/3 on the slice in one clause only is not on the slice |
| PL-AA | every struct parameter is on the slice (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 3 failures` (red) | input_owner/3 on the slice in one clause only is not on the slice; input_owner/3 a struct parameter bound and not used is not on the slice; input_owner/3 a struct parameter matched and not used is not on the slice |
| PL-AB | two structs are one owner (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 4 failures` (red) | output_owner/2 two different structs are ambiguous; input_owner/3 two struct parameters on the slice are ambiguous; output_owner/2 a struct beside a non-error member has no owner; build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted |
| PL-BA | an ambiguous output is not counted (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted |
| PL-BB | a function with no clause is not counted (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted |
| PL-AC | a struct beside a non-error member is owned (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 1 failure` (red) | output_owner/2 a struct beside a non-error member has no owner |
| PL-AD | an {:ok, S} return names no struct (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 1 failure` (red) | output_owner/2 an ok tuple as a beam writes it, a tuple node, is the struct's module |
| PL-AE | an error member counts (`lib/anchor/domain/placement/ownership.ex`) | U | `136 tests, 1 failure` (red) | output_owner/2 an ok tuple with an error member is the struct's module |
| PL-AF | the input owner is never asked (`lib/anchor/domain/placement.ex`) | U | `136 tests, 10 failures` (red) | one violation per proposal, with the def's file and line; proposals/3 input owner, from a clause's slice; build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted; proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there; every placement violation's Fix equals the render of the proposal with its key; each finding carries the acceptance criteria's reason and target; no key carries a line number: every module shifted five lines gives the same keys; every reason the canary emits renders one non-empty line, and all five are there; the canary yields exactly its listed findings; report mode never fails, and still prints each finding |
| PL-AG | no spec is not counted (`lib/anchor/domain/placement.ex`) | U | `136 tests, 2 failures` (red) | a rule that needs it: built once, and its precision is in the summary and the JSON; build/1 precision counts the public functions whose ownership is unknown |
| PL-AH | the shared flag names every function a root reaches directly (`lib/anchor/domain/placement.ex`) | U | `136 tests, 1 failure` (red) | build/1 a root is not shared |
| PL-AI | the manager builds the model for every run (`lib/anchor/managers/graph.ex`) | `test/anchor/managers/graph_placement_test.exs` | `6 tests, 1 failure` (red) | a rule that needs the inference only: no model is built |
| PL-AJ | a crashed model is ignored (`lib/anchor/managers/graph.ex`) | `test/anchor/managers/graph_placement_test.exs` | `6 tests, 2 failures` (red) | a model that is no %Placement{}: the rule that needs it is one issue and is not run; the others run; a model that raises: the rule that needs it is one issue and is not run; the others run |
| PL-AK | the model is built with no inference (`lib/anchor/managers/graph.ex`) | `test/anchor/managers/graph_placement_test.exs` | `6 tests, 1 failure` (red) | an inference that crashed: no model is built, and the rule reports the inference |
| PL-AL | the report leaves out the placement counts (`lib/anchor/managers/graph.ex`) | `test/anchor/managers/graph_placement_test.exs`, `test/anchor/integration/placement_invariant_test.exs` | `18 tests, 2 failures` (red) | a rule that needs it: built once, and its precision is in the summary and the JSON; the precision is printed, and a computed name turns reachability into one issue |
| PL-AM | the effects rule drops the selector (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | `test/anchor/domain/graph_rules/effects_match_bucket_test.exs` | `17 tests, 2 failures` (red) | a selected function's proposal only: the selector limits it; the selector narrows the modules judged |
| PL-AN | function_placement drops the selector (`lib/anchor/domain/graph_rules/function_placement.ex`) | `test/anchor/domain/graph_rules/function_placement_test.exs` | `5 tests, 1 failure` (red) | the selector limits the subjects |
| PL-AO | reachable_from_root drops the selector (`lib/anchor/domain/graph_rules/reachable_from_root.ex`) | `test/anchor/domain/graph_rules/reachable_from_root_test.exs` | `9 tests, 1 failure` (red) | the selector limits the subjects |
| PL-AP | function_placement has no floor (`lib/anchor/domain/graph_rules/function_placement.ex`) | `test/anchor/domain/graph_rules/function_placement_test.exs` | `5 tests, 1 failure` (red) | selected modules of which no function can be judged: it checked nothing |
| PL-AQ | reachable_from_root has no floor (`lib/anchor/domain/graph_rules/reachable_from_root.ex`) | `test/anchor/domain/graph_rules/reachable_from_root_test.exs` | `9 tests, 1 failure` (red) | selected modules with no authored public function: it checked nothing |
| PL-AR | result_nodes gives the final expression only (`lib/anchor/domain/data_flow.ex`) **off-domain** | `test/anchor/domain/data_flow_test.exs`, `test/anchor/domain/placement/ownership_test.exs` | `109 tests, 2 failures` (red) | result_nodes/1 the final expression, and each value block's final expression; result_nodes/1 an empty body has none |
| PL-AS | struct_of always answers nil (`lib/anchor/domain/struct_types.ex`) **off-domain** | `test/anchor/domain/struct_types_test.exs` | `10 tests, 1 failure` (red) | struct_of/3 a project struct, through a named type, or nil |
| PL-AU | an unknown reason gets a default text (`lib/anchor/domain/placement.ex`) | `test/anchor/domain/placement_render_test.exs` | `7 tests, 1 failure` (red) | an unknown reason raises: there is no default text |
| PL-AV | the lost-precision issue names no site (`lib/anchor/domain/failures.ex`) **off-domain** | `test/anchor/domain/failures_graph_test.exs`, `test/anchor/domain/graph_rules/reachable_from_root_test.exs` | `26 tests, 2 failures` (red) | lost precision fails closed, naming the site, with no finding; every graph message is fail-closed, on its file, with its subject and a Fix: line |
| PL-AW | reachable_from_root runs on the ast engine (`lib/anchor/domain/rule_schema.ex`) **off-domain** | `test/anchor/domain/rule_schema_test.exs`, `test/anchor/domain/rule_checks_nothing_test.exs`, `test/anchor/domain/graph_rules_test.exs` | `87 tests, 5 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; the positive case the README lists exactly the keys each rule type accepts, its relation and engine; reachable_from_root: every rule that checks nothing is refused, and the positive rows load; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; the positive case the ast types are exactly the rule types of Anchor.checks/0 |
| PL-AX | function_placement is not a registered rule (`lib/anchor/domain/graph_rules.ex`) **off-domain** | `test/anchor/domain/graph_rules_test.exs` | `16 tests, 1 failure` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types |
| PL-AY | the bucket render leaves out the word bucket (`lib/anchor/domain/placement.ex`) | `test/anchor/integration/effects_canary_test.exs`, `test/anchor/domain/graph_rules/effects_match_bucket_test.exs`, `test/anchor/domain/placement_render_test.exs` | `27 tests, 5 failures` (red) | bucket text names the context and module when known, and the evidence; a domain function that reaches an effect is one issue naming the chain; an adapter function with no effect is an issue; an adapter that reaches effects only through another module names it; a manager with a direct effect is an issue |
| PL-BC | a literal {M, :f, args} is no edge (`lib/anchor/domain/placement/call_graph.ex`) | `test/anchor/integration/placement_invariant_test.exs` | `12 tests, 1 failure` (red) | a function a literal {M, :f, args} names is reachable, and stays public |
| PL-AT | the note says precise whatever the reachability (`lib/anchor/domain/graph_report.ex`) **off-domain** | `test/anchor/domain/graph_report_test.exs` | `36 tests, 1 failure` (red) | placement precision |
| PL-BO | a held module does not reach its child spec (`lib/anchor/domain/placement/call_graph.ex`) | U | `137 tests, 1 failure` (red) | a supervised process outside a framework bucket is reached through its child spec |
| PL-BS | a module's own name reaches its child spec (`lib/anchor/domain/placement/call_graph.ex`) | U | `137 tests, 1 failure` (red) | a supervised process outside a framework bucket is reached through its child spec |
| PL-BP | held_atoms reads the top of a literal only (`lib/anchor/domain/core.ex`) **off-domain** | `test/anchor/domain/core_mfa_references_test.exs` | `70 tests, 1 failure` (red) | held_atoms/1 reads a literal of any depth |
| PL-BQ | held_atoms takes the module a call is made on (`lib/anchor/domain/core.ex`) **off-domain** | `test/anchor/domain/core_mfa_references_test.exs` | `70 tests, 1 failure` (red) | held_atoms/1 the module a call is made on is not held |
| PL-BR | a table row is gone (`lib/anchor/domain/core.ex`) **off-domain** | `test/anchor/domain/core_mfa_references_test.exs` | `70 tests, 1 failure` (red) | partial_mfa_calls/1 the table's row row_proc_spawn reads its module, and a computed name |

## Failure text

### PL-A — swap the rule order: rule 2 before rule 1

Run summary: `136 tests, 4 failures`

```text
  1) test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:202
     Assertion with == failed
     code:  assert proposal.rule == :effects_match_bucket
     left:  :function_placement
     right: :effects_match_bucket
     stacktrace:
       test/anchor/domain/placement_test.exs:213: (test)


  2) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


  3) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)


  4) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)
```

### PL-B — drop rule 4's same-bucket-and-context guard

Run summary: `136 tests, 13 failures`

```text
  1) test one violation per proposal, with the def's file and line (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:38
     Assertion with == failed
     code:  assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     left:  [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Inv.total/1", "lib/domain/Inv.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     right: [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:39: (test)


  2) test the key has no line number and is stable when lines shift (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:59
     Assertion with == failed
     code:  assert build.(10) == ["function_placement|function|Round.r/1|Inv"]
     left:  ["function_placement|function|Inv.total/1|W",
             "function_placement|function|Round.r/1|Inv"]
     right: ["function_placement|function|Round.r/1|Inv"]
     stacktrace:
       test/anchor/domain/placement_render_test.exs:76: (test)


  3) test proposals/3 dominated across buckets is not moved (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:278
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Calc, :f, 1},
                current: Calc,
                proposed: Mgr,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Mgr calls it"],
                key: "function_placement|function|Calc.f/1|Mgr"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:282: (test)


  4) test proposals/3 dominated across contexts is not moved (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:285
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: W,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only W calls it"],
                key: "function_placement|function|Inv.total/1|W"
              },
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:294: (test)


  5) test proposals/3 a function in its owner stays, though only another module of its bucket calls it (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:434
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :add, 0},
                current: Inv,
                proposed: W,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only W calls it"],
                key: "function_placement|function|Inv.add/0|W"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:444: (test)


  6) test proposals/3 a function a dynamic call can reach cannot go private (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:338
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: W,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only W calls it"],
                key: "function_placement|function|Inv.total/1|W"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:347: (test)


  7) test proposals/3 dominated by one module (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:264
     match (=) failed
     code:  assert [proposal] = proposals(modules, calls, :function_placement)
     left:  [proposal]
     right: [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: W,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only W calls it"],
                key: "function_placement|function|Inv.total/1|W"
              },
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     stacktrace:
       test/anchor/domain/placement_test.exs:273: (test)


  8) test proposals/3 a project behaviour's callback is not moved (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:350
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: W,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only W calls it"],
                key: "function_placement|function|Inv.total/1|W"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:360: (test)


  9) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1|AnchorFixtures.PlacementTest.Billing.Managers.Invoices",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Statement.total/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1|AnchorFixtures.PlacementTest.Billing.Web.Entry",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)


 10) test positive control: the compliant half alone gives no finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:270
     Assertion with == failed
     code:  assert report.findings == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1|AnchorFixtures.PlacementTest.Billing.Managers.Invoices",
                file: "lib/placement/adapters/store.ex",
                line: 3,
                message: "AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1 is in AnchorFixtures.PlacementTest.Billing.Adapters.Store (bucket adapters), but only AnchorFixtures.PlacementTest.Billing.Managers.Invoices calls it. Fix: move AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1 into AnchorFixtures.PlacementTest.Billing.Managers.Invoices as a private function (only AnchorFixtures.PlacementTest.Billing.Managers.Invoices calls it)"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1|AnchorFixtures.PlacementTest.Billing.Web.Entry",
                file: "lib/placement/managers/invoices.ex",
                line: 5,
                message: "AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1 is in AnchorFixtures.PlacementTest.Billing.Managers.Invoices (bucket managers), but only AnchorFixtures.PlacementTest.Billing.Web.Entry calls it. Fix: move AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1 into AnchorFixtures.PlacementTest.Billing.Web.Entry as a private function (only AnchorFixtures.PlacementTest.Billing.Web.Entry calls it)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:273: (test)


 11) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1|AnchorFixtures.PlacementTest.Billing.Managers.Invoices",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Statement.total/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1|AnchorFixtures.PlacementTest.Billing.Web.Entry",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)



 12) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  10
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)



 13) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Adapters.Store.load/1|AnchorFixtures.PlacementTest.Billing.Managers.Invoices",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Statement.total/1|AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Managers.Invoices.fetch/1|AnchorFixtures.PlacementTest.Billing.Web.Entry",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)
```

### PL-C — drop capture edges

Run summary: `136 tests, 7 failures`

```text
  1) test a captured function passes (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:39
     Assertion with == failed
     code:  assert check([@root, {M, "domain", [used: 1], []}], calls) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "M.used/1",
                message: "M.used/1 is public and no root reaches it. Fix: delete M.used/1 (no root reaches it), or add the root that should call it",
                filename: "lib/domain/M.ex",
                kind: :rule,
                key: "reach|function|M.used/1|delete",
                rule_id: "reach",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:41: (test)


  2) test build/1 a capture makes its target reachable (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:53
     Expected truthy, got false
     code: assert facts([@root, {M, "domain", [f: 1], []}], calls, {M, :f, 1}).reachable?
     stacktrace:
       test/anchor/domain/placement_test.exs:55: (test)


  3) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|delete",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)



  4) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  7
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)



  5) test the same function captured by a reachable one is reachable (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:152
     Expected truthy, got false
     code: assert Placement.facts(placement, {dead, :captured, 1}).reachable?
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:156: (test)


  6) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|delete",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)


  7) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.captured/1|delete",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)
```

### PL-D — lost precision passes silently

Run summary: `136 tests, 3 failures`

```text
  1) test lost precision fails closed, naming the site, with no finding (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:48
     match (=) failed
     code:  assert [issue] = check(modules, [{{W, :a, 0}, {:dynamic, nil, 2, :call}, :apply}])
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:51: (test)


  2) test spawn with a computed name loses reachability, naming its line (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:190
     match (=) failed
     code:  assert [issue] = Enum.filter(report.findings, &(&1.message =~ "reachability is imprecise"))
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:202: (test)


  3) test the precision is printed, and a computed name turns reachability into one issue (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:291
     match (=) failed
     code:  assert [issue] = Enum.filter(report.findings, &(&1.message =~ "reachability is imprecise"))
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:309: (test)
```

### PL-E — no roots passes silently

Run summary: `136 tests, 1 failure`

```text
  1) test no roots fails closed (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:59
     match (=) failed
     code:  assert [issue] = check([{M, "domain", [dead: 0], []}], [])
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:60: (test)
```

### PL-F — a variable application loses precision too

Run summary: `136 tests, 8 failures`

```text
  1) test build/1 a variable application is the closure form: it loses nothing (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:102
     Assertion with == failed
     code:  assert Placement.build(model).precision.reachability == :precise
     left:  :lost
     right: :precise
     stacktrace:
       test/anchor/domain/placement_test.exs:105: (test)


  2) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  [nil,
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)



  3) test every reason the canary emits renders one non-empty line, and all five are there (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:240
     Assertion with == failed
     code:  assert proposals |> Enum.map(& &1.reason) |> Enum.uniq() |> Enum.sort() == [
              :bucket_from_effects,
              :dominated_by,
              :input_type_owner,
              :output_type_owner,
              :unreachable
            ]
     left:  [:bucket_from_effects, :dominated_by, :input_type_owner,
             :output_type_owner]
     right: [:bucket_from_effects, :dominated_by, :input_type_owner,
             :output_type_owner, :unreachable]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:246: (test)


  4) test the precision is printed, and a computed name turns reachability into one issue (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:291
     Assertion with =~ failed
     code:  assert summary =~ "1 calls of a computed name, reachability lost at 1 call sites"
     left:  "anchor.graph: 14 modules in 1 apps, 3 rules, 7 violations (0 report-only, 0 baselined); apply sites: 8 resolved, 0 any; effects: 21 functions (domain 15, managers 1, adapters 2, framework 3), 1 unresolved dynamic calls; placement: 21 functions placed, 0 with no @spec (ownership unknown), 0 ambiguous owner, 0 with no clause to slice, 2 calls of a computed name, reachability lost at 2 call sites"
     right: "1 calls of a computed name, reachability lost at 1 call sites"
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:307: (test)


  5) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  5
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)



  6) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:286: (test)



  7) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  [nil,
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)



  8) test each finding carries the acceptance criteria's reason and target (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:129
     Assertion with == failed
     code:  assert reasons["Dead"] == {:unreachable, :delete}
     left:  nil
     right: {:unreachable, :delete}
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:148: (test)
```

### PL-G — a dynamic call adds no edge

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 a dynamic call reaches the implementations, and marks them named (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:60
     Expected truthy, got false
     code: assert facts.reachable?
     stacktrace:
       test/anchor/domain/placement_test.exs:65: (test)
```

### PL-H — a dynamic call does not mark its target named

Run summary: `136 tests, 2 failures`

```text
  1) test proposals/3 a function a dynamic call can reach cannot go private (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:338
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:347: (test)



  2) test build/1 a dynamic call reaches the implementations, and marks them named (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:60
     Expected truthy, got false
     code: assert facts.named?
     stacktrace:
       test/anchor/domain/placement_test.exs:66: (test)
```

### PL-I — macros are not roots

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 a macro counts as a root (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:69
     Expected truthy, got false
     code: assert facts(modules, [{{M, :m, 1}, {H, :help, 0}}], {H, :help, 0}).reachable?
     stacktrace:
       test/anchor/domain/placement_test.exs:76: (test)
```

### PL-J — interface modules are judged by rules 2 to 4

Run summary: `136 tests, 2 failures`

```text
  1) test selected modules of which no function can be judged: it checked nothing (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:68
     match (=) failed
     code:  assert [issue] = FunctionPlacement.check(model(modules, []), @rule)
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:71: (test)


  2) test proposals/3 an interface module's functions are exempt from rules 2 to 4 (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:404
     Assertion with == failed
     code:  assert proposals(modules, []) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Fmt, :line, 1},
                current: Fmt,
                proposed: Inv.Line,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "function_placement|function|Fmt.line/1|Inv.Line"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:411: (test)
```

### PL-K — a project behaviour's callback is judged

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 a project behaviour's callback is not moved (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:350
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:360: (test)
```

### PL-L — an owner in any bucket is taken

Run summary: `136 tests, 2 failures`

```text
  1) test proposals/3 an input owner in another bucket gives no proposal (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:253
     Assertion with == failed
     code:  assert proposals(modules, []) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Calc, :expired?, 1},
                current: Calc,
                proposed: Lease,
                rule: :function_placement,
                reason: :input_type_owner,
                evidence: ["its result is computed from %Lease{}"],
                key: "function_placement|function|Calc.expired?/1|Lease"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:261: (test)


  2) test proposals/3 an owner in another bucket gives no proposal (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:231
     Assertion with == failed
     code:  assert proposals(modules, []) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Fmt, :line, 1},
                current: Fmt,
                proposed: Inv.Line,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "function_placement|function|Fmt.line/1|Inv.Line"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:237: (test)
```

### PL-M — a function in its own owner still moves

Run summary: `136 tests, 8 failures`

```text
  1) test proposals/3 a function in its owner stays, though only another module of its bucket calls it (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:434
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv.Line, :new, 0},
                current: Inv.Line,
                proposed: Inv.Line,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "function_placement|function|Inv.Line.new/0|Inv.Line"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:444: (test)


  2) test proposals/3 a function already in its owner gives no proposal (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:425
     Assertion with == failed
     code:  assert proposals(modules, []) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: Inv,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv{}"],
                key: "function_placement|function|Inv.total/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:431: (test)


  3) test proposals/3 a long, well-placed function gets no proposal (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:472
     Assertion with == failed
     code:  assert proposals(modules, [{{W, :a, 0}, {Inv, :total, 1}}]) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv, :total, 1},
                current: Inv,
                proposed: Inv,
                rule: :function_placement,
                reason: :input_type_owner,
                evidence: ["its result is computed from %Inv{}"],
                key: "function_placement|function|Inv.total/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:483: (test)


  4) test positive control: the compliant half alone gives no finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:270
     Assertion with == failed
     code:  assert report.findings == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
                file: "lib/placement/domain/invoice/line.ex",
                line: 8,
                message: "AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1 is in AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line (bucket domain), but it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line{}. Fix: move AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1 to AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line (it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line{}; the owner of a type holds its transitions)"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
                file: "lib/placement/domain/invoice.ex",
                line: 10,
                message: "AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2 is in AnchorFixtures.PlacementTest.Billing.Domain.Invoice (bucket domain), but it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}. Fix: move AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2 to AnchorFixtures.PlacementTest.Billing.Domain.Invoice (it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}; the owner of a type holds its transitions)"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
                file: "lib/placement/domain/invoice.ex",
                line: 18,
                message: "AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1 is in AnchorFixtures.PlacementTest.Billing.Domain.Invoice (bucket domain), but its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}. Fix: move AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1 to AnchorFixtures.PlacementTest.Billing.Domain.Invoice (its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{})"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "function_placement",
                type: :function_placement,
                label: "rule 2 (id: \"function_placement\", function_placement)",
                enforcement: :enforce,
                key: "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
                file: "lib/placement/domain/invoice.ex",
                line: 14,
                message: "AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1 is in AnchorFixtures.PlacementTest.Billing.Domain.Invoice (bucket domain), but its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}. Fix: move AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1 to AnchorFixtures.PlacementTest.Billing.Domain.Invoice (its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{})"
              }
            ]
     right: []
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:273: (test)



  5) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


  6) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)


  7) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line.new/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.add/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.summary/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.total/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)



  8) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  10
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)
```

### PL-BD — a function in its own owner falls through to rule 4

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 a function in its owner stays, though only another module of its bucket calls it (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:434
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Inv.Line, :new, 0},
                current: Inv.Line,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Inv.Line.new/0|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:444: (test)
```

### PL-BE — rule 4 never fires

Run summary: `136 tests, 9 failures`

```text
  1) test the key has no line number and is stable when lines shift (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:59
     Assertion with == failed
     code:  assert build.(10) == ["function_placement|function|Round.r/1|Inv"]
     left:  []
     right: ["function_placement|function|Round.r/1|Inv"]
     stacktrace:
       test/anchor/domain/placement_render_test.exs:76: (test)


  2) test one violation per proposal, with the def's file and line (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:38
     Assertion with == failed
     code:  assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     left:  [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11}
            ]
     right: [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:39: (test)


  3) test proposals/3 dominated by one module (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:264
     match (=) failed
     code:  assert [proposal] = proposals(modules, calls, :function_placement)
     left:  [proposal]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:273: (test)


  4) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)



  5) test every reason the canary emits renders one non-empty line, and all five are there (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:240
     Assertion with == failed
     code:  assert proposals |> Enum.map(& &1.reason) |> Enum.uniq() |> Enum.sort() == [
              :bucket_from_effects,
              :dominated_by,
              :input_type_owner,
              :output_type_owner,
              :unreachable
            ]
     left:  [:bucket_from_effects, :input_type_owner, :output_type_owner,
             :unreachable]
     right: [:bucket_from_effects, :dominated_by, :input_type_owner,
             :output_type_owner, :unreachable]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:246: (test)


  6) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)


  7) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


  8) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  5
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)


  9) test each finding carries the acceptance criteria's reason and target (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:129
     Assertion with == failed
     code:  assert reasons["Rounding"] == {:dominated_by, AnchorFixtures.PlacementTest.Billing.Domain.Statement}
     left:  nil
     right: {:dominated_by,
             AnchorFixtures.PlacementTest.Billing.Domain.Statement}
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:145: (test)
```

### PL-BF — reachable_from_root proposes under lost precision

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 unreachable lists none under lost precision (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:495
     Assertion with == failed
     code:  assert proposals(modules, calls, :reachable_from_root) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {M, :dead, 0},
                current: M,
                proposed: :delete,
                rule: :reachable_from_root,
                reason: :unreachable,
                evidence: [],
                key: "reachable_from_root|function|M.dead/0|delete"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:499: (test)
```

### PL-BG — rule 4 takes the virtual root's callers as its dominator

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 a shared function gets no move from rule 4 (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:375
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement, roots: [%{"pattern" => "Dm"}]) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {K, :c, 0},
                current: K,
                proposed: Dm,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Dm calls it"],
                key: "function_placement|function|K.c/0|Dm"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:381: (test)
```

### PL-BH — a shared function still moves by rules 2 and 3

Run summary: `136 tests, 2 failures`

```text
  1) test proposals/3 rule 1 of a shared pure function names its bucket, not an owner (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:384
     match (=) failed
     code:  assert [%{reason: :bucket_from_effects}] = proposals(modules, calls)
     left:  [%{reason: :bucket_from_effects}]
     right: [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Mgr, :line, 0},
                current: {:bucket, :managers, "ctx", Mgr},
                proposed: Inv.Line,
                rule: :effects_match_bucket,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "effects_match_bucket|Mgr.line/0|domain"
              }
            ]
     stacktrace:
       test/anchor/domain/placement_test.exs:389: (test)



  2) test proposals/3 a shared function gets no move from rules 2 or 3 (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:363
     Assertion with == failed
     code:  assert proposals(modules, shared, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Fmt, :line, 0},
                current: Fmt,
                proposed: Inv.Line,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "function_placement|function|Fmt.line/0|Inv.Line"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:368: (test)
```

### PL-BI — a macro alone counts as a root for no_roots

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 a macro alone is no root the inference found: still no roots (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:113
     Assertion with == failed
     code:  assert Placement.build(model(modules, [])).precision.reachability == :no_roots
     left:  :precise
     right: :no_roots
     stacktrace:
       test/anchor/domain/placement_test.exs:116: (test)
```

### PL-BJ — rule 4 moves into an interface

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 a move into an interface module is not proposed (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:392
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Impl, :g, 0},
                current: Impl,
                proposed: Foo,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Foo calls it"],
                key: "function_placement|function|Impl.g/0|Foo"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:401: (test)
```

### PL-BK — a spawn with a computed name loses nothing

Run summary: `137 tests, 1 failure`

```text
  1) test spawn with a computed name loses reachability, naming its line (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:190
     Assertion with == failed
     code:  assert placement.precision.reachability == :lost
     left:  :precise
     right: :lost
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:201: (test)
```

### PL-BL — a known name with unknown arguments is no edge

Run summary: `137 tests, 1 failure`

```text
  1) test a known name with arguments of unknown length reaches every arity, and stays public (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:206
     {AnchorFixtures.PlacementTest.Billing.Domain.Partial, :loop, 1}
     code: for mfa <- [{partial, :loop, 1}, {partial, :loop, 2}, {partial, :other_loop, 1}] do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/integration/placement_invariant_test.exs:234: (test)
```

### PL-BM — partial_mfa_calls reads the triple from the wrong place

Run summary: `41 tests, 1 failure`

```text
  1) test partial_mfa_calls/1 literal_args_var/1 reads as {M, :f} (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:136
     match (=) failed
     The following variables were pinned:
       module = M
       name = :f
     code:  assert [%{module: ^module, name: ^name, line: line}] =
              binary |> core({:literal_args_var, 1}) |> Core.partial_mfa_calls()
     left:  [%{module: ^module, name: ^name, line: line}]
     right: []
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:139: (test)
```

### PL-BN — partial_mfa_calls keeps a whole triple

Run summary: `41 tests, 1 failure`

```text
  1) test partial_mfa_calls/1 a whole triple is mfa_references/1's, and nothing else is read (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:146
     Assertion with == failed
     code:  assert binary |> core({:whole, 1}) |> Core.partial_mfa_calls() == []
     left:  [%{line: 7, module: M, name: :f}]
     right: []
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:147: (test)
```

### PL-N — rule 1 ignores a known owner

Run summary: `136 tests, 2 failures`

```text
  1) test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:202
     Assertion with == failed
     code:  assert proposal.reason == :input_type_owner
     left:  :bucket_from_effects
     right: :input_type_owner
     stacktrace:
       test/anchor/domain/placement_test.exs:211: (test)


  2) test each finding carries the acceptance criteria's reason and target (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:129
     Assertion with == failed
     code:  assert reasons["Calc"] == {:input_type_owner, invoice}
     left:  {:bucket_from_effects,
             {:bucket, :domain,
              "AnchorFixtures.PlacementTest.Billing", nil}}
     right: {:input_type_owner,
             AnchorFixtures.PlacementTest.Billing.Domain.Invoice}
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:141: (test)
```

### PL-O — rule 4 ignores other callers

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 dominated but called from two modules is not moved (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:297
     Assertion with == failed
     code:  assert Enum.filter(
              proposals(modules, calls, :function_placement),
              &(&1.subject == {Round, :r, 1})
            ) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:312: (test)
```

### PL-P — rule 4 moves a named function

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 a function a dynamic call can reach cannot go private (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:338
     Assertion with == failed
     code:  assert proposals(modules, calls, :function_placement) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Round, :r, 1},
                current: Round,
                proposed: Inv,
                rule: :function_placement,
                reason: :dominated_by,
                evidence: ["only Inv calls it"],
                key: "function_placement|function|Round.r/1|Inv"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:347: (test)
```

### PL-Q — a private function can be unreachable

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 unreachable: a public function, with delete; a private one is not judged (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:486
     match (=) failed
     code:  assert [proposal] = proposals(modules, [], :reachable_from_root)
     left:  [proposal]
     right: [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {M, :dead, 0},
                current: M,
                proposed: :delete,
                rule: :reachable_from_root,
                reason: :unreachable,
                evidence: [],
                key: "reachable_from_root|function|M.dead/0|delete"
              },
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {M, :hid, 0},
                current: M,
                proposed: :delete,
                rule: :reachable_from_root,
                reason: :unreachable,
                evidence: [],
                key: "reachable_from_root|function|M.hid/0|delete"
              }
            ]
     stacktrace:
       test/anchor/domain/placement_test.exs:489: (test)
```

### PL-R — generated functions are judged

Run summary: `136 tests, 2 failures`

```text
  1) test generated functions are not reported (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:44
     Assertion with == failed
     code:  assert check([@root, {M, "domain", [dead: 0], generated: true}], []) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "M.dead/0",
                message: "M.dead/0 is public and no root reaches it. Fix: delete M.dead/0 (no root reaches it), or add the root that should call it",
                filename: "lib/domain/M.ex",
                kind: :rule,
                key: "reach|function|M.dead/0|delete",
                rule_id: "reach",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:45: (test)


  2) test proposals/3 generated functions, roots and compiler names are not judged by rules 2 to 4 (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:455
     Assertion with == failed
     code:  assert proposals([@line_struct, {Fmt, "domain", [line: 1], specs: spec, generated: true}], []) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {Fmt, :line, 1},
                current: Fmt,
                proposed: Inv.Line,
                rule: :function_placement,
                reason: :output_type_owner,
                evidence: ["it returns %Inv.Line{}"],
                key: "function_placement|function|Fmt.line/1|Inv.Line"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:458: (test)
```

### PL-S — child_spec/1 is judged

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 child_spec/1 and compiler names are not unreachable (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:502
     Assertion with == failed
     code:  assert proposals(modules, [], :reachable_from_root) == []
     left:  [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {M, :child_spec, 1},
                current: M,
                proposed: :delete,
                rule: :reachable_from_root,
                reason: :unreachable,
                evidence: [],
                key: "reachable_from_root|function|M.child_spec/1|delete"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:509: (test)
```

### PL-T — rule 1's named target takes the first of several

Run summary: `136 tests, 1 failure`

```text
  1) test proposals/3 rule 1 names no module when two have the subject's tail name, or none has (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:189
     match (=) failed
     code:  assert [%{proposed: {:bucket, :domain, "ctx", nil}}] = proposals(two, [])
     left:  [%{proposed: {:bucket, :domain, "ctx", nil}}]
     right: [
              %Anchor.Domain.Proposal{
                level: :function,
                subject: {App.Managers.Inv, :f, 0},
                current: {:bucket, :managers, "ctx",
                 App.Managers.Inv},
                proposed: {:bucket, :domain, "ctx", App.Domain.Inv},
                rule: :effects_match_bucket,
                reason: :bucket_from_effects,
                evidence: ["no effect is reachable"],
                key: "effects_match_bucket|App.Managers.Inv.f/0|domain"
              }
            ]
     stacktrace:
       test/anchor/domain/placement_test.exs:196: (test)
```

### PL-U — the violation's Fix is not the render

Run summary: `136 tests, 8 failures`

```text
  1) test each message ends with Fix: and exactly render(proposal) (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:46
     Expected truthy, got false
     code: assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
     arguments:

         # 1
         "Calc.expired?/1 is in Calc (bucket domain), but its result is computed from %Lease{}. Fix: see move Calc.expired?/1 to Lease (its result is computed from %Lease{})"

         # 2
         "Fix: move Calc.expired?/1 to Lease (its result is computed from %Lease{})"

     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:55: anonymous fn/2 in Anchor.Domain.GraphRules.FunctionPlacementTest."test each message ends with Fix: and exactly render(proposal)"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/function_placement_test.exs:54: (test)



  2) test an uncalled public function is one violation, and its Fix is the rendered proposal (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:17
     Expected truthy, got false
     code: assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
     arguments:

         # 1
         "M.dead/0 is public and no root reaches it. Fix: see delete M.dead/0 (no root reaches it), or add the root that should call it"

         # 2
         "Fix: delete M.dead/0 (no root reaches it), or add the root that should call it"

     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:26: (test)


  3) test a manager with a direct effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:60
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move M.run/1 to the adapters bucket: M.run/1 -> App.Repo"
     left:  "M.run/1 is in bucket managers (managers) but calls an effect itself. Fix: see move M.run/1 to the adapters bucket: M.run/1 -> App.Repo.insert/1"
     right: "Fix: move M.run/1 to the adapters bucket: M.run/1 -> App.Repo"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:68: (test)


  4) test the Fix is Placement.render/1 of its proposal, and the key is the landed one (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:165
     Expected truthy, got false
     code: assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
     arguments:

         # 1
         "D.f/1 is in bucket domain (domain) but reaches an effect. Fix: see move D.f/1 to the adapters bucket: D.f/1 -> File.read/1"

         # 2
         "Fix: move D.f/1 to the adapters bucket: D.f/1 -> File.read/1"

     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:174: (test)



  5) test an adapter that reaches effects only through another module names it (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:82
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move A.run/1 to the managers bucket: A.run/1 -> A2.save/1"
     left:  "A.run/1 is in bucket adapters (adapters) but reaches effects only through A2.save/1. Fix: see move A.run/1 to the managers bucket: A.run/1 -> A2.save/1 -> File.write/2"
     right: "Fix: move A.run/1 to the managers bucket: A.run/1 -> A2.save/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:90: (test)


  6) test an adapter function with no effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:71
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move A.to_map/1 to the domain bucket: no effect is reachable"
     left:  "A.to_map/1 is in bucket adapters but reaches no effect. Fix: see move A.to_map/1 to the domain bucket: no effect is reachable"
     right: "Fix: move A.to_map/1 to the domain bucket: no effect is reachable"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:76: (test)


  7) test a domain function that reaches an effect is one issue naming the chain (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:36
     Assertion with =~ failed
     code:  assert one.message =~ "Fix: move D.f/1 to the managers bucket: D.f/1 -> D2.g/1"
     left:  "D.f/1 is in bucket domain (domain) but reaches an effect. Fix: see move D.f/1 to the managers bucket: D.f/1 -> D2.g/1 -> App.Repo.insert/1"
     right: "Fix: move D.f/1 to the managers bucket: D.f/1 -> D2.g/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:51: (test)


  8) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert fix == Placement.render(proposal)
     left:  "see move AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1 to the adapters bucket of AnchorFixtures.PlacementTest.Billing: AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1 -> File.read/1"
     right: "move AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1 to the adapters bucket of AnchorFixtures.PlacementTest.Billing: AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1 -> File.read/1"
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:124: anonymous fn/2 in Anchor.Integration.PlacementInvariantTest."test every placement violation's Fix equals the render of the proposal with its key"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/integration/placement_invariant_test.exs:121: (test)
```

### PL-V — the violation's key keeps the type, not the rule's name

Run summary: `136 tests, 5 failures`

```text
  1) test each message ends with Fix: and exactly render(proposal) (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:46
     Assertion with == failed
     code:  assert violation.key ==
              "placed|function|" <> (proposal.key |> String.split("|", parts: 3) |> List.last())
     left:  "function_placement|function|Calc.expired?/1|Lease"
     right: "placed|function|Calc.expired?/1|Lease"
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:57: anonymous fn/2 in Anchor.Domain.GraphRules.FunctionPlacementTest."test each message ends with Fix: and exactly render(proposal)"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/function_placement_test.exs:54: (test)


  2) test an uncalled public function is one violation, and its Fix is the rendered proposal (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:17
     Assertion with == failed
     code:  assert violation.key == "reach|function|M.dead/0|delete"
     left:  "reachable_from_root|function|M.dead/0|delete"
     right: "reach|function|M.dead/0|delete"
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:27: (test)


  3) test a domain function that reaches an effect is one issue naming the chain (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:36
     Assertion with == failed
     code:  assert one.key == "effects|D.f/1|managers"
     left:  "effects_match_bucket|D.f/1|managers"
     right: "effects|D.f/1|managers"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:52: (test)


  4) test an adapter function with no effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:71
     Assertion with == failed
     code:  assert violation.key == "effects|A.to_map/1|domain"
     left:  "effects_match_bucket|A.to_map/1|domain"
     right: "effects|A.to_map/1|domain"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:79: (test)


  5) test the Fix is Placement.render/1 of its proposal, and the key is the landed one (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:165
     Assertion with == failed
     code:  assert violation.key == "effects|D.f/1|adapters"
     left:  "effects_match_bucket|D.f/1|adapters"
     right: "effects|D.f/1|adapters"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:175: (test)
```

### PL-W — the key carries what moves (callers, evidence)

Run summary: `136 tests, 6 failures`

```text
  1) test the key has no line number and is stable when lines shift (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:59
     Assertion with == failed
     code:  assert build.(10) == ["function_placement|function|Round.r/1|Inv"]
     left:  ["function_placement|function|Round.r/1|Inv|{Inv, :total, 1}10[\"only Inv calls it\"]"]
     right: ["function_placement|function|Round.r/1|Inv"]
     stacktrace:
       test/anchor/domain/placement_render_test.exs:76: (test)


  2) test an uncalled public function is one violation, and its Fix is the rendered proposal (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:17
     Assertion with == failed
     code:  assert violation.key == "reach|function|M.dead/0|delete"
     left:  "reach|function|M.dead/0|delete|nil00[]"
     right: "reach|function|M.dead/0|delete"
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:27: (test)


  3) test proposals/3 output owner in a Domain bucket (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:217
     Assertion with == failed
     code:  assert proposal.key == "function_placement|function|Fmt.line/1|Inv.Line"
     left:  "function_placement|function|Fmt.line/1|Inv.Line|nil00[\"it returns %Inv.Line{}\"]"
     right: "function_placement|function|Fmt.line/1|Inv.Line"
     stacktrace:
       test/anchor/domain/placement_test.exs:228: (test)


  4) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement|{AnchorFixtures.PlacementTest.Billing.Domain.Statement, :total, 1}10[\"only AnchorFixtures.PlacementTest.Billing.Domain.Statement calls it\"]",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete|nil00[]"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


  5) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement|{AnchorFixtures.PlacementTest.Billing.Domain.Statement, :total, 1}10[\"only AnchorFixtures.PlacementTest.Billing.Domain.Statement calls it\"]",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete|nil00[]"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)



  6) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"it returns %AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice|{AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry, :show, 3}10[\"its result is computed from %AnchorFixtures.PlacementTest.Billing.Domain.Invoice{}\"]",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement|{AnchorFixtures.PlacementTest.Billing.Domain.Statement, :total, 1}10[\"only AnchorFixtures.PlacementTest.Billing.Domain.Statement calls it\"]",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete|nil00[]"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)
```

### PL-X — the effects key takes the design's form, breaking the landed baselines

Run summary: `136 tests, 7 failures`

```text
  1) test a domain function that reaches an effect is one issue naming the chain (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:36
     Assertion with == failed
     code:  assert one.key == "effects|D.f/1|managers"
     left:  "effects|function|D.f/1|managers"
     right: "effects|D.f/1|managers"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:52: (test)


  2) test an adapter function with no effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:71
     Assertion with == failed
     code:  assert violation.key == "effects|A.to_map/1|domain"
     left:  "effects|function|A.to_map/1|domain"
     right: "effects|A.to_map/1|domain"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:79: (test)



  3) test the Fix is Placement.render/1 of its proposal, and the key is the landed one (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:165
     Assertion with == failed
     code:  assert violation.key == "effects|D.f/1|adapters"
     left:  "effects|function|D.f/1|adapters"
     right: "effects|D.f/1|adapters"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:175: (test)


  4) test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:202
     Assertion with == failed
     code:  assert proposal.key == "effects_match_bucket|Mgr.total/1|domain"
     left:  "effects_match_bucket|function|Mgr.total/1|domain"
     right: "effects_match_bucket|Mgr.total/1|domain"
     stacktrace:
       test/anchor/domain/placement_test.exs:214: (test)


  5) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


  6) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)



  7) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|function|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)
```

### PL-Y — a guard's read is off the slice

Run summary: `136 tests, 1 failure`

```text
  1) test input_owner/3 a parameter only a guard reads decides the result: it is on the slice (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:102
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, integer()) :: integer()", ["def f(l, n) when l.x > 0, do: n"]) ==
              {:ok, Inv}
     left:  :none
     right: {:ok, Inv}
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:103: (test)
```

### PL-Z — on the slice in any clause is enough

Run summary: `136 tests, 1 failure`

```text
  1) test input_owner/3 on the slice in one clause only is not on the slice (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:114
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, integer()) :: integer()", [
              "def f(%Inv{} = l, 0), do: l.x",
              "def f(%Inv{}, n), do: n"
            ]) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:115: (test)
```

### PL-AA — every struct parameter is on the slice

Run summary: `136 tests, 3 failures`

```text
  1) test input_owner/3 on the slice in one clause only is not on the slice (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:114
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, integer()) :: integer()", [
              "def f(%Inv{} = l, 0), do: l.x",
              "def f(%Inv{}, n), do: n"
            ]) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:115: (test)


  2) test input_owner/3 a struct parameter bound and not used is not on the slice (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:90
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, integer()) :: integer()", [
              "def f(%Inv{} = l, n) do\n  _ = n\n  m = l\n  _ = m\n  n * 2\nend"
            ]) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:91: (test)



  3) test input_owner/3 a struct parameter matched and not used is not on the slice (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:85
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, integer()) :: integer()", ["def f(%Inv{}, n), do: n * 2"]) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:86: (test)
```

### PL-AB — two structs are one owner

Run summary: `136 tests, 4 failures`

```text
  1) test output_owner/2 two different structs are ambiguous (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:51
     Assertion with == failed
     code:  assert Ownership.output_owner(graph, {F, :f, 1}) == :ambiguous
     left:  {:ok, Inv}
     right: :ambiguous
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:54: (test)


  2) test input_owner/3 two struct parameters on the slice are ambiguous (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:108
     Assertion with == failed
     code:  assert input_owner("f(%Inv{}, %Pay{}) :: boolean()", ["def f(%Inv{} = a, %Pay{} = b), do: a.x > b.y"]) ==
              :ambiguous
     left:  {:ok, Inv}
     right: :ambiguous
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:109: (test)



  3) test output_owner/2 a struct beside a non-error member has no owner (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:61
     Assertion with == failed
     code:  assert Ownership.output_owner(graph("f(term()) :: %Inv{} | integer()"), {F, :f, 1}) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:62: (test)


  4) test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:145
     Assertion with == failed
     code:  assert precision.ambiguous_owner == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement_test.exs:158: (test)
```

### PL-BA — an ambiguous output is not counted

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:145
     Assertion with == failed
     code:  assert precision.ambiguous_owner == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement_test.exs:158: (test)
```

### PL-BB — a function with no clause is not counted

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:145
     Assertion with == failed
     code:  assert precision.unjoined == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement_test.exs:159: (test)
```

### PL-AC — a struct beside a non-error member is owned

Run summary: `136 tests, 1 failure`

```text
  1) test output_owner/2 a struct beside a non-error member has no owner (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:61
     Assertion with == failed
     code:  assert Ownership.output_owner(graph("f(term()) :: %Inv{} | integer()"), {F, :f, 1}) == :none
     left:  {:ok, Inv}
     right: :none
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:62: (test)
```

### PL-AD — an {:ok, S} return names no struct

Run summary: `136 tests, 1 failure`

```text
  1) test output_owner/2 an ok tuple as a beam writes it, a tuple node, is the struct's module (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:42
     Assertion with == failed
     code:  assert Ownership.output_owner(graph, {F, :f, 1}) == {:ok, Inv}
     left:  :none
     right: {:ok, Inv}
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:48: (test)
```

### PL-AE — an error member counts

Run summary: `136 tests, 1 failure`

```text
  1) test output_owner/2 an ok tuple with an error member is the struct's module (Anchor.Domain.Placement.OwnershipTest)
     test/anchor/domain/placement/ownership_test.exs:33
     Assertion with == failed
     code:  assert Ownership.output_owner(graph, {F, :f, 1}) == expected
     left:  :none
     right: {:ok, Inv}
     stacktrace:
       test/anchor/domain/placement/ownership_test.exs:38: (test)
```

### PL-AF — the input owner is never asked

Run summary: `136 tests, 10 failures`

```text
  1) test one violation per proposal, with the def's file and line (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:38
     Assertion with == failed
     code:  assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     left:  [
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     right: [
              {"Calc.expired?/1", "lib/domain/Calc.ex", 11},
              {"Fmt.line/1", "lib/domain/Fmt.ex", 11},
              {"Round.r/1", "lib/domain/Round.ex", 11}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:39: (test)


  2) test proposals/3 input owner, from a clause's slice (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:240
     match (=) failed
     code:  assert [proposal] = proposals(modules, [])
     left:  [proposal]
     right: []
     stacktrace:
       test/anchor/domain/placement_test.exs:248: (test)


  3) test build/1 precision of ownership two structs are ambiguous, and a primitive with no clause is unjoined: both counted (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:145
     Assertion with == failed
     code:  assert precision.unjoined == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement_test.exs:159: (test)


  4) test proposals/3 rule 1: a pure function in a Manager whose input owner is known goes there (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:202
     Assertion with == failed
     code:  assert proposal.reason == :input_type_owner
     left:  :bucket_from_effects
     right: :input_type_owner
     stacktrace:
       test/anchor/domain/placement_test.exs:211: (test)


  5) test every placement violation's Fix equals the render of the proposal with its key (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:113
     Assertion with == failed
     code:  assert map_size(proposals) == length(@expected)
     left:  5
     right: 6
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:119: (test)


  6) test each finding carries the acceptance criteria's reason and target (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:129
     Assertion with == failed
     code:  assert reasons["Calc"] == {:input_type_owner, invoice}
     left:  {:bucket_from_effects,
             {:bucket, :domain,
              "AnchorFixtures.PlacementTest.Billing", nil}}
     right: {:input_type_owner,
             AnchorFixtures.PlacementTest.Billing.Domain.Invoice}
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:141: (test)


  7) test no key carries a line number: every module shifted five lines gives the same keys (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:263
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:266: (test)



  8) test every reason the canary emits renders one non-empty line, and all five are there (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:240
     Assertion with == failed
     code:  assert proposals |> Enum.map(& &1.reason) |> Enum.uniq() |> Enum.sort() == [
              :bucket_from_effects,
              :dominated_by,
              :input_type_owner,
              :output_type_owner,
              :unreachable
            ]
     left:  [:bucket_from_effects, :dominated_by, :output_type_owner,
             :unreachable]
     right: [:bucket_from_effects, :dominated_by, :input_type_owner,
             :output_type_owner, :unreachable]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:246: (test)



  9) test the canary yields exactly its listed findings (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:105
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:109: (test)


 10) test report mode never fails, and still prints each finding (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:277
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
     left:  ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     right: ["effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Domain.Leaky.read/1|adapters",
             "effects_match_bucket|AnchorFixtures.PlacementTest.Billing.Managers.Calc.total/1|domain",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Format.invoice_line/1|AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Lease.expired?/2|AnchorFixtures.PlacementTest.Billing.Domain.Invoice",
             "function_placement|function|AnchorFixtures.PlacementTest.Billing.Domain.Rounding.round_cents/1|AnchorFixtures.PlacementTest.Billing.Domain.Statement",
             "reachable_from_root|function|AnchorFixtures.PlacementTest.Billing.Domain.Dead.unused/0|delete"]
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:287: (test)
```

### PL-AG — no spec is not counted

Run summary: `136 tests, 2 failures`

```text
  1) test a rule that needs it: built once, and its precision is in the summary and the JSON (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:136
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; placement: 1 functions placed, 1 with no @spec (ownership unknown), " <>
                "0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, " <>
                "reachability no roots"
     left:  "anchor.graph: 1 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 0 any; effects: 1 functions (domain 1, managers 0, adapters 0, framework 0), 0 unresolved dynamic calls; placement: 1 functions placed, 0 with no @spec (ownership unknown), 0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, reachability no roots"
     right: "; placement: 1 functions placed, 1 with no @spec (ownership unknown), 0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, reachability no roots"
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:155: (test)


  2) test build/1 precision counts the public functions whose ownership is unknown (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:132
     Assertion with == failed
     code:  assert precision.no_spec == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/placement_test.exs:140: (test)
```

### PL-AH — the shared flag names every function a root reaches directly

Run summary: `136 tests, 1 failure`

```text
  1) test build/1 a root is not shared (Anchor.Domain.PlacementTest)
     test/anchor/domain/placement_test.exs:45
     Expected false or nil, got true
     code: refute facts.shared?
     stacktrace:
       test/anchor/domain/placement_test.exs:50: (test)
```

### PL-AI — the manager builds the model for every run

Run summary: `6 tests, 1 failure`

```text
  1) test a rule that needs the inference only: no model is built (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:119
     Unexpectedly received message :built (which matched :built)
     code: refute_received :built
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:131: (test)
```

### PL-AJ — a crashed model is ignored

Run summary: `6 tests, 2 failures`

```text
  1) test a model that is no %Placement{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:169
     match (=) failed
     code:  assert [issue, probe] = report.findings
     left:  [issue, probe]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "probe",
                type: :stub_cfa_probe,
                label: "rule 2 (id: \"probe\", stub_cfa_probe)",
                enforcement: :enforce,
                key: "probe",
                file: "lib/my_app/domain/reader.ex",
                line: 1,
                message: "probe saw cfa: 0 sites. Fix: none, a probe."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:176: (test)


  2) test a model that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:169
     match (=) failed
     code:  assert [issue, probe] = report.findings
     left:  [issue, probe]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "probe",
                type: :stub_cfa_probe,
                label: "rule 2 (id: \"probe\", stub_cfa_probe)",
                enforcement: :enforce,
                key: "probe",
                file: "lib/my_app/domain/reader.ex",
                line: 1,
                message: "probe saw cfa: 0 sites. Fix: none, a probe."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:176: (test)
```

### PL-AK — the model is built with no inference

Run summary: `6 tests, 1 failure`

```text
  1) test an inference that crashed: no model is built, and the rule reports the inference (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:185
     Unexpectedly received message :built (which matched :built)
     code: refute_received :built
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:200: (test)
```

### PL-AL — the report leaves out the placement counts

Run summary: `18 tests, 2 failures`

```text
  1) test a rule that needs it: built once, and its precision is in the summary and the JSON (Anchor.Managers.GraphPlacementTest)
     test/anchor/managers/graph_placement_test.exs:136
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; placement: 1 functions placed, 1 with no @spec (ownership unknown), " <>
                "0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, " <>
                "reachability no roots"
     left:  "anchor.graph: 1 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 0 any; effects: 1 functions (domain 1, managers 0, adapters 0, framework 0), 0 unresolved dynamic calls"
     right: "; placement: 1 functions placed, 1 with no @spec (ownership unknown), 0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, reachability no roots"
     stacktrace:
       test/anchor/managers/graph_placement_test.exs:155: (test)


  2) test the precision is printed, and a computed name turns reachability into one issue (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:291
     Assertion with =~ failed
     code:  assert summary =~ "; placement: "
     left:  "anchor.graph: 14 modules in 1 apps, 3 rules, 7 violations (0 report-only, 0 baselined); apply sites: 8 resolved, 0 any; effects: 21 functions (domain 15, managers 1, adapters 2, framework 3), 1 unresolved dynamic calls"
     right: "; placement: "
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:306: (test)
```

### PL-AM — the effects rule drops the selector

Run summary: `17 tests, 2 failures`

```text
  1) test a selected function's proposal only: the selector limits it (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:178
     match (=) failed
     code:  assert [%{trigger: "D.f/1"}] = check(modules, calls, [], rule)
     left:  [%{trigger: "D.f/1"}]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 is in bucket domain (domain) but reaches an effect. Fix: move D.f/1 to the adapters bucket: D.f/1 -> File.read/1",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "effects|D.f/1|adapters",
                rule_id: "effects",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D2.g/1",
                message: "D2.g/1 is in bucket domain (domain) but reaches an effect. Fix: move D2.g/1 to the adapters bucket: D2.g/1 -> File.read/1",
                filename: "lib/domain/D2.ex",
                kind: :rule,
                key: "effects|D2.g/1|adapters",
                rule_id: "effects",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:183: (test)


  2) test the selector narrows the modules judged (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:138
     Assertion with == failed
     code:  assert check(modules, [], [], rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "M.run/1",
                message: "M.run/1 is in bucket managers but reaches no effect. Fix: move M.run/1 to the domain bucket: no effect is reachable",
                filename: "lib/managers/M.ex",
                kind: :rule,
                key: "effects_match_bucket|M.run/1|domain",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:142: (test)
```

### PL-AN — function_placement drops the selector

Run summary: `5 tests, 1 failure`

```text
  1) test the selector limits the subjects (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:62
     match (=) failed
     code:  assert [%{trigger: "Fmt.line/1"}] = FunctionPlacement.check(model(@modules, @calls), rule)
     left:  [%{trigger: "Fmt.line/1"}]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "Calc.expired?/1",
                message: "Calc.expired?/1 is in Calc (bucket domain), but its result is computed from %Lease{}. Fix: move Calc.expired?/1 to Lease (its result is computed from %Lease{})",
                filename: "lib/domain/Calc.ex",
                kind: :rule,
                key: "placed|function|Calc.expired?/1|Lease",
                rule_id: "placed",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "Fmt.line/1",
                message: "Fmt.line/1 is in Fmt (bucket domain), but it returns %Inv.Line{}. Fix: move Fmt.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its transitions)",
                filename: "lib/domain/Fmt.ex",
                kind: :rule,
                key: "placed|function|Fmt.line/1|Inv.Line",
                rule_id: "placed",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "Round.r/1",
                message: "Round.r/1 is in Round (bucket domain), but only Inv calls it. Fix: move Round.r/1 into Inv as a private function (only Inv calls it)",
                filename: "lib/domain/Round.ex",
                kind: :rule,
                key: "placed|function|Round.r/1|Inv",
                rule_id: "placed",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:65: (test)
```

### PL-AO — reachable_from_root drops the selector

Run summary: `9 tests, 1 failure`

```text
  1) test the selector limits the subjects (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:75
     match (=) failed
     code:  assert [%{trigger: "M.dead/0"}] = ReachableFromRoot.check(model, rule)
     left:  [%{trigger: "M.dead/0"}]
     right: [
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "M.dead/0",
                message: "M.dead/0 is public and no root reaches it. Fix: delete M.dead/0 (no root reaches it), or add the root that should call it",
                filename: "lib/domain/M.ex",
                kind: :rule,
                key: "reach|function|M.dead/0|delete",
                rule_id: "reach",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 10,
                trigger: "N.dead/0",
                message: "N.dead/0 is public and no root reaches it. Fix: delete N.dead/0 (no root reaches it), or add the root that should call it",
                filename: "lib/domain/N.ex",
                kind: :rule,
                key: "reach|function|N.dead/0|delete",
                rule_id: "reach",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:79: (test)
```

### PL-AP — function_placement has no floor

Run summary: `5 tests, 1 failure`

```text
  1) test selected modules of which no function can be judged: it checked nothing (Anchor.Domain.GraphRules.FunctionPlacementTest)
     test/anchor/domain/graph_rules/function_placement_test.exs:68
     match (=) failed
     code:  assert [issue] = FunctionPlacement.check(model(modules, []), @rule)
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/function_placement_test.exs:71: (test)
```

### PL-AQ — reachable_from_root has no floor

Run summary: `9 tests, 1 failure`

```text
  1) test selected modules with no authored public function: it checked nothing (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:66
     match (=) failed
     code:  assert [issue] = ReachableFromRoot.check(model, rule)
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:70: (test)
```

### PL-AR — result_nodes gives the final expression only

Run summary: `109 tests, 2 failures`

```text
  1) test result_nodes/1 the final expression, and each value block's final expression (Anchor.Domain.DataFlowTest)
     test/anchor/domain/data_flow_test.exs:57
     Assertion with == failed
     code:  assert DataFlow.result_nodes(flow) ==
              Enum.sort([flow.result | Map.keys(flow.nodes) -- [flow.result, hd(flow.blocks[[]])]])
     left:  [[1]]
     right: [[1], [1, :clause, 0, 0], [1, :clause, 1, 0]]
     stacktrace:
       test/anchor/domain/data_flow_test.exs:60: (test)


  2) test result_nodes/1 an empty body has none (Anchor.Domain.DataFlowTest)
     test/anchor/domain/data_flow_test.exs:66
     Assertion with == failed
     code:  assert DataFlow.result_nodes(DataFlow.analyze({[], [], {:__block__, [], []}})) == []
     left:  [nil]
     right: []
     stacktrace:
       test/anchor/domain/data_flow_test.exs:67: (test)
```

### PL-AS — struct_of always answers nil

Run summary: `10 tests, 1 failure`

```text
  1) test struct_of/3 a project struct, through a named type, or nil (Anchor.Domain.StructTypesTest)
     test/anchor/domain/struct_types_test.exs:90
     Assertion with == failed
     code:  assert StructTypes.struct_of(type, @game, graph) == @turn
     left:  nil
     right: AnchorFixtures.StructFlow.Types.Turn
     stacktrace:
       test/anchor/domain/struct_types_test.exs:94: (test)
```

### PL-AU — an unknown reason gets a default text

Run summary: `7 tests, 1 failure`

```text
  1) test an unknown reason raises: there is no default text (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:55
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn -> Placement.render(proposal(:nope, F)) end
     stacktrace:
       test/anchor/domain/placement_render_test.exs:56: (test)
```

### PL-AV — the lost-precision issue names no site

Run summary: `26 tests, 2 failures`

```text
  1) test lost precision fails closed, naming the site, with no finding (Anchor.Domain.GraphRules.ReachableFromRootTest)
     test/anchor/domain/graph_rules/reachable_from_root_test.exs:48
     Assertion with =~ failed
     code:  assert issue.message =~ "reachability is imprecise: lib/framework/W.ex:7 calls an unknown"
     left:  "rule (id: \"reach\", reachable_from_root) reachability is imprecise: 0 calls an unknown function dynamically. Fix: resolve it through a behaviour, or accept that reachable_from_root cannot judge this repo."
     right: "reachability is imprecise: lib/framework/W.ex:7 calls an unknown"
     stacktrace:
       test/anchor/domain/graph_rules/reachable_from_root_test.exs:53: (test)


  2) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:449
     reachability_lost: "reachability is imprecise: lib/a.ex:3, ?:? calls an unknown function dynamically" in rule 2 (id: "web", layering) reachability is imprecise: 0 calls an unknown function dynamically. Fix: resolve it through a behaviour, or accept that reachable_from_root cannot judge this repo.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:454: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:450: (test)
```

### PL-AW — reachable_from_root runs on the ast engine

Run summary: `87 tests, 5 failures`

```text
  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:70
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :function_placement, :interface,
             :layering, :parameter_reaches_sink,
             :reachable_from_root, :struct_owned_by_module_flow]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :function_placement, :interface,
             :layering, :parameter_reaches_sink,
             :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:73: (test)


  2) test the positive case the README lists exactly the keys each rule type accepts, its relation and engine (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:227
     README engine for reachable_from_root
     code: for type <- RuleSchema.rule_types() do
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:240: anonymous fn/2 in Anchor.Domain.RuleSchemaTest."test the positive case the README lists exactly the keys each rule type accepts, its relation and engine"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/rule_schema_test.exs:236: (test)


  3) test reachable_from_root: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:55
     reachable_from_root / positive: a bucket selector: refused: {:error, {:invalid_rule, "rule 1: unknown key \"bucket\" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module"}}
     reachable_from_root / positive: min_modules, id, enforcement and baseline: refused: {:error, {:invalid_rule, "rule 1 (id: \"r\"): unknown keys \"bucket\", \"min_modules\" in a reachable_from_root rule (`bucket` applies to graph rules only; \"min_modules\": did you mean \"min_files\"?; `min_modules` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module"}}
     reachable_from_root / no selector: wrong reason (want "no selector, so it would select no module"): rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     reachable_from_root / bucket and pattern (only bucket was read): wrong reason (want "more than one selector (bucket, pattern)"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / bucket that is not a string: wrong reason (want "`bucket` must be a non-empty string"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / an empty bucket: wrong reason (want "`bucket` must be a non-empty string"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / uses_module (an ast selector): wrong reason (want "`uses_module` applies to ast rules only"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / recursive (graph paths are always recursive): wrong reason (want "unknown key \"recursive\""): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / min_files (the graph floor is min_modules): wrong reason (want "did you mean \"min_modules\"?"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / min_modules: 0 (no floor): wrong reason (want "`min_modules` must be a positive integer"): rule 1: unknown keys "bucket", "min_modules" in a reachable_from_root rule (`bucket` applies to graph rules only; "min_modules": did you mean "min_files"?; `min_modules` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / min_modules that is not an integer: wrong reason (want "`min_modules` must be a positive integer"): rule 1: unknown keys "bucket", "min_modules" in a reachable_from_root rule (`bucket` applies to graph rules only; "min_modules": did you mean "min_files"?; `min_modules` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / an empty id: wrong reason (want "`id` must be a non-empty string"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / enforcement: warn: wrong reason (want "`enforcement` must be report or enforce"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / baseline without id (entries start with it): wrong reason (want "`baseline` needs the rule's `id`"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / an absolute baseline path: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / a baseline path climbing out: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / a baseline path with an inner ..: wrong reason (want "with no `..` segment"): rule 1 (id: "r"): unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / an empty baseline: wrong reason (want "`baseline` must be a non-empty path"): rule 1 (id: "r"): unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     reachable_from_root / a bucket naming no architecture bucket: wrong reason (want "`bucket: web` names no architecture: bucket"): rule 1: unknown key "bucket" in a reachable_from_root rule (`bucket` applies to graph rules only); known keys for reachable_from_root: baseline, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:61: (test)


  4) test engine/1 every shipped type has an engine; the graph types are the graph rule modules' (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:283
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:graph) ==
              Anchor.Domain.GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort()
     left:  [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :function_placement, :interface,
             :layering, :parameter_reaches_sink,
             :struct_owned_by_module_flow]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :function_placement, :interface,
             :layering, :parameter_reaches_sink,
             :reachable_from_root, :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:291: (test)


  5) test the positive case the ast types are exactly the rule types of Anchor.checks/0 (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:219
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:ast) == check_types
     left:  [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :reachable_from_root, :single_control_flow,
             :struct_getter_convention, :struct_owned_by_module]
     right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention,
             :struct_owned_by_module]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:222: (test)
```

### PL-AX — function_placement is not a registered rule

Run summary: `16 tests, 1 failure`

```text
  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:70
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :interface, :layering,
             :parameter_reaches_sink, :reachable_from_root,
             :struct_owned_by_module_flow]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :analyses_complete, :context_acyclic,
             :effects_match_bucket, :function_placement, :interface,
             :layering, :parameter_reaches_sink,
             :reachable_from_root, :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:73: (test)
```

### PL-AY — the bucket render leaves out the word bucket

Run summary: `27 tests, 5 failures`

```text
  1) test bucket text names the context and module when known, and the evidence (Anchor.Domain.PlacementRenderTest)
     test/anchor/domain/placement_render_test.exs:46
     Assertion with == failed
     code:  assert Placement.render(
              proposal(:bucket_from_effects, {:bucket, :managers, "App.B", App.B.Inv}, ["a -> b"])
            ) == "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"
     left:  "move F.line/1 to the managers of App.B (App.B.Inv): a -> b"
     right: "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"
     stacktrace:
       test/anchor/domain/placement_render_test.exs:47: (test)


  2) test a domain function that reaches an effect is one issue naming the chain (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:36
     Assertion with =~ failed
     code:  assert one.message =~ "Fix: move D.f/1 to the managers bucket: D.f/1 -> D2.g/1"
     left:  "D.f/1 is in bucket domain (domain) but reaches an effect. Fix: move D.f/1 to the managers: D.f/1 -> D2.g/1 -> App.Repo.insert/1"
     right: "Fix: move D.f/1 to the managers bucket: D.f/1 -> D2.g/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:51: (test)



  3) test an adapter function with no effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:71
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move A.to_map/1 to the domain bucket: no effect is reachable"
     left:  "A.to_map/1 is in bucket adapters but reaches no effect. Fix: move A.to_map/1 to the domain: no effect is reachable"
     right: "Fix: move A.to_map/1 to the domain bucket: no effect is reachable"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:76: (test)


  4) test an adapter that reaches effects only through another module names it (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:82
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move A.run/1 to the managers bucket: A.run/1 -> A2.save/1"
     left:  "A.run/1 is in bucket adapters (adapters) but reaches effects only through A2.save/1. Fix: move A.run/1 to the managers: A.run/1 -> A2.save/1 -> File.write/2"
     right: "Fix: move A.run/1 to the managers bucket: A.run/1 -> A2.save/1"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:90: (test)


  5) test a manager with a direct effect is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:60
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix: move M.run/1 to the adapters bucket: M.run/1 -> App.Repo"
     left:  "M.run/1 is in bucket managers (managers) but calls an effect itself. Fix: move M.run/1 to the adapters: M.run/1 -> App.Repo.insert/1"
     right: "Fix: move M.run/1 to the adapters bucket: M.run/1 -> App.Repo"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:68: (test)
```

### PL-BC — a literal {M, :f, args} is no edge

Run summary: `12 tests, 1 failure`

```text
  1) test a function a literal {M, :f, args} names is reachable, and stays public (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:160
     Expected truthy, got false
     code: assert facts.named?
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:187: (test)
```

### PL-AT — the note says precise whatever the reachability

Run summary: `36 tests, 1 failure`

```text
  1) test placement precision (DND-5448) the placement precision: counts, and each reachability answer (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:234
     Assertion with =~ failed
     code:  assert summary.(%{placement | reachability: :lost, lost_sites: 2}) =~ "reachability lost at 2 call sites"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); placement: 9 functions placed, 2 with no @spec (ownership unknown), 1 ambiguous owner, 3 with no clause to slice, 4 calls of a computed name, reachability precise"
     right: "reachability lost at 2 call sites"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:254: (test)
```

### PL-BO — a held module does not reach its child spec

Run summary: `137 tests, 1 failure`

```text
  1) test a supervised process outside a framework bucket is reached through its child spec (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:240
     AnchorFixtures.PlacementTest.Billing.Managers.Bare
     code: for module <- [Module.concat(managers, Bare), Module.concat(managers, Tupled)] do
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:288: anonymous fn/3 in Anchor.Integration.PlacementInvariantTest."test a supervised process outside a framework bucket is reached through its child spec"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/integration/placement_invariant_test.exs:287: (test)
```

### PL-BS — a module's own name reaches its child spec

Run summary: `137 tests, 1 failure`

```text
  1) test a supervised process outside a framework bucket is reached through its child spec (Anchor.Integration.PlacementInvariantTest)
     test/anchor/integration/placement_invariant_test.exs:240
     Expected false or nil, got true
     code: refute Placement.facts(placement, {unsupervised, :start_link, 1}).reachable?
     stacktrace:
       test/anchor/integration/placement_invariant_test.exs:293: (test)
```

### PL-BP — held_atoms reads the top of a literal only

Run summary: `70 tests, 1 failure`

```text
  1) test held_atoms/1 reads a literal of any depth (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:195
     Bare
     code: for atom <- [Bare, Tupled, Mapped, :x, :key], do: assert(atom in held, inspect(atom))
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/core_mfa_references_test.exs:198: (test)
```

### PL-BQ — held_atoms takes the module a call is made on

Run summary: `70 tests, 1 failure`

```text
  1) test held_atoms/1 the module a call is made on is not held (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:208
     Refute with in failed
     code:  refute Called in (binary |> core({:called, 1}) |> Core.held_atoms())
     left:  Called
     right: [Called, :function_clause, :match_fail, true]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:209: (test)
```

### PL-BR — a table row is gone

Run summary: `70 tests, 1 failure`

```text
  1) test partial_mfa_calls/1 the table's row row_proc_spawn reads its module, and a computed name (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:181
     match (=) failed
     code:  assert [%{module: M, name: nil}] = binary |> core({:row_proc_spawn, 2}) |> Core.partial_mfa_calls()
     left:  [%{module: M, name: nil}]
     right: []
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:182: (test)
```
