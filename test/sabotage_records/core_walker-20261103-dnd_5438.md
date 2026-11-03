# Sabotage record — CoreWalker call and struct-use edges from Core Erlang (DND-5438)

- **Domain:** core_walker
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.CoreWalker` (`walk/3,4`)
- **Suite run:** `mix test test/anchor/domain/graph/core_walker_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run: only the unmutated edits of the branch showed). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| CW-A | delete the make_fun clause (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to |
| CW-B | a module function name used as a value is not a capture (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a local capture |
| CW-C | stop descending into receive (`lib/anchor/domain/graph/core_walker.ex`) | **0** | — (measured zero, see below) |
| CW-D | stop descending into letrec definitions (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for |
| CW-E | classify a struct update as build (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with |
| CW-F | erlang:apply/2,3 is read as a plain remote call (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 call edges (AC1) apply/2 is :apply with no name; walk/3 call edges (AC1) apply/3 is :apply, naming the function and arity it can see |
| CW-G | a variable let-bound to a call is read as a plain variable (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver |
| CW-H | a node with no line gets nil instead of the def line (`lib/anchor/domain/graph/core_walker.ex`) | 3 | walk/4 line fallback a node with no line gets the def line, flagged :def; walk/4 line fallback with no def line given, the c_fun's own line is the def line; walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def |
| CW-I | a letrec-bound name (receive loop) is read as a module function (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for |
| CW-J | line 0 is read as a source line (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def |

## CW-A — delete the make_fun clause

Run summary: `18 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:130
     Assertion with == failed
     code:  assert calls(binary, {:rcap, 1}) == [
              call({M, :rcap, 1}, {Other, :f, 1}, :capture, "# rcap"),
              call({M, :rcap, 1}, {Enum, :map, 2}, :remote, "# rcap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {:erlang, :make_fun, 3},
                kind: :remote,
                line: 14,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {Enum, :map, 2},
                kind: :remote,
                line: 14,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                kind: :capture,
                line: 14,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {Enum, :map, 2},
                kind: :remote,
                line: 14,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:131: (test)
```

## CW-B — a module function name used as a value is not a capture

Run summary: `18 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a local capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:138
     Assertion with == failed
     code:  assert calls(binary, {:lcap, 1}) == [
              call({M, :lcap, 1}, {M, :helper, 1}, :capture, "# lcap"),
              call({M, :lcap, 1}, {Enum, :map, 2}, :remote, "# lcap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :lcap, 1},
                to: {Enum, :map, 2},
                kind: :remote,
                line: 15,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :lcap, 1},
                to: {AnchorFixtures.CoreWalkerTest.M, :helper, 1},
                kind: :capture,
                line: 15,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :lcap, 1},
                to: {Enum, :map, 2},
                kind: :remote,
                line: 15,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:139: (test)
```

## CW-C — stop descending into receive

Run summary: `18 tests, 0 failures`

**CW-C: a measured zero, and why it is not a gap.** In Core Erlang as OTP 28's `v3_core` writes it, `receive` is not a `c_receive` node: it is a `letrec` (`'recv$^0'/0`) over `primop 'recv_peek_message'`, `recv_next`, `remove_message` and `recv_wait_timeout` (probe: `explore/probe5.exs` in the run's scratch). So skipping `receive` nodes skips nothing. The descent into a receive's body is protected by CW-D (stop descending into `letrec` definitions), which drops `Other.c13` and `Other.c14`, the two calls in the fixture's `receive`. The zero stays, per ADR 003.

## CW-D — stop descending into letrec definitions

Run summary: `18 tests, 1 failure`

CW-D drops exactly the two calls inside the fixture's `receive` (`c13`, `c14`): the `for` comprehension over a variable is lowered to `Enum.reduce/3` with a fun, not a `letrec`, so `c16` survives this mutation and is pinned by the walk of the fun.

```
  1) test walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     Assertion with == failed
     code:  assert Enum.sort(found) == Enum.sort(expected)
     left:  [
              c1: 23,
              c10: 37,
              c11: 41,
              c12: 43,
              c15: 55,
              c16: 52,
              c2: 24,
              c3: 25,
              c4: 26,
              c5: 29,
              c6: 29,
              c7: 30,
              c8: 35,
              c9: 36
            ]
     right: [
              c1: 23,
              c10: 37,
              c11: 41,
              c12: 43,
              c13: 47,
              c14: 49,
              c15: 55,
              c16: 52,
              c2: 24,
              c3: 25,
              c4: 26,
              c5: 29,
              c6: 29,
              c7: 30,
              c8: 35,
              c9: 36
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:191: (test)
```

## CW-E — classify a struct update as build

Run summary: `18 tests, 1 failure`

```
  1) test walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:229
     Assertion with == failed
     code:  assert uses(binary, {:update, 2}) == [
              %StructUse{
                from: {M, :update, 2},
                struct: S,
                op: :match,
                line: line("# update clause 1"),
                line_source: :call
              },
              %StructUse{
                from: {M, :update, 2},
                struct: S,
                op: :update,
                line: line("# update clause 1"),
                line_source: :call
              },
              %StructUse{
                from: {M, :update, 2},
                struct: S,
                op: :update,
                line: line("# update clause 2"),
                line_source: :call
              }
            ]
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :match,
                line: 60,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 60,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
     ... (truncated here; the full log is in the run's scratch)
```

## CW-F — erlang:apply/2,3 is read as a plain remote call

Run summary: `18 tests, 2 failures`

```
  1) test walk/3 call edges (AC1) apply/2 is :apply with no name (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:157
     Assertion with == failed
     code:  assert calls(binary, {:app2, 2}) == [call({M, :app2, 2}, {:dynamic, nil, 1, :call}, :apply, "# app2")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app2, 2},
                to: {:erlang, :apply, 2},
                kind: :remote,
                line: 18,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app2, 2},
                to: {:dynamic, nil, 1, :call},
                kind: :apply,
                line: 18,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:158: (test)
....
```

```
  2) test walk/3 call edges (AC1) apply/3 is :apply, naming the function and arity it can see (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:152
     Assertion with == failed
     code:  assert calls(binary, {:app3, 2}) == [call({M, :app3, 2}, {:dynamic, :f, 1, :call}, :apply, "# app3")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3, 2},
                to: {:erlang, :apply, 3},
                kind: :remote,
                line: 17,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :app3, 2},
                to: {:dynamic, :f, 1, :call},
                kind: :apply,
                line: 17,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:153: (test)
```

## CW-G — a variable let-bound to a call is read as a plain variable

Run summary: `18 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:169
     Assertion with == failed
     code:  assert calls(binary, {:computed, 1}) == [
              call({M, :computed, 1}, {Module, :concat, 1}, :remote, "# computed"),
              call({M, :computed, 1}, {:dynamic, :f, 1, :call}, :remote, "# computed")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :computed,
                 1},
                to: {Module, :concat, 1},
                kind: :remote,
                line: 20,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :computed,
                 1},
                to: {:dynamic, :f, 1, :variable},
                kind: :remote,
                line: 20,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :computed,
                 1},
                to: {Module, :concat, 1},
                kind: :remote,
                line: 20,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :computed,
                 1},
                to: {:dynamic, :f, 1, :call},
                kind: :remote,
                line: 20,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:170: (test)
```

## CW-H — a node with no line gets nil instead of the def line

Run summary: `18 tests, 3 failures`

```
  1) test walk/4 line fallback a node with no line gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:287
     Assertion with == failed
     code:  assert CoreWalker.walk(M, {:f, 0}, fun, 7) ==
              {[%Call{from: {M, :f, 0}, to: {Other, :f, 0}, kind: :remote, line: 7, line_source: :def}], []}
     left:  {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0},
                 kind: :remote,
                 line: nil,
                 line_source: :def
               }
             ], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0},
                 kind: :remote,
                 line: 7,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:290: (test)
.
```

```
  2) test walk/4 line fallback with no def line given, the c_fun's own line is the def line (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:309
     match (=) failed
     code:  assert {[%Call{line: 12, line_source: :def}], []} = CoreWalker.walk(M, {:f, 0}, fun)
     left:  {[%Anchor.Domain.Graph.Call{line: 12, line_source: :def}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0},
                 kind: :remote,
                 line: nil,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:313: (test)
.............
```

```
  3) test walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:302
     match (=) failed
     code:  assert {[%Call{line: 7, line_source: :def}], []} = CoreWalker.walk(M, {:f, 0}, fun, 7)
     left:  {[%Anchor.Domain.Graph.Call{line: 7, line_source: :def}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0},
                 kind: :remote,
                 line: nil,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:306: (test)
```

## CW-I — a letrec-bound name (receive loop) is read as a module function

Run summary: `18 tests, 1 failure`

```
  1) test walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     the letrec loop Core makes of a receive is part of the function, not a local call
     code: refute Enum.any?(calls, &(&1.kind == :local)),
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:198: (test)
```

## CW-J — line 0 is read as a source line

Run summary: `18 tests, 1 failure`

```
  1) test walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:302
     match (=) failed
     code:  assert {[%Call{line: 7, line_source: :def}], []} = CoreWalker.walk(M, {:f, 0}, fun, 7)
     left:  {[%Anchor.Domain.Graph.Call{line: 7, line_source: :def}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0},
                 kind: :remote,
                 line: 0,
                 line_source: :call
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:306: (test)
```

## Traps

- A first run of BR-B, BR-C and CW-H failed to compile under `warnings_as_errors` (an unreachable clause, an unused alias, an unused variable) and printed no ExUnit summary; the driver records `NO SUMMARY` for such a run, and each mutation was rewritten to compile and re-run. Read a sabotage run's test count, never its exit code alone.
