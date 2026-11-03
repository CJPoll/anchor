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


## Second run (DND-5550) — a macro's spec is keyed by the macro's own name and arity

- **Domain:** builder
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.Builder` (`specs/2`, `macro_spec/3`, `without_caller/1`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph/builder_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy. Every mutation failed the one test "a macro's spec is keyed by the macro's own name and arity, without the caller", each on a different assertion (quoted below).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| MS-A | a macro's spec stays under MACRO-name/arity+1 (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller |
| MS-B | the caller argument is kept in a macro's spec (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller |
| MS-C | any MACRO- name is read as a macro, unchecked against the module's macros (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller |
| MS-D | a when-bounded spec keeps its caller argument (`lib/anchor/domain/graph/builder.ex`) | 1 | build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller |

### MS-A — a macro's spec stays under MACRO-name/arity+1

Run summary: `16 tests, 1 failure`

```

  1) test build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:147
     Assertion with == failed
     code:  assert Enum.sort(Map.keys(specs)) == ["MACRO-fake": 2, bounded: 1, mac: 1, run: 1]
     left:  ["MACRO-bounded": 2, "MACRO-fake": 2, "MACRO-mac": 2, run: 1]
     right: ["MACRO-fake": 2, bounded: 1, mac: 1, run: 1]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:172: (test)

.......
```

### MS-B — the caller argument is kept in a macro's spec

Run summary: `16 tests, 1 failure`

```

  1) test build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:147
     Assertion with == failed
     code:  assert Enum.map(specs[{:mac, 1}], &Macro.to_string/1) == ["mac(Macro.t()) :: Macro.t()"]
     left:  ["mac(term(), Macro.t()) :: Macro.t()"]
     right: ["mac(Macro.t()) :: Macro.t()"]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:179: (test)

......
```

### MS-C — any MACRO- name is read as a macro, unchecked against the module's macros

Run summary: `16 tests, 1 failure`

```

  1) test build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:147
     Assertion with == failed
     code:  assert Enum.sort(Map.keys(specs)) == ["MACRO-fake": 2, bounded: 1, mac: 1, run: 1]
     left:  [bounded: 1, fake: 1, mac: 1, run: 1]
     right: ["MACRO-fake": 2, bounded: 1, mac: 1, run: 1]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:172: (test)
```

### MS-D — a when-bounded spec keeps its caller argument

Run summary: `16 tests, 1 failure`

```



  1) test build/2 macro specs (DND-5550) a macro's spec is keyed by the macro's own name and arity, without the caller (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:147
     Assertion with == failed
     code:  assert Enum.map(specs[{:bounded, 1}], &Macro.to_string/1) == ["bounded(a) :: a when a: Macro.t()"]
     left:  ["bounded(term(), a) :: a when a: Macro.t()"]
     right: ["bounded(a) :: a when a: Macro.t()"]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:181: (test)

...............
```

