# Sabotage record — apply/3 with literal module, function and arity is a static edge (DND-5547)

- **Domain:** core_walker
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.CoreWalker` (`apply_call/4` for `apply/3`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph/core_walker_test.exs test/anchor/domain/graph/builder_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy (the driver prints `git status` after the run; only this branch's own edits were listed).

Rows that stayed green and why: the existing row "apply/3 is :apply, naming the function and arity it can see" (a variable module) and "apply/2 is :apply with no name" do not move under these mutations; they pin the dynamic cases, which each mutation leaves alone.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| AP-A | apply/3 is never a static edge (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 call edges (AC1) apply/3 with a literal module, function and argument list is a static :apply edge; walk/3 call edges (AC1) apply/3 on a variable let-bound to literals is a static :apply edge |
| AP-B | apply/3's function name is read as a literal only, not through a let (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) apply/3 on a variable let-bound to literals is a static :apply edge |
| AP-C | an argument list of unknown length still makes a static edge (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) apply/3 stays dynamic when the argument count or the function is not literal |

## AP-A — apply/3 is never a static edge

Run summary: `46 tests, 2 failures`

```

  1) test walk/3 call edges (AC1) apply/3 with a literal module, function and argument list is a static :apply edge (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:169
     Assertion with == failed
     code:  assert calls(binary, {:app3lit, 1}) == [call({M, :app3lit, 1}, {Other, :f, 1}, :apply, "# app3lit")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3lit, 1},
                to: {:dynamic, :f, 1, :call},
                kind: :apply,
                line: 19,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3lit, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                kind: :apply,
                line: 19,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:172: (test)

.........
```

## AP-B — apply/3's function name is read as a literal only, not through a let

Run summary: `46 tests, 1 failure`

```

  1) test walk/3 call edges (AC1) apply/3 on a variable let-bound to literals is a static :apply edge (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:189
     match (=) failed
     code:  assert {[%Call{to: {Other, :g, 2}, kind: :apply}], []} =
              CoreWalker.walk(M, {:h, 0}, :cerl.c_fun([], body), 1)
     left:  {[%Anchor.Domain.Graph.Call{to: {AnchorFixtures.CoreWalkerTest.Other, :g, 2}, kind: :apply}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :h, 0},
                 to: {:dynamic, nil, 2, :call},
                 kind: :apply,
                 line: 1,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:207: (test)

...........................
```

## AP-C — an argument list of unknown length still makes a static edge

Run summary: `46 tests, 1 failure`

```

  1) test walk/3 call edges (AC1) apply/3 stays dynamic when the argument count or the function is not literal (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     Assertion with == failed
     code:  assert calls(binary, {:app3args, 1}) == [
              call({M, :app3args, 1}, {:dynamic, :f, nil, :call}, :apply, "# app3args")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3args,
                 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, nil},
                kind: :apply,
                line: 21,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3args,
                 1},
                to: {:dynamic, :f, nil, :call},
                kind: :apply,
                line: 21,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:182: (test)

..............
```

