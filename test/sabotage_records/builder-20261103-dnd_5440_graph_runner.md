# Sabotage record — Graph.Builder guards each module's walk (DND-5548)

- **Domain:** builder
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.Builder.build/2` (the per-module guard)
- **Suite run:** `mix test test/anchor/domain/graph/builder_test.exs` (BU-S also `--timeout 2000 --max-cases 2`)

The regression tests "build/2 a module whose walk crashes (DND-5548)" were written first and run on the unfixed code (BU-R2, the regression red), then the fix landed and one mutation of the fix was run (BU-S). The file was restored from its saved copy after the mutation (`cmp` clean).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| BU-R2 | the unfixed code: no per-module guard (the regression red) | 2 | build/2 a module whose walk crashes (DND-5548) the crashing module is unreadable with its crash summary; the others are built; build/2 a module whose walk crashes (DND-5548) a crash inside one function's Core walk is the module's, never the build's |
| BU-S | crashed modules caught but dropped, not put in `unreadable` (`Enum.concat(Enum.take(crashed, 0))`) | 2 | the same two tests |

## BU-R2 — the unfixed code (before the guard): a crash in one module aborts the whole build

Run summary: `13 tests, 2 failures`

```
  1) test build/2 a module whose walk crashes (DND-5548) the crashing module is unreadable with its crash summary; the others are built (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:222
     ** (ErlangError) Erlang error: {:badrecord, :not_core}
     code: graph = Builder.build([broken | pair], %{})
     stacktrace:
       (compiler 9.0.3) cerl.erl:650: :cerl.module_defs/1
       (anchor 0.1.0) lib/anchor/domain/graph/builder.ex:135: Anchor.Domain.Graph.Builder.core_defs/1
       (anchor 0.1.0) lib/anchor/domain/graph/builder.ex:81: Anchor.Domain.Graph.Builder.module_node/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph/builder.ex:44: Anchor.Domain.Graph.Builder.build/2
       test/anchor/domain/graph/builder_test.exs:234: (test)



  2) test build/2 a module whose walk crashes (DND-5548) a crash inside one function's Core walk is the module's, never the build's (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:256
     ** (FunctionClauseError) no function clause matching in :cerl.type/1

     The following arguments were given to :cerl.type/1:

         # 1
         :not_a_fun

     code: graph = Builder.build([walk_broken | others], %{})
     stacktrace:
       (compiler 9.0.3) cerl.erl:250: :cerl.type/1
       (anchor 0.1.0) lib/anchor/domain/graph/core_walker.ex:80: Anchor.Domain.Graph.CoreWalker.visit/3
       (anchor 0.1.0) lib/anchor/domain/graph/core_walker.ex:75: Anchor.Domain.Graph.CoreWalker.walk/5
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph/builder.ex:103: Anchor.Domain.Graph.Builder.module_edges/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/domain/graph/builder.ex:47: Anchor.Domain.Graph.Builder.build/2
       test/anchor/domain/graph/builder_test.exs:274: (test)

......
Finished in 0.2 seconds (0.2s async, 0.00s sync)
13 tests, 2 failures
```

## BU-S — crashed modules caught but dropped

Run summary: `13 tests, 2 failures`

```
  1) test build/2 a module whose walk crashes (DND-5548) the crashing module is unreadable with its crash summary; the others are built (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:222
     match (=) failed
     code:  assert [%{path: "ebin/broken.beam", module: AnchorFixtures.BuilderTest.Broken, reason: reason}] =
              graph.unreadable
     left:  [%{path: "ebin/broken.beam", module: AnchorFixtures.BuilderTest.Broken, reason: reason}]
     right: []
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:236: (test)

........

  2) test build/2 a module whose walk crashes (DND-5548) a crash inside one function's Core walk is the module's, never the build's (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:256
     match (=) failed
     code:  assert [%{module: B, reason: {:walk_crashed, summary}}] = graph.unreadable
     left:  [%{module: AnchorFixtures.BuilderTest.B, reason: {:walk_crashed, summary}}]
     right: []
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:276: (test)

..
Finished in 0.4 seconds (0.4s async, 0.00s sync)
13 tests, 2 failures
```

After the fix: `mix test test/anchor/domain/graph/` gives `51 tests, 0 failures`.
