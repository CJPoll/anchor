# Sabotage record — one call-site name normalization across Elixir's inlining (DND-5613)

- **Domain:** inlines
- **Branch:** dnd-5447-graph-rules-c
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.Inlines.Derive` (`tags/1`, `tag/3`), `Anchor.Domain.Graph.Inlines` (`tags/0`, `tag/1`, `arities/2`, `spellings/1`, `tagged_source/2`, `candidates/1`, `ambiguous?/1`, `describe/1`), `Anchor.Domain.Graph.CoreWalker` (a tagged inline read back into its Elixir name), `Anchor.Domain.FunctionRef` (`names/1`, `matches?/4`, `may_reach?/4`), through `Anchor.Domain.Graph.calls_to/2` and `Anchor.Domain.Checks.NoDependency`'s `forbidden_functions`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/call_names_test.exs test/anchor/domain/function_ref_test.exs test/anchor/domain/graph/inlines_test.exs test/anchor/domain/graph/core_walker_test.exs test/anchor/domain/checks/no_dependency_forbidden_functions_test.exs`, through `test-slot`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy (`git status` afterwards listed only this branch's own edits). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

## The bug, red before the fix (regression rule)

The new tests ran on the unfixed code (bc7f7b2's `Inlines`, `CoreWalker` and `FunctionRef`): `50 tests, 21 failures`. Most failures were the missing tag table and functions; the over-match itself is this one, in the graph (a rule naming `Process.monitor/1` also matched `Port.monitor/1`, both `:erlang.monitor/2` on the edge):

```
 10) test graph: a rule naming one tagged function matches only its own calls Process.monitor/1 finds proc and the ambiguous call, never Port.monitor (Anchor.Domain.CallNamesTest)
     test/anchor/domain/call_names_test.exs:107
     Assertion with == failed
     code:  assert callers(graph, {Process, :monitor, 1}) == [{M, :proc, 1}, {M, :erl_tagged, 1}, {M, :untagged, 2}]
     left:  [
              {AnchorFixtures.CallNamesTest.M, :proc, 1},
              {AnchorFixtures.CallNamesTest.M, :port, 1},
              {AnchorFixtures.CallNamesTest.M, :erl_tagged, 1},
              {AnchorFixtures.CallNamesTest.M, :untagged, 2}
            ]
     right: [
              {AnchorFixtures.CallNamesTest.M, :proc, 1},
              {AnchorFixtures.CallNamesTest.M, :erl_tagged, 1},
              {AnchorFixtures.CallNamesTest.M, :untagged, 2}
            ]
     stacktrace:
       test/anchor/domain/call_names_test.exs:110: (test)

..
```

The AST half was red too: a rule naming `:maps.put/3` did not match a source `Map.put/3` (`left: []`). After the fix: `50 tests, 0 failures`, and the full suite `2142 tests, 0 failures`.

Traps seen:

- CN-G's first form (take the first tagged name, never call `tag_holds?/2`) left `tag_holds?/2` and `one/1` unused, which does not compile under warnings-as-errors; the row is the second form, which reads any literal at a tag's position as the tag.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| CN-A | spellings/1 ignores tags: every sibling is a spelling (`lib/anchor/domain/graph/inlines.ex`) | 5 | tags/0 and spellings/1 of tagged inlines (DND-5613) a tagged name's spellings leave out a sibling with another tag; matches?/4 across Elixir's inlining (DND-5613) may_reach?/4 matches through the names too; matches?/4 across Elixir's inlining (DND-5613) a tagged name does not match its sibling; graph: a rule naming one tagged function matches only its own calls Process.monitor/1 finds proc and the ambiguous call, never Port.monitor; AST: a rule naming either spelling matches a source call in either a rule naming Process.monitor/1 does not match a source Port.monitor/1 |
| CN-B | the walker keeps the Core name of a tagged inline (`lib/anchor/domain/graph/core_walker.ex`) | 5 | the walker reads an inline's tag back into its Elixir name the Erlang spelling with a literal tag is the same function as its Elixir name; graph: a rule naming one tagged function matches only its own calls Process.monitor/1 finds proc and the ambiguous call, never Port.monitor; the walker reads an inline's tag back into its Elixir name Process.monitor/2 is read from :erlang.monitor/3 with the :process tag; the walker reads an inline's tag back into its Elixir name Float.to_string/1 is read from :erlang.float_to_binary/2 with [:short]; the walker reads an inline's tag back into its Elixir name Process.monitor/1 and Port.monitor/1 are two edges, each its own name |
| CN-C | FunctionRef.matches?/4 compares the token's own name only (`lib/anchor/domain/function_ref.ex`) | 5 | AST: a rule naming either spelling matches a source call in either a rule naming Map.put (any arity) matches a source :maps.put/3; AST: a rule naming either spelling matches a source call in either a rule naming Map.put/3 matches a source :maps.put/3; AST: a rule naming either spelling matches a source call in either a rule naming :erlang.monitor/2 matches both Elixir names; AST: a rule naming either spelling matches a source call in either a rule naming :maps.put/3 matches a source Map.put/3; matches?/4 across Elixir's inlining (DND-5613) the Erlang spelling matches a call of the Elixir name, and back |
| CN-D | names/1 of a token with no arity gives only the token (`lib/anchor/domain/function_ref.ex`) | 3 | AST: a rule naming either spelling matches a source call in either a rule naming Map.put (any arity) matches a source :maps.put/3; matches?/4 across Elixir's inlining (DND-5613) the Erlang spelling matches a call of the Elixir name, and back; matches?/4 across Elixir's inlining (DND-5613) names/1 lists every name a token stands for |
| CN-E | Derive.tag/3 finds no tag (`lib/anchor/domain/graph/inlines/derive.ex`) | 11 | tags/0 and spellings/1 of tagged inlines (DND-5613) a tagged name's spellings leave out a sibling with another tag; tags/0 and spellings/1 of tagged inlines (DND-5613) tagged_source/2 names the one Elixir name whose tag the literal arguments hold; tags/0 and spellings/1 of tagged inlines (DND-5613) the tag table holds each rewrite's literal arguments by position; matches?/4 across Elixir's inlining (DND-5613) may_reach?/4 matches through the names too; matches?/4 across Elixir's inlining (DND-5613) a tagged name does not match its sibling; the walker reads an inline's tag back into its Elixir name Process.monitor/1 and Port.monitor/1 are two edges, each its own name; AST: a rule naming either spelling matches a source call in either a rule naming Process.monitor/1 does not match a source Port.monitor/1; the walker reads an inline's tag back into its Elixir name the Erlang spelling with a literal tag is the same function as its Elixir name; the walker reads an inline's tag back into its Elixir name Process.monitor/2 is read from :erlang.monitor/3 with the :process tag; graph: a rule naming one tagged function matches only its own calls Process.monitor/1 finds proc and the ambiguous call, never Port.monitor; the walker reads an inline's tag back into its Elixir name Float.to_string/1 is read from :erlang.float_to_binary/2 with [:short] |
| CN-F | describe/1 of an ambiguous call guesses its first Elixir name (`lib/anchor/domain/graph/inlines.ex`) | 2 | an ambiguous inline names every candidate source function Bitwise.band/2 and &&&/2 are both candidates of :erlang.band/2; an ambiguous inline names every candidate source function an untagged :erlang.monitor/2 names Process.monitor/1 and Port.monitor/1 |
| CN-G | tag_holds?/2 reads any literal at a tag's position as that tag (`lib/anchor/domain/graph/inlines.ex`) | 4 | tags/0 and spellings/1 of tagged inlines (DND-5613) tagged_source/2 names the one Elixir name whose tag the literal arguments hold; the walker reads an inline's tag back into its Elixir name the Erlang spelling with a literal tag is the same function as its Elixir name; graph: a rule naming one tagged function matches only its own calls Process.monitor/1 finds proc and the ambiguous call, never Port.monitor; the walker reads an inline's tag back into its Elixir name Process.monitor/1 and Port.monitor/1 are two edges, each its own name |
| CN-H | may_reach?/4 compares the token's own name only (`lib/anchor/domain/function_ref.ex`) | 1 | matches?/4 across Elixir's inlining (DND-5613) may_reach?/4 matches through the names too |

## CN-A — spellings/1 ignores tags: every sibling is a spelling

Run summary: `100 tests, 5 failures`

```



  1) test tags/0 and spellings/1 of tagged inlines (DND-5613) a tagged name's spellings leave out a sibling with another tag (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:111
     Assertion with == failed
     code:  assert Inlines.spellings({Process, :monitor, 1}) == [{Process, :monitor, 1}, {:erlang, :monitor, 2}]
     left:  [
              {Port, :monitor, 1},
              {Process, :monitor, 1},
              {:erlang, :monitor, 2}
            ]
     right: [{Process, :monitor, 1}, {:erlang, :monitor, 2}]
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:112: (test)

......................
```

## CN-B — the walker keeps the Core name of a tagged inline

Run summary: `100 tests, 5 failures`

```

  1) test the walker reads an inline's tag back into its Elixir name the Erlang spelling with a literal tag is the same function as its Elixir name (Anchor.Domain.CallNamesTest)
     test/anchor/domain/call_names_test.exs:87
     Assertion with in failed
     code:  assert {Process, :monitor, 1} in callees(b, {:erl_tagged, 1})
     left:  {Process, :monitor, 1}
     right: [{:erlang, :monitor, 2}]
     stacktrace:
       test/anchor/domain/call_names_test.exs:90: (test)

..........
```

## CN-C — FunctionRef.matches?/4 compares the token's own name only

Run summary: `100 tests, 5 failures`

```

  1) test AST: a rule naming either spelling matches a source call in either a rule naming Map.put (any arity) matches a source :maps.put/3 (Anchor.Domain.CallNamesTest)
     test/anchor/domain/call_names_test.exs:159
     Assertion with == failed
     code:  assert ast_triggers("  def a(m), do: :maps.put(:k, 1, m)", ["Map.put"]) == [":maps.put/3"]
     left:  []
     right: [":maps.put/3"]
     stacktrace:
       test/anchor/domain/call_names_test.exs:160: (test)

...
```

## CN-D — names/1 of a token with no arity gives only the token

Run summary: `100 tests, 3 failures`

```

  1) test AST: a rule naming either spelling matches a source call in either a rule naming Map.put (any arity) matches a source :maps.put/3 (Anchor.Domain.CallNamesTest)
     test/anchor/domain/call_names_test.exs:159
     Assertion with == failed
     code:  assert ast_triggers("  def a(m), do: :maps.put(:k, 1, m)", ["Map.put"]) == [":maps.put/3"]
     left:  []
     right: [":maps.put/3"]
     stacktrace:
       test/anchor/domain/call_names_test.exs:160: (test)

...............
```

## CN-E — Derive.tag/3 finds no tag

Run summary: `100 tests, 11 failures`

```



  1) test tags/0 and spellings/1 of tagged inlines (DND-5613) a tagged name's spellings leave out a sibling with another tag (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:111
     Assertion with == failed
     code:  assert Inlines.spellings({Process, :monitor, 1}) == [{Process, :monitor, 1}, {:erlang, :monitor, 2}]
     left:  [
              {Port, :monitor, 1},
              {Process, :monitor, 1},
              {:erlang, :monitor, 2}
            ]
     right: [{Process, :monitor, 1}, {:erlang, :monitor, 2}]
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:112: (test)

.............
```

## CN-F — describe/1 of an ambiguous call guesses its first Elixir name

Run summary: `100 tests, 2 failures`

```

  1) test an ambiguous inline names every candidate source function Bitwise.band/2 and &&&/2 are both candidates of :erlang.band/2 (Anchor.Domain.CallNamesTest)
     test/anchor/domain/call_names_test.exs:182
     Assertion with =~ failed
     code:  assert Inlines.describe({:erlang, :band, 2}) =~ "Bitwise.band/2"
     left:  "Bitwise.&&&/2"
     right: "Bitwise.band/2"
     stacktrace:
       test/anchor/domain/call_names_test.exs:188: (test)

.
```

## CN-G — tag_holds?/2 reads any literal at a tag's position as that tag

Run summary: `100 tests, 4 failures`

```

  1) test tags/0 and spellings/1 of tagged inlines (DND-5613) tagged_source/2 names the one Elixir name whose tag the literal arguments hold (Anchor.Domain.Graph.InlinesTest)
     test/anchor/domain/graph/inlines_test.exs:124
     Assertion with == failed
     code:  assert Inlines.tagged_source({:erlang, :monitor, 2}, [{:ok, :process}, :error]) == {Process, :monitor, 1}
     left:  nil
     right: {Process, :monitor, 1}
     stacktrace:
       test/anchor/domain/graph/inlines_test.exs:125: (test)

..................................
```

## CN-H — may_reach?/4 compares the token's own name only

Run summary: `100 tests, 1 failure`

```

  1) test matches?/4 across Elixir's inlining (DND-5613) may_reach?/4 matches through the names too (Anchor.Domain.FunctionRefTest)
     test/anchor/domain/function_ref_test.exs:137
     Expected truthy, got false
     code: assert FunctionRef.may_reach?(ref!(":maps.put/3"), Map, nil, 3)
     arguments:

         # 1
         %Anchor.Domain.FunctionRef{module: :maps, function: :put, arity: 3}

         # 2
         Map

         # 3
         nil

         # 4
         3

     stacktrace:
       test/anchor/domain/function_ref_test.exs:138: (test)

...................................................................
```
