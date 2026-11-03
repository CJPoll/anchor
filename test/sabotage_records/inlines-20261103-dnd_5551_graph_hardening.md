# Sabotage record — inline table, both spellings, and the inlined Map.put in Core (DND-5551)

- **Domain:** inlines
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.Inlines.Derive` (`derive/0`, `rewritten/3`), `Anchor.Domain.Graph.Inlines` (`table/0`, `spellings/1`), `Anchor.Domain.Graph` (`calls_to/2`), `Anchor.Domain.Graph.CoreWalker` (the inlined `Map.put` read from a map update)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph/inlines_test.exs test/anchor/domain/graph/builder_test.exs test/anchor/domain/graph/core_walker_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy (the driver prints `git status` after the run; only this branch's own edits were listed). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

Traps seen:

- IN-B's first run (load1 near 15) failed only by `ExUnit.TimeoutError` at 2000 ms in "is the table Elixir's rewrite rules give ... not a copy": that test derives the table afresh, which loads every `Elixir.*` module of the `:elixir` app (about 100 ms cold on an idle host). A timeout is not a caught mutation, so IN-B was run again; the row below is that second run, which failed by assertion. The suite's normal 60 s timeout leaves wide headroom.
- IN-A's first form (`false -> nil`) left `rewritten_call/3` unused, which does not compile under warnings-as-errors; the row is the second form, which never calls it.
- IN-G's first form (`!= :never`) did not compile (a typing warning under warnings-as-errors); the row is the second form, which returns every pair.
- IN-H stayed green on its first run (a measured zero: no test built a map from values on `%{}`). The test "a map built from values on %{} is no put" was added, and the row is the run after it.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| IN-A | derive the table from inline/3 only, not rewrite/5 (`lib/anchor/domain/graph/inlines/derive.ex`) | 6 | table/0 holds Map.put/3 and Map.merge/2 under their Erlang spellings; spellings/1 the Elixir name gives both spellings; spellings/1 the Erlang name gives both spellings; elixir_names/1 maps an Erlang function back to the Elixir names that compile to it; table/0 a function Elixir does not rewrite is not in it (positive control: Map.get/2); build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name |
| IN-B | a hand-copied table (two entries) instead of the derived one (`lib/anchor/domain/graph/inlines.ex`) | 2 | spellings/1 every Elixir name Core cannot tell apart is a spelling (Bitwise.band and &&&); table/0 is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy |
| IN-C | spellings/1 gives no Elixir names for an Erlang name (`lib/anchor/domain/graph/inlines.ex`) | 3 | spellings/1 the Erlang name gives both spellings; spellings/1 every Elixir name Core cannot tell apart is a spelling (Bitwise.band and &&&); build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name |
| IN-D | Graph.calls_to/2 by mfa matches only the name as given (`lib/anchor/domain/graph.ex`) | 1 | build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name |
| IN-E | Graph.calls_to/2 by module ignores the Elixir spelling (`lib/anchor/domain/graph.ex`) | 1 | build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name |
| IN-F | the walker reads no put from a map update (`lib/anchor/domain/graph/core_walker.ex`) | 4 | walk/3 stdlib calls Elixir inlines (DND-5551) Map.put/3 lowered to a map update is a :remote call to :maps.put/3; walk/3 stdlib calls Elixir inlines (DND-5551) :maps.put/3 written in source lowers the same way; walk/3 stdlib calls Elixir inlines (DND-5551) puts in a row that Core folds into one update are one edge each; build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name |
| IN-G | every pair of a map update is a put, := included (`lib/anchor/domain/graph/core_walker.ex`) | 2 | walk/3 stdlib calls Elixir inlines (DND-5551) a map literal and a := map update are no put; walk/3 dynamic captures and shapes Core builds by hand a struct map built on a variable (not on %{}) is an :update |
| IN-H | a map built on a literal is read as a put too (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 stdlib calls Elixir inlines (DND-5551) a map built from values on %{} is no put |
| IN-I | one put edge per map update, not per => pair (`lib/anchor/domain/graph/core_walker.ex`) | 1 | walk/3 stdlib calls Elixir inlines (DND-5551) puts in a row that Core folds into one update are one edge each |

## IN-A — derive the table from inline/3 only, not rewrite/5

Run summary: `53 tests, 6 failures`

```

  1) test table/0 holds Map.put/3 and Map.merge/2 under their Erlang spellings (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:14
     ** (KeyError) key {Map, :put, 3} not found in:

         %{
           {Integer, :to_charlist, 1} => {:erlang, :integer_to_list, 1},
           {List, :to_float, 1} => {:erlang, :list_to_float, 1},
           {List, :to_existing_atom, 1} => {:erlang, :list_to_existing_atom, 1},
           {System, :unique_integer, 0} => {:erlang, :unique_integer, 0},
           {Bitwise, :bxor, 2} => {:erlang, :bxor, 2},
           {Process, :read_timer, 1} => {:erlang, :read_timer, 1},
           {Kernel, :==, 2} => {:erlang, :==, 2},
           {String, :to_integer, 2} => {:erlang, :binary_to_integer, 2},
           {Node, :spawn_monitor, 2} => {:erlang, :spawn_monitor, 2},
           {Kernel, :is_function, 1} => {:erlang, :is_function, 1},
           {Node, :list, 1} => {:erlang, :nodes, 1},
           {List, :to_atom, 1} => {:erlang, :list_to_atom, 1},
           {Kernel, :is_pid, 1} => {:erlang, :is_pid, 1},
           {Kernel, :tl, 1} => {:erlang, :tl, 1},
           {Process, ...} => {...},
           ...
         }

     code: assert Map.fetch!(Inlines.table(), {Map, :put, 3}) == {:maps, :put, 3}
     stacktrace:
       :erlang.map_get({Map, :put, 3}, %{{Integer, :to_charlist, 1} => {:erlang, :integer_to_list, 1}, {List, :to_float, 1} => {:erlang, :list_to_float, 1}, {List, :to_existing_atom, 1} => {:erlang, :list_to_existing_atom, 1}, {System, :unique_integer, 0} => {:erlang, :unique_integer, 0}, {Bitwise, :bxor, 2} => {:erlang, :bxor, 2}, {Process, :read_timer, 1} => {:erlang, :read_timer, 1}, {Kernel, :==, 2} => {:erlang, :==, 2}, {String, :to_integer, 2} => {:erlang, :binary_to_integer, 2}, {Node, :spawn_monitor, 2} => {:erlang, :spawn_monitor, 2}, {Kernel, :is_function, 1} => {:erlang, :is_function, 1}, {Node, :list, 1} => {:erlang, :nodes, 1}, {List, :to_atom, 1} => {:erlang, :list_to_atom, 1}, {Kernel, :is_pid, 1} => {:erlang, :is_pid, 1}, {Kernel, :tl, 1} => {:erlang, :tl, 1}, {Process, ...} => {...}, ...})
       test/anchor/domain/graph/inlines_test.exs:15: (test)

.
```

## IN-B — a hand-copied table (two entries) instead of the derived one

Run summary: `53 tests, 2 failures`

```

  1) test spellings/1 every Elixir name Core cannot tell apart is a spelling (Bitwise.band and &&&) (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:48
     Assertion with == failed
     code:  assert Inlines.spellings({Bitwise, :band, 2}) == expected
     left:  [{Bitwise, :band, 2}]
     right: [{Bitwise, :&&&, 2}, {Bitwise, :band, 2}, {:erlang, :band, 2}]
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:51: (test)

...............................
```

## IN-C — spellings/1 gives no Elixir names for an Erlang name

Run summary: `52 tests, 3 failures`

```

  1) test spellings/1 the Erlang name gives both spellings (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:43
     Assertion with == failed
     code:  assert Inlines.spellings({:maps, :put, 3}) == [{Map, :put, 3}, {:maps, :put, 3}]
     left:  [{:maps, :put, 3}]
     right: [{Map, :put, 3}, {:maps, :put, 3}]
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:44: (test)

..
```

## IN-D — Graph.calls_to/2 by mfa matches only the name as given

Run summary: `52 tests, 1 failure`

```

  1) test build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:332
     Assertion with == failed
     code:  assert Graph.calls_to(graph, {Map, :put, 3}) == [erlang_put, put]
     left:  []
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined,
                 :erlang_put, 1},
                to: {:maps, :put, 3},
                kind: :remote,
                line: 4,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined, :put, 1},
                to: {:maps, :put, 3},
                kind: :remote,
                line: 2,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/builder_test.exs:375: (test)

.......................................
```

## IN-E — Graph.calls_to/2 by module ignores the Elixir spelling

Run summary: `52 tests, 1 failure`

```

  1) test build/2 edges and Graph queries a stdlib call Elixir inlines is found by its Elixir and its Erlang name (Anchor.Domain.Graph.BuilderTest)
     test/anchor/domain/graph/builder_test.exs:332
     Assertion with == failed
     code:  assert Enum.sort(Graph.calls_to(graph, Map)) ==
              Enum.sort([put, merge, erlang_put] ++ Graph.calls_from(graph, {inlined, :get, 1}))
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined, :get, 1},
                to: {Map, :get, 2},
                kind: :remote,
                line: 5,
                line_source: :call
              }
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined,
                 :erlang_put, 1},
                to: {:maps, :put, 3},
                kind: :remote,
                line: 4,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined, :get, 1},
                to: {Map, :get, 2},
                kind: :remote,
                line: 5,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.BuilderTest.Inlined, :merge,
                 2},
                to: {:maps, :merge, 2},
                kind: :remote,
                line: 3,
                line_source: :call
              },
              %Anchor.Domain.Graph.Call{
```

## IN-F — the walker reads no put from a map update

Run summary: `52 tests, 4 failures`

```

  1) test walk/3 stdlib calls Elixir inlines (DND-5551) Map.put/3 lowered to a map update is a :remote call to :maps.put/3 (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:349
     Assertion with == failed
     code:  assert [call({M, :put, 2}, {:maps, :put, 3}, :remote, "# put")] ==
              Enum.filter(calls(binary, {:put, 2}), &(&1.to == {:maps, :put, 3}))
     left:  [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :put, 2},
                to: {:maps, :put, 3},
                kind: :remote,
                line: 74,
                line_source: :call
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:350: (test)

...
```

## IN-G — every pair of a map update is a put, := included

Run summary: `53 tests, 2 failures`

```

  1) test walk/3 stdlib calls Elixir inlines (DND-5551) a map literal and a := map update are no put (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:379
     Expected false or nil, got true
     code: refute Enum.any?(calls, &(&1.to == {:maps, :put, 3}))
     arguments:

         # 1
         [
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
             to: {:erlang, :is_map, 1},
             kind: :remote,
             line: 72,
             line_source: :call
           },
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
             to: {:maps, :put, 3},
             kind: :remote,
             line: 72,
             line_source: :call
           },
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :plain, 1},
             to: {AnchorFixtures.CoreWalkerTest.Other, :f, 1},
             kind: :remote,
             line: 72,
             line_source: :call
           }
         ]

         # 2
         #Function<4.67408531/1 in Anchor.Domain.Graph.CoreWalkerTest."test walk/3 stdlib calls Elixir inlines (DND-5551) a map literal and a := map update are no put"/1>

     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:381: (test)

.....
```

## IN-H — a map built on a literal is read as a put too

Run summary: `53 tests, 1 failure`

```

  1) test walk/3 stdlib calls Elixir inlines (DND-5551) a map built from values on %{} is no put (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:372
     Expected false or nil, got true
     code: refute Enum.any?(calls, &(&1.to == {:maps, :put, 3}))
     arguments:

         # 1
         [
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :built, 2},
             to: {:maps, :put, 3},
             kind: :remote,
             line: 78,
             line_source: :call
           },
           %Anchor.Domain.Graph.Call{
             from: {AnchorFixtures.CoreWalkerTest.M, :built, 2},
             to: {:maps, :put, 3},
             kind: :remote,
             line: 78,
             line_source: :call
           }
         ]

         # 2
         #Function<2.67408531/1 in Anchor.Domain.Graph.CoreWalkerTest."test walk/3 stdlib calls Elixir inlines (DND-5551) a map built from values on %{} is no put"/1>

     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:374: (test)

..............
```

## IN-I — one put edge per map update, not per => pair

Run summary: `52 tests, 1 failure`

```

  1) test walk/3 stdlib calls Elixir inlines (DND-5551) puts in a row that Core folds into one update are one edge each (Anchor.Domain.Graph.CoreWalkerTest)
     test/anchor/domain/graph/core_walker_test.exs:354
     match (=) failed
     code:  assert [%Call{line: line, line_source: :call}, %Call{line: line, line_source: :call}] =
              Enum.filter(calls(binary, {:puts, 1}), &(&1.to == {:maps, :put, 3}))
     left:  [
              %Anchor.Domain.Graph.Call{line: line, line_source: :call},
              %Anchor.Domain.Graph.Call{line: line, line_source: :call}
            ]
     right: [
              %Anchor.Domain.Graph.Call{
                from: {AnchorFixtures.CoreWalkerTest.M, :puts, 1},
                to: {:maps, :put, 3},
                kind: :remote,
                line: 75,
                line_source: :call
              }
            ]
     stacktrace:
       test/anchor/domain/graph/core_walker_test.exs:355: (test)

............................
```

