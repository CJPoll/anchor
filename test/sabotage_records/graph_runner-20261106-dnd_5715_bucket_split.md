# Sabotage record: the demand analysis in `mix anchor.graph` (DND-5715)

- **Domain:** graph_runner
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Managers.Graph` (the lazy, guarded `Demand.analyze/3` run and `Model.demand`, the crash chain in `run_check`, `unreadable_issues`), `GraphRules.needs/1`
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: 257f359, 2d8b756. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| GR-A | the demand analysis is never run | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs`, `analyses_complete_integration_test.exs` | `21 tests, 17 failures` | analyses_complete fails the run closed on a floor the analyses fell below, each reported; analyses_complete fails the run closed on a flow analysis that hit its step bound; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a demand analysis that hit its round bound; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above); fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed the effect inference and the demand analysis both crashed: each rule says its own; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a function the analysis left unsummarised; real beams through the real read path: clean, with the known results; violating: a flow analysis that hit its bound fails the run; violating: a demand analysis that hit its bound fails the run; violating: a floor above what the project holds fails the run |
| GR-B | the analysis runs whatever the rules need | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `16 tests, 2 failures` | no rule that runs needs the analysis --only narrowing away the rule that needs it: not run; no rule that runs needs the analysis it is not run, and the rule that does not need it sees none |
| GR-C | the analysis runs twice | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 1 failure` | a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens |
| GR-D | the architecture's effect tokens are not passed | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 1 failure` | a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens |
| GR-E | a crashed analysis is ignored: the rule runs without it | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 5 failures` | fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; fail closed the effect inference and the demand analysis both crashed: each rule says its own; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run |
| GR-F | an analysis that returns no %Demand{} is accepted | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 1 failure` | fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run |
| GR-G | after a crashed effect inference a rule runs without looking at demand | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 1 failure` | fail closed the effect inference and the demand analysis both crashed: each rule says its own |
| GR-H | a crashed flow analysis still runs the demand analysis | `lib/anchor/managers/graph.ex` | `graph_demand_test.exs` | `14 tests, 1 failure` | fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why |
| GR-I | the runner does not provide :demand | `lib/anchor/domain/graph_rules.ex` | `graph_rules_test.exs`, `graph_demand_test.exs` | `27 tests, 14 failures` | needs/1 (DND-5574) the rule that holds the analyses complete needs the flow analysis and demand; needs/1 (DND-5574) a need the runner does not compute raises, naming it and what it computes; needs/1 (DND-5574) a needs/0 that is not a list raises; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a function the analysis left unsummarised; analyses_complete fails the run closed on a demand analysis that hit its round bound; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run; fail closed the effect inference and the demand analysis both crashed: each rule says its own; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed on a flow analysis that hit its step bound; fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why |
| GR-J | an unreadable beam is no issue | `lib/anchor/managers/graph.ex` | `analyses_complete_integration_test.exs` | `5 tests, 1 failure` | a beam on disk that cannot be read fails the run, naming it |

## Failure strings (verbatim, the first failing test of each row)

### GR-A: the demand analysis is never run

```

  1) test analyses_complete fails the run closed on a floor the analyses fell below, each reported (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:217
     match (=) failed
     code:  assert [functions, sites, absent] = report.findings
     left:  [functions, sites, absent]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor.yml",
                line: nil,
                message: "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:47: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:223: (test)
```

### GR-B: the analysis runs whatever the rules need

```

  1) test no rule that runs needs the analysis --only narrowing away the rule that needs it: not run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:136
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:139: (test)
```

### GR-C: the analysis runs twice

```

  1) test a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:145
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:150: (test)
```

### GR-D: the architecture's effect tokens are not passed

```

  1) test a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:145
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

  1) test fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:224
     Assertion with =~ failed
     code:  assert crashed.message =~
              ~s|rule 1 (id: "complete", analyses_complete) could not run: the demand | <>
                "analysis it needs (Anchor.Domain.Demand) crashed: #{"ArgumentError: the analysis returned :oops, not a %Demand{}"}"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:38: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "rule 1 (id: \"complete\", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: ArgumentError: the analysis returned :oops, not a %Demand{}"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:234: (test)
```

### GR-F: an analysis that returns no %Demand{} is accepted

```

  1) test fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:224
     Assertion with =~ failed
     code:  assert crashed.message =~
              ~s|rule 1 (id: "complete", analyses_complete) could not run: the demand | <>
                "analysis it needs (Anchor.Domain.Demand) crashed: #{"ArgumentError: the analysis returned :oops, not a %Demand{}"}"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:38: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "rule 1 (id: \"complete\", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: ArgumentError: the analysis returned :oops, not a %Demand{}"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:234: (test)
```

### GR-G: after a crashed effect inference a rule runs without looking at demand

```

  1) test fail closed the effect inference and the demand analysis both crashed: each rule says its own (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:243
     Assertion with =~ failed
     code:  assert demand.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     left:  "rule 1 (id: \"complete\", analyses_complete) could not run: FunctionClauseError: no function clause matching in Anchor.Domain.GraphRules.AnalysesComplete.check/2 (raised at lib/anchor/domain/graph_rules/analyses_complete.ex:38: Anchor.Domain.GraphRules.AnalysesComplete.check/2), so it checked nothing. Fix: this is an Anchor bug; file it with this line."
     right: "the demand analysis it needs (Anchor.Domain.Demand) crashed"
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:254: (test)
```

### GR-H: a crashed flow analysis still runs the demand analysis

```

  1) test fail closed a flow analysis that crashed: the demand analysis is not run, and the rule says why (Anchor.Managers.GraphDemandTest)
     test/anchor/managers/graph_demand_test.exs:258
     Unexpectedly received message :demand_ran (which matched :demand_ran)
     code: refute_received :demand_ran
     stacktrace:
       test/anchor/managers/graph_demand_test.exs:262: (test)
```

### GR-I: the runner does not provide :demand

```

  1) test needs/1 (DND-5574) the rule that holds the analyses complete needs the flow analysis and demand (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:45
     ** (ArgumentError) Anchor.Domain.GraphRules.AnalysesComplete.needs/0 names [:demand], which the graph runner does not compute (it computes [:cfa, :effects])
     code: assert GraphRules.needs(GraphRules.AnalysesComplete) == [:cfa, :demand]
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph_rules.ex:123: Anchor.Domain.GraphRules.provided_needs!/2
       test/anchor/domain/graph_rules_test.exs:46: (test)
```

### GR-J: an unreadable beam is no issue

```

  1) test a beam on disk that cannot be read fails the run, naming it (Anchor.Integration.AnalysesCompleteIntegrationTest)
     test/anchor/integration/analyses_complete_integration_test.exs:135
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/analyses_complete_integration_test.exs:140: (test)
```
