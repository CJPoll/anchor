# Sabotage record — the coverage run refuses a project module that cannot load (DND-5690)

- **Domain:** sabotage (`Anchor.Adapters.CallTracer`, `Anchor.Managers.Sabotage.Coverage`). The preload's rows from
  the same run are `test_preload-20261106-dnd_5690_preload.md`.
- **Branch:** dnd-5690-preload
- **Date:** 2026-11-06
- **Code under test:** `CallTracer.start/2` (`loaded_then_traced/2`), `Coverage.traced_suite/3` (the `:not_loadable` branch)
- **Suite run:** `mix test --timeout 2000 --max-cases 2` over `test/anchor/adapters/call_tracer_test.exs` (rows S1,
  S2, S3, S7) or `test/anchor/managers/sabotage_coverage_test.exs` (S4, S5, S6, S8, S9, S10), each mutation applied
  alone and restored byte-for-byte after its run, through `test-slot`. Line numbers are those of the run's own commit.

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

## Second run: the suite's message, and the absences the first run did not prove

`Coverage.build/5` dropped the suite's message on a zero-test exit 3, so the name `test_helper.exs` raises with was
lost in a coverage run. On the unfixed code the new test read `16 tests, 1 failure`, `left: "COULD NOT MEASURE:
tests: 0, modules_traced: 2; no map was written. Fix: check the suite runs tests and the ebin directories hold the
project's modules"`. S2 above stopped at the pattern assertion, so the flag assertion had no red; S6 changed only
the exit code, so "the suite never runs" had none.

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| S7 | `start/2` sets flags and patterns, then refuses | adapter: refuses by name, nothing traced | `8 tests, 1 failure` |
| S8 | the Manager runs the suite past the refusal | Manager: exit 3 naming it, the suite never runs | `16 tests, 1 failure` |
| S9 | the suite's message is dropped again | Manager: exit 3 carrying the suite's message | `16 tests, 1 failure` |
| S10 | a suite that passed with zero tests is said to have failed | Manager: zero tests traced | `16 tests, 1 failure` |

### Failure strings (verbatim)

### S7

```
  1) test a project module that cannot load refuses by name, and nothing is traced (Anchor.Adapters.CallTracerTest)
     test/anchor/adapters/call_tracer_test.exs:104
     Assertion with == failed
     code:  assert :erlang.trace_info(:new_processes, :tracer) == {:tracer, []}
     left:  {:tracer, #PID<0.1238.0>}
     right: {:tracer, []}
     stacktrace:
       test/anchor/adapters/call_tracer_test.exs:113: (test)
```

### S8

```
  1) test a project module that cannot load: exit 3 naming it, the suite never runs (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:221
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.InProcessTestsMock.run/1 in process #PID<0.1250.0> with args [[]]
     code: assert {3, [message]} = Sabotage.coverage(facts(), @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/coverage.ex:153: Anchor.Managers.Sabotage.Coverage.traced_suite/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/coverage.ex:68: Anchor.Managers.Sabotage.Coverage.run/2
       test/anchor/managers/sabotage_coverage_test.exs:229: (test)
```

### S9

```
  1) test a suite that failed before any test: exit 3 carrying the suite's message (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:186
     Assertion with =~ failed
     code:  assert refusal =~ "The suite failed before any test ran: #{message}"
     left:  "COULD NOT MEASURE: tests: 0, modules_traced: 2; no map was written. Fix: check the suite runs tests 0"
     right: "The suite failed before any test ran: 1 module(s) of :anchor's closure failed to load:\n  Dep: :nofile\nFix: repair it"
     stacktrace:
       test/anchor/managers/sabotage_coverage_test.exs:193: (test)
```

### S10

```
  1) test zero tests traced: exit 3, no map written (Anchor.Managers.SabotageCoverageTest)
     test/anchor/managers/sabotage_coverage_test.exs:173
     Refute with =~ failed
     code:  refute message =~ "The suite failed"
     left:  "COULD NOT MEASURE: tests: 0, modules_traced: 2; no map was written. The suite failed before any test ran. Fix: check the suite runs tests"
     right: "The suite failed"
     stacktrace:
       test/anchor/managers/sabotage_coverage_test.exs:179: (test)
```

