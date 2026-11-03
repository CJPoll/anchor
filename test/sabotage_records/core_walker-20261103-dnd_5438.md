# Sabotage record — CoreWalker call and struct-use edges from Core Erlang (DND-5438)

- **Domain:** core_walker
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.CoreWalker` (`walk/3,4`)
- **Suite run:** `mix test test/anchor/domain/graph/core_walker_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run, and the tree was clean). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| CW-A | delete the make_fun clause (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to; walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture |
| CW-B | a module function name used as a value is not a capture (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a local capture |
| CW-C | stop descending into receive nodes (`lib/anchor/domain/graph/core_walker.ex`) | **0** | — (measured zero, see below) |
| CW-D | stop descending into letrec definitions (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for |
| CW-E | classify a struct update as build (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with |
| CW-F | erlang:apply/2,3 is read as a plain remote call (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 call edges (AC1) apply/3 is :apply, naming the function and arity it can see; walk/3 call edges (AC1) apply/2 is :apply with no name |
| CW-G | a variable let-bound to a call is read as a plain variable (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver |
| CW-H | a node with no line gets nil instead of the def line (`lib/anchor/domain/graph/core_walker.ex`) | 4 | walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def; walk/4 line fallback a node with no line gets the def line, flagged :def; walk/4 line fallback with no def line given, the c_fun's own line is the def line; walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct |
| CW-I | a letrec-bound name (receive loop) is read as a module function (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for |
| CW-J | line 0 is read as a source line (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def |
| CW-K | a remote call gets the wrong arity (`lib/anchor/domain/graph/core_walker.ex`) | 9 | walk/3 call edges (AC1) a remote call with a literal module; walk/3 dynamic captures and shapes Core builds by hand a variable let-bound to a literal module resolves to a :remote call; walk/4 line fallback a node with no line gets the def line, flagged :def; walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for; walk/3 struct uses (AC2) a plain map and a plain map update are no struct use; walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver; walk/3 call edges (AC1) a call through a module attribute is a plain remote call; walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to; walk/3 call edges (AC1) a local capture |
| CW-L | a local call is labelled :remote (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 call edges (AC1) a local call |
| CW-M | every variable receiver is read as :call (`lib/anchor/domain/graph/core_walker.ex`) | 3 | walk/3 call edges (AC1) fun application is :apply through a variable; walk/3 call edges (AC1) a call on a variable module is a dynamic receiver; walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture |
| CW-N | a struct map built on %{} is an update (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 struct uses (AC2) a struct literal and a struct built from values are :build |
| CW-O | a struct literal is an update (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct; walk/3 struct uses (AC2) a struct literal and a struct built from values are :build |
| CW-P | a struct pattern is a build (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 struct uses (AC2) a struct in a pattern is :match; walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with |
| CW-Q | any map key holding an atom is read as a struct (Core map nodes) (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 struct uses (AC2) a plain map and a plain map update are no struct use |
| CW-R | any literal map key :a holding an atom is read as a struct (`lib/anchor/domain/graph/core_walker.ex`) | 4 | walk/3 struct uses (AC2) a struct literal and a struct built from values are :build; walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct; walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order; walk/3 struct uses (AC2) a plain map and a plain map update are no struct use |
| CW-S | a variable let-bound to a literal module is not resolved (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand a variable let-bound to a literal module resolves to a :remote call |
| CW-T | a dynamic capture loses its function name (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture |
| CW-U | a literal external fun is not a capture (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand a literal external fun is a :capture |
| CW-V | do not look for structs inside literal lists (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order; walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct |
| CW-W | applying a non-variable expression records no edge (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand applying an expression that is not a variable is :apply through :call |
| CW-X | structs inside one literal come out newest first (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order |
| CW-Y | a line annotated with another file (location: :keep) is used (`lib/anchor/domain/graph/core_walker.ex`) | 1 | build/2 lines of code a macro injects from another file a call annotated with another file gets the def line, flagged :def |
| CW-Z | a struct map built on a variable is a build (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 dynamic captures and shapes Core builds by hand a struct map built on a variable (not on %{}) is an :update |

## CW-A — delete the make_fun clause

Run summary: `25 tests, 2 failures`

```
  1) test walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:131
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
       test/anchor/domain/graph/core_walker_test.exs:132: (test)
.
```

```
  2) test walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     Assertion with == failed
     code:  assert calls(binary, {:dyncap, 1}) == [
              call({M, :dyncap, 1}, {:dynamic, :f, 1, :variable}, :capture, "# dyncap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:erlang, :make_fun, 3},
                kind: :remote,
                line: 21,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:dynamic, :f, 1, :variable},
                kind: :capture,
                line: 21,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:180: (test)
```

## CW-B — a module function name used as a value is not a capture

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a local capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:139
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
       test/anchor/domain/graph/core_walker_test.exs:140: (test)
```

## CW-C — stop descending into receive nodes

Run summary: `25 tests, 0 failures`

**CW-C: a measured zero, and why it is not a gap.** In Core Erlang as OTP 28's `v3_core` writes it, `receive` is not a `c_receive` node: it is a `letrec` (`'recv$^0'/0`) over `primop 'recv_peek_message'`, `recv_next`, `remove_message` and `recv_wait_timeout`. So skipping `receive` nodes skips nothing. The descent into a receive's body is protected by CW-D (stop descending into `letrec` definitions), which drops `Other.c13` and `Other.c14`, the two calls in the fixture's `receive`. The zero stays, per ADR 003. The probe: `defmodule Rv do def f(y) do receive do {:m, v} -> v after 0 -> y end end end`, read with `:elixir_erl.debug_info(:core_v1, Rv, data, [:no_copt])` and printed with `:core_pp`, gives (abridged):

```
'f'/1 = fun (_0) -> case _0 of <_X_y@1> when 'true' ->
  letrec 'recv$^0'/0 = fun () ->
    let <_4,_2> = primop 'recv_peek_message'()
    in case _4 of
      <'true'> when 'true' -> case _2 of <{'m',_X_v@1}> when 'true' -> do primop 'remove_message'() _X_v@1
                                      <Other> when 'true' -> do primop 'recv_next'() apply 'recv$^0'/0()
      <'false'> when 'true' -> let <_3> = primop 'recv_wait_timeout'(0) in ...
```

## CW-D — stop descending into letrec definitions

Run summary: `25 tests, 1 failure`

CW-D drops exactly the two calls inside the fixture's `receive` (`c13`, `c14`): the `for` comprehension over a variable is lowered to `Enum.reduce/3` with a fun, not a `letrec`, so `c16` survives this mutation and is pinned by the walk of the fun.

```
  1) test walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:235
     Assertion with == failed
     code:  assert Enum.sort(found) == Enum.sort(expected)
     left:  [
              c1: 24,
              c10: 38,
              c11: 42,
              c12: 44,
              c15: 56,
              c16: 53,
              c2: 25,
              c3: 26,
              c4: 27,
              c5: 30,
              c6: 30,
              c7: 31,
              c8: 36,
              c9: 37
            ]
     right: [
              c1: 24,
              c10: 38,
              c11: 42,
              c12: 44,
              c13: 48,
              c14: 50,
              c15: 56,
              c16: 53,
              c2: 25,
              c3: 26,
              c4: 27,
              c5: 30,
              c6: 30,
              c7: 31,
              c8: 36,
              c9: 37
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:247: (test)
```

## CW-E — classify a struct update as build

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:285
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
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 62,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :match,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 62,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:286: (test)
```

## CW-F — erlang:apply/2,3 is read as a plain remote call

Run summary: `25 tests, 2 failures`

```
  1) test walk/3 call edges (AC1) apply/3 is :apply, naming the function and arity it can see (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:153
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
       test/anchor/domain/graph/core_walker_test.exs:154: (test)
.....
```

```
  2) test walk/3 call edges (AC1) apply/2 is :apply with no name (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:158
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
       test/anchor/domain/graph/core_walker_test.exs:159: (test)
```

## CW-G — a variable let-bound to a call is read as a plain variable

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:170
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
       test/anchor/domain/graph/core_walker_test.exs:171: (test)
```

## CW-H — a node with no line gets nil instead of the def line

Run summary: `25 tests, 4 failures`

```
  1) test walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:358
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
       test/anchor/domain/graph/core_walker_test.exs:362: (test)
```

```
  2) test walk/4 line fallback a node with no line gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:343
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
       test/anchor/domain/graph/core_walker_test.exs:346: (test)
......
```

```
  3) test walk/4 line fallback with no def line given, the c_fun's own line is the def line (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:365
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
       test/anchor/domain/graph/core_walker_test.exs:369: (test)
......
```

```
  4) test walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:201
     match (=) failed
     code:  assert {[], [%StructUse{struct: S, op: :build, line: 1, line_source: :def}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 1,
                 line_source: :def
               }
             ]}
     right: {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: nil,
                 line_source: :def
               }
             ]}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:204: (test)
```

## CW-I — a letrec-bound name (receive loop) is read as a module function

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:235
     the letrec loop Core makes of a receive is part of the function, not a local call
     code: refute Enum.any?(calls, &(&1.kind == :local)),
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:254: (test)
```

## CW-J — line 0 is read as a source line

Run summary: `25 tests, 1 failure`

```
  1) test walk/4 line fallback line 0 is no line: the edge gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:358
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
       test/anchor/domain/graph/core_walker_test.exs:362: (test)
```

## CW-K — a remote call gets the wrong arity

Run summary: `25 tests, 9 failures`

```
  1) test walk/3 call edges (AC1) a remote call with a literal module (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:114
     Assertion with == failed
     code:  assert calls(binary, {:remote, 1}) == [call({M, :remote, 1}, {Other, :f, 1}, :remote, "# remote")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :remote, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 2},
                kind: :remote,
                line: 11,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :remote, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                kind: :remote,
                line: 11,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:115: (test)
```

```
  2) test walk/3 dynamic captures and shapes Core builds by hand a variable let-bound to a literal module resolves to a :remote call (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:186
     match (=) failed
     code:  assert {[%Call{to: {Other, :f, 0}, kind: :remote}], []} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[%Anchor.Domain.Graph.Call{to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0}, kind: :remote}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                 kind: :remote,
                 line: 1,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:190: (test)
...
```

```
  3) test walk/4 line fallback a node with no line gets the def line, flagged :def (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:343
     Assertion with == failed
     code:  assert CoreWalker.walk(M, {:f, 0}, fun, 7) ==
              {[%Call{from: {M, :f, 0}, to: {Other, :f, 0}, kind: :remote, line: 7, line_source: :def}], []}
     left:  {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :f, 0},
                 to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                 kind: :remote,
                 line: 7,
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
       test/anchor/domain/graph/core_walker_test.exs:346: (test)
```

```
  4) test walk/3 through every form Core lowers (AC6) no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:235
     Assertion with == failed
     code:  assert Enum.sort(found) == Enum.sort(expected)
     left:  []
     right: [
              c1: 24,
              c10: 38,
              c11: 42,
              c12: 44,
              c13: 48,
              c14: 50,
              c15: 56,
              c16: 53,
              c2: 25,
              c3: 26,
              c4: 27,
              c5: 30,
              c6: 30,
              c7: 31,
              c8: 36,
              c9: 37
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:247: (test)
..
```

```
  5) test walk/3 struct uses (AC2) a plain map and a plain map update are no struct use (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:335
     Expected truthy, got false
     code: assert Enum.any?(calls(binary, {:plain, 1}), &(&1.to == {Other, :f, 1}))
     arguments:
         # 1
         [
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
             to: {:erlang, :is_map, 2},
             kind: :remote,
             line: 72,
             line_source: :call
           },
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
             to: {AnchorFixtures.CoreWalkerTest.Other, :f, 2},
             kind: :remote,
             line: 72,
             line_source: :call
           }
         ]
         # 2
         #Function<0.109530292/1 in Anchor.Domain.Graph.CoreWalkerTest."test walk/3 struct uses (AC2) a plain map and a plain map update are no struct use"/1>
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:337: (test)
```

```
  6) test walk/3 call edges (AC1) a call on a computed module is a dynamic :call receiver (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:170
     Assertion with == failed
     code:  assert calls(binary, {:computed, 1}) == [
              call({M, :computed, 1}, {Module, :concat, 1}, :remote, "# computed"),
              call({M, :computed, 1}, {:dynamic, :f, 1, :call}, :remote, "# computed")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :computed,
                 1},
                to: {Module, :concat, 2},
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
       test/anchor/domain/graph/core_walker_test.exs:171: (test)
....
```

```
  7) test walk/3 call edges (AC1) a call through a module attribute is a plain remote call (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:120
     Assertion with == failed
     code:  assert calls(binary, {:attr, 1}) == [call({M, :attr, 1}, {Other, :f, 1}, :remote, "# attr")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :attr, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 2},
                kind: :remote,
                line: 12,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :attr, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                kind: :remote,
                line: 12,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:121: (test)
..
```

```
  8) test walk/3 call edges (AC1) a remote capture, beside the remote call it is passed to (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:131
     Assertion with == failed
     code:  assert calls(binary, {:rcap, 1}) == [
              call({M, :rcap, 1}, {Other, :f, 1}, :capture, "# rcap"),
              call({M, :rcap, 1}, {Enum, :map, 2}, :remote, "# rcap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
                kind: :capture,
                line: 14,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :rcap, 1},
                to: {Enum, :map, 3},
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
       test/anchor/domain/graph/core_walker_test.exs:132: (test)
.....
```

```
  9) test walk/3 call edges (AC1) a local capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:139
     Assertion with == failed
     code:  assert calls(binary, {:lcap, 1}) == [
              call({M, :lcap, 1}, {M, :helper, 1}, :capture, "# lcap"),
              call({M, :lcap, 1}, {Enum, :map, 2}, :remote, "# lcap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :lcap, 1},
                to: {AnchorFixtures.CoreWalkerTest.M, :helper, 1},
                kind: :capture,
                line: 15,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :lcap, 1},
                to: {Enum, :map, 3},
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
       test/anchor/domain/graph/core_walker_test.exs:140: (test)
```

## CW-L — a local call is labelled :remote

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 call edges (AC1) a local call (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:125
     Assertion with == failed
     code:  assert calls(binary, {:local, 1}) == [call({M, :local, 1}, {M, :helper, 1}, :local, "# local")]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :local, 1},
                to: {AnchorFixtures.CoreWalkerTest.M, :helper, 1},
                kind: :remote,
                line: 13,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :local, 1},
                to: {AnchorFixtures.CoreWalkerTest.M, :helper, 1},
                kind: :local,
                line: 13,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:126: (test)
```

## CW-M — every variable receiver is read as :call

Run summary: `25 tests, 3 failures`

```
  1) test walk/3 call edges (AC1) fun application is :apply through a variable (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:147
     Assertion with == failed
     code:  assert calls(binary, {:funapp, 2}) == [
              call({M, :funapp, 2}, {:dynamic, nil, 1, :variable}, :apply, "# funapp")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :funapp, 2},
                to: {:dynamic, nil, 1, :call},
                kind: :apply,
                line: 16,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :funapp, 2},
                to: {:dynamic, nil, 1, :variable},
                kind: :apply,
                line: 16,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:148: (test)
.......
```

```
  2) test walk/3 call edges (AC1) a call on a variable module is a dynamic receiver (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:164
     Assertion with == failed
     code:  assert calls(binary, {:varmod, 2}) == [
              call({M, :varmod, 2}, {:dynamic, :f, 1, :variable}, :remote, "# varmod")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :varmod, 2},
                to: {:dynamic, :f, 1, :call},
                kind: :remote,
                line: 19,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :varmod, 2},
                to: {:dynamic, :f, 1, :variable},
                kind: :remote,
                line: 19,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:165: (test)
..
```

```
  3) test walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     Assertion with == failed
     code:  assert calls(binary, {:dyncap, 1}) == [
              call({M, :dyncap, 1}, {:dynamic, :f, 1, :variable}, :capture, "# dyncap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:dynamic, :f, 1, :call},
                kind: :capture,
                line: 21,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:dynamic, :f, 1, :variable},
                kind: :capture,
                line: 21,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:180: (test)
```

## CW-N — a struct map built on %{} is an update

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 struct uses (AC2) a struct literal and a struct built from values are :build (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:261
     Assertion with == failed
     code:  assert uses(binary, {:build_var, 1}) == [
              %StructUse{
                from: {M, :build_var, 1},
                struct: S,
                op: :build,
                line: line("# build var"),
                line_source: :call
              }
            ]
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :build_var,
                 1},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 59,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :build_var,
                 1},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 59,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:272: (test)
```

## CW-O — a struct literal is an update

Run summary: `25 tests, 2 failures`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:201
     match (=) failed
     code:  assert {[], [%StructUse{struct: S, op: :build, line: 1, line_source: :def}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 1,
                 line_source: :def
               }
             ]}
     right: {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :update,
                 line: 1,
                 line_source: :def
               }
             ]}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:204: (test)
..
```

```
  2) test walk/3 struct uses (AC2) a struct literal and a struct built from values are :build (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:261
     Assertion with == failed
     code:  assert uses(binary, {:build, 0}) == [
              %StructUse{
                from: {M, :build, 0},
                struct: S,
                op: :build,
                line: line("# build literal"),
                line_source: :call
              }
            ]
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :build, 0},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 58,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :build, 0},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 58,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:262: (test)
```

## CW-P — a struct pattern is a build

Run summary: `25 tests, 2 failures`

```
  1) test walk/3 struct uses (AC2) a struct in a pattern is :match (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:322
     Assertion with == failed
     code:  assert uses(binary, {:match, 1}) == [
              %StructUse{
                from: {M, :match, 1},
                struct: S,
                op: :match,
                line: line("# match"),
                line_source: :call
              }
            ]
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :match, 1},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 70,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :match, 1},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :match,
                line: 70,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:323: (test)
................
```

```
  2) test walk/3 struct uses (AC2) a struct update is :update, in each clause and inside with (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:285
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
                op: :build,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 62,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :match,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 61,
                line_source: :call
              },
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :update, 2},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :update,
                line: 62,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:286: (test)
```

## CW-Q — any map key holding an atom is read as a struct (Core map nodes)

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 struct uses (AC2) a plain map and a plain map update are no struct use (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:335
     Assertion with == failed
     code:  assert uses(binary, {:plain, 1}) == []
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
                struct: :y,
                op: :update,
                line: 72,
                line_source: :call
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:336: (test)
```

## CW-R — any literal map key :a holding an atom is read as a struct

Run summary: `25 tests, 4 failures`

```
  1) test walk/3 struct uses (AC2) a struct literal and a struct built from values are :build (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:261
     Assertion with == failed
     code:  assert uses(binary, {:build, 0}) == [
              %StructUse{
                from: {M, :build, 0},
                struct: S,
                op: :build,
                line: line("# build literal"),
                line_source: :call
              }
            ]
     left:  []
     right: [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :build, 0},
                struct: AnchorFixtures.CoreWalkerTest.S,
                op: :build,
                line: 58,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:262: (test)
...........
```

```
  2) test walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:201
     match (=) failed
     code:  assert {[], [%StructUse{struct: S, op: :build, line: 1, line_source: :def}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 1,
                 line_source: :def
               }
             ]}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:204: (test)
....
```

```
  3) test walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:217
     match (=) failed
     code:  assert {[], [%StructUse{struct: S}, %StructUse{struct: Other}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.S},
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.Other}
             ]}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:220: (test)
.
```

```
  4) test walk/3 struct uses (AC2) a plain map and a plain map update are no struct use (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:335
     Assertion with == failed
     code:  assert uses(binary, {:plain, 1}) == []
     left:  [
              %Anchor.Domain.Graph.StructUse{
                from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
                struct: :x,
                op: :build,
                line: 72,
                line_source: :call
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:336: (test)
```

## CW-S — a variable let-bound to a literal module is not resolved

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand a variable let-bound to a literal module resolves to a :remote call (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:186
     match (=) failed
     code:  assert {[%Call{to: {Other, :f, 0}, kind: :remote}], []} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[%Anchor.Domain.Graph.Call{to: {AnchorFixtures.CoreWalkerTest.Other, :f, 0}, kind: :remote}], []}
     right: {[
               %Anchor.Domain.Graph.Call{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 to: {:dynamic, :f, 0, :variable},
                 kind: :remote,
                 line: 1,
                 line_source: :def
               }
             ], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:190: (test)
```

## CW-T — a dynamic capture loses its function name

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand a capture through a variable module is a dynamic :capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:179
     Assertion with == failed
     code:  assert calls(binary, {:dyncap, 1}) == [
              call({M, :dyncap, 1}, {:dynamic, :f, 1, :variable}, :capture, "# dyncap")
            ]
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:dynamic, nil, 1, :variable},
                kind: :capture,
                line: 21,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :dyncap, 1},
                to: {:dynamic, :f, 1, :variable},
                kind: :capture,
                line: 21,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:180: (test)
```

## CW-U — a literal external fun is not a capture

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand a literal external fun is a :capture (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:194
     match (=) failed
     code:  assert {[%Call{to: {Enum, :count, 1}, kind: :capture}], []} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[%Anchor.Domain.Graph.Call{to: {Enum, :count, 1}, kind: :capture}], []}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:197: (test)
```

## CW-V — do not look for structs inside literal lists

Run summary: `25 tests, 2 failures`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:217
     match (=) failed
     code:  assert {[], [%StructUse{struct: S}, %StructUse{struct: Other}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.S},
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.Other}
             ]}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:220: (test)
....
```

```
  2) test walk/3 dynamic captures and shapes Core builds by hand a struct inside a literal term is a :build of that struct (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:201
     match (=) failed
     code:  assert {[], [%StructUse{struct: S, op: :build, line: 1, line_source: :def}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 1,
                 line_source: :def
               }
             ]}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:204: (test)
```

## CW-W — applying a non-variable expression records no edge

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand applying an expression that is not a variable is :apply through :call (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:224
     match (=) failed
     code:  assert {[%Call{to: {:dynamic, nil, 1, :call}, kind: :apply}], []} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[%Anchor.Domain.Graph.Call{to: {:dynamic, nil, 1, :call}, kind: :apply}], []}
     right: {[], []}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:228: (test)
```

## CW-X — structs inside one literal come out newest first

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand structs inside one literal come out in term order (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:217
     match (=) failed
     code:  assert {[], [%StructUse{struct: S}, %StructUse{struct: Other}]} =
              CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.S},
               %Anchor.Domain.Graph.StructUse{struct: AnchorFixtures.CoreWalkerTest.Other}
             ]}
     right: {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 struct: AnchorFixtures.CoreWalkerTest.Other,
                 op: :build,
                 line: 1,
                 line_source: :def
               },
               %Anchor.Domain.Graph.StructUse{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 0},
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 1,
                 line_source: :def
               }
             ]}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:220: (test)
```

## CW-Y — a line annotated with another file (location: :keep) is used

Run summary: `10 tests, 1 failure`

CW-Y is run against the builder suite (`test/anchor/domain/graph/builder_test.exs`): the two-file `location: :keep` fixture lives there, because only the builder knows the module's file.

```
  1) test build/2 lines of code a macro injects from another file a call annotated with another file gets the def line, flagged :def (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:239
     match (=) failed
     The following variables were pinned:
       def_line = 2
     code:  assert [%Call{to: {Enum, :map, 2}, line: ^def_line, line_source: :def}] =
              Enum.filter(
                Graph.calls_from(graph, {user_module, :hello, 1}),
                &(&1.to == {Enum, :map, 2})
              )
     left:  [%Anchor.Domain.Graph.Call{to: {Enum, :map, 2}, line: ^def_line, line_source: :def}]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.KeepUser, :hello,
                 1},
                to: {Enum, :map, 2},
                kind: :remote,
                line: 5,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:266: (test)
```

## CW-Z — a struct map built on a variable is a build

Run summary: `25 tests, 1 failure`

```
  1) test walk/3 dynamic captures and shapes Core builds by hand a struct map built on a variable (not on %{}) is an :update (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:208
     match (=) failed
     code:  assert {[], [%StructUse{struct: S, op: :update, line: 3, line_source: :call}]} =
              CoreWalker.walk(M, {:g, 1}, :cerl.c_fun([s], body), 1)
     left:  {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :update,
                 line: 3,
                 line_source: :call
               }
             ]}
     right: {[],
             [
               %Anchor.Domain.Graph.StructUse{
                 from: {AnchorFixtures.CoreWalkerTest.M, :g, 1},
                 struct: AnchorFixtures.CoreWalkerTest.S,
                 op: :build,
                 line: 3,
                 line_source: :call
               }
             ]}
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:213: (test)
```

## Traps

- A first run of BR-B, BR-C, CW-H and SF-B failed to compile under `warnings_as_errors` (an unreachable clause, an unused alias, unused variables) and printed no ExUnit summary; the driver records `NO SUMMARY` for such a run, and each mutation was rewritten to compile and re-run. Read a sabotage run's test count, never its exit code alone.
