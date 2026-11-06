# Sabotage record: the behaviours moved out of cfa_self_test.exs (DND-5715)

- **Domain:** cfa
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Cfa` (the report and its counts)
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: d9c0da5. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| CF-A | every site reads any | `lib/anchor/domain/cfa.ex` | `cfa_test.exs`, `analyses_complete_integration_test.exs` | `41 tests, 24 failures` | real beams through the real read path: clean, with the known results; analyze/2 an exported parameter under the default seed is :any; a seed naming its closures resolves; letrec names are keyed per scope (DND-5575) L2: a letrec nested in one of the same name: the inner apply reaches the inner one; analyze/2 recursion: a function passing its own lambda parameter to itself terminates and resolves; analyze/2 apply/3 and spawn/3 with a literal project M:F feed its parameters; analyze/2 a lambda returned in an {:ok, f} tuple resolves at the caller's apply; analyze/2 AC4 stored in a struct field and read back resolves (literal key); analyze/2 apply/2 spreads its argument list over the applied lambda's parameters; analyze/2 stored under a non-literal key: a literal-key read sees the wildcard slot; analyze/2 a pipeline of two literal fns under the default seed: each site resolves to its own; analyze/2 AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture; analyze/2 a captured local &helper/1 passed and applied resolves to the capture; analyze/2 monovariance: two callers pass different lambdas, the one site resolves to both; analyze/2 Map.put then Map.get on the same map resolves; counts the total is the number of sites, every one resolved or any; analyze/2 a field kept through a map update is read from the map it was built on; counts the fixture's exact resolved and any counts, total and per function; analyze/2 elem/2 on a tuple reads the field at that position; analyze/2 AC1 direct: a lambda bound and applied resolves to that lambda; analyze/2 apply/3 with a variable module may call any exported function of that arity with anything; letrec names are keyed per scope (DND-5575) L3: positive control: the compiler's own distinct names resolve the same way; letrec names are keyed per scope (DND-5575) L1: two sibling letrecs of one name do not merge their reaching sets; analyze/2 AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda; analyze/2 AC3 returned: make().() resolves to the lambda make/0 returns |
| CF-B | the total is one too many | `lib/anchor/domain/cfa.ex` | `cfa_test.exs` | `39 tests, 5 failures` | the bound a run that hits :max_steps reports every site :any and says so; counts the total is the number of sites, every one resolved or any; analyze/2 a pipeline of two literal fns under the default seed: each site resolves to its own; counts an empty graph and a graph with no apply sites count zero sites; counts the fixture's exact resolved and any counts, total and per function |
| CF-C | the resolved count is one too few | `lib/anchor/domain/cfa.ex` | `cfa_test.exs` | `39 tests, 5 failures` | counts the total is the number of sites, every one resolved or any; counts the fixture's exact resolved and any counts, total and per function; the bound a run that hits :max_steps reports every site :any and says so; counts an empty graph and a graph with no apply sites count zero sites; analyze/2 a pipeline of two literal fns under the default seed: each site resolves to its own |

## Failure strings (verbatim, the first failing test of each row)

### CF-A: every site reads any

```



  1) test real beams through the real read path: clean, with the known results (Anchor.Integration.AnalysesCompleteIntegrationTest)
     test/anchor/integration/analyses_complete_integration_test.exs:102
     match (=) failed
     code:  assert %{total: 1, resolved: 1, any: 0, bound_hit?: false} = report.counts.apply_sites
     left:  %{total: 1, resolved: 1, any: 0, bound_hit?: false}
     right: %{
              any: 1,
              total: 1,
              resolved: 0,
              by_function: %{
                {AnchorFixtures.AnalysesCompleteIntegrationTest.Flow,
                 :run, 2} => %{any: 1, total: 1, resolved: 0}
              },
              bound_hit?: false
            }
     stacktrace:
       test/anchor/integration/analyses_complete_integration_test.exs:116: (test)
```

### CF-B: the total is one too many

```

  1) test the bound a run that hits :max_steps reports every site :any and says so (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:469
     Assertion with == failed
     code:  assert cfa.counts.any == cfa.counts.total
     left:  27
     right: 28
     stacktrace:
       test/anchor/domain/cfa_test.exs:476: (test)
```

### CF-C: the resolved count is one too few

```

  1) test counts the total is the number of sites, every one resolved or any (Anchor.Domain.CfaTest)
     test/anchor/domain/cfa_test.exs:446
     Assertion with == failed
     code:  assert cfa.counts.total == cfa.counts.resolved + cfa.counts.any
     left:  27
     right: 26
     stacktrace:
       test/anchor/domain/cfa_test.exs:448: (test)
```
