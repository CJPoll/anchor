# Sabotage record — the rule schema rows of graph rules wave C (DND-5447, DND-5454)

- **Domain:** rule_schema
- **Branch:** dnd-5447-graph-rules-c
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleSchema`'s `@keys_by_type` and `@engine_by_type` entries for `effects_match_bucket` and `struct_owned_by_module_flow`, and `Anchor.Domain.GraphRules`' `@rules` and `@provided_needs`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/rule_checks_nothing_test.exs test/anchor/domain/rule_schema_test.exs test/anchor/domain/graph_rules_test.exs`, through `test-slot`

The review floor (ADR reviewer) found the new and changed rows in these three test files unrecorded. Each mutation replaced one exact text, the suite ran, and the file was restored.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| RS-A | struct_owned_by_module_flow reads no owned_namespaces key (`lib/anchor/domain/rule_schema.ex`) | 2 | struct_owned_by_module_flow: every rule that checks nothing is refused, and the positive rows load; the positive case the README lists exactly the keys each rule type accepts, its relation and engine |
| RS-B | struct_owned_by_module_flow runs on the ast engine (`lib/anchor/domain/rule_schema.ex`) | 5 | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; the positive case the README lists exactly the keys each rule type accepts, its relation and engine; engine/1 every shipped type has an engine; the graph types are the graph rule modules'; struct_owned_by_module_flow: every rule that checks nothing is refused, and the positive rows load; the positive case the ast types are exactly the rule types of Anchor.checks/0 |
| RS-C | effects_match_bucket runs on the ast engine (`lib/anchor/domain/rule_schema.ex`) | 5 | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; effects_match_bucket: every rule that checks nothing is refused, and the positive rows load; the positive case the ast types are exactly the rule types of Anchor.checks/0; the positive case the README lists exactly the keys each rule type accepts, its relation and engine; engine/1 every shipped type has an engine; the graph types are the graph rule modules' |
| RS-D | the runner provides only :cfa (`lib/anchor/domain/graph_rules.ex`) | 2 | needs/1 (DND-5574) a needs/0 that is not a list raises; needs/1 (DND-5574) a need the runner does not compute raises, naming it and what it computes |
| RS-E | StructOwnedByModuleFlow is not registered (`lib/anchor/domain/graph_rules.ex`) | 2 | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; engine/1 every shipped type has an engine; the graph types are the graph rule modules' |

## RS-A — struct_owned_by_module_flow reads no owned_namespaces key

Run summary: `73 tests, 2 failures`

```

  1) test struct_owned_by_module_flow: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     struct_owned_by_module_flow / positive: owned_namespaces: refused: {:error, {:invalid_rule, "rule 1: unknown key \"owned_namespaces\" in a struct_owned_by_module_flow rule (`owned_namespaces` applies to: struct_owned_by_module); known keys for struct_owned_by_module_flow: baseline, bucket, enforcement, id, min_modules, paths, pattern, type"}}
     struct_owned_by_module_flow / owned_namespaces: [] checks no struct: wrong reason (want "`owned_namespaces: []` checks no struct"): rule 1: unknown key "owned_namespaces" in a struct_owned_by_module_flow rule (`owned_namespaces` applies to: struct_owned_by_module); known keys for struct_owned_by_module_flow: baseline, bucket, enforcement, id, min_modules, paths, pattern, type
     struct_owned_by_module_flow / an owned_namespaces glob: wrong reason (want "is not an exact Elixir module name"): rule 1: unknown key "owned_namespaces" in a struct_owned_by_module_flow rule (`owned_namespaces` applies to: struct_owned_by_module); known keys for struct_owned_by_module_flow: baseline, bucket, enforcement, id, min_modules, paths, pattern, type
     struct_owned_by_module_flow / owned_namespaces that is a string: wrong reason (want "`owned_namespaces` must be a list of non-empty strings"): rule 1: unknown key "owned_namespaces" in a struct_owned_by_module_flow rule (`owned_namespaces` applies to: struct_owned_by_module); known keys for struct_owned_by_module_flow: baseline, bucket, enforcement, id, min_modules, paths, pattern, type
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

................................
```

## RS-B — struct_owned_by_module_flow runs on the ast engine

Run summary: `73 tests, 5 failures`

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:context_acyclic, :effects_match_bucket, :layering,
             :struct_owned_by_module_flow]
     right: [:context_acyclic, :effects_match_bucket, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

...............
```

## RS-C — effects_match_bucket runs on the ast engine

Run summary: `73 tests, 5 failures`

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:context_acyclic, :effects_match_bucket, :layering,
             :struct_owned_by_module_flow]
     right: [:context_acyclic, :layering, :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

......................
```

## RS-D — the runner provides only :cfa

Run summary: `73 tests, 2 failures`

```

  1) test needs/1 (DND-5574) a needs/0 that is not a list raises (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:52
     Assertion with == failed
     code:  assert error.message ==
              "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa, :effects]"
     left:  "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa]"
     right: "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:cfa, :effects]"
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:55: (test)

..
```

## RS-E — StructOwnedByModuleFlow is not registered

Run summary: `73 tests, 2 failures`

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:context_acyclic, :effects_match_bucket, :layering]
     right: [:context_acyclic, :effects_match_bucket, :layering,
             :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

..................................................
```
