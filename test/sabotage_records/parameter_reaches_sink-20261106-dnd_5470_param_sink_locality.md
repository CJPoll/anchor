# Sabotage record — the parameter_reaches_sink rule and its runner wiring

- **Domain:** parameter_reaches_sink
- **Branch:** dnd-5470-param-sink-locality
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.ParameterReachesSink`, `Anchor.Domain.Core.mfa_references/1`, `Anchor.Domain.DynamicCalls.computed_name_count/1`, the `:demand` wiring in `Anchor.Managers.Graph`, `Anchor.Domain.GraphReport.parameter_sinks/4` and its note, and the two rows of `Anchor.Domain.Demand.Transfer` the QA plan names.
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

The first table holds the last full run, and each of its sections shows the first failure, cut at 70 lines. It was rewritten in place through the critic's rounds, so `## Measured zeros` and `## Retired mutants` keep what those rewrites dropped, and `## Second run` to `## Seventh run` are appended after it.

**Not run on purpose, and then run by mistake (`## Fourth run`, PW-A; the trap is in `## Fifth run`):** the chain's recursion guard (`MapSet.member?(seen, step)` read as `false`). Without it `steps/3` does not terminate, so its mutant spins and allocates for the whole 2000 ms bound on the desktop (the sabotage load rule). `count/2` in the canary and `D.rec/1` in the Domain test are the rows it would fail.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PL-A | a literal MFA exempts nothing (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exactly the dropped parameters are findings; every compliant and exempt one is not |
| PL-B | a tuple is no reference (`lib/anchor/domain/core.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs`, `core_mfa_references_test.exs` | `73 tests, 4 failures` (red) | tuple/1; tuple_two/2; in_map/1; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PL-C | three arguments of a call are no reference (`lib/anchor/domain/core.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs`, `core_mfa_references_test.exs` | `73 tests, 3 failures` (red) | spawned/1; later_args/1; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PL-D | a literal term is no reference (`lib/anchor/domain/core.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs`, `core_mfa_references_test.exs` | `73 tests, 7 failures` (red) | literal_map/0; nested_literal/0; tuple_in_map/0; list_in_map/0; literal_list/0; literal/0; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PL-F | any third element counts as a list (`lib/anchor/domain/core.ex`) | `core_mfa_references_test.exs` | `35 tests, 7 failures` (red) | spawn_improper/2; args_var/1; applied_literal_name/1; timeout_arg/0; message_call/1; tuple_var/1; improper/2 |
| PL-G | a literal term in a map is not read (`lib/anchor/domain/core.ex`) | `core_mfa_references_test.exs` | `35 tests, 3 failures` (red) | literal_map/0; list_in_map/0; tuple_in_map/0 |
| PL-H | a literal list is not read past its head (`lib/anchor/domain/core.ex`) | `core_mfa_references_test.exs` | `35 tests, 1 failure` (red) | list_in_map/0 |
| PL-I | a nested literal tuple is not read (`lib/anchor/domain/core.ex`) | `core_mfa_references_test.exs` | `35 tests, 3 failures` (red) | tuple_in_map/0; list_in_map/0; literal_map/0 |
| PL-J | the module of a reference outside the project crashes (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 3 failures` (red) | the summary prints the precision counts, and the apply site that fell to any; exactly the dropped parameters are findings; every compliant and exempt one is not; the message names the parameter, its chain and its call sites |
| PL-K | a fun apply counts as a computed name (`lib/anchor/domain/dynamic_calls.ex`) | `parameter_reaches_sink_canary_test.exs` | `3 tests, 1 failure` (red) | the summary prints the precision counts, and the apply site that fell to any |
| PL-O | a local call is not read (`lib/anchor/domain/core.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs`, `core_mfa_references_test.exs` | `73 tests, 2 failures` (red) | local/1; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PL-Q | an improper literal crashes (`lib/anchor/domain/core.ex`) | `core_mfa_references_test.exs` | `35 tests, 1 failure` (red) | literal_improper/0 |
| PL-W | a variable third argument reads as args (`lib/anchor/domain/core.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs`, `core_mfa_references_test.exs` | `73 tests, 5 failures` (red) | tuple_two/2; message_call/1; tuple_var/1; applied_literal_name/1; args_var/1 |
| PL-U | a rule over modules with no function reads clean (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `35 tests, 1 failure` (red) | the floor selected modules with no def or defp at all: the same issue |
| PL-V | counts crash the run (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | a rule that crashes while it counts is one issue: the run still reports the others |
| PL-L | computed names repeat per call (`lib/anchor/domain/dynamic_calls.ex`) | `parameter_reaches_sink_canary_test.exs`, `dynamic_calls_test.exs` | `10 tests, 1 failure` (red) | computed_name_count/1 counts a computed name once per caller and shape, never a fun apply or a known name |
| PL-M | the computed-name count is a constant (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `15 tests, 1 failure` (red) | the summary prints the precision counts, and the apply site that fell to any |
| PL-N | no rule reads as a row of zeros (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `29 tests, 1 failure` (red) | parameter_sinks/4: no such rule is nil, never a row of zeros |
| PS-0 | the demand-less rule is read clean instead of refused (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | check/2 the rule refuses a model with no demand analysis: never a clean read |
| PS-A | the absent check reads any parameter as dropped (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 10 failures` (red) | check/2 an absent parameter is one violation; its Fix names the parameter; check/2 a dropped chain is a violation at each level, naming the callee; check/2 a used parameter passes: positive control; exempt functions a dynamic call cannot reach a private function; exempt functions a public function a dynamic call can reach, and not another arity; check/2 reading a field is a use: only an absent whole parameter is reported; exempt functions a hand-written argument beside a generated one keeps the function judged; check/2 the rule selects: a module it does not select is not judged; check/2 the chain follows an absent callee, past one that is not, and stops at recursion; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-B | drop the capture exemption (QA) (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | exempt functions a captured function, public or private; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-C | treat unresolved applies as non-demanding (QA) (`lib/anchor/domain/demand/transfer.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-D | ignore guards (QA) (`lib/anchor/domain/demand/transfer.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-E | drop the callback exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 3 failures` (red) | exempt functions a callback of an external behaviour; exempt functions a callback of a project behaviour, read from the graph; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-F | drop the dynamic-call exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 4 failures` (red) | exempt functions a dynamic call with no known arity reaches every arity of the name; exempt functions a dynamic call cannot reach a private function; exempt functions a public function a dynamic call can reach, and not another arity; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-G | a call with no known arity reaches no arity (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | exempt functions a dynamic call with no known arity reaches every arity of the name; exempt functions a dynamic call cannot reach a private function |
| PS-G2 | a call of one arity reaches every arity (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a public function a dynamic call can reach, and not another arity |
| PS-G3 | a dynamic call can reach a private function (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a dynamic call cannot reach a private function |
| PS-H | drop the generated-module exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a function of a generated module |
| PS-I | drop the __name__ exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a function the compiler names __name__ |
| PS-J | drop the quote generated exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a function quote generated: true wrote |
| PS-K | drop the macro context exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | exempt functions a function a macro's quote wrote; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-L | drop the default-head exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 3 failures` (red) | exempt functions a default's head, whose arguments Elixir generates; the message names the parameter, its chain and its call sites; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-M | a head with any generated argument is generated (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | exempt functions a hand-written argument beside a generated one keeps the function judged |
| PS-N | a private function is always judged, even captured (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | exempt functions a captured function, public or private; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-O | an unread behaviour is judged (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | what is not analysed: counted, never judged a public function of a module whose external behaviour gave no callbacks |
| PS-P | an unknown module is judged (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | what is not analysed: counted, never judged a module that may be generated |
| PS-Q | a function with no summary is exempt (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | what is not analysed: counted, never judged a function with no summary |
| PS-R | a macro is counted (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | what is not analysed: counted, never judged a macro is neither judged nor counted; the summary prints the precision counts, and the apply site that fell to any |
| PS-S | the floor issue never speaks (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | the floor selected modules of which nothing could be judged: one fail-closed issue; exempt functions a function of a generated module |
| PS-T | the position in the key is 0-based (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 11 failures` (red) | exempt functions a function of a behaviour module that is no callback is judged; exempt functions a dynamic call cannot reach a private function; what is not analysed: counted, never judged a private function of that module is still judged: no behaviour fixes it; check/2 a dropped chain is a violation at each level, naming the callee; exempt functions a public function a dynamic call can reach, and not another arity; exempt functions not exempt: the positive control for this block; check/2 an absent parameter is one violation; its Fix names the parameter; exempt functions a dynamic call with a computed name exempts nothing; exempt functions a hand-written argument beside a generated one keeps the function judged; the message names the parameter, its chain and its call sites; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-U | the chain follows a used callee (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | check/2 the chain follows an absent callee, past one that is not, and stops at recursion; check/2 a callee outside the summaries, or an unknown lambda, ends the chain |
| PS-V | the chain stops at once (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 3 failures` (red) | check/2 a dropped chain is a violation at each level, naming the callee; check/2 the chain follows an absent callee, past one that is not, and stops at recursion; the message names the parameter, its chain and its call sites |
| PS-W | a lambda callee is never absent (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | the message names the parameter, its chain and its call sites |
| PS-X | call sites are not counted (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | check/2 a dropped chain is a violation at each level, naming the callee; the message names the parameter, its chain and its call sites |
| PS-Y | the name ignores the = pattern's variable (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 1 failure` (red) | check/2 the parameter's name comes from the first clause that names it |
| PS-Z | _ reads as a name (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `38 tests, 2 failures` (red) | check/2 a position with no variable in any clause is arg<position>; check/2 the parameter's name comes from the first clause that names it |
| PR-A | the runner never runs the analysis (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `15 tests, 7 failures` (red) | the rule reads the callbacks the behaviour port read; the analysis runs once for two rules, with the config's effect tokens; a needing rule over code with no apply sites: a measured zero, never null; a crashed effect inference does not stop a rule that needs only demand; exactly the dropped parameters are findings; every compliant and exempt one is not; the summary prints the precision counts, and the apply site that fell to any; the message names the parameter, its chain and its call sites |
| PR-B | the analysis runs whatever the rules need (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | no rule that runs needs it: not run, no counts, null in the JSON |
| PR-C | the config effect tokens are dropped (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | the analysis runs once for two rules, with the config's effect tokens |
| PR-D | the callbacks read are dropped (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `15 tests, 2 failures` (red) | the rule reads the callbacks the behaviour port read; the summary prints the precision counts, and the apply site that fell to any |
| PR-E | a return that is no %Demand{} is taken for one (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| PR-F | a crashed demand analysis is reported as the flow analysis's (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 5 failures` (red) | an analysis that raises: the rule that needs it is one issue and is not run; the others run; a behaviour read that raises is the same one issue; a crashed demand analysis does not stop a rule that needs only effects; both crashed: the rule that needs demand reports demand; an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| PR-G | a crashed effect inference stops the demand clause (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | both crashed: the rule that needs demand reports demand |
| PR-H | the counts are always nil (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `15 tests, 4 failures` (red) | the analysis runs once for two rules, with the config's effect tokens; the rule reads the callbacks the behaviour port read; a needing rule over code with no apply sites: a measured zero, never null; the summary prints the precision counts, and the apply site that fell to any |
| PR-I | two rules do not add (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | the analysis runs once for two rules, with the config's effect tokens |
| PR-J | the imprecise count is a constant (`lib/anchor/domain/graph_report.ex`) | `parameter_reaches_sink_canary_test.exs` | `3 tests, 1 failure` (red) | the summary prints the precision counts, and the apply site that fell to any |
| PR-K | the note is dropped (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `15 tests, 2 failures` (red) | a needing rule over code with no apply sites: a measured zero, never null; the summary prints the precision counts, and the apply site that fell to any |
| PR-L | the JSON reads a measured zero as null (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | a needing rule over code with no apply sites: a measured zero, never null |

## PL-A — a literal MFA exempts nothing

Run summary: `38 tests, 1 failure`

```text
1) test exactly the dropped parameters are findings; every compliant and exempt one is not (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:70
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "sinks|#{@drops}.count/2|param 1",
              "sinks|#{@drops}.drop_first/2|param 1",
              "sinks|#{@drops}.f/2|param 2",
              "sinks|#{@drops}.g/1|param 1",
              "sinks|#{@drops}.index/1|param 1",
              "sinks|#{@drops}.ping/2|param 1",
              "sinks|#{@drops}.price/2|param 2",
              "sinks|#{@drops}.via_lambda/1|param 1",
              "sinks|#{@drops}.via_var/1|param 1"
            ]
     left:  ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Started.literal_target/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Started.local_worker/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Started.start_link/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Started.worker/1|param 1"]
     right: ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1"]
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:78: (test)

..
```

## PL-B — a tuple is no reference

Run summary: `73 tests, 4 failures`

```text
1) test tuple/1 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

......
```

## PL-C — three arguments of a call are no reference

Run summary: `73 tests, 3 failures`

```text
1) test spawned/1 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

..
```

## PL-D — a literal term is no reference

Run summary: `73 tests, 7 failures`

```text
1) test literal_map/0 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

..
```

## PL-F — any third element counts as a list

Run summary: `35 tests, 7 failures`

```text
1) test spawn_improper/2 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     ** (FunctionClauseError) no function clause matching in :cerl.list_length/2

     The following arguments were given to :cerl.list_length/2:

         # 1
         {:c_var, [{17, 51}, {:file, ~c"nofile"}], :_y@1}

         # 2
         1

     code: |> Core.mfa_references()
     stacktrace:
       (compiler 9.0.3) cerl.erl:1272: :cerl.list_length/2
       (anchor 0.1.0) lib/anchor/domain/core.ex:248: Anchor.Domain.Core.triple_reference/1
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/domain/core.ex:276: anonymous fn/3 in Anchor.Domain.Core.collect/2
       (compiler 9.0.3) cerl_trees.erl:243: :cerl_trees.fold/3
       (compiler 9.0.3) cerl_trees.erl:335: :cerl_trees.fold_list/3
       (compiler 9.0.3) cerl_trees.erl:243: :cerl_trees.fold/3
       (anchor 0.1.0) lib/anchor/domain/core.ex:277: Anchor.Domain.Core.collect/2
       (anchor 0.1.0) lib/anchor/domain/core.ex:159: Anchor.Domain.Core.mfa_references/1
       test/anchor/domain/core_mfa_references_test.exs:101: (test)
```

## PL-G — a literal term in a map is not read

Run summary: `35 tests, 3 failures`

```text
1) test literal_map/0 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

....
```

## PL-H — a literal list is not read past its head

Run summary: `35 tests, 1 failure`

```text
1) test list_in_map/0 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

..............
```

## PL-I — a nested literal tuple is not read

Run summary: `35 tests, 3 failures`

```text
1) test tuple_in_map/0 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

...............
```

## PL-J — the module of a reference outside the project crashes

Run summary: `38 tests, 3 failures`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:124
     ** (KeyError) key :parameter_sinks not found in:

         %{
           modules: 13,
           opaque: 0,
           apps: 1,
           rules: 1,
           apply_sites: %{
             any: 1,
             total: 4,
             resolved: 3,
             bound_hit?: false,
             by_function: %{
               {AnchorFixtures.ParameterSinks.Captures, :run, 1} => %{
                 any: 0,
                 total: 1,
                 resolved: 1
               },
               {AnchorFixtures.ParameterSinks.Drops, :via_lambda, 1} => %{
                 any: 0,
                 total: 1,
                 resolved: 1
               },
               {AnchorFixtures.ParameterSinks.Order, :__struct__, 1} => %{
                 any: 0,
                 total: 1,
                 resolved: 1
               },
               {AnchorFixtures.ParameterSinks.Uses, :invoked, 2} => %{
                 any: 1,
                 total: 1,
                 resolved: 0
               }
             }
           },
           no_core: 0,
           dynamic_calls: %{
             narrowed: [],
             fanned_out: [
               {{AnchorFixtures.ParameterSinks.Dynamic, :call, 2}, :handle_it, 2}
             ]
           },
           interface_width: nil,
           outside_root: 0
         }

     code: } = report.counts.parameter_sinks
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:136: (test)
```

## PL-K — a fun apply counts as a computed name

Run summary: `3 tests, 1 failure`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:124
     Uses.applied/3, Computed.dispatch/2, Computed.anywhere/3, Started.run/3
     code: assert report.counts.parameter_sinks.computed_names == 4,
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:141: (test)

.
```

## PL-O — a local call is not read

Run summary: `73 tests, 2 failures`

```text
1) test local/1 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 1}]
     left:  []
     right: [{M, :f, 1}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

.....................................................................
```

## PL-Q — an improper literal crashes

Run summary: `35 tests, 1 failure`

```text
1) test literal_improper/0 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     ** (ArgumentError) errors were found at the given arguments:

       * 1st argument: not a list

     code: |> Core.mfa_references()
     stacktrace:
       :erlang.length([:a | :b])
       (anchor 0.1.0) lib/anchor/domain/core.ex:259: Anchor.Domain.Core.term_references/1
       (anchor 0.1.0) lib/anchor/domain/core.ex:276: anonymous fn/3 in Anchor.Domain.Core.collect/2
       (compiler 9.0.3) cerl_trees.erl:243: :cerl_trees.fold/3
       (compiler 9.0.3) cerl_trees.erl:335: :cerl_trees.fold_list/3
       (compiler 9.0.3) cerl_trees.erl:243: :cerl_trees.fold/3
       (anchor 0.1.0) lib/anchor/domain/core.ex:277: Anchor.Domain.Core.collect/2
       (anchor 0.1.0) lib/anchor/domain/core.ex:159: Anchor.Domain.Core.mfa_references/1
       test/anchor/domain/core_mfa_references_test.exs:101: (test)

...
```

## PL-W — a variable third argument reads as args

Run summary: `73 tests, 5 failures`

```text
1) test tuple_two/2 (Anchor.Domain.CoreMfaReferencesTest)
     test/anchor/domain/core_mfa_references_test.exs:97
     Assertion with == failed
     code:  assert Enum.sort(references) == [{M, :f, 2}]
     left:  [{M, :f, 1}]
     right: [{M, :f, 2}]
     stacktrace:
       test/anchor/domain/core_mfa_references_test.exs:105: (test)

..........
```

## PL-U — a rule over modules with no function reads clean

Run summary: `35 tests, 1 failure`

```text
1) test the floor selected modules with no def or defp at all: the same issue (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:376
     match (=) failed
     code:  assert [%{kind: :fail_closed} = issue] = ParameterReachesSink.check(model, @rule)
     left:  [%{kind: :fail_closed} = issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:379: (test)

..
```

## PL-V — counts crash the run

Run summary: `12 tests, 1 failure`

```text
1) test a rule that crashes while it counts is one issue: the run still reports the others (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:220
     ** (BadMapError) expected a map, got:

         :not_a_map

     code: run([sinks(), probe(2)], beams, demand: fn _g, _c, _e -> %Demand{summaries: :not_a_map} end)
     stacktrace:
       :erlang.is_map_key({AnchorFixtures.GraphDemandTest.Reader, :drop, 1}, :not_a_map)
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:157: Anchor.Domain.GraphRules.ParameterReachesSink.verdict/5
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:151: anonymous fn/6 in Anchor.Domain.GraphRules.ParameterReachesSink.verdicts/2
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:146: Anchor.Domain.GraphRules.ParameterReachesSink.verdicts/2
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:132: Anchor.Domain.GraphRules.ParameterReachesSink.counts/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:387: anonymous fn/3 in Anchor.Managers.Graph.sink_counts/2
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:386: Anchor.Managers.Graph.sink_counts/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:292: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_demand_test.exs:226: (test)

..........
```

## PL-L — computed names repeat per call

Run summary: `10 tests, 1 failure`

```text
1) test computed_name_count/1 counts a computed name once per caller and shape, never a fun apply or a known name (Anchor.Domain.DynamicCallsTest)
     test/anchor/domain/dynamic_calls_test.exs:85
     Assertion with == failed
     code:  assert DynamicCalls.computed_name_count(%Graph{calls: calls}) == 3
     left:  4
     right: 3
     stacktrace:
       test/anchor/domain/dynamic_calls_test.exs:95: (test)

.......
```

## PL-M — the computed-name count is a constant

Run summary: `15 tests, 1 failure`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:124
     Uses.applied/3, Computed.dispatch/2, Computed.anywhere/3, Started.run/3
     code: assert report.counts.parameter_sinks.computed_names == 4,
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:141: (test)

.
```

## PL-N — no rule reads as a row of zeros

Run summary: `29 tests, 1 failure`

```text
1) test parameter_sinks/4: no such rule is nil, never a row of zeros (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with == failed
     code:  assert GraphReport.parameter_sinks([], %Anchor.Domain.Cfa{}, %Anchor.Domain.Demand{}, 3) == nil
     left:  %{computed_names: 3}
     right: nil
     stacktrace:
       test/anchor/domain/graph_report_test.exs:365: (test)

.................
```

## PS-0 — the demand-less rule is read clean instead of refused

Run summary: `38 tests, 1 failure`

```text
1) test check/2 the rule refuses a model with no demand analysis: never a clean read (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:176
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn ->
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:177: (test)

........
```

## PS-A — the absent check reads any parameter as dropped

Run summary: `38 tests, 10 failures`

```text
1) test check/2 an absent parameter is one violation; its Fix names the parameter (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:61
     match (=) failed
     code:  assert [violation] = ParameterReachesSink.check(model, @rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "D.g/2",
                message: "D.g/2 parameter 1 (arg1) reaches no return value and no effect (chain: D.g/2 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.g/2 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.g/2|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "D.g/2",
                message: "D.g/2 parameter 2 (arg2) reaches no return value and no effect (chain: D.g/2 param 2 (dropped); call sites: 0). Fix: drop parameter 2 (arg2) of D.g/2 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.g/2|param 2",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:68: (test)
```

## PS-B — drop the capture exemption (QA)

Run summary: `38 tests, 2 failures`

```text
1) test exempt functions a captured function, public or private (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:236
     Assertion with == failed
     code:  assert ParameterReachesSink.check(capture.(kind), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 1). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 1 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:244: (test)

...................................
```

## PS-C — treat unresolved applies as non-demanding (QA)

Run summary: `38 tests, 1 failure`

```text
1) test exactly the dropped parameters are findings; every compliant and exempt one is not (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:70
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "sinks|#{@drops}.count/2|param 1",
              "sinks|#{@drops}.drop_first/2|param 1",
              "sinks|#{@drops}.f/2|param 2",
              "sinks|#{@drops}.g/1|param 1",
              "sinks|#{@drops}.index/1|param 1",
              "sinks|#{@drops}.ping/2|param 1",
              "sinks|#{@drops}.price/2|param 2",
              "sinks|#{@drops}.via_lambda/1|param 1",
              "sinks|#{@drops}.via_var/1|param 1"
            ]
     left:  ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Uses.invoked/2|param 2"]
     right: ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1"]
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:78: (test)
```

## PS-D — ignore guards (QA)

Run summary: `38 tests, 1 failure`

```text
1) test exactly the dropped parameters are findings; every compliant and exempt one is not (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:70
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "sinks|#{@drops}.count/2|param 1",
              "sinks|#{@drops}.drop_first/2|param 1",
              "sinks|#{@drops}.f/2|param 2",
              "sinks|#{@drops}.g/1|param 1",
              "sinks|#{@drops}.index/1|param 1",
              "sinks|#{@drops}.ping/2|param 1",
              "sinks|#{@drops}.price/2|param 2",
              "sinks|#{@drops}.via_lambda/1|param 1",
              "sinks|#{@drops}.via_var/1|param 1"
            ]
     left:  ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Uses.guarded/2|param 2"]
     right: ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.drop_first/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.index/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.ping/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_var/1|param 1"]
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:78: (test)
```

## PS-E — drop the callback exemption

Run summary: `38 tests, 3 failures`

```text
1) test exempt functions a callback of an external behaviour (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:214
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:203: Anchor.Domain.GraphRules.ParameterReachesSinkTest.exempt?/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:217: (test)

..........
```

## PS-F — drop the dynamic-call exemption

Run summary: `38 tests, 4 failures`

```text
1) test exempt functions a dynamic call with no known arity reaches every arity of the name (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:258
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "D.f/2",
                message: "D.f/2 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/2 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/2 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/2|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:263: (test)

.....
```

## PS-G — a call with no known arity reaches no arity

Run summary: `38 tests, 2 failures`

```text
1) test exempt functions a dynamic call with no known arity reaches every arity of the name (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:258
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "D.f/2",
                message: "D.f/2 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/2 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/2 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/2|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:263: (test)

...
```

## PS-G2 — a call of one arity reaches every arity

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a public function a dynamic call can reach, and not another arity (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:249
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  []
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:255: (test)

.................
```

## PS-G3 — a dynamic call can reach a private function

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a dynamic call cannot reach a private function (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:266
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  []
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:271: (test)

................
```

## PS-H — drop the generated-module exemption

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a function of a generated module (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:283
     match (=) failed
     code:  assert [%{kind: :fail_closed}] = ParameterReachesSink.check(model, @rule)
     left:  [%{kind: :fail_closed}]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:287: (test)

..................................
```

## PS-I — drop the __name__ exemption

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a function the compiler names __name__ (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:291
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.__struct__/1",
                message: "D.__struct__/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.__struct__/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.__struct__/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.__struct__/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:203: Anchor.Domain.GraphRules.ParameterReachesSinkTest.exempt?/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:293: (test)

...
```

## PS-J — drop the quote generated exemption

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a function quote generated: true wrote (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:300
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (x) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (x) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:203: Anchor.Domain.GraphRules.ParameterReachesSinkTest.exempt?/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:304: (test)

......
```

## PS-K — drop the macro context exemption

Run summary: `38 tests, 2 failures`

```text
1) test exempt functions a function a macro's quote wrote (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:300
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (x) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (x) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:203: Anchor.Domain.GraphRules.ParameterReachesSinkTest.exempt?/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:304: (test)

...............................
```

## PS-L — drop the default-head exemption

Run summary: `38 tests, 3 failures`

```text
1) test exempt functions a default's head, whose arguments Elixir generates (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:308
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (x0) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (x0) of D.f/1 and stop passing it at its 0 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:203: Anchor.Domain.GraphRules.ParameterReachesSinkTest.exempt?/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:314: (test)

............................
```

## PS-M — a head with any generated argument is generated

Run summary: `38 tests, 1 failure`

```text
1) test exempt functions a hand-written argument beside a generated one keeps the function judged (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:317
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  [nil]
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:326: (test)

.........................
```

## PS-N — a private function is always judged, even captured

Run summary: `38 tests, 2 failures`

```text
1) test exempt functions a captured function, public or private (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:236
     Assertion with == failed
     code:  assert ParameterReachesSink.check(capture.(kind), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.f/1",
                message: "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 1). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 1 call sites.",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "sinks|D.f/1|param 1",
                rule_id: "sinks",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:244: (test)

.................................
```

## PS-O — an unread behaviour is judged

Run summary: `38 tests, 1 failure`

```text
1) test what is not analysed: counted, never judged a public function of a module whose external behaviour gave no callbacks (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:344
     match (=) failed
     code:  assert %{not_analysed: 1} = ParameterReachesSink.counts(model, @rule)
     left:  %{not_analysed: 1}
     right: %{judged: 1, exempt: 0, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:332: Anchor.Domain.GraphRules.ParameterReachesSinkTest.not_analysed/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:345: (test)

.......................
```

## PS-P — an unknown module is judged

Run summary: `38 tests, 1 failure`

```text
1) test what is not analysed: counted, never judged a module that may be generated (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:340
     match (=) failed
     code:  assert %{not_analysed: 1} = ParameterReachesSink.counts(model, @rule)
     left:  %{not_analysed: 1}
     right: %{judged: 1, exempt: 0, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:332: Anchor.Domain.GraphRules.ParameterReachesSinkTest.not_analysed/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:341: (test)

....
```

## PS-Q — a function with no summary is exempt

Run summary: `38 tests, 1 failure`

```text
1) test what is not analysed: counted, never judged a function with no summary (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:336
     match (=) failed
     code:  assert %{not_analysed: 1} = ParameterReachesSink.counts(model, @rule)
     left:  %{not_analysed: 1}
     right: %{judged: 0, exempt: 1, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:332: Anchor.Domain.GraphRules.ParameterReachesSinkTest.not_analysed/1
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:337: (test)

.........................
```

## PS-R — a macro is counted

Run summary: `38 tests, 2 failures`

```text
1) test what is not analysed: counted, never judged a macro is neither judged nor counted (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:360
     Assertion with == failed
     code:  assert ParameterReachesSink.counts(model, @rule) == %{judged: 1, exempt: 0, not_analysed: 0}
     left:  %{judged: 1, exempt: 0, not_analysed: 1}
     right: %{judged: 1, exempt: 0, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:362: (test)

.........................
```

## PS-S — the floor issue never speaks

Run summary: `38 tests, 2 failures`

```text
1) test the floor selected modules of which nothing could be judged: one fail-closed issue (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:367
     match (=) failed
     code:  assert [issue] = ParameterReachesSink.check(model, @rule)
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:370: (test)

............
```

## PS-T — the position in the key is 0-based

Run summary: `38 tests, 11 failures`

```text
1) test exempt functions a function of a behaviour module that is no callback is judged (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:228
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
     left:  ["sinks|D.f/1|param 0"]
     right: ["sinks|D.f/1|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:233: (test)
```

## PS-U — the chain follows a used callee

Run summary: `38 tests, 2 failures`

```text
1) test check/2 the chain follows an absent callee, past one that is not, and stops at recursion (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:109
     Assertion with =~ failed
     code:  assert f.message =~ "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     left:  "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 -> D.used/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites."
     right: "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:119: (test)

.............
```

## PS-V — the chain stops at once

Run summary: `38 tests, 3 failures`

```text
1) test check/2 a dropped chain is a violation at each level, naming the callee (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:92
     Assertion with =~ failed
     code:  assert f.message =~ "chain: D.f/2 param 2 -> D.g/1 param 1 (dropped)"
     left:  "D.f/2 parameter 2 (arg2) reaches no return value and no effect (chain: D.f/2 param 2 (dropped); call sites: 0). Fix: drop parameter 2 (arg2) of D.f/2 and stop passing it at its 0 call sites."
     right: "chain: D.f/2 param 2 -> D.g/1 param 1 (dropped)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:102: (test)

..
```

## PS-W — a lambda callee is never absent

Run summary: `38 tests, 1 failure`

```text
1) test the message names the parameter, its chain and its call sites (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:95
     Assertion with =~ failed
     code:  assert finding(report, "via_lambda/1|param 1").message =~
              "#{@drops}.via_lambda/1 param 1 -> fn 0 in #{@drops}.via_lambda/1 param 1 (dropped)"
     left:  "AnchorFixtures.ParameterSinks.Drops.via_lambda/1 parameter 1 (unused) reaches no return value and no effect (chain: AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (unused) of AnchorFixtures.ParameterSinks.Drops.via_lambda/1 and stop passing it at its 0 call sites."
     right: "AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 -> fn 0 in AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 (dropped)"
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:120: (test)

..
```

## PS-X — call sites are not counted

Run summary: `38 tests, 2 failures`

```text
1) test check/2 a dropped chain is a violation at each level, naming the callee (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:92
     Assertion with =~ failed
     code:  assert g.message =~ "call sites: 1"
     left:  "D.g/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.g/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.g/1 and stop passing it at its 0 call sites."
     right: "call sites: 1"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:105: (test)

....
```

## PS-Y — the name ignores the = pattern's variable

Run summary: `38 tests, 1 failure`

```text
1) test check/2 the parameter's name comes from the first clause that names it (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:135
     Assertion with =~ failed
     code:  assert first.message =~ "parameter 1 (named)"
     left:  "D.f/2 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/2 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/2 and stop passing it at its 0 call sites."
     right: "parameter 1 (named)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:151: (test)

..................................
```

## PS-Z — _ reads as a name

Run summary: `38 tests, 2 failures`

```text
1) test check/2 a position with no variable in any clause is arg<position> (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:155
     Assertion with =~ failed
     code:  assert violation.message =~ "parameter 1 (arg1)"
     left:  "D.f/1 parameter 1 (_) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (_) of D.f/1 and stop passing it at its 0 call sites."
     right: "parameter 1 (arg1)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:164: (test)

..........
```

## PR-A — the runner never runs the analysis

Run summary: `15 tests, 7 failures`

```text
1) test the rule reads the callbacks the behaviour port read (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:177
     Assertion with == failed
     code:  assert finding.key == "sinks|#{@dropper}|param 1"
     left:  nil
     right: "sinks|AnchorFixtures.GraphDemandTest.Reader.drop/1|param 1"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:194: (test)
```

## PR-B — the analysis runs whatever the rules need

Run summary: `12 tests, 1 failure`

```text
1) test no rule that runs needs it: not run, no counts, null in the JSON (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:101
     Unexpectedly received message :read_behaviours (which matched :read_behaviours)
     code: refute_received :read_behaviours
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:118: (test)

..........
```

## PR-C — the config effect tokens are dropped

Run summary: `12 tests, 1 failure`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:158
     Assertion failed, no matching message after 0ms
     Showing 1 of 1 message in the mailbox
     code: assert_received {:analysed, ["Req"]}
     mailbox:
       pattern: {:analysed, ["Req"]}
       value:   {:analysed, []}
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:169: (test)

..
```

## PR-D — the callbacks read are dropped

Run summary: `15 tests, 2 failures`

```text
1) test the rule reads the callbacks the behaviour port read (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:177
     match (=) failed
     code:  assert %{exempt: 1} = report.counts.parameter_sinks
     left:  %{exempt: 1}
     right: %{
              any: 0,
              imprecise: 0,
              not_analysed: 2,
              judged: 2,
              exempt: 0,
              computed_names: 0,
              precise: 0
            }
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:195: (test)
```

## PR-E — a return that is no %Demand{} is taken for one

Run summary: `12 tests, 1 failure`

```text
1) test an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:204
     Assertion with =~ failed
     code:  assert issue.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.ParameterReachesSink.check/2 (raised at lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:116: Anchor.Domain.GraphRules.ParameterReachesSink.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:211: (test)

....
```

## PR-F — a crashed demand analysis is reported as the flow analysis's

Run summary: `12 tests, 5 failures`

```text
1) test an analysis that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:204
     Assertion with =~ failed
     code:  assert issue.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed: RuntimeError: demand blew up (raised at anonymous fn/3 in Anchor.Managers.GraphDemandTest.\"test an analysis that raises: the rule that needs it is one issue and is not run; the others run\"/1), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:211: (test)
```

## PR-G — a crashed effect inference stops the demand clause

Run summary: `12 tests, 1 failure`

```text
1) test both crashed: the rule that needs demand reports demand (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:270
     Assertion with =~ failed
     code:  assert demand.message =~ "the demand analysis it needs"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.ParameterReachesSink.check/2 (raised at lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:116: Anchor.Domain.GraphRules.ParameterReachesSink.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:281: (test)

...........
```

## PR-H — the counts are always nil

Run summary: `15 tests, 4 failures`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:158
     match (=) failed
     code:  assert %{judged: 4, precise: 0} = report.counts.parameter_sinks
     left:  %{judged: 4, precise: 0}
     right: nil
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:174: (test)
```

## PR-I — two rules do not add

Run summary: `12 tests, 1 failure`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:158
     match (=) failed
     code:  assert %{judged: 4, precise: 0} = report.counts.parameter_sinks
     left:  %{judged: 4, precise: 0}
     right: %{
              any: 0,
              not_analysed: 0,
              precise: 0,
              imprecise: 0,
              computed_names: 0,
              judged: 2,
              exempt: 0
            }
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:174: (test)

...
```

## PR-J — the imprecise count is a constant

Run summary: `3 tests, 1 failure`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:124
     Uses.applied/3 passes p to an apply/3 Core does not name
     code: assert imprecise > 0, "Uses.applied/3 passes p to an apply/3 Core does not name"
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:139: (test)
```

## PR-K — the note is dropped

Run summary: `15 tests, 2 failures`

```text
1) test a needing rule over code with no apply sites: a measured zero, never null (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:125
     Assertion with =~ failed
     code:  assert summary =~
              "; parameter_reaches_sink: 0 apply sites precise, 0 fell to any, " <>
                "0 imprecise parameters, 0 calls of a computed name, 2 functions judged, 0 exempt, " <>
                "0 not analysed"
     left:  "anchor.graph: 1 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 0 any"
     right: "; parameter_reaches_sink: 0 apply sites precise, 0 fell to any, 0 imprecise parameters, 0 calls of a computed name, 2 functions judged, 0 exempt, 0 not analysed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:147: (test)

...
```

## PR-L — the JSON reads a measured zero as null

Run summary: `12 tests, 1 failure`

```text
1) test a needing rule over code with no apply sites: a measured zero, never null (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:125
     match (=) failed
     code:  assert %{
              "apply_sites" => %{"total" => 0, "resolved" => 0, "any" => 0},
              "parameter_sinks" => %{"precise" => 0, "any" => 0, "judged" => 2}
            } = JSON.decode!(GraphReport.render(report, :json))
     left:  %{
              "apply_sites" => %{"total" => 0, "resolved" => 0, "any" => 0},
              "parameter_sinks" => %{"precise" => 0, "any" => 0, "judged" => 2}
            }
     right: %{
              "aggregates" => nil,
              "apply_sites" => %{
                "any" => 0,
                "bound_hit" => false,
                "by_function" => %{},
                "resolved" => 0,
                "total" => 0
              },
              "apps" => 1,
              "could_not_check" => [],
              "dynamic_calls" => %{
                "fanned_out" => [],
                "narrowed" => []
              },
              "effects" => nil,
              "exit_code" => 1,
              "findings" => [
                %{
                  "enforcement" => "enforce",
                  "file" => "lib/my_app/domain/reader.ex",
                  "fix" => "drop parameter 1 (_x) of AnchorFixtures.GraphDemandTest.Reader.drop/1 and stop passing it at its 0 call sites.",
                  "key" => "sinks|AnchorFixtures.GraphDemandTest.Reader.drop/1|param 1",
                  "line" => 2,
                  "message" => "AnchorFixtures.GraphDemandTest.Reader.drop/1 parameter 1 (_x) reaches no return value and no effect (chain: AnchorFixtures.GraphDemandTest.Reader.drop/1 param 1 (dropped); call sites: 0).",
                  "rule_id" => "sinks",
                  "type" => "parameter_reaches_sink"
                }
              ],
              "held" => [],
              "interface_width" => nil,
              "modules" => 1,
              "no_core" => 0,
              "opaque" => 0,
              "outside_root" => 0,
              "parameter_sinks" => nil,
              "refused" => [],
              "rules" => 1
            }
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:152: (test)
```

## Measured zeros

Each mutation reddened nothing when first run. The zero stays; the fix is beneath the table. Where the summary line was not kept, the row says so.

| # | Mutation | Result when first run |
|---|---|---|
| PR-B | the analysis runs whatever the rules need | `11 tests, 0 failures` |
| PR-G | a crashed effect inference stops the demand clause | `11 tests, 0 failures` |
| PS-G3 | a dynamic call can reach a private function | `37 tests, 0 failures` |
| PL-H | a literal list is not read past its head | `17 tests, 0 failures` |
| PL-I | a nested literal tuple is not read | 0 failures, summary line not kept |
| PL-J | the module of a reference outside the project crashes | `37 tests, 0 failures` |
| (no id) | the `when name != nil` guard on the dynamic clause removed | 0 failures, summary line not kept |

Fixes:

- **PR-B:** `no rule needs it` used a `CfaProbe`, which needs nothing, so it proved less than it said. The test now uses `:stub_needs_cfa`, and PR-B is red in the table.
- **PR-G:** `both crashed` ran no effects rule. It runs one now.
- **PS-G3:** a private function with no public sibling is no candidate at all. A private function beside a public one of the same name is now the row.
- **PL-H, PL-I:** a literal list or nested tuple is read as a term only inside a map, because `:cerl_trees.fold` already walks the others. The rows now put them inside a map.
- **PL-J:** no fixture named a module outside the project. One does now.
- **`when name != nil`:** no project function is named `nil`, so `DynamicCalls.targets/2` already answers none and the guard did nothing. The guard is gone; `a dynamic call with a computed name exempts nothing` holds the behaviour.

## Retired mutants

These ran red in earlier rounds; `3d5cccf`'s copy of this record holds their output. Their code left the branch in `f3edea3`, when the reading narrowed to names spelled out in full, so there is nothing left to mutate. `core_mfa_references_test.exs` now pins each shape as no reference, and PL-W (a variable third argument reads as args) replaces them.

| # | What it mutated |
|---|---|
| PL-E | args that are a variable are no reference (`Core`) |
| PL-P | a list of unknown length is no reference (`Core`) |
| PL-R | apply/3 with a computed name is no reference (`Core`) |
| PL-R2 | apply/3 with a literal name is read only as a call window (`Core`) |
| PL-R3 | any call of a literal module and a variable name is an apply (`Core`) |
| PL-R4 | any variable for the module names it (`Core`) |
| PL-S | a variable for the module is an apply (`Core`) |
| PL-T | a nameless reference reaches no function (`ParameterReachesSink`) |

## Second run

The critic's fifth round found nothing held `args != []` in `generated_clause?/1`, so this one mutation ran against `03971b6`, through the same driver and `test-slot`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PS-Z0 | no arguments count as all generated (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 2 failures` (red) | a function with no arguments is judged: no arguments are not all generated ones; a function with no arguments a module holding only such functions trips no floor |

## PS-Z0 — no arguments count as all generated

Run summary: `37 tests, 2 failures`

```text
1) test a function with no arguments is judged: no arguments are not all generated ones (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:340
     match (=) failed
     code:  assert %{judged: 1, exempt: 0, not_analysed: 0} = ParameterReachesSink.counts(model, @rule)
     left:  %{judged: 1, exempt: 0, not_analysed: 0}
     right: %{judged: 0, exempt: 1, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:341: (test)

.......
```

## Third run

The critic's eighth round found nothing held which number lands in which field of the counts, so these mutations ran against `40c989d`, through the same driver and `test-slot`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PR-S1 | precise and any swap (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `parameter_reaches_sink_canary_test.exs` | `33 tests, 2 failures` (red) | parameter_sinks/4: each number lands in its own field, summed over the rules; the summary prints the precision counts, and the apply site that fell to any |
| PR-S2 | the summary swaps exempt and not analysed (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `parameter_reaches_sink_canary_test.exs` | `33 tests, 2 failures` (red) | parameter_sinks/4: each number lands in its own field, summed over the rules; the summary prints the precision counts, and the apply site that fell to any |
| PR-S3 | the summary swaps precise and any (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `parameter_reaches_sink_canary_test.exs` | `33 tests, 2 failures` (red) | parameter_sinks/4: each number lands in its own field, summed over the rules; the summary prints the precision counts, and the apply site that fell to any |
| PR-S4 | the summary swaps imprecise and computed names (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `parameter_reaches_sink_canary_test.exs` | `33 tests, 2 failures` (red) | parameter_sinks/4: each number lands in its own field, summed over the rules; the summary prints the precision counts, and the apply site that fell to any |
| PR-S5 | two rules' counts are not summed (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `30 tests, 1 failure` (red) | parameter_sinks/4: each number lands in its own field, summed over the rules |

### PR-S1 — precise and any swap

Run summary: `33 tests, 2 failures`

```text
1) test parameter_sinks/4: each number lands in its own field, summed over the rules (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with == failed
     code:  assert counts == %{
              precise: 11,
              any: 7,
              imprecise: 5,
              computed_names: 13,
              judged: 21,
              exempt: 32,
              not_analysed: 43
            }
     left:  %{
              any: 11,
              not_analysed: 43,
              precise: 7,
              imprecise: 5,
              computed_names: 13,
              judged: 21,
              exempt: 32
            }
     right: %{
              any: 7,
              not_analysed: 43,
              precise: 11,
              imprecise: 5,
              computed_names: 13,
              judged: 21,
              exempt: 32
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:375: (test)

.
```

### PR-S2 — the summary swaps exempt and not analysed

Run summary: `33 tests, 2 failures`

```text
1) test parameter_sinks/4: each number lands in its own field, summed over the rules (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, " <>
                "5 imprecise parameters, 13 calls of a computed name, " <>
                "21 functions judged, 32 exempt, 43 not analysed"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); parameter_reaches_sink: 11 apply sites precise, 7 fell to any, 5 imprecise parameters, 13 calls of a computed name, 21 functions judged, 43 exempt, 32 not analysed"
     right: "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, 5 imprecise parameters, 13 calls of a computed name, 21 functions judged, 32 exempt, 43 not analysed"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:387: (test)

................
```

### PR-S3 — the summary swaps precise and any

Run summary: `33 tests, 2 failures`

```text
1) test parameter_sinks/4: each number lands in its own field, summed over the rules (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, " <>
                "5 imprecise parameters, 13 calls of a computed name, " <>
                "21 functions judged, 32 exempt, 43 not analysed"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); parameter_reaches_sink: 7 apply sites precise, 11 fell to any, 5 imprecise parameters, 13 calls of a computed name, 21 functions judged, 32 exempt, 43 not analysed"
     right: "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, 5 imprecise parameters, 13 calls of a computed name, 21 functions judged, 32 exempt, 43 not analysed"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:387: (test)

...............
```

### PR-S4 — the summary swaps imprecise and computed names

Run summary: `33 tests, 2 failures`

```text
1) test parameter_sinks/4: each number lands in its own field, summed over the rules (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, " <>
                "5 imprecise parameters, 13 calls of a computed name, " <>
                "21 functions judged, 32 exempt, 43 not analysed"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); parameter_reaches_sink: 11 apply sites precise, 7 fell to any, 13 imprecise parameters, 5 calls of a computed name, 21 functions judged, 32 exempt, 43 not analysed"
     right: "; parameter_reaches_sink: 11 apply sites precise, 7 fell to any, 5 imprecise parameters, 13 calls of a computed name, 21 functions judged, 32 exempt, 43 not analysed"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:387: (test)

........
```

### PR-S5 — two rules' counts are not summed

Run summary: `30 tests, 1 failure`

```text
1) test parameter_sinks/4: each number lands in its own field, summed over the rules (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:364
     Assertion with == failed
     code:  assert counts == %{
              precise: 11,
              any: 7,
              imprecise: 5,
              computed_names: 13,
              judged: 21,
              exempt: 32,
              not_analysed: 43
            }
     left:  %{
              any: 7,
              not_analysed: 3,
              precise: 11,
              imprecise: 5,
              computed_names: 13,
              judged: 1,
              exempt: 2
            }
     right: %{
              any: 7,
              not_analysed: 43,
              precise: 11,
              imprecise: 5,
              computed_names: 13,
              judged: 21,
              exempt: 32
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:375: (test)

......
```

## Fourth run

The review floor found tests with no recorded red, because no mutation had been aimed at them. These ran against `705588e`, through the same driver and `test-slot`. PW-A was meant as the recursion guard in a form that terminates, and did not terminate (`## Fifth run`). PW-F and PW-H stayed green.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PW-A | the chain stops after three steps, not at a repeat (the bounded form of the recursion guard) (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `40 tests, 4 failures` (red) | check/2 the chain follows an absent callee, past one that is not, and stops at recursion; exactly the dropped parameters are findings; every compliant and exempt one is not; the message names the parameter, its chain and its call sites; the summary prints the precision counts, and the apply site that fell to any |
| PW-B | a rule that selects no module still trips the floor (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 1 failure` (red) | the floor a rule that selects no module leaves it to the selection floor |
| PW-C | the shape says something else (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 1 failure` (red) | shape/1 states the rule |
| PW-D | the rule needs no flow analysis (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 1 failure` (red) | rule_type/0, needs/0 and narrows?/2 |
| PW-E | any two keys narrow (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 1 failure` (red) | rule_type/0, needs/0 and narrows?/2 |
| PW-F | the demand analysis runs with the flow analysis crashed (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 0 failures` (GREEN: survived) |  |
| PW-G | the rule is not in the graph rule types (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs`, `rule_schema_test.exs` | `67 tests, 4 failures` (red) | the positive case the ast types are exactly the rule types of Anchor.checks/0; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; the positive case the README lists exactly the keys each rule type accepts, its relation and engine; parameter_reaches_sink: every rule that checks nothing is refused, and the positive rows load |
| PW-H | the rule is not registered (`lib/anchor/domain/rule_shapes.ex`) | `graph_canary_test.exs`, `rule_schema_test.exs` | `46 tests, 0 failures` (GREEN: survived) |  |

### PW-A — the chain stops after three steps, not at a repeat (the bounded form of the recursion guard)

Run summary: `40 tests, 4 failures`

```text
1) test check/2 the chain follows an absent callee, past one that is not, and stops at recursion (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:109
     ** (ExUnit.TimeoutError) test timed out after 2000ms. You can change the timeout:

       1. per test by setting "@tag timeout: x" (accepts :infinity)
       2. per test module by setting "@moduletag timeout: x" (accepts :infinity)
       3. globally via "ExUnit.start(timeout: x)" configuration
       4. by running "mix test --timeout x" which sets timeout
       5. or by running "mix test --trace" which sets timeout to infinity
          (useful when using IEx.pry/0)

     where "x" is the timeout given as integer in milliseconds (defaults to 60_000).

     code: [f, rec] = model |> ParameterReachesSink.check(@rule) |> Enum.sort_by(& &1.key)
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:3045: Enum.amount_with_step/2
       (elixir 1.19.4) lib/enum.ex:4629: Enum.slice_forward/4
       (elixir 1.19.4) lib/enum.ex:483: Enum.at/3
       (anchor 0.1.0) lib/anchor/domain/demand.ex:131: Anchor.Domain.Demand.param/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:328: Anchor.Domain.GraphRules.ParameterReachesSink.absent?/2
       (elixir 1.19.4) lib/enum.ex:4459: Enum.find_list/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:314: Anchor.Domain.GraphRules.ParameterReachesSink.steps/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:318: Anchor.Domain.GraphRules.ParameterReachesSink.steps/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:305: Anchor.Domain.GraphRules.ParameterReachesSink.chain/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:268: Anchor.Domain.GraphRules.ParameterReachesSink.violation/5
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:125: anonymous fn/6 in Anchor.Domain.GraphRules.ParameterReachesSink.check/2
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:122: Anchor.Domain.GraphRules.ParameterReachesSink.check/2
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:117: (test)
       (ex_unit 1.19.4) lib/ex_unit/runner.ex:528: ExUnit.Runner.exec_test/2
       (stdlib 7.1) timer.erl:599: :timer.tc/2
       (ex_unit 1.19.4) lib/ex_unit/runner.ex:450: anonymous fn/6 in ExUnit.Runner.spawn_test_monitor/4

............
```

### PW-B — a rule that selects no module still trips the floor

Run summary: `37 tests, 1 failure`

```text
1) test the floor a rule that selects no module leaves it to the selection floor (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:402
     Assertion with == failed
     code:  assert ParameterReachesSink.check(model, %{@rule | bucket: "managers"}) == []
     left:  [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"sinks\", parameter_reaches_sink) judged no function: every function of the modules it selects is exempt, has no Core body, or could not be analysed, so it checked nothing. Fix: select modules with functions of their own, or remove the rule.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:404: (test)

....
```

### PW-C — the shape says something else

Run summary: `37 tests, 1 failure`

```text
1) test shape/1 states the rule (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:409
     Assertion with =~ failed
     code:  assert shape =~ "every parameter reaches the return value or an effect"
     left:  "each parameter is read, directly or through a callee; callback implementations and captured, dynamically called or generated functions are exempt"
     right: "every parameter reaches the return value or an effect"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:411: (test)

.....
```

### PW-D — the rule needs no flow analysis

Run summary: `37 tests, 1 failure`

```text
1) test rule_type/0, needs/0 and narrows?/2 (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:416
     Assertion with == failed
     code:  assert ParameterReachesSink.needs() == [:cfa, :demand]
     left:  [:demand]
     right: [:cfa, :demand]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:418: (test)

..............
```

### PW-E — any two keys narrow

Run summary: `37 tests, 1 failure`

```text
1) test rule_type/0, needs/0 and narrows?/2 (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:416
     Expected false or nil, got true
     code: refute ParameterReachesSink.narrows?("a", "b")
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:419: (test)

.............
```

### PW-F — the demand analysis runs with the flow analysis crashed

Run summary: `12 tests, 0 failures`

```text
Compiling 17 files (.ex)
Generated anchor app
Running ExUnit with seed: 440004, max_cases: 2

............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
12 tests, 0 failures
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/parameter_reaches_sink.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/managers/graph.ex" was set to the future, resetting to now
```

### PW-G — the rule is not in the graph rule types

Run summary: `67 tests, 4 failures`

```text
1) test the positive case the ast types are exactly the rule types of Anchor.checks/0 (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:209
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:ast) == check_types
     left:  [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :parameter_reaches_sink, :single_control_flow,
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
       test/anchor/domain/rule_schema_test.exs:212: (test)

........
```

### PW-H — the rule is not registered

Run summary: `46 tests, 0 failures`

```text
Compiling 18 files (.ex)
Generated anchor app
Running ExUnit with seed: 679826, max_cases: 2

..............................................
Finished in 0.3 seconds (0.3s async, 0.00s sync)
46 tests, 0 failures
warning: mtime (modified time) for "lib/anchor/domain/rule_shapes.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/rule_schema.ex" was set to the future, resetting to now
```


### The zeros, and what closed them

- **PW-F:** the flow-crash test's `refute` could not fail. The behaviours read comes before the analysis and had no stub, so the mutant crashed there and never called the analysis. `663555d` stubs it, and PW-F is red below.
- **PW-H:** it removed the rule from `RuleShapes`, which the tests it named do not read. It proved nothing about `@own_canary`, the row it was meant for. The row is now mutated directly (PW-H below), and the `RuleShapes` removal is PW-I, run against the test that reads it.

Re-run against `663555d`:

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PW-F | the demand analysis runs with the flow analysis crashed (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `12 tests, 1 failure` (red) | a crashed flow analysis: the rule reports it and the demand analysis is not run |
| PW-H | the rule is not in @own_canary (`test/anchor/integration/graph_canary_test.exs`) | `graph_canary_test.exs` | `10 tests, 1 failure` (red) | every graph rule type finds its violating canary module; every finding has one Fix: |
| PW-I | the rule has no shape entry (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs` | `7 tests, 1 failure` (red) | for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape |

### PW-F — the demand analysis runs with the flow analysis crashed

Run summary: `12 tests, 1 failure`

```text
1) test a crashed flow analysis: the rule reports it and the demand analysis is not run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:243
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:261: (test)
```

### PW-H — the rule is not in @own_canary

Run summary: `10 tests, 1 failure`

```text
1) test every graph rule type finds its violating canary module; every finding has one Fix: (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:272
     Anchor.Domain.GraphRules.ParameterReachesSink has no violating module in this canary. Fix: add one, or name the integration test of its own canary in @own_canary
     code: for module <- GraphRules.all(),
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:281: anonymous fn/3 in Anchor.Integration.GraphCanaryTest."test every graph rule type finds its violating canary module; every finding has one Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/integration/graph_canary_test.exs:279: (test)

....
```

### PW-I — the rule has no shape entry

Run summary: `7 tests, 1 failure`

```text
1) test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:30
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.RuleShapes.for/1

     The following arguments were given to Anchor.Domain.RuleShapes.for/1:

         # 1
         %{id: nil, match: :reference, type: :parameter_reaches_sink, mode: nil, pattern: "MyApp.*", recursive: false, enforcement: :enforce, forbidden_modules: [], forbidden_patterns: [], forbidden_functions: [], allowed_callers: [], same_context: false, context_depth: 2, required_modules: [], max_lines: nil, allowed_functions: [], uses_module: nil, bucket: nil, paths: nil, min_modules: nil, baseline: nil, max_width: nil, min_files: 1, owned_namespaces: nil, pure_patterns: []}

     Attempted function clauses (showing 1 out of 1):

         def for(%{type: type} = rule) when -is_map_key(
       %{
         aggregate_declarations: Anchor.Domain.GraphRules.AggregateDeclarations,
         alphabetized_functions: Anchor.Domain.Checks.AlphabetizedFunctions,
         case_on_bare_arg: Anchor.Domain.Checks.CaseOnBareArg,
         context_acyclic: Anchor.Domain.GraphRules.ContextAcyclic,
         effects_match_bucket: Anchor.Domain.GraphRules.EffectsMatchBucket,
         interface: Anchor.Domain.GraphRules.Interface,
         layering: Anchor.Domain.GraphRules.Layering,
         max_file_length: Anchor.Domain.Checks.MaxFileLength,
         module_pattern_restrictions: Anchor.Domain.Checks.ModulePatternRestrictions,
         must_use_module: Anchor.Domain.Checks.MustUseModule,
         no_comparison_in_if: Anchor.Domain.Checks.NoComparisonInIf,
         no_direct_dependency: Anchor.Domain.Checks.NoDependency,
         no_discarded_pure_expression: Anchor.Domain.Checks.NoDiscardedPureExpression,
         no_discarding_arrow_in_with: Anchor.Domain.Checks.NoDiscardingArrowInWith,
         no_forwarding_function: Anchor.Domain.Checks.NoForwardingFunction,
         no_transitive_dependency: Anchor.Domain.Checks.NoTransitiveDependency,
         no_tuple_match_in_head: Anchor.Domain.Checks.NoTupleMatchInHead,
         single_control_flow: Anchor.Domain.Checks.SingleControlFlow,
         struct_getter_convention: Anchor.Domain.Checks.StructGetterConvention,
         struct_owned_by_module: Anchor.Domain.Checks.StructOwnedByModule,
         struct_owned_by_module_flow: Anchor.Domain.GraphRules.StructOwnedByModuleFlow
       },
       type
     )-

     code: for type <- RuleSchema.rule_types() do
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/rule_shapes.ex:56: Anchor.Domain.RuleShapes.for/1
       test/anchor/domain/rule_shapes_test.exs:32: anonymous fn/2 in Anchor.Domain.RuleShapesTest."test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/rule_shapes_test.exs:31: (test)

.
```

## Fifth run

**A trap: PW-A's red is a timeout, not an assertion.** `MapSet.size(seen) >= 3` never fires on a recursion, because a repeated step adds nothing to `seen`, so `seen` stays small and the mutant spun in `steps/3` until the 2000 ms bound on each test that reached it. PW-A's row says `red`, and what it proves is only that a chain with no working guard does not finish. It also broke the load rule the header cites, for about 2 s per test. Do not re-run it.

Any mutant that truly removes the guard spins, so that break can only be killed by a timeout. What can be held by an assertion is where the chain stops. PW-J stops it early, which always terminates, and it fails on the chain text itself. It ran against `2d73cfb`, through the same driver and `test-slot`, on the Domain test alone.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PW-J | the chain stops at its second step, not at a repeat (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs` | `37 tests, 1 failure` (red) | check/2 the chain follows an absent callee, past one that is not, and stops at recursion |

### PW-J — the chain stops at its second step, not at a repeat

Run summary: `37 tests, 1 failure`

```text
1) test check/2 the chain follows an absent callee, past one that is not, and stops at recursion (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:109
     Assertion with =~ failed
     code:  assert f.message =~ "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     left:  "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 -> D.rec/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites."
     right: "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:119: (test)

...........
```

## Sixth run

The merge of `origin/main` (`072bfa6`) took DND-5715's `:demand` wiring and read the callbacks beside it only for this rule. PW-F's line was replaced with that wiring. PX-A stayed green against `35bfb96`: no test had a rule that needs the analysis and not the callbacks. `53b273b` adds it, and PX-A is the re-run. PX-B ran against `35bfb96`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PX-B | the callbacks are never read (`lib/anchor/managers/graph.ex`) | `graph_parameter_sinks_test.exs` | `12 tests, 7 failures` (red) | the analysis runs once for two rules, with the config's effect tokens; a behaviour read that raises is the same one issue; an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; the rule reads the callbacks the behaviour port read; an analysis that raises: the rule that needs it is one issue and is not run; the others run; a needing rule over code with no apply sites: a measured zero, never null; a rule that crashes while it counts is one issue: the run still reports the others |

### PX-B — the callbacks are never read

Run summary: `12 tests, 7 failures`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphParameterSinksTest)
     test/anchor/managers/graph_parameter_sinks_test.exs:158
     ** (Mox.VerificationError) error while verifying mocks for #PID<0.1260.0>:

       * expected Anchor.BehaviourSourceMock.callbacks/1 to be invoked once but it was invoked 0 times
     stacktrace:
       (mox 1.2.0) lib/mox.ex:862: Mox.__verify_mock_or_all__/2
       (mox 1.2.0) lib/mox.ex:819: anonymous fn/1 in Mox.verify_on_exit!/1
       (ex_unit 1.19.4) lib/ex_unit/on_exit_handler.ex:140: ExUnit.OnExitHandler.exec_callback/1
       (ex_unit 1.19.4) lib/ex_unit/on_exit_handler.ex:126: ExUnit.OnExitHandler.on_exit_runner_loop/0
```

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PX-A | the callbacks are read for any rule needing demand (`lib/anchor/managers/graph.ex`) | `graph_parameter_sinks_test.exs` | `13 tests, 1 failure` (red) | a rule that needs the analysis but is no parameter_reaches_sink reads no behaviour |

### PX-A — the callbacks are read for any rule needing demand

Run summary: `13 tests, 1 failure`

```text
1) test a rule that needs the analysis but is no parameter_reaches_sink reads no behaviour (Anchor.Managers.GraphParameterSinksTest)
     test/anchor/managers/graph_parameter_sinks_test.exs:110
     Expected truthy, got false
     code: assert Map.has_key?(report.counts, :demand)
     arguments:

         # 1
         %{
           modules: 1,
           opaque: 0,
           apps: 1,
           rules: 0,
           no_core: 0,
           outside_root: 0,
           apply_sites: nil,
           interface_width: nil,
           dynamic_calls: %{narrowed: [], fanned_out: []}
         }

         # 2
         :demand

     stacktrace:
       test/anchor/managers/graph_parameter_sinks_test.exs:126: (test)

..
```

## Seventh run

**A trap: the PX-A re-run in `## Sixth run` proves nothing.** Its test was failing with no mutation applied, because the injected rule list was ignored (a keyword list keeps its first key), so its `1 failure` is not this mutation's. Check a test green before you sabotage it. This run is against `f9da957`, where the test passes unmutated and fails here on `refute_received :read_behaviours`.

The merge also moved this branch's runner tests from `graph_demand_test.exs`, which is now main's, to `graph_parameter_sinks_test.exs`. The rows above that name the old file ran before the move.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PX-A | the callbacks are read for any rule needing demand (`lib/anchor/managers/graph.ex`) | `graph_parameter_sinks_test.exs` | `13 tests, 1 failure` (red) | a rule that needs the analysis but is no parameter_reaches_sink reads no behaviour |

### PX-A — the callbacks are read for any rule needing demand

Run summary: `13 tests, 1 failure`

```text
1) test a rule that needs the analysis but is no parameter_reaches_sink reads no behaviour (Anchor.Managers.GraphParameterSinksTest)
     test/anchor/managers/graph_parameter_sinks_test.exs:110
     Unexpectedly received message :read_behaviours (which matched :read_behaviours)
     code: refute_received :read_behaviours
     stacktrace:
       test/anchor/managers/graph_parameter_sinks_test.exs:122: (test)

..
```

