# Sabotage record: the split of InlinesTest (DND-5715)

- **Domain:** inlines
- **Branch:** dnd-5715-bucket-split
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Graph.Inlines.Derive` (`derive/1`, `tags/1`) on hand-built exports, and `Inlines.table/0` and `tags/0` against the real stdlib
- **Suite run:** one `test-slot` held a driver that, per mutation, asserted the replaced text occurs exactly once, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and wrote the file back. Heads: 4e5b28f, d9c0da5. Every row compiled and ran (its summary line is quoted), so no row is a compile failure read as a test failure.

| # | Mutation | File | Tests run | Result | Failing tests |
|---|---|---|---|---|---|
| IL-A | derive/1 reads the first module only | `lib/anchor/domain/graph/inlines/derive.ex` | `inlines_test.exs` | `20 tests, 1 failure` | table/0 derive/1 covers every module it is given |
| IL-B | tags/1 reads the first module only | `lib/anchor/domain/graph/inlines/derive.ex` | `inlines_test.exs` | `20 tests, 4 failures` | tags/0 and spellings/1 of tagged inlines (DND-5613) tagged_source/2 names the one Elixir name whose tag the literal arguments hold; tags/0 and spellings/1 of tagged inlines (DND-5613) the tag table holds each rewrite's literal arguments by position; tags/0 and spellings/1 of tagged inlines (DND-5613) tags/1 reads only the exports it is given, every module, leaving out the untagged; tags/0 and spellings/1 of tagged inlines (DND-5613) a tagged name's spellings leave out a sibling with another tag |
| IL-C | tags/1 keeps a function with no tag | `lib/anchor/domain/graph/inlines/derive.ex` | `inlines_test.exs` | `20 tests, 2 failures` | tags/0 and spellings/1 of tagged inlines (DND-5613) tags/1 of exports with no tagged function is empty (positive control above); tags/0 and spellings/1 of tagged inlines (DND-5613) tags/1 reads only the exports it is given, every module, leaving out the untagged |
| IL-D | derive/1 reads a generated function too (the filter removed) | `lib/anchor/domain/graph/inlines/derive.ex` | `inlines_test.exs`, `inlines_stdlib_test.exs` | `23 tests, 0 failures (measured zero)` | none |
| IL-E | the compiled table is a stale copy: it lost one entry | `lib/anchor/domain/graph/inlines.ex` | `inlines_stdlib_test.exs` | `3 tests, 1 failure` | table/0 is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy |
| IL-F | the compiled tag table is a stale copy: it lost one entry | `lib/anchor/domain/graph/inlines.ex` | `inlines_stdlib_test.exs` | `3 tests, 1 failure` | tags/0 is derived from Elixir's rules, not copied |
| IL-G | the adapter test reads no stdlib module (the test's own read) | `test/anchor/adapters/inlines_stdlib_test.exs` | `inlines_stdlib_test.exs` | `3 tests, 3 failures` | the stdlib was read: Map is there, with put/3 (positive control); table/0 is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy; tags/0 is derived from Elixir's rules, not copied |

## Failure strings (verbatim, the first failing test of each row)

### IL-A: derive/1 reads the first module only

```

  1) test table/0 derive/1 covers every module it is given (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:29
     Assertion with == failed
     code:  assert Derive.derive([{Map, [merge: 2, __info__: 1, module_info: 1]}, {Kernel, [elem: 2, __info__: 1]}]) ==
              %{{Map, :merge, 2} => {:maps, :merge, 2}, {Kernel, :elem, 2} => {:erlang, :element, 2}}
     left:  %{{Map, :merge, 2} => {:maps, :merge, 2}}
     right: %{
              {Kernel, :elem, 2} => {:erlang, :element, 2},
              {Map, :merge, 2} => {:maps, :merge, 2}
            }
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:30: (test)
```

### IL-B: tags/1 reads the first module only

```

  1) test tags/0 and spellings/1 of tagged inlines (DND-5613) tagged_source/2 names the one Elixir name whose tag the literal arguments hold (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:136
     Assertion with == failed
     code:  assert Inlines.tagged_source({:erlang, :monitor, 2}, [{:ok, :process}, :error]) == {Process, :monitor, 1}
     left:  nil
     right: {Process, :monitor, 1}
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:137: (test)
```

### IL-C: tags/1 keeps a function with no tag

```

  1) test tags/0 and spellings/1 of tagged inlines (DND-5613) tags/1 of exports with no tagged function is empty (positive control above) (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:113
     Assertion with == failed
     code:  assert Derive.tags([{Map, [put: 3, get: 2]}]) == %{}
     left:  %{{Map, :get, 2} => [], {Map, :put, 3} => []}
     right: %{}
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:114: (test)
```

### IL-D: derive/1 reads a generated function too (the filter removed)

Measured zero. `:elixir_rewrite` rewrites neither `module_info` nor `__info__`, so the `name not in [:module_info, :__info__]` filter in `Derive.derive/1` and `tags/1` changes no output on any input: it only skips two calls. Not load-bearing, and no test can tell. Code that predates this ticket, left as it is.

### IL-E: the compiled table is a stale copy: it lost one entry

```

  1) test table/0 is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy (Anchor.Adapters.InlinesStdlibTest)
     test/anchor/adapters/inlines_stdlib_test.exs:31
     Assertion with == failed
     code:  assert Inlines.table() == Derive.derive(exports)
     left:  %{
              {Map, :fetch, 2} => {:maps, :find, 2},
              {Integer, :to_charlist, 1} => {:erlang,
               :integer_to_list, 1},
              {List, :to_float, 1} => {:erlang, :list_to_float, 1},
              {List, :to_existing_atom, 1} => {:erlang,
               :list_to_existing_atom, 1},
              {System, :unique_integer, 0} => {:erlang,
               :unique_integer, 0},
              {Bitwise, :bxor, 2} => {:erlang, :bxor, 2},
              {Process, :read_timer, 1} => {:erlang, :read_timer, 1},
              {Process, :monitor, 2} => {:erlang, :monitor, 3},
              {Kernel, :==, 2} => {:erlang, :==, 2},
              {String, :to_integer, 2} => {:erlang,
               :binary_to_integer, 2},
              {Node, :spawn_monitor, 2} => {:erlang, :spawn_monitor,
               2},
              {Kernel, :is_function, 1} => {:erlang, :is_function,
               1},
              {Node, :list, 1} => {:erlang, :nodes, 1},
              {Float, :to_string, 1} => {:erlang, :float_to_binary,
               2},
              {List, ...} => {...},
              ..
```

### IL-F: the compiled tag table is a stale copy: it lost one entry

```

  1) test tags/0 is derived from Elixir's rules, not copied (Anchor.Adapters.InlinesStdlibTest)
     test/anchor/adapters/inlines_stdlib_test.exs:36
     Assertion with == failed
     code:  assert Inlines.tags() == Derive.tags(exports)
     left:  %{
              {Float, :to_charlist, 1} => [{1, [:short]}],
              {Port, :monitor, 1} => [{0, :port}],
              {Process, :monitor, 1} => [{0, :process}],
              {Process, :monitor, 2} => [{0, :process}]
            }
     right: %{
              {Float, :to_charlist, 1} => [{1, [:short]}],
              {Float, :to_string, 1} => [{1, [:short]}],
              {Port, :monitor, 1} => [{0, :port}],
              {Process, :monitor, 1} => [{0, :process}],
              {Process, :monitor, 2} => [{0, :process}]
            }
     stacktrace:
       test/anchor/adapters/inlines_stdlib_test.exs:37: (test)
```

### IL-G: the adapter test reads no stdlib module (the test's own read)

```



  1) test the stdlib was read: Map is there, with put/3 (positive control) (Anchor.Adapters.InlinesStdlibTest)
     test/anchor/adapters/inlines_stdlib_test.exs:27
     ** (KeyError) key Map not found in:
```
