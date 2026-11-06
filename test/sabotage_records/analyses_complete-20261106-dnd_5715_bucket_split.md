# Sabotage record: the `analyses_complete` graph rule and CI's dogfood run (DND-5715)

- **Domain:** analyses_complete
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.AnalysesComplete`, its `Anchor.Domain.Failures` messages, its `RuleSchema` and `Anchor.Config` keys, its registration in `GraphRules.all/0`, and `mix anchor.graph` over Anchor's own lib/
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: 257f359, 4e3798f. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

## What each removed assertion became

`test/anchor/integration/demand_self_test.exs` and `cfa_self_test.exs` are gone. Each assertion, and what proves it now:

| Removed assertion | Proven now by | Seen failing |
|---|---|---|
| demand and cfa: `graph.unreadable == []` over Anchor | `mix anchor.graph` (`unreadable_issues`, exit 1); `analyses_complete_integration_test.exs` "a beam on disk that cannot be read fails the run, naming it"; `graph_test.exs` "a beam with no debug_info is an issue on it" | DF-D, GR-J |
| cfa: `Map.has_key?(graph.modules, Cfa)` | the rule's `min_modules` in `.anchor.yml` (185 on this branch's base, 201 once main came in) | DF-E |
| cfa: `refute cfa.bound_hit?` over Anchor | `analyses_complete` in `mix anchor.graph` | DF-A, AC-A |
| demand: `demand.bound_hit == []` over Anchor | `analyses_complete` in `mix anchor.graph` | DF-B, AC-B |
| "every function summarised" over Anchor | `analyses_complete` in `mix anchor.graph` | DF-C, AC-C |
| demand: `counts.functions == map_size(summaries)`, `counts.parameters == flatten(summaries)` | `demand_test.exs` "the counts agree with the summaries they count" | DM-C, DM-D |
| cfa: `counts.total == map_size(sites)` | `cfa_test.exs` "the total is the number of sites, every one resolved or any" | CF-B, CF-C |
| demand: `Lattice.at/2` param 0 and `join/2` param 1 are `:all` | `demand_test.exs` "a lattice's shape" rows, on a copy of those clauses | DM-A |
| cfa: `default_seed/1`'s two sites each resolve to one of its own lambdas | `cfa_test.exs` "a pipeline of two literal fns under the default seed" | CF-A |
| demand: `counts.functions > 500` over Anchor | `min_functions: 501` in `.anchor.yml` | DF-G, AC-N |
| cfa: `counts.total > 100` over Anchor | `min_apply_sites: 101` in `.anchor.yml` | DF-H, DF-J, AC-P |
| demand: `counts.absent > 0` over Anchor | `min_absent_parameters: 1` in `.anchor.yml` | DF-I, AC-Q |

No bound changed: the floors are the self tests' own values, and each analysis keeps its default `max_steps` and `max_rounds`.

## The dogfood run under sabotage

Each row applied one mutation and ran `MIX_ENV=dev mix anchor.graph`, the run CI makes. A row's exit is that command's. DF-0 is the positive control.

| # | Mutation | File | Exit | What it printed |
|---|---|---|---|---|
| DF-0 | no sabotage (positive control) | - | 0 | anchor.graph: 185 modules (15 functions with no Core body) in 1 apps, 5 rules, 0 violations (0 report-only, 122 baselined); apply sites: 1537 resolved, 53 any; effects: 2661 functions (domain 1985, managers 153, adapters 102, framework 421), 24 unresolved dynamic calls |
| DF-A | the flow analysis hits its step bound (max_steps: 1) | `lib/anchor/managers/graph.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the higher-order flow analysis (Anchor.Domain.Cfa) hit its step bound after 1 steps, so every apply site reads any and no closure was resolved. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound is the owner's call. |
| DF-B | the demand analysis hits its round bound (default 1 round) | `lib/anchor/domain/demand.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the demand analysis (Anchor.Domain.Demand) hit its round bound on 2261 function(s) (Anchor.Adapters.BaselineFile.confined/2, Anchor.Adapters.BaselineFile.create/3, Anchor.Adapters.BaselineFile.link/2, Anchor.Adapters.BaselineFile.no_symlink/3, Anchor |
| DF-C | the demand analysis leaves every defp unsummarised | `lib/anchor/domain/demand.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): 1615 function(s) have a Core body and no demand summary (Anchor.Adapters.BaselineFile.confined/2, Anchor.Adapters.BaselineFile.link/2, Anchor.Adapters.BaselineFile.no_symlink/3, Anchor.Adapters.BaselineFile.write_new/2, Anchor.Adapters.BaselineFile.w |
| DF-D | one module has no debug_info: an unreadable module | `lib/anchor/domain/violation.ex` | 1 | _build/dev/lib/anchor/ebin/Elixir.Anchor.Domain.Violation.beam:1: [enforce] anchor.graph Anchor.Domain.Violation was compiled without debug_info, so Anchor cannot read it. Fix: remove debug_info: false from the project's elixirc_options (Elixir keeps debug_info by default). |
| DF-E | the rule's floor above the modules it selects | `.anchor.yml` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete) selects 185 modules, below min_modules 999. Fix: correct the selector; lowering min_modules is the owner's call. |
| DF-F | the demand analysis crashes | `lib/anchor/domain/demand.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: RuntimeError: sabotaged (raised at lib/anchor/domain/demand.ex:116: Anchor.Domain.Demand.analyze/4), so it checked nothing. Fix: this is an Anchor bug; file it with this line. |
| DF-G | min_functions above what the demand analysis judged | `.anchor.yml` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the whole-program analyses judged 2646, below min_functions 99999, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call. |
| DF-H | min_apply_sites above what the flow analysis counted | `.anchor.yml` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the whole-program analyses judged 1590, below min_apply_sites 99999, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call. |
| DF-I | the demand analysis judges no parameter absent (min_absent_parameters: 1) | `lib/anchor/domain/demand.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the whole-program analyses judged 0, below min_absent_parameters 1, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call. |
| DF-J | the flow analysis counts no site (min_apply_sites: 101) | `lib/anchor/domain/cfa.ex` | 1 | .anchor.yml:1: [enforce] anchor.graph rule 4 (id: "analyses_complete", analyses_complete): the whole-program analyses judged 0, below min_apply_sites 101, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call. |

## Mutations of the rule

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| AC-A | a hit step bound is no violation | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 5 failures` | a hit step bound is one fail-closed violation on the config, naming the steps; a config path comes from the model, the default when there is none; every kind of failure is reported together, in order; analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; analyses_complete fails the run closed on a flow analysis that hit its step bound |
| AC-B | a hit round bound is no violation | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 3 failures` | every kind of failure is reported together, in order; a hit round bound is one fail-closed violation, naming the members; analyses_complete fails the run closed on a demand analysis that hit its round bound |
| AC-C | an unsummarised function is no violation | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 5 failures` | a defp with no summary is one too; a def with no summary is one fail-closed violation naming it; every kind of failure is reported together, in order; a module outside the selector, once selected, is judged (positive control of Z); analyses_complete fails the run closed on a function the analysis left unsummarised |
| AC-D | a defp need not be summarised | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs` | `15 tests, 2 failures` | a defp with no summary is one too; every kind of failure is reported together, in order |
| AC-E | a function with no Core body must be summarised | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs` | `15 tests, 12 failures` | the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; a selected module with no node in the graph is not a crash and not a function; a hit round bound is one fail-closed violation, naming the members; every selected function summarised, no bound hit: no violation; a hit step bound is one fail-closed violation on the config, naming the steps; the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; every kind of failure is reported together, in order; a config path comes from the model, the default when there is none; the floors (the positive controls) no floor declared: the counts are not judged; a defp with no summary is one too; a def with no summary is one fail-closed violation naming it |
| AC-F | a macro must be summarised | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs` | `15 tests, 12 failures` | a config path comes from the model, the default when there is none; a def with no summary is one fail-closed violation naming it; the floors (the positive controls) no floor declared: the counts are not judged; a defp with no summary is one too; the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; every selected function summarised, no bound hit: no violation; every kind of failure is reported together, in order; a selected module with no node in the graph is not a crash and not a function; a hit step bound is one fail-closed violation on the config, naming the steps; a hit round bound is one fail-closed violation, naming the members; the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none |
| AC-G | the selector is ignored: every classified module is judged | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs` | `15 tests, 11 failures` | a defp with no summary is one too; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; a config path comes from the model, the default when there is none; a hit step bound is one fail-closed violation on the config, naming the steps; the floors (the positive controls) no floor declared: the counts are not judged; the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; a def with no summary is one fail-closed violation naming it; every selected function summarised, no bound hit: no violation; a hit round bound is one fail-closed violation, naming the members; every kind of failure is reported together, in order |
| AC-H | needs/0 asks for no demand | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs`, `graph_rules_test.exs`, `analyses_complete_integration_test.exs` | `49 tests, 19 failures` | needs/1 (DND-5574) the rule that holds the analyses complete needs the flow analysis and demand; its contract; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above); analyses_complete fails the run closed on a flow analysis that hit its step bound; fail closed an analysis that returns no %Demand{}: the rule that needs it is one issue and is not run; the others run; fail closed an analysis that raises: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; fail closed an analysis that throws: the rule that needs it is one issue and is not run; the others run; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed on a demand analysis that hit its round bound; fail closed the effect inference and the demand analysis both crashed: each rule says its own; fail closed an analysis that exits: the rule that needs it is one issue and is not run; the others run; analyses_complete fails the run closed on a floor the analyses fell below, each reported; analyses_complete fails the run closed on a function the analysis left unsummarised; violating: a demand analysis that hit its bound fails the run; violating: a floor above what the project holds fails the run; real beams through the real read path: clean, with the known results; violating: a flow analysis that hit its bound fails the run |
| AC-I | the rule is not registered | `lib/anchor/domain/graph_rules.ex` | `graph_rules_test.exs`, `graph_demand_test.exs`, `analyses_complete_integration_test.exs`, `rule_schema_test.exs` | `67 tests, 6 failures` | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; real beams through the real read path: clean, with the known results; violating: a flow analysis that hit its bound fails the run; violating: a demand analysis that hit its bound fails the run; violating: a floor above what the project holds fails the run |
| AC-J | the failure names every function, never counting the rest | `lib/anchor/domain/failures.ex` | `failures_graph_test.exs` | `16 tests, 1 failure` | every graph message is fail-closed, on its file, with its subject and a Fix: line |
| AC-K | the round-bound failure gives no count | `lib/anchor/domain/failures.ex` | `failures_graph_test.exs`, `analyses_complete_test.exs`, `graph_demand_test.exs` | `47 tests, 3 failures` | a hit round bound is one fail-closed violation, naming the members; every graph message is fail-closed, on its file, with its subject and a Fix: line; analyses_complete fails the run closed on a demand analysis that hit its round bound |
| AC-L | the config path is dropped from the bound failure | `lib/anchor/domain/failures.ex` | `failures_graph_test.exs`, `analyses_complete_test.exs` | `31 tests, 2 failures` | a hit step bound is one fail-closed violation on the config, naming the steps; every graph message is fail-closed, on its file, with its subject and a Fix: line |
| AC-M | a model with no analysis reads clean (a catch-all clause) | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs` | `15 tests, 1 failure` | with no analysis on the model the check crashes: the runner's guard reports it |
| AC-N | a floor is never judged | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs`, `analyses_complete_integration_test.exs` | `36 tests, 7 failures` | every kind of failure is reported together, in order; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; violating: a demand analysis that hit its bound fails the run; analyses_complete fails the run closed on a floor the analyses fell below, each reported; violating: a floor above what the project holds fails the run |
| AC-O | a count at the floor reads as below it | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 4 failures` | the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above) |
| AC-P | min_apply_sites reads the wrong count | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 2 failures` | the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; analyses_complete fails the run closed on a floor the analyses fell below, each reported |
| AC-Q | min_absent_parameters reads the wrong count | `lib/anchor/domain/graph_rules/analyses_complete.ex` | `analyses_complete_test.exs`, `graph_demand_test.exs` | `31 tests, 1 failure` | the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none |
| AC-R | a floor of 0 loads | `lib/anchor/domain/rule_schema.ex` | `rule_checks_nothing_test.exs` | `30 tests, 1 failure` | analyses_complete: every rule that checks nothing is refused, and the positive rows load |
| AC-S | a floor that is no integer loads | `lib/anchor/domain/rule_schema.ex` | `rule_checks_nothing_test.exs` | `30 tests, 1 failure` | analyses_complete: every rule that checks nothing is refused, and the positive rows load |
| AC-T | min_functions is not parsed | `lib/anchor/domain/config.ex` | `config_test.exs` | `45 tests, 1 failure` | parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent |
| AC-U | the floor failure names no key | `lib/anchor/domain/failures.ex` | `failures_graph_test.exs`, `analyses_complete_test.exs` | `31 tests, 5 failures` | every kind of failure is reported together, in order; the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none; the floors (the positive controls) min_functions: below it is one fail-closed violation naming it and the count; at it, none; every graph message is fail-closed, on its file, with its subject and a Fix: line |
| AC-V | min_apply_sites is not parsed | `lib/anchor/domain/config.ex` | `config_test.exs` | `45 tests, 1 failure` | parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent |
| AC-W | min_absent_parameters is not parsed | `lib/anchor/domain/config.ex` | `config_test.exs` | `45 tests, 1 failure` | parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent |

## Failure strings (verbatim, the first failing test of each row)

### AC-A: a hit step bound is no violation

```

  1) test a hit step bound is one fail-closed violation on the config, naming the steps (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:78
     match (=) failed
     code:  assert [violation] = AnalysesComplete.check(model(complete(), %Cfa{bound_hit?: true, steps: 7}), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:79: (test)
```

### AC-B: a hit round bound is no violation

```

  1) test every kind of failure is reported together, in order (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:142
     match (=) failed
     code:  assert [cfa, rounds, missing, floor] =
              AnalysesComplete.check(model(demand, %Cfa{bound_hit?: true, steps: 1}), rule)
     left:  [cfa, rounds, missing, floor]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the higher-order flow analysis (Anchor.Domain.Cfa) hit its step bound after 1 steps, so every apply site reads any and no closure was resolved. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound is the owner's call.",
                filename: "proj/.anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): 2 function(s) have a Core body and no demand summary (A.priv/1, A.pub/1), so the analysis judged none of their parameters. Fix: this is an Anchor bug; file it with this line.",
                filename: "proj/.anchor.yml",
   
```

### AC-C: an unsummarised function is no violation

```

  1) test a defp with no summary is one too (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:107
     match (=) failed
     code:  assert [violation] = AnalysesComplete.check(model(demand), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:110: (test)
```

### AC-D: a defp need not be summarised

```

  1) test a defp with no summary is one too (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:107
     match (=) failed
     code:  assert [violation] = AnalysesComplete.check(model(demand), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:110: (test)
```

### AC-E: a function with no Core body must be summarised

```



  1) test the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:122
     match (=) failed
     code:  assert [violation] = AnalysesComplete.check(model(complete(), @sites), rule)
     left:  [violation]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): 1 function(s) have a Core body and no demand summary (A.unused/1), so the analysis judged none of their parameters. Fix: this is an Anchor bug; file it with this line.",
                filename: "proj/.anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the whole-program analyses judged 7, below min_apply_sites 8, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call.",
                filename: "proj/.anchor.yml",
                kind: :fail_closed,
                key: nil,
        
```

### AC-F: a macro must be summarised

```



  1) test a config path comes from the model, the default when there is none (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:176
     match (=) failed
     code:  assert [%{filename: ".anchor.yml"}] = AnalysesComplete.check(model, @rule)
     left:  [%{filename: ".anchor.yml"}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the higher-order flow analysis (Anchor.Domain.Cfa) hit its step bound after 1 steps, so every apply site reads any and no closure was resolved. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound is the owner's call.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): 1 function(s) have a Core body and no demand summary (A.mac/1), so the analysis judged none of their parameters. Fix: this is an Anchor bug; file it with this line.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
  
```

### AC-G: the selector is ignored: every classified module is judged

```



  1) test a defp with no summary is one too (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:107
     Assertion with =~ failed
     code:  assert violation.message =~ "(A.priv/1)"
     left:  "rule (id: \"complete\", analyses_complete): 2 function(s) have a Core body and no demand summary (A.priv/1, Z.other/1), so the analysis judged none of their parameters. Fix: this is an Anchor bug; file it with this line."
     right: "(A.priv/1)"
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:111: (test)
```

### AC-H: needs/0 asks for no demand

```

  1) test needs/1 (DND-5574) the rule that holds the analyses complete needs the flow analysis and demand (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:45
     Assertion with == failed
     code:  assert GraphRules.needs(GraphRules.AnalysesComplete) == [:cfa, :demand]
     left:  [:cfa]
     right: [:cfa, :demand]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:46: (test)
```

### AC-I: the rule is not registered

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:66
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :context_acyclic, :effects_match_bucket,
             :layering, :struct_owned_by_module_flow]
     right: [:aggregate_declarations, :analyses_complete, :context_acyclic,
             :effects_match_bucket, :layering,
             :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:69: (test)
```

### AC-J: the failure names every function, never counting the rest

```

  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:328
     analyses_unsummarised names five functions and counts the rest: "MyApp.X.f/0, MyApp.X.f/1, MyApp.X.f/2, MyApp.X.f/3, MyApp.X.f/4 and 2 more" in rule 2 (id: "web", layering): 7 function(s) have a Core body and no demand summary (MyApp.X.f/0, MyApp.X.f/1, MyApp.X.f/2, MyApp.X.f/3, MyApp.X.f/4, MyApp.X.f/5, MyApp.X.f/6), so the analysis judged none of their parameters. Fix: this is an Anchor bug; file it with this line.
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:333: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:329: (test)
```

### AC-K: the round-bound failure gives no count

```

  1) test a hit round bound is one fail-closed violation, naming the members (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:88
     Assertion with =~ failed
     code:  assert violation.message =~ "hit its round bound on 2 function(s) (A.pub/1, Z.other/1)"
     left:  "rule (id: \"complete\", analyses_complete): the demand analysis (Anchor.Domain.Demand) hit its round bound on (A.pub/1, Z.other/1), so their parameters read as used without being judged. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound is the owner's call."
     right: "hit its round bound on 2 function(s) (A.pub/1, Z.other/1)"
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:95: (test)
```

### AC-L: the config path is dropped from the bound failure

```

  1) test a hit step bound is one fail-closed violation on the config, naming the steps (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:78
     Assertion with == failed
     code:  assert violation.filename == "proj/.anchor.yml"
     left:  ".anchor.yml"
     right: "proj/.anchor.yml"
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:83: (test)
```

### AC-M: a model with no analysis reads clean (a catch-all clause)

```

  1) test with no analysis on the model the check crashes: the runner's guard reports it (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:170
     Expected exception FunctionClauseError but nothing was raised
     code: assert_raise FunctionClauseError, fn ->
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:171: (test)
```

### AC-N: a floor is never judged

```

  1) test every kind of failure is reported together, in order (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:142
     match (=) failed
     code:  assert [cfa, rounds, missing, floor] =
              AnalysesComplete.check(model(demand, %Cfa{bound_hit?: true, steps: 1}), rule)
     left:  [cfa, rounds, missing, floor]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the higher-order flow analysis (Anchor.Domain.Cfa) hit its step bound after 1 steps, so every apply site reads any and no closure was resolved. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound is the owner's call.",
                filename: "proj/.anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the demand analysis (Anchor.Domain.Demand) hit its round bound on 1 function(s) (A.pub/1), so their parameters read as used without being judged. Fix: this is a scale limit of Anchor; file it with this line. Raising the bound 
```

### AC-O: a count at the floor reads as below it

```

  1) test the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:122
     Assertion with == failed
     code:  assert AnalysesComplete.check(model(complete(), @sites), at) == []
     left:  [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"complete\", analyses_complete): the whole-program analyses judged 1, below min_absent_parameters 1, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call.",
                filename: "proj/.anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:132: (test)
```

### AC-P: min_apply_sites reads the wrong count

```

  1) test the floors (the positive controls) min_apply_sites: below it is one fail-closed violation naming it and the count; at it, none (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:122
     Assertion with =~ failed
     code:  assert violation.message =~ "judged #{7}, below #{:min_apply_sites} #{8}"
     left:  "rule (id: \"complete\", analyses_complete): the whole-program analyses judged 2, below min_apply_sites 8, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call."
     right: "judged 7, below min_apply_sites 8"
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:128: (test)
```

### AC-Q: min_absent_parameters reads the wrong count

```

  1) test the floors (the positive controls) min_absent_parameters: below it is one fail-closed violation naming it and the count; at it, none (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:122
     match (=) failed
     code:  assert [violation] = AnalysesComplete.check(model(complete(), @sites), rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:125: (test)
```

### AC-R: a floor of 0 loads

```

  1) test analyses_complete: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     analyses_complete / min_absent_parameters: 0 (no floor): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     analyses_complete / min_apply_sites: 0 (no floor): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     analyses_complete / min_functions: 0 (no floor): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)
```

### AC-S: a floor that is no integer loads

```

  1) test analyses_complete: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     analyses_complete / min_absent_parameters that is not an integer: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     analyses_complete / min_apply_sites that is not an integer: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     analyses_complete / min_functions that is not an integer: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)
```

### AC-T: min_functions is not parsed

```

  1) test parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:104
     Assertion with == failed
     code:  assert {rule.min_functions, rule.min_apply_sites, rule.min_absent_parameters} == {501, 101, 1}
     left:  {nil, 101, 1}
     right: {501, 101, 1}
     stacktrace:
       test/anchor/domain/config_test.exs:114: (test)
```

### AC-U: the floor failure names no key

```



  1) test every kind of failure is reported together, in order (Anchor.Domain.GraphRules.AnalysesCompleteTest)
     test/anchor/domain/graph_rules/analyses_complete_test.exs:142
     Assertion with =~ failed
     code:  assert floor.message =~ "below min_functions 1"
     left:  "rule (id: \"complete\", analyses_complete): the whole-program analyses judged 0, below 1, so they may be judging nothing. Fix: find what stopped them reading this code; lowering the floor is the owner's call."
     right: "below min_functions 1"
     stacktrace:
       test/anchor/domain/graph_rules/analyses_complete_test.exs:149: (test)
```

### AC-V: min_apply_sites is not parsed

```

  1) test parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:104
     Assertion with == failed
     code:  assert {rule.min_functions, rule.min_apply_sites, rule.min_absent_parameters} == {501, 101, 1}
     left:  {501, nil, 1}
     right: {501, 101, 1}
     stacktrace:
       test/anchor/domain/config_test.exs:114: (test)
```

### AC-W: min_absent_parameters is not parsed

```

  1) test parse_rule/1 (test-matrix: config.ex -> parse_rule/1) analyses_complete's floors surfaced as atom-keyed integers, nil when absent (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:104
     Assertion with == failed
     code:  assert {rule.min_functions, rule.min_apply_sites, rule.min_absent_parameters} == {501, 101, 1}
     left:  {501, 101, nil}
     right: {501, 101, 1}
     stacktrace:
       test/anchor/domain/config_test.exs:114: (test)
```
