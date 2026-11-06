# Sabotage record — the coverage run refuses a project module that cannot load (DND-5690)

- **Domain:** sabotage (`Anchor.Adapters.CallTracer`, `Anchor.Managers.Sabotage.Coverage`). The preload's rows from
  the same run are `test_preload-20261106-dnd_5690_preload.md`.
- **Branch:** dnd-5690-preload
- **Date:** 2026-11-06
- **Code under test:** `CallTracer.start/2` (`loaded_then_traced/2`), `Coverage.traced_suite/3` (the `:not_loadable` branch)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <the file in the table>`, each mutation applied alone and
  restored byte-for-byte after its run, through `test-slot`.

## On the unfixed code

`CallTracer.start/2` filtered on `Code.ensure_loaded?/1`, so a project module that could not load went untraced with
nothing said. The new tests against that code: `23 tests, 2 failures`, the adapter's reading `left: :ok`, the
Manager's a `Hammox.TypeMatchError` (the port's return type did not yet hold the refusal). S1 below is the same
behaviour as the unfixed filter.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| S1 | `start/2` traces the modules that did load, as the old filter did | adapter: refuses by name, nothing traced | `8 tests, 1 failure` |
| S2 | patterns are set before the refusal | same test, on `{:traced, :local}` | `8 tests, 1 failure` |
| S3 | the refusal's names are not sorted | same test | `8 tests, 1 failure` |
| S4 | the Manager's message gives a count, not the names | Manager: exit 3 naming it | `15 tests, 1 failure` |
| S5 | the message loses its `Fix:` line | same test | `15 tests, 1 failure` |
| S6 | the refusal exits 0 | same test | `15 tests, 1 failure` |

## Failure strings (verbatim)

### S1

```
  1) test a project module that cannot load refuses by name, and nothing is traced (Anchor.Adapters.CallTracerTest)
     test/anchor/adapters/call_tracer_test.exs:104
     Assertion with == failed
     code:  assert CallTracer.start(collector, [a | missing] ++ [b]) == {:error, {:not_loadable, Enum.sort(missing)}}
     left:  :ok
     right: {:error,
             {:not_loadable,
              [AnchorFixtures.CallTracerTest.NoBeamA,
               AnchorFixtures.CallTracerTest.NoBeamB]}}
     stacktrace:
       test/anchor/adapters/call_tracer_test.exs:110: (test)
```

### S2

```
  1) test a project module that cannot load refuses by name, and nothing is traced (Anchor.Adapters.CallTracerTest)
     test/anchor/adapters/call_tracer_test.exs:104
     Assertion with == failed
     code:  assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}
     left:  {:traced, :local}
     right: {:traced, false}
     stacktrace:
       test/anchor/adapters/call_tracer_test.exs:114: (test)
```

### S3

```
  1) test a project module that cannot load refuses by name, and nothing is traced (Anchor.Adapters.CallTracerTest)
     test/anchor/adapters/call_tracer_test.exs:104
     Assertion with == failed
     code:  assert CallTracer.start(collector, [a | missing] ++ [b]) == {:error, {:not_loadable, Enum.sort(missing)}}
     left:  {:error,
             {:not_loadable,
              [AnchorFixtures.CallTracerTest.NoBeamB,
               AnchorFixtures.CallTracerTest.NoBeamA]}}
     right: {:error,
             {:not_loadable,
              [AnchorFixtures.CallTracerTest.NoBeamA,
               AnchorFixtures.CallTracerTest.NoBeamB]}}
     stacktrace:
       test/anchor/adapters/call_tracer_test.exs:110: (test)
```

### S4

```
  1) test a project module that cannot load: exit 3 naming it, the suite never runs (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:206
     Assertion with =~ failed
     code:  assert message =~
              "COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls " <>
                "cannot be traced: A, B; no map was written."
     left:  "COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls cannot be traced: 2; no map was written. Fix: recompile the project (MIX_ENV=test mix compile --force); a beam that still does not load is broken in this build"
     right: "COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls cannot be traced: A, B; no map was written."
     stacktrace:
       test/anchor/managers/sabotage_coverage_test.exs:216: (test)
```

### S5

```
  1) test a project module that cannot load: exit 3 naming it, the suite never runs (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:206
     Assertion with =~ failed
     code:  assert message =~ "Fix: "
     left:  "COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls cannot be traced: A, B; no map was written."
     right: "Fix: "
     stacktrace:
       test/anchor/managers/sabotage_coverage_test.exs:220: (test)
```

### S6

```
  1) test a project module that cannot load: exit 3 naming it, the suite never runs (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:206
     match (=) failed
     code:  assert {3, [message]} = Sabotage.coverage(facts(), @opts)
     left:  {3, [message]}
     right: {0,
             ["COULD NOT MEASURE: 2 project module(s) could not be loaded, so their calls cannot be traced: A, B; no map was written. Fix: recompile the project (MIX_ENV=test mix compile --force); a beam that still does not load is broken in this build"]}
     stacktrace:
       test/anchor/managers/sabotage_coverage_test.exs:214: (test)
```

## Rows that stayed green

The other tests in both files: none of them hands the tracer a module with no beam.
