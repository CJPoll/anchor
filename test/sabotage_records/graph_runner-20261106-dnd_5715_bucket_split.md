# Sabotage record: the demand analysis in `mix anchor.graph` (DND-5715)

- **Domain:** graph_runner
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Managers.Graph` (the lazy, guarded `Demand.analyze/3` run and `Model.demand`, the crash chain in `run_check`, `unreadable_issues`), `GraphRules.needs/1`, `Anchor.Domain.GraphReport` (the demand counts in the summary and the JSON)
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: 667ab06, d32964e. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| GR-A | the demand analysis is never run | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs`, `analyses_complete_integration_test.exs` | `21 tests, 17 failures` | real beams through the real read path: clean, with the known results; analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; violating: a flow analysis that hit its bound fails the run; fail closed the effect inference and the demand analysis both crashed: each rule says its own; analyses_complete fails the run closed on a demand analysis that hit its round bound; analyses_complete fails the run closed on a flow analysis that hit its step bound; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above); fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a floor the analyses fell below, each reported; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; analyses_complete fails the run closed on a function the analysis left unsummarised; violating: a floor above what the project holds fails the run; violating: a demand analysis that hit its bound fails the run |
| GR-B | the analysis runs whatever the rules need | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 2 failures` | no rule that runs needs the analysis it is not run, and the rule that does not need it sees none; no rule that runs needs the analysis --only narrowing away the rule that needs it: not run |
| GR-C | the analysis runs twice | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 1 failure` | a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens |
| GR-D | the architecture's effect tokens are not passed | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 1 failure` | a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens |
| GR-E | a crashed analysis is ignored: the rule runs without it | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 5 failures` | fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; fail closed the effect inference and the demand analysis both crashed: each rule says its own; fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run |
| GR-F | an analysis that returns no %Demand{} is accepted | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 1 failure` | fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| GR-G | after a crashed effect inference a rule runs without looking at demand | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 1 failure` | fail closed the effect inference and the demand analysis both crashed: each rule says its own |
| GR-H | a crashed flow analysis still runs the demand analysis | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 1 failure` | fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why |
| GR-I | the runner does not provide :demand | `lib/anchor/domain/graph_rules.ex` | `graph_rules_test.exs`, `graph_demand_test.exs` | `32 tests, 17 failures` | needs/1 (DND-5574) a needs/0 that is not a list raises; needs/1 (DND-5574) the rule that holds the analyses complete needs the flow analysis and demand; needs/1 (DND-5574) a need the runner does not compute raises, naming it and what it computes; analyses_complete fails the run closed on a flow analysis that hit its step bound; fail closed the effect inference and the demand analysis both crashed: each rule says its own; analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above); fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a function the analysis left unsummarised; fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; analyses_complete fails the run closed on a demand analysis that hit its round bound; fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why; analyses_complete fails the run closed on a floor the analyses fell below, each reported; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding |
| GR-J | an unreadable beam is no issue | `lib/anchor/managers/graph.ex` | `analyses_complete_integration_test.exs` | `5 tests, 1 failure` | a beam on disk that cannot be read fails the run, naming it |
| GR-K | the counts are not put on the report | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 2 failures` | a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed on a demand analysis that hit its round bound |
| RP-A | the summary never prints the demand counts | `lib/anchor/domain/graph_report.ex` | `graph_demand_test.exs`, `graph_report_test.exs` | `46 tests, 4 failures` | demand counts (DND-5715) a hit round bound is said, with how many functions hit it; demand counts (DND-5715) the summary ends with the counts when the analysis ran, with no finding; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed on a demand analysis that hit its round bound |
| RP-B | a hit round bound is not said | `lib/anchor/domain/graph_report.ex` | `graph_demand_test.exs`, `graph_report_test.exs` | `46 tests, 2 failures` | demand counts (DND-5715) a hit round bound is said, with how many functions hit it; analyses_complete fails the run closed on a demand analysis that hit its round bound |
| RP-C | the JSON always says null | `lib/anchor/domain/graph_report.ex` | `graph_demand_test.exs`, `graph_report_test.exs` | `46 tests, 2 failures` | demand counts (DND-5715) the JSON carries the same counts under string keys; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding |
| RP-D | no analysis still prints a demand note | `lib/anchor/domain/graph_report.ex` | `graph_demand_test.exs`, `graph_report_test.exs` | `46 tests, 9 failures` | demand counts (DND-5715) no analysis says nothing in the summary, and null in the JSON; render/2 :text one line per finding, then the summary with exact counts; apply sites (DND-5574, R6) the summary ends with the resolved and any counts when the analysis ran; render/2 functions with no Core body (DND-5549) are counted in the summary and the JSON when there are any; render/2 :text opaque modules are counted in the summary when there are any; render/2 modules outside the root (DND-5588, DND-5630) are counted in the summary and the JSON when there are any; render/2 :text could-not-check entries print first and count as violations; dynamic calls (DND-5633) the summary ends with the fanned-out and narrowed counts; no rule that runs needs the analysis it is not run, and the rule that does not need it sees none |
| RP-E | the bound is printed as a list length of one | `lib/anchor/domain/graph_report.ex` | `graph_report_test.exs` | `30 tests, 1 failure` | demand counts (DND-5715) demand/1 takes the counts from the analysis, and the bound as a count; nil for none |

## Failure strings (verbatim, the first failing test of each row)

### GR-A: the demand analysis is never run

```



  1) test real beams through the real read path: clean, with the known results (Anchor.Integration.AnalysesCompleteIntegrationTest)
     test/anchor/integration/analyses_complete_integration_test.exs:83
     Assertion with == failed
     code:  assert report.findings == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "test/fixtures/graph_canary/analyses_complete/.anchor.yml",
                line: nil,
                message: "rule 1 (id: \"analyses_complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:44: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              }
            ]
     right: []
     stacktrace:
       test/anchor/integration/analyses_complete_integration_test.exs:94: (test)
```

### GR-B: the analysis runs whatever the rules need

```



  1) test no rule that runs needs the analysis it is not run, and the rule that does not need it sees none (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:130
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:133: (test)
```

### GR-C: the analysis runs twice

```

  1) test a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:149
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:154: (test)
```

### GR-D: the architecture's effect tokens are not passed

```

  1) test a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:149
     Assertion failed, no matching message after 0ms
     Showing 1 of 1 message in the mailbox
     code: assert_received {:demand_result, %Cfa{} = cfa, ["AnchorFixtures.GraphDemandTest.Extra"], demand}
     mailbox:
       pattern: {:demand_result, %Anchor.Domain.Cfa{} = cfa, ["AnchorFixtures.GraphDemandTest.Extra"], demand}
       value:   {:demand_result,
                 %Anchor.Domain.Cfa{
                   sites: %{
                     {{AnchorFixtures.GraphDemandTest.Flow,
                       :doubled, 1}, 0} => {:ok,
                      MapSet.new([
                        {{AnchorFixtures.GraphDemandTest.Flow,
                          :doubled, 1}, 0}
                      ])}
                   },
                   returns: %{
                     {AnchorFixtures.GraphDemandTest.Flow,
                      :doubled, 1} => :any,
                     {AnchorFixtures.GraphDemandTest.Flow,
                      :first, 2} => :any,
                     {AnchorFixtures.GraphDemandTest.Flow,
                      :ping, 2} => :any,
                     {AnchorFixtures.GraphDemandTest.Flow,
                      :pong, 2} => :any
                   },
           
```

### GR-E: a crashed analysis is ignored: the rule runs without it

```

  1) test fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:266
     Assertion with =~ failed
     code:  assert crashed.message =~
              ~s|rule 1 (id: "complete", analyses_complete) could not run: the demand | <>
                "analysis it needs (Anchor.Domain.Demand) crashed: #{"RuntimeError: demand blew up"}"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:44: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "rule 1 (id: \"complete\", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: RuntimeError: demand blew up"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:276: (test)
```

### GR-F: an analysis that returns no %Demand{} is accepted

```

  1) test fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:266
     Assertion with =~ failed
     code:  assert crashed.message =~
              ~s|rule 1 (id: "complete", analyses_complete) could not run: the demand | <>
                "analysis it needs (Anchor.Domain.Demand) crashed: #{"ArgumentError: the analysis returned :oops, not a %Demand{}"}"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:44: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "rule 1 (id: \"complete\", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: ArgumentError: the analysis returned :oops, not a %Demand{}"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:276: (test)
```

### GR-G: after a crashed effect inference a rule runs without looking at demand

```

  1) test fail closed the effect inference and the demand analysis both crashed: each rule says its own (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:285
     Assertion with =~ failed
     code:  assert demand.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:44: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:296: (test)
```

### GR-H: a crashed flow analysis still runs the demand analysis

```

  1) test fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:300
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:304: (test)
```

### GR-I: the runner does not provide :demand

```



  1) test needs/1 (DND-5574) a needs/0 that is not a list raises (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:60
     Assertion with == failed
     code:  assert error.message ==
              "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa, :effects, :demand]"
     left:  "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa, :effects]"
     right: "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa, :effects, :demand]"
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:63: (test)
```

### GR-J: an unreadable beam is no issue

```



  1) test a beam on disk that cannot be read fails the run, naming it (Anchor.Integration.AnalysesCompleteIntegrationTest)
     test/anchor/integration/analyses_complete_integration_test.exs:147
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/analyses_complete_integration_test.exs:152: (test)
```

### GR-K: the counts are not put on the report

```

  1) test a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:167
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; demand: 4 functions, 7 parameters, 1 absent, 0 imprecise functions"
     left:  "anchor.graph: 1 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined); apply sites: 1 resolved, 0 any"
     right: "; demand: 4 functions, 7 parameters, 1 absent, 0 imprecise functions"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:175: (test)
```

### RP-A: the summary never prints the demand counts

```

  1) test demand counts (DND-5715) a hit round bound is said, with how many functions hit it (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:227
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~ "2 imprecise functions (round bound hit on 3 functions)"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "2 imprecise functions (round bound hit on 3 functions)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:230: (test)
```

### RP-B: a hit round bound is not said

```

  1) test demand counts (DND-5715) a hit round bound is said, with how many functions hit it (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:227
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~ "2 imprecise functions (round bound hit on 3 functions)"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); demand: 4 functions, 7 parameters, 1 absent, 2 imprecise functions"
     right: "2 imprecise functions (round bound hit on 3 functions)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:230: (test)
```

### RP-C: the JSON always says null

```

  1) test demand counts (DND-5715) the JSON carries the same counts under string keys (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:241
     Assertion with == failed
     code:  assert JSON.decode!(GraphReport.render(report, :json))["demand"] == %{
              "functions" => 4,
              "parameters" => 7,
              "absent" => 1,
              "imprecise_functions" => 2,
              "bound_hit" => 0
            }
     left:  nil
     right: %{
              "absent" => 1,
              "bound_hit" => 0,
              "functions" => 4,
              "imprecise_functions" => 2,
              "parameters" => 7
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:244: (test)
```

### RP-D: no analysis still prints a demand note

```

  1) test demand counts (DND-5715) no analysis says nothing in the summary, and null in the JSON (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:234
     Refute with =~ failed
     code:  refute GraphReport.summary(report) =~ "demand"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); demand: none"
     right: "demand"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:237: (test)
```

### RP-E: the bound is printed as a list length of one

```

  1) test demand counts (DND-5715) demand/1 takes the counts from the analysis, and the bound as a count; nil for none (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:208
     Assertion with == failed
     code:  assert GraphReport.demand(analysis) == %{@demand | bound_hit: 3}
     left:  %{
              functions: 4,
              parameters: 7,
              absent: 1,
              imprecise_functions: 2,
              bound_hit: 1
            }
     right: %{
              functions: 4,
              parameters: 7,
              absent: 1,
              imprecise_functions: 2,
              bound_hit: 3
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:214: (test)
```
