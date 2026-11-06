# Sabotage record — the parameter_reaches_sink rule and its runner wiring

- **Domain:** parameter_reaches_sink
- **Branch:** dnd-5470-param-sink-locality
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.ParameterReachesSink`, `Anchor.Domain.Core.mfa_references/1`, `Anchor.Domain.DynamicCalls.computed_name_count/1`, the `:demand` wiring in `Anchor.Managers.Graph`, `Anchor.Domain.GraphReport.parameter_sinks/4` and its note, and the two rows of `Anchor.Domain.Demand.Transfer` the QA plan names.
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

The first table holds the last full run, and each of its sections shows the first failure, cut at 70 lines. It was rewritten in place through the critic's rounds, so `## Measured zeros` and `## Retired mutants` keep what those rewrites dropped, and `## Second run

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
