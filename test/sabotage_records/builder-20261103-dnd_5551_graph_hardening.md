# Sabotage record — a function with no Core body is counted and, when public, reported (DND-5549)

- **Domain:** builder
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.Builder` (`build/2`, the `{:no_core, _}` unreadable entry); `Anchor.Domain.Graph.functions_without_core/1`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph/builder_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy (the driver prints `git status` after the run; only this branch's own edits were listed).

Traps seen: NC-A's first form (`_missing -> []`) left `path` and `module` unused, which does not compile under warnings-as-errors; the row is the second form, which never takes the reporting branch.

Measured on Anchor's own `_build/dev` (537 modules, deps included, 2026-11-03): 16 functions had no Core, all private (11 `defp` that nothing calls, 5 `defmacrop`); no public one. That is why a public one is an `unreadable` entry and a private one is only counted.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| NC-A | a public function with no Core is not reported (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 functions with no Core body (DND-5549) a public function with no Core is unreadable, naming it; the module is kept |
| NC-B | a private function or macro with no Core is reported as unreadable too (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted |
| NC-C | functions_without_core/1 counts nothing (`lib/anchor/domain/graph.ex`) | 2 | build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted; build/2 functions with no Core body (DND-5549) a public function with no Core is unreadable, naming it; the module is kept |
| NC-D | functions_without_core/1 counts only public functions (`lib/anchor/domain/graph.ex`) | 1 | build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted |

## NC-A — a public function with no Core is not reported

Run summary: `15 tests, 1 failure`

```



  1) test build/2 functions with no Core body (DND-5549) a public function with no Core is unreadable, naming it; the module is kept (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:247
     Assertion with == failed
     code:  assert graph.unreadable == [%{path: beam.path, module: Plain, reason: {:no_core, m: 1, run: 1}}]
     left:  []
     right: [
              %{
                module: AnchorFixtures.BuilderTest.Plain,
                reason: {:no_core, [m: 1, run: 1]},
                path: "ebin/Elixir.AnchorFixtures.BuilderTest.Plain.beam"
              }
            ]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:268: (test)

..............
```

## NC-B — a private function or macro with no Core is reported as unreadable too

Run summary: `15 tests, 1 failure`

```

  1) test build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:218
     Assertion with == failed
     code:  assert graph.unreadable == []
     left:  [
              %{
                module: AnchorFixtures.BuilderTest.NoCore,
                reason: {:no_core, [twice: 1, unused: 1]},
                path: "ebin/Elixir.AnchorFixtures.BuilderTest.NoCore.beam"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:244: (test)

.............
```

## NC-C — functions_without_core/1 counts nothing

Run summary: `15 tests, 2 failures`

```



  1) test build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:218
     Assertion with == failed
     code:  assert Graph.functions_without_core(graph) == %{module => [twice: 1, unused: 1]}
     left:  %{}
     right: %{AnchorFixtures.BuilderTest.NoCore => [twice: 1, unused: 1]}
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:234: (test)

........
```

## NC-D — functions_without_core/1 counts only public functions

Run summary: `15 tests, 1 failure`

```

  1) test build/2 functions with no Core body (DND-5549) a private macro and a private function nothing calls have no Core; each is counted (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:218
     Assertion with == failed
     code:  assert Graph.functions_without_core(graph) == %{module => [twice: 1, unused: 1]}
     left:  %{}
     right: %{AnchorFixtures.BuilderTest.NoCore => [twice: 1, unused: 1]}
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:234: (test)

....
```

