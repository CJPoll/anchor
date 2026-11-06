# Sabotage record: the behaviours moved out of demand_self_test.exs (DND-5715)

- **Domain:** demand
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Demand` (`analyze/4`, its counts, its round bound), `Anchor.Domain.Demand.Lattice`
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: 257f359, d9c0da5. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| DM-A | join(:absent, x) is :absent (the lattice) | `lib/anchor/domain/demand/lattice.ex` | `demand_test.exs`, `analyses_complete_integration_test.exs` | `33 tests, 24 failures` | real beams through the real read path: clean, with the known results; analyze/4 self recursion loop(n, acc): acc absent, n used; analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; a lattice's shape (the two summaries the whole-Anchor self test knew, DND-5715) join/2 reads both parameters in full, through its own recursion; analyze/4 AC3 positive control: the last returns it, and it is used at all three; analyze/4 inside try, a project call or a lambda apply that can raise uses its argument; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; a lattice's shape (the two summaries the whole-Anchor self test knew, DND-5715) at/2 reads its first parameter in full, and its key; analyze/4 an extra effect token makes a library call an effect: used, and precise; analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; analyze/4 positive control: the same shape with a lambda that returns its argument: used; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 AC1 def f(a, b), do: a gives [used(all), absent]; analyze/4 AC5 positive control: mutual recursion that returns p at the base uses it on both sides; analyze/4 receive (a letrec over recv primops): a captured parameter the clause uses is used; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})]; analyze/4 a caller of an imprecise function is imprecise through it; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent; analyze/4 a closure capturing p handed to Task.start/1 uses p (escape) |
| DM-B | the SCC loop runs one round only | `lib/anchor/domain/demand.ex` | `demand_test.exs`, `graph_demand_test.exs`, `analyses_complete_integration_test.exs` | `52 tests, 28 failures` | analyze/4 self recursion loop(n, acc): acc absent, n used; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely; analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})]; analyze/4 positive control: the same shape with a lambda that returns its argument: used; analyze/4 a caller of an imprecise function is imprecise through it; analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used; analyze/4 AC1 def f(a, b), do: a gives [used(all), absent]; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; analyze/4 a closure capturing p handed to Task.start/1 uses p (escape); analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; violating: a flow analysis that hit its bound fails the run; analyze/4 an extra module token makes every function of the module an effect; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 an extra effect token makes a library call an effect: used, and precise; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); real beams through the real read path: clean, with the known results; a rule that runs needs the analysis it runs once, over the flow analysis and the architecture's effect tokens; analyses_complete fails the run closed on a floor the analyses fell below, each reported; a rule that runs needs the analysis the rule alone over a complete analysis: exit 0, no finding; analyses_complete fails the run closed on a flow analysis that hit its step bound; analyses_complete fails the run closed with the counts at its floors, clean (the positive control of the row above); analyses_complete fails the run closed under enforcement: report too, since it is fail-closed; analyses_complete fails the run closed on a function the analysis left unsummarised; violating: a floor above what the project holds fails the run |
| DM-C | the parameter count is one too many | `lib/anchor/domain/demand.ex` | `demand_test.exs` | `31 tests, 2 failures` | counts functions analysed, absent parameters and imprecise functions, exact; counts the counts agree with the summaries they count |
| DM-D | the function count is one too many | `lib/anchor/domain/demand.ex` | `demand_test.exs` | `31 tests, 2 failures` | counts functions analysed, absent parameters and imprecise functions, exact; counts the counts agree with the summaries they count |

## Failure strings (verbatim, the first failing test of each row)

### DM-A: join(:absent, x) is :absent (the lattice)

```



  1) test real beams through the real read path: clean, with the known results (Anchor.Integration.AnalysesCompleteIntegrationTest)
     test/anchor/integration/analyses_complete_integration_test.exs:102
     Assertion with == failed
     code:  assert Demand.param(demand, {Helper, :keep, 2}, 0) == :all
     left:  :absent
     right: :all
     stacktrace:
       test/anchor/integration/analyses_complete_integration_test.exs:123: (test)
```

### DM-B: the SCC loop runs one round only

```

  1) test analyze/4 self recursion loop(n, acc): acc absent, n used (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:227
     Assertion with == failed
     code:  assert demands(demand, {A, :loop, 2}) == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand_test.exs:228: (test)
```

### DM-C: the parameter count is one too many

```

  1) test counts functions analysed, absent parameters and imprecise functions, exact (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:414
     Assertion with == failed
     code:  assert %{
              functions: 30,
              parameters: 41,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              components: 25,
              rounds: 50
            } == demand.counts
     left:  %{
              functions: 30,
              parameters: 41,
              components: 25,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              rounds: 50
            }
     right: %{
              functions: 30,
              parameters: 42,
              components: 25,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              rounds: 50
            }
     stacktrace:
       test/anchor/domain/demand_test.exs:415: (test)
```

### DM-D: the function count is one too many

```

  1) test counts functions analysed, absent parameters and imprecise functions, exact (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:414
     Assertion with == failed
     code:  assert %{
              functions: 30,
              parameters: 41,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              components: 25,
              rounds: 50
            } == demand.counts
     left:  %{
              functions: 30,
              parameters: 41,
              components: 25,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              rounds: 50
            }
     right: %{
              functions: 31,
              parameters: 41,
              components: 25,
              absent: 13,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              rounds: 50
            }
     stacktrace:
       test/anchor/domain/demand_test.exs:415: (test)
```
