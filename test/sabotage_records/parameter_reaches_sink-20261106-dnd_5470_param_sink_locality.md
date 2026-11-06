# Sabotage record — the parameter_reaches_sink rule and its runner wiring

- **Domain:** parameter_reaches_sink
- **Branch:** dnd-5470-param-sink-locality
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.ParameterReachesSink`, the `:demand` wiring in `Anchor.Managers.Graph`, `Anchor.Domain.GraphReport.parameter_sinks/3` and its note, and the two rows of `Anchor.Domain.Demand.Transfer` the QA plan names.
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

Every mutation below reddens a test. Two rounds came first: their survivors were test defects, fixed in this branch. A `CfaProbe` needs nothing, so `no rule needs it` proved less than it said (PR-B); `both crashed` did not run an effects rule (PR-G); a private function with no public sibling is no candidate at all (PS-G3).

**Not run:** the chain's recursion guard (`MapSet.member?(seen, step)` read as `false`). Without it `steps/3` does not terminate, so its mutant spins and allocates for the whole 2000 ms bound on the desktop (the sabotage load rule). `count/2` in the canary and `D.rec/1` in the Domain test are the rows it would fail.

**Measured removal:** an earlier `when name != nil` on the dynamic clause survived its mutation: no project function is named `nil`, so `DynamicCalls.targets/2` already answers none. The guard is gone; `a dynamic call with a computed name exempts nothing` holds the behaviour.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| PS-0 | the demand-less rule is read clean instead of refused (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | check/2 the rule refuses a model with no demand analysis: never a clean read |
| PS-A | the absent check reads any parameter as dropped (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 10 failures` (red) | check/2 the rule selects: a module it does not select is not judged; check/2 an absent parameter is one violation; its Fix names the parameter; exempt functions a hand-written argument beside a generated one keeps the function judged; check/2 the chain follows an absent callee, past one that is not, and stops at recursion; check/2 a dropped chain is a violation at each level, naming the callee; check/2 a used parameter passes: positive control |
| PS-B | drop the capture exemption (QA) (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | exempt functions a captured function, public or private; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-C | treat unresolved applies as non-demanding (QA) (`lib/anchor/domain/demand/transfer.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-D | ignore guards (QA) (`lib/anchor/domain/demand/transfer.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-E | drop the callback exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 3 failures` (red) | exempt functions a callback of a project behaviour, read from the graph; exempt functions a callback of an external behaviour; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-F | drop the dynamic-call exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 4 failures` (red) | exempt functions a dynamic call cannot reach a private function; exempt functions a dynamic call with no known arity reaches every arity of the name; exempt functions a public function a dynamic call can reach, and not another arity; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-G | a call with no known arity reaches no arity (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | exempt functions a dynamic call cannot reach a private function; exempt functions a dynamic call with no known arity reaches every arity of the name |
| PS-G2 | a call of one arity reaches every arity (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a public function a dynamic call can reach, and not another arity |
| PS-G3 | a dynamic call can reach a private function (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a dynamic call cannot reach a private function |
| PS-H | drop the generated-module exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a function of a generated module |
| PS-I | drop the __name__ exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a function the compiler names __name__ |
| PS-J | drop the quote generated exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a function quote generated: true wrote |
| PS-K | drop the macro context exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | exempt functions a function a macro's quote wrote; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-L | drop the default-head exemption (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a default's head, whose arguments Elixir generates |
| PS-M | a head with any generated argument is generated (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | exempt functions a hand-written argument beside a generated one keeps the function judged |
| PS-N | a private function is always judged, even captured (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | exempt functions a captured function, public or private; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PS-O | an unread behaviour is judged (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | what is not analysed: counted, never judged a public function of a module whose external behaviour gave no callbacks |
| PS-P | an unknown module is judged (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | what is not analysed: counted, never judged a module that may be generated |
| PS-Q | a function with no summary is exempt (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | what is not analysed: counted, never judged a function with no summary |
| PS-R | a macro is counted (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | what is not analysed: counted, never judged a macro is neither judged nor counted; the summary prints the precision counts, and the apply site that fell to any |
| PS-S | the floor issue never speaks (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | exempt functions a function of a generated module; the floor selected modules of which nothing could be judged: one fail-closed issue |
| PS-T | the position in the key is 0-based (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 11 failures` (red) | exempt functions not exempt: the positive control for this block; exempt functions a hand-written argument beside a generated one keeps the function judged; check/2 a dropped chain is a violation at each level, naming the callee; exempt functions a dynamic call with a computed name exempts nothing; exempt functions a function of a behaviour module that is no callback is judged; what is not analysed: counted, never judged a private function of that module is still judged: no behaviour fixes it |
| PS-U | the chain follows a used callee (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | check/2 a callee outside the summaries, or an unknown lambda, ends the chain; check/2 the chain follows an absent callee, past one that is not, and stops at recursion |
| PS-V | the chain stops at once (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 3 failures` (red) | check/2 the chain follows an absent callee, past one that is not, and stops at recursion; check/2 a dropped chain is a violation at each level, naming the callee; the message names the parameter, its chain and its call sites |
| PS-W | a lambda callee is never absent (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | the message names the parameter, its chain and its call sites |
| PS-X | call sites are not counted (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | check/2 a dropped chain is a violation at each level, naming the callee; the message names the parameter, its chain and its call sites |
| PS-Y | the name ignores the = pattern's variable (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 1 failure` (red) | check/2 the parameter's name comes from the first clause that names it |
| PS-Z | _ reads as a name (`lib/anchor/domain/graph_rules/parameter_reaches_sink.ex`) | `parameter_reaches_sink_test.exs`, `parameter_reaches_sink_canary_test.exs` | `37 tests, 2 failures` (red) | check/2 the parameter's name comes from the first clause that names it; check/2 a position with no variable in any clause is arg<position> |
| PR-A | the runner never runs the analysis (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `14 tests, 7 failures` (red) | the analysis runs once for two rules, with the config's effect tokens; the rule reads the callbacks the behaviour port read; a needing rule over code with no apply sites: a measured zero, never null; a crashed effect inference does not stop a rule that needs only demand; the summary prints the precision counts, and the apply site that fell to any; exactly the dropped parameters are findings; every compliant and exempt one is not |
| PR-B | the analysis runs whatever the rules need (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | no rule that runs needs it: not run, no counts, null in the JSON |
| PR-C | the config effect tokens are dropped (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | the analysis runs once for two rules, with the config's effect tokens |
| PR-D | the callbacks read are dropped (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `14 tests, 2 failures` (red) | the summary prints the precision counts, and the apply site that fell to any; the rule reads the callbacks the behaviour port read |
| PR-E | a return that is no %Demand{} is taken for one (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| PR-F | a crashed demand analysis reads as nil: the rule runs without it (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `11 tests, 5 failures` (red) | an analysis that raises: the rule that needs it is one issue and is not run; the others run; a behaviour read that raises is the same one issue; both crashed: the rule that needs demand reports demand; a crashed demand analysis does not stop a rule that needs only effects; an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| PR-G | a crashed effect inference stops the demand clause (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | both crashed: the rule that needs demand reports demand |
| PR-H | the counts are always nil (`lib/anchor/managers/graph.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `14 tests, 4 failures` (red) | the rule reads the callbacks the behaviour port read; a needing rule over code with no apply sites: a measured zero, never null; the analysis runs once for two rules, with the config's effect tokens; the summary prints the precision counts, and the apply site that fell to any |
| PR-I | two rules do not add (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | the analysis runs once for two rules, with the config's effect tokens |
| PR-J | the imprecise count is a constant (`lib/anchor/domain/graph_report.ex`) | `parameter_reaches_sink_canary_test.exs` | `3 tests, 1 failure` (red) | the summary prints the precision counts, and the apply site that fell to any |
| PR-K | the note is dropped (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs`, `parameter_reaches_sink_canary_test.exs` | `14 tests, 2 failures` (red) | a needing rule over code with no apply sites: a measured zero, never null; the summary prints the precision counts, and the apply site that fell to any |
| PR-L | the JSON reads a measured zero as null (`lib/anchor/domain/graph_report.ex`) | `graph_demand_test.exs` | `11 tests, 1 failure` (red) | a needing rule over code with no apply sites: a measured zero, never null |

## PS-0 — the demand-less rule is read clean instead of refused

Run summary: `37 tests, 1 failure`

```text
1) test check/2 the rule refuses a model with no demand analysis: never a clean read (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:176
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn ->
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:177: (test)

.................
```

## PS-A — the absent check reads any parameter as dropped

Run summary: `37 tests, 10 failures`

```text
1) test check/2 the rule selects: a module it does not select is not judged (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:167
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
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:173: (test)

....
```

## PS-B — drop the capture exemption (QA)

Run summary: `37 tests, 2 failures`

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

...................
```

## PS-C — treat unresolved applies as non-demanding (QA)

Run summary: `37 tests, 1 failure`

```text
1) test exactly the dropped parameters are findings; every compliant and exempt one is not (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:70
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "sinks|#{@drops}.count/2|param 1",
              "sinks|#{@drops}.count_from/2|param 2",
              "sinks|#{@drops}.f/2|param 2",
              "sinks|#{@drops}.g/1|param 1",
              "sinks|#{@drops}.price/2|param 2",
              "sinks|#{@drops}.via_lambda/1|param 1"
            ]
     left:  ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.count_from/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Uses.invoked/2|param 2"]
     right: ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.count_from/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1"]
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:78: (test)
```

## PS-D — ignore guards (QA)

Run summary: `37 tests, 1 failure`

```text
1) test exactly the dropped parameters are findings; every compliant and exempt one is not (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:70
     Assertion with == failed
     code:  assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
              "sinks|#{@drops}.count/2|param 1",
              "sinks|#{@drops}.count_from/2|param 2",
              "sinks|#{@drops}.f/2|param 2",
              "sinks|#{@drops}.g/1|param 1",
              "sinks|#{@drops}.price/2|param 2",
              "sinks|#{@drops}.via_lambda/1|param 1"
            ]
     left:  ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.count_from/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Uses.guarded/2|param 2"]
     right: ["sinks|AnchorFixtures.ParameterSinks.Drops.count/2|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.count_from/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.f/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.g/1|param 1",
             "sinks|AnchorFixtures.ParameterSinks.Drops.price/2|param 2",
             "sinks|AnchorFixtures.ParameterSinks.Drops.via_lambda/1|param 1"]
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:78: (test)
```

## PS-E — drop the callback exemption

Run summary: `37 tests, 3 failures`

```text
1) test exempt functions a callback of a project behaviour, read from the graph (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:220
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
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:225: (test)

................
```

## PS-F — drop the dynamic-call exemption

Run summary: `37 tests, 4 failures`

```text
1) test exempt functions a dynamic call cannot reach a private function (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:266
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  ["sinks|D.f/1|param 1", "sinks|D.f/2|param 1"]
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:271: (test)

.......................
```

## PS-G — a call with no known arity reaches no arity

Run summary: `37 tests, 2 failures`

```text
1) test exempt functions a dynamic call cannot reach a private function (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:266
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  ["sinks|D.f/1|param 1", "sinks|D.f/2|param 1"]
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:271: (test)

.................
```

## PS-G2 — a call of one arity reaches every arity

Run summary: `37 tests, 1 failure`

```text
1) test exempt functions a public function a dynamic call can reach, and not another arity (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:249
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  []
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:255: (test)

...............
```

## PS-G3 — a dynamic call can reach a private function

Run summary: `37 tests, 1 failure`

```text
1) test exempt functions a dynamic call cannot reach a private function (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:266
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  []
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:271: (test)

....
```

## PS-H — drop the generated-module exemption

Run summary: `37 tests, 1 failure`

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

................
```

## PS-I — drop the __name__ exemption

Run summary: `37 tests, 1 failure`

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

.........
```

## PS-J — drop the quote generated exemption

Run summary: `37 tests, 1 failure`

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

.........................
```

## PS-K — drop the macro context exemption

Run summary: `37 tests, 2 failures`

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

............................
```

## PS-L — drop the default-head exemption

Run summary: `37 tests, 1 failure`

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

....
```

## PS-M — a head with any generated argument is generated

Run summary: `37 tests, 1 failure`

```text
1) test exempt functions a hand-written argument beside a generated one keeps the function judged (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:317
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
     left:  [nil]
     right: ["sinks|D.f/2|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:326: (test)

..............................
```

## PS-N — a private function is always judged, even captured

Run summary: `37 tests, 2 failures`

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

...........................
```

## PS-O — an unread behaviour is judged

Run summary: `37 tests, 1 failure`

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

...............
```

## PS-P — an unknown module is judged

Run summary: `37 tests, 1 failure`

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

..............
```

## PS-Q — a function with no summary is exempt

Run summary: `37 tests, 1 failure`

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

..............
```

## PS-R — a macro is counted

Run summary: `37 tests, 2 failures`

```text
1) test what is not analysed: counted, never judged a macro is neither judged nor counted (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:360
     Assertion with == failed
     code:  assert ParameterReachesSink.counts(model, @rule) == %{judged: 1, exempt: 0, not_analysed: 0}
     left:  %{judged: 1, exempt: 0, not_analysed: 1}
     right: %{judged: 1, exempt: 0, not_analysed: 0}
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:362: (test)
```

## PS-S — the floor issue never speaks

Run summary: `37 tests, 2 failures`

```text
1) test exempt functions a function of a generated module (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:283
     match (=) failed
     code:  assert [%{kind: :fail_closed}] = ParameterReachesSink.check(model, @rule)
     left:  [%{kind: :fail_closed}]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:287: (test)

......
```

## PS-T — the position in the key is 0-based

Run summary: `37 tests, 11 failures`

```text
1) test exempt functions not exempt: the positive control for this block (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:207
     Assertion with == failed
     code:  assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
     left:  ["sinks|D.f/1|param 0"]
     right: ["sinks|D.f/1|param 1"]
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:210: (test)

..
```

## PS-U — the chain follows a used callee

Run summary: `37 tests, 2 failures`

```text
1) test check/2 a callee outside the summaries, or an unknown lambda, ends the chain (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:123
     ** (KeyError) key {Other, :g, 1} not found in:

         %{
           {D, :f, 1} => [
             %Anchor.Domain.Demand.Param{
               demand: :absent,
               passes: [{{Other, :g, 1}, 0}, {{{D, :f, 1}, 9}, 0}],
               imprecise?: false
             }
           ]
         }

     code: assert [violation] = ParameterReachesSink.check(model, @rule)
     stacktrace:
       :erlang.map_get({Other, :g, 1}, %{{D, :f, 1} => [%Anchor.Domain.Demand.Param{demand: :absent, passes: [{{Other, :g, 1}, 0}, {{{D, :f, 1}, 9}, 0}], imprecise?: false}]})
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:286: Anchor.Domain.GraphRules.ParameterReachesSink.passes/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:277: Anchor.Domain.GraphRules.ParameterReachesSink.steps/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:281: Anchor.Domain.GraphRules.ParameterReachesSink.steps/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:268: Anchor.Domain.GraphRules.ParameterReachesSink.chain/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:231: Anchor.Domain.GraphRules.ParameterReachesSink.violation/5
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:109: anonymous fn/6 in Anchor.Domain.GraphRules.ParameterReachesSink.check/2
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:106: Anchor.Domain.GraphRules.ParameterReachesSink.check/2
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:131: (test)

.........
```

## PS-V — the chain stops at once

Run summary: `37 tests, 3 failures`

```text
1) test check/2 the chain follows an absent callee, past one that is not, and stops at recursion (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:109
     Assertion with =~ failed
     code:  assert f.message =~ "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     left:  "D.f/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/1 and stop passing it at its 0 call sites."
     right: "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:119: (test)

......
```

## PS-W — a lambda callee is never absent

Run summary: `37 tests, 1 failure`

```text
1) test the message names the parameter, its chain and its call sites (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:92
     Assertion with =~ failed
     code:  assert finding(report, "via_lambda/1|param 1").message =~
              "#{@drops}.via_lambda/1 param 1 -> fn 0 in #{@drops}.via_lambda/1 param 1 (dropped)"
     left:  "AnchorFixtures.ParameterSinks.Drops.via_lambda/1 parameter 1 (unused) reaches no return value and no effect (chain: AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (unused) of AnchorFixtures.ParameterSinks.Drops.via_lambda/1 and stop passing it at its 0 call sites."
     right: "AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 -> fn 0 in AnchorFixtures.ParameterSinks.Drops.via_lambda/1 param 1 (dropped)"
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:114: (test)

..
```

## PS-X — call sites are not counted

Run summary: `37 tests, 2 failures`

```text
1) test check/2 a dropped chain is a violation at each level, naming the callee (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:92
     Assertion with =~ failed
     code:  assert g.message =~ "call sites: 1"
     left:  "D.g/1 parameter 1 (arg1) reaches no return value and no effect (chain: D.g/1 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.g/1 and stop passing it at its 0 call sites."
     right: "call sites: 1"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:105: (test)

...................
```

## PS-Y — the name ignores the = pattern's variable

Run summary: `37 tests, 1 failure`

```text
1) test check/2 the parameter's name comes from the first clause that names it (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:135
     Assertion with =~ failed
     code:  assert first.message =~ "parameter 1 (named)"
     left:  "D.f/2 parameter 1 (arg1) reaches no return value and no effect (chain: D.f/2 param 1 (dropped); call sites: 0). Fix: drop parameter 1 (arg1) of D.f/2 and stop passing it at its 0 call sites."
     right: "parameter 1 (named)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:151: (test)

..........................
```

## PS-Z — _ reads as a name

Run summary: `37 tests, 2 failures`

```text
1) test check/2 the parameter's name comes from the first clause that names it (Anchor.Domain.GraphRules.ParameterReachesSinkTest)
     test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:135
     Assertion with =~ failed
     code:  assert second.message =~ "parameter 2 (_opts)"
     left:  "D.f/2 parameter 2 (_) reaches no return value and no effect (chain: D.f/2 param 2 (dropped); call sites: 0). Fix: drop parameter 2 (_) of D.f/2 and stop passing it at its 0 call sites."
     right: "parameter 2 (_opts)"
     stacktrace:
       test/anchor/domain/graph_rules/parameter_reaches_sink_test.exs:152: (test)

....
```

## PR-A — the runner never runs the analysis

Run summary: `14 tests, 7 failures`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:156
     ** (KeyError) key :parameter_sinks not found in:

         %{
           modules: 1,
           opaque: 0,
           apps: 1,
           rules: 2,
           no_core: 0,
           outside_root: 0,
           apply_sites: %{
             any: 0,
             total: 0,
             resolved: 0,
             by_function: %{},
             bound_hit?: false
           },
           interface_width: nil,
           dynamic_calls: %{narrowed: [], fanned_out: []}
         }

     code: assert %{judged: 4, precise: 0} = report.counts.parameter_sinks
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:172: (test)
```

## PR-B — the analysis runs whatever the rules need

Run summary: `11 tests, 1 failure`

```text
1) test no rule that runs needs it: not run, no counts, null in the JSON (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:101
     Unexpectedly received message :read_behaviours (which matched :read_behaviours)
     code: refute_received :read_behaviours
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:118: (test)

......
```

## PR-C — the config effect tokens are dropped

Run summary: `11 tests, 1 failure`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:156
     Assertion failed, no matching message after 0ms
     Showing 1 of 1 message in the mailbox
     code: assert_received {:analysed, ["Req"]}
     mailbox:
       pattern: {:analysed, ["Req"]}
       value:   {:analysed, []}
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:167: (test)

.........
```

## PR-D — the callbacks read are dropped

Run summary: `14 tests, 2 failures`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:118
     Assertion with == failed
     code:  assert not_analysed == 0
     left:  2
     right: 0
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:136: (test)
```

## PR-E — a return that is no %Demand{} is taken for one

Run summary: `11 tests, 1 failure`

```text
1) test an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:202
     Assertion with =~ failed
     code:  assert issue.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.ParameterReachesSink.check/2 (raised at lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:102: Anchor.Domain.GraphRules.ParameterReachesSink.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:209: (test)

.........
```

## PR-F — a crashed demand analysis reads as nil: the rule runs without it

Run summary: `11 tests, 5 failures`

```text
1) test an analysis that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:202
     Assertion with =~ failed
     code:  assert issue.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed: RuntimeError: demand blew up (raised at anonymous fn/3 in Anchor.Managers.GraphDemandTest.\"test an analysis that raises: the rule that needs it is one issue and is not run; the others run\"/1), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:209: (test)

.
```

## PR-G — a crashed effect inference stops the demand clause

Run summary: `11 tests, 1 failure`

```text
1) test both crashed: the rule that needs demand reports demand (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:254
     Assertion with =~ failed
     code:  assert demand.message =~ "the demand analysis it needs"
     left:  "rule 1 (id: \"sinks\", parameter_reaches_sink) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.ParameterReachesSink.check/2 (raised at lib/anchor/domain/graph_rules/parameter_reaches_sink.ex:102: Anchor.Domain.GraphRules.ParameterReachesSink.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:265: (test)

......
```

## PR-H — the counts are always nil

Run summary: `14 tests, 4 failures`

```text
1) test the rule reads the callbacks the behaviour port read (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:175
     match (=) failed
     code:  assert %{exempt: 1} = report.counts.parameter_sinks
     left:  %{exempt: 1}
     right: nil
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:193: (test)
```

## PR-I — two rules do not add

Run summary: `11 tests, 1 failure`

```text
1) test the analysis runs once for two rules, with the config's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:156
     match (=) failed
     code:  assert %{judged: 4, precise: 0} = report.counts.parameter_sinks
     left:  %{judged: 4, precise: 0}
     right: %{
              any: 0,
              not_analysed: 0,
              precise: 0,
              imprecise: 0,
              judged: 2,
              exempt: 0
            }
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:172: (test)

......
```

## PR-J — the imprecise count is a constant

Run summary: `3 tests, 1 failure`

```text
1) test the summary prints the precision counts, and the apply site that fell to any (Anchor.Integration.ParameterReachesSinkCanaryTest)
     test/anchor/integration/parameter_reaches_sink_canary_test.exs:118
     Uses.applied/3 passes p to an apply/3 Core does not name
     code: assert imprecise > 0, "Uses.applied/3 passes p to an apply/3 Core does not name"
     stacktrace:
       test/anchor/integration/parameter_reaches_sink_canary_test.exs:133: (test)

.
```

## PR-K — the note is dropped

Run summary: `14 tests, 2 failures`

```text
1) test a needing rule over code with no apply sites: a measured zero, never null (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:125
     Assertion with =~ failed
     code:  assert summary =~
              "; parameter_reaches_sink: 0 apply sites precise, 0 fell to any, " <>
                "0 imprecise parameters, 2 functions judged, 0 exempt, 0 not analysed"
     left:  "anchor.graph: 1 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 0 any; sinks: 0 apply sites precise, 0 fell to any, 0 imprecise parameters, 2 functions judged, 0 exempt, 0 not analysed"
     right: "; parameter_reaches_sink: 0 apply sites precise, 0 fell to any, 0 imprecise parameters, 2 functions judged, 0 exempt, 0 not analysed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:146: (test)

......
```

## PR-L — the JSON reads a measured zero as null

Run summary: `11 tests, 1 failure`

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
```
