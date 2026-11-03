# Sabotage record — the struct_owned_by_module_flow graph rule (DND-5454)

- **Domain:** struct_flow
- **Branch:** dnd-5447-graph-rules-c
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.StructTypes` (`index/1`, `field/3`, `return/2`), `Anchor.Domain.StructFlow` (`known/3`, `writes/3`), `Anchor.Domain.GraphRules.StructOwnedByModuleFlow` (`check/2`), and `Anchor.Domain.StructOwnership` (`in_scope?/2`, shared with the AST rule `struct_owned_by_module`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/struct_types_test.exs test/anchor/domain/struct_flow_test.exs test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs test/anchor/domain/checks/struct_owned_by_module_test.exs`, through `test-slot`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy. The QA plan's two named sabotages are SF-A (drop the field-type lookup in `StructFlow.known`) and SF-C (drop the defimpl exemption).

Traps seen:

- First forms that did not compile under warnings-as-errors (an unused function, variable or always-false clause): SF-A (`<- nil`), SF-C (`owners = %{}`), SF-D (identical `if` branches), SF-F (the spec lookup replaced by `nil`), SF-M (`is_map(literal)`), SF-O (`hd(writes)`). The rows are the second forms, which change the same behaviour.
- SF-R first survived (0 failures): no test bound a name in a clause that the enclosing scope also binds. The test "a clause's rebinding of a name ends with the clause" (hand-built Core) was added, and SF-R is red against it.
- SF-C's second form first survived: the fixture bucket selected `AnchorFixtures.*`, so the `Inspect.AnchorFixtures...` implementation was never selected and the defimpl row checked nothing. The fixture selector became `*AnchorFixtures.*`, and SF-C is red.
- Every row below is from one run after both fixes, on the final tree.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| SF-A | drop the field-type lookup in StructFlow.known: a field read is unknown (`lib/anchor/domain/struct_flow.ex`) | 2 | flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it; writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf |
| SF-B | drop the field-type lookup for a field in a pattern (%Game{turn: t}) (`lib/anchor/domain/struct_flow.ex`) | 10 | flow rows, flagged crew:754 map update syntax on a field typed as another module's struct; flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it; flow rows, flagged crew:770 a field typed nil \| Struct.t(), and a nested field; flow rows, flagged crew:784 the Map writers, struct/2 and put_in on a field typed as another struct; known/3 %Game{turn: t} in the head: t known by the field type; writes/3: one per op a spec return and a field read, written to; known/3 t = g.turn with g matched %Game{}: known by the field type; check/2 a write outside the owner is one violation naming how the value is known; check/2 owned_namespaces: a struct outside them is not judged, and its module is reported; check/2 the whole fixture: exactly these sites |
| SF-C | drop the defimpl exemption: every impl is owned by its own module (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 2 | check/2 inside the owner none; inside defimpl Inspect, for: Turn none; check/2 the whole fixture: exactly these sites |
| SF-D | a defimpl with a list for: is owned by its struct, not its protocol (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 2 | check/2 a defimpl with a list for: is owned by its protocol, as in the AST rule; check/2 the whole fixture: exactly these sites |
| SF-E | a spec return is never known (`lib/anchor/domain/struct_flow.ex`) | 11 | flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return; flow rows, flagged crew:815 a remote function's return, called directly and piped; flow rows, flagged crew:916 a t naming another module's struct: flagged outside it, not inside it; writes/3: scopes a clause's rebinding of a name ends with the clause; known/3 s = Turn.new(): known by the spec, remote or local; writes/3: one per op a spec return and a field read, written to; check/2 one finding per site: put_in on a spec-known Game reports Game, not also its turn; check/2 a write outside the owner is one violation naming how the value is known; check/2 a defimpl with a list for: is owned by its protocol, as in the AST rule; check/2 owned_namespaces: a struct outside them is not judged, and its module is reported; check/2 the whole fixture: exactly these sites |
| SF-F | a local call's spec return is never known (`lib/anchor/domain/struct_flow.ex`) | 2 | flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return; known/3 s = Turn.new(): known by the spec, remote or local |
| SF-G | a union of structs names its first struct (`lib/anchor/domain/struct_types.ex`) | 2 | index/1 fields a union of two structs, map(), a non-struct and a type outside the graph are unknown; flow rows, allowed (never guessed) crew:855 r855: not reported |
| SF-H | nil \| S.t() is not S (`lib/anchor/domain/struct_types.ex`) | 3 | index/1 fields nil \| Turn.t() is Turn, and the module's own t() names its own struct; index/1 returns two specs agreeing (nil \| t() is t()) are known; disagreeing ones are not; flow rows, flagged crew:770 a field typed nil \| Struct.t(), and a nested field |
| SF-I | specs that disagree name the first one's struct (`lib/anchor/domain/struct_types.ex`) | 2 | index/1 returns two specs agreeing (nil \| t() is t()) are known; disagreeing ones are not; flow rows, allowed (never guessed) crew:875 r875: not reported |
| SF-J | a fun handed to Map.update! gets no field seed (put_in's nested write is lost) (`lib/anchor/domain/struct_flow.ex`) | 2 | flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it; writes/3: one per op put_in(g.turn.status, :x) judges g and g.turn, not the status leaf |
| SF-K | a Map.drop of :__struct__ is a write (`lib/anchor/domain/struct_flow.ex`) | 1 | writes/3: not writes dropping :__struct__ makes a plain map, not a write |
| SF-L | a matched write in hand-written code is reported (two findings with the AST rule) (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 3 | flow rows, flagged crew:784 the Map writers, struct/2 and put_in on a field typed as another struct; check/2 the AST rule's sites are not reported again: a match in hand-written code, a line with literal struct syntax, and a path rooted at a matched value; check/2 the whole fixture: exactly these sites |
| SF-M | a line holding literal struct syntax is reported too (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 2 | check/2 the AST rule's sites are not reported again: a match in hand-written code, a line with literal struct syntax, and a path rooted at a matched value; check/2 the whole fixture: exactly these sites |
| SF-N | a macro-injected function reads as hand-written (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 2 | check/2 the whole fixture: exactly these sites; check/2 a macro-injected write on a matched %Turn{} is one violation, at the use line |
| SF-O | a site reports its first write in Core order, not the one it starts from (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 2 | check/2 one finding per site: put_in on a spec-known Game reports Game, not also its turn; check/2 the whole fixture: exactly these sites |
| SF-P | owned_namespaces does not limit the writes judged (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 1 | check/2 owned_namespaces: a struct outside them is not judged, and its module is reported |
| SF-Q | a struct module outside owned_namespaces is not reported (`lib/anchor/domain/graph_rules/struct_owned_by_module_flow.ex`) | 1 | check/2 owned_namespaces: a struct outside them is not judged, and its module is reported |
| SF-R | the environment is not lexical: a clause's bindings leak into the next (`lib/anchor/domain/struct_flow.ex`) | 1 | writes/3: scopes a clause's rebinding of a name ends with the clause |
| SF-S | a field read's failure clauses count: the read is never known (`lib/anchor/domain/struct_flow.ex`) | 9 | flow rows, flagged crew:754 map update syntax on a field typed as another module's struct; flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it; flow rows, flagged crew:770 a field typed nil \| Struct.t(), and a nested field; flow rows, flagged crew:784 the Map writers, struct/2 and put_in on a field typed as another struct; check/2 the whole fixture: exactly these sites; check/2 a write outside the owner is one violation naming how the value is known; check/2 owned_namespaces: a struct outside them is not judged, and its module is reported; writes/3: one per op a spec return and a field read, written to; known/3 t = g.turn with g matched %Game{}: known by the field type |
| SF-T | a map update records no write (`lib/anchor/domain/struct_flow.ex`) | 18 | flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return; flow rows, flagged crew:815 a remote function's return, called directly and piped; flow rows, flagged crew:770 a field typed nil \| Struct.t(), and a nested field; flow rows, flagged crew:784 the Map writers, struct/2 and put_in on a field typed as another struct; flow rows, flagged crew:916 a t naming another module's struct: flagged outside it, not inside it; flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it; flow rows, flagged crew:754 map update syntax on a field typed as another module's struct; writes/3: one per op merge: Map.put on a matched Turn; writes/3: one per op a spec return and a field read, written to; writes/3: one per op put: Map.put on a matched Turn; writes/3: not writes reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one; writes/3: scopes a clause's rebinding of a name ends with the clause; writes/3: one per op upd: map update on a matched Turn; check/2 the whole fixture: exactly these sites; check/2 a defimpl with a list for: is owned by its protocol, as in the AST rule; check/2 owned_namespaces: a struct outside them is not judged, and its module is reported; check/2 a macro-injected write on a matched %Turn{} is one violation, at the use line; check/2 a write outside the owner is one violation naming how the value is known |
| SF-U | owned_namespaces matches a name it only prefixes (`lib/anchor/domain/struct_ownership.ex`) | 1 | owned_namespaces (crew:605-642) a namespace covers itself and its nested modules, not a name it prefixes |

## SF-A — drop the field-type lookup in StructFlow.known: a field read is unknown

Run summary: `106 tests, 2 failures`

```

  1) test flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:277
     Assertion with == failed
     code:  assert flagged(findings, "AgentState") == [{"finish/1", "Map.update!"}, {"inline/1", "map update"}]
     left:  [{"inline/1", "map update"}]
     right: [{"finish/1", "Map.update!"}, {"inline/1", "map update"}]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:280: (test)

................
```

## SF-B — drop the field-type lookup for a field in a pattern (%Game{turn: t})

Run summary: `106 tests, 10 failures`

```

  1) test flow rows, flagged crew:754 map update syntax on a field typed as another module's struct (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:257
     Assertion with == failed
     code:  assert decider(findings, "r754") == [{"r754/1", "map update"}]
     left:  []
     right: [{"r754/1", "map update"}]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:260: (test)

.
```

## SF-C — drop the defimpl exemption: every impl is owned by its own module

Run summary: `106 tests, 2 failures`

```

  1) test check/2 inside the owner none; inside defimpl Inspect, for: Turn none (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:128
     Expected false or nil, got true
     code: refute Enum.any?(triggers, &(&1 =~ "Inspect"))
     arguments:

         # 1
         ["AnchorFixtures.StructFlow.Rule.Runtime.Decider.box/0",
          "AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1",
          "AnchorFixtures.StructFlow.Rule.Runtime.Decider.injected/1",
          "AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0",
          "AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0",
          "AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1",
          "AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Turn.touch/1",
          "Inspect.AnchorFixtures.StructFlow.Rule.Runtime.Turn.inspect/2"]

         # 2
         #Function<8.70887571/1 in Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest."test check/2 inside the owner none; inside defimpl Inspect, for: Turn none"/1>

     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:132: (test)

..
```

## SF-D — a defimpl with a list for: is owned by its struct, not its protocol

Run summary: `106 tests, 2 failures`

```

  1) test check/2 a defimpl with a list for: is owned by its protocol, as in the AST rule (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:135
     Assertion with in failed
     code:  assert "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Turn.touch/1|#{inspect(@turn)}|Map.put" in keys(model)
     left:  "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Turn.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put"
     right: ["flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.box/0|AnchorFixtures.StructFlow.Rule.Ext.Box|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.injected/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put"]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:138: (test)

.......
```

## SF-E — a spec return is never known

Run summary: `106 tests, 11 failures`

```

  1) test flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:294
     Assertion with == failed
     code:  assert decider(findings, "r831") == [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     left:  []
     right: [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:297: (test)

.......
```

## SF-F — a local call's spec return is never known

Run summary: `106 tests, 2 failures`

```

  1) test flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:294
     Assertion with == failed
     code:  assert decider(findings, "r831") == [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     left:  [{"r831b/0", "map update"}]
     right: [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:297: (test)

............
```

## SF-G — a union of structs names its first struct

Run summary: `106 tests, 2 failures`

```

  1) test index/1 fields a union of two structs, map(), a non-struct and a type outside the graph are unknown (Anchor.Domain.StructTypesTest)
     test/anchor/domain/struct_types_test.exs:104
     Assertion with == failed
     code:  assert StructTypes.field(index, @game, :both) == nil
     left:  AnchorFixtures.StructFlow.Types.Turn
     right: nil
     stacktrace:
       test/anchor/domain/struct_types_test.exs:106: (test)

...............................................
```

## SF-H — nil | S.t() is not S

Run summary: `106 tests, 3 failures`

```

  1) test index/1 fields nil | Turn.t() is Turn, and the module's own t() names its own struct (Anchor.Domain.StructTypesTest)
     test/anchor/domain/struct_types_test.exs:92
     Assertion with == failed
     code:  assert StructTypes.field(index, @game, :last) == @turn
     left:  nil
     right: AnchorFixtures.StructFlow.Types.Turn
     stacktrace:
       test/anchor/domain/struct_types_test.exs:95: (test)

...
```

## SF-I — specs that disagree name the first one's struct

Run summary: `106 tests, 2 failures`

```

  1) test index/1 returns two specs agreeing (nil | t() is t()) are known; disagreeing ones are not (Anchor.Domain.StructTypesTest)
     test/anchor/domain/struct_types_test.exs:121
     Assertion with == failed
     code:  assert StructTypes.return(index, {@turn, :either, 1}) == nil
     left:  AnchorFixtures.StructFlow.Types.Turn
     right: nil
     stacktrace:
       test/anchor/domain/struct_types_test.exs:125: (test)

...................................................
```

## SF-J — a fun handed to Map.update! gets no field seed (put_in's nested write is lost)

Run summary: `106 tests, 2 failures`

```

  1) test flow rows, flagged crew:799 the owner of the outer struct may not write a nested struct through it (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:277
     Assertion with == failed
     code:  assert flagged(findings, "AgentState") == [{"finish/1", "Map.update!"}, {"inline/1", "map update"}]
     left:  [{"inline/1", "map update"}]
     right: [{"finish/1", "Map.update!"}, {"inline/1", "map update"}]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:280: (test)

.............................
```

## SF-K — a Map.drop of :__struct__ is a write

Run summary: `106 tests, 1 failure`

```

  1) test writes/3: not writes dropping :__struct__ makes a plain map, not a write (Anchor.Domain.StructFlowTest)
     test/anchor/domain/struct_flow_test.exs:196
     Assertion with == failed
     code:  assert writes(ctx, :drop_struct, 1) == []
     left:  [
              %{
                line: 47,
                how: :matched,
                op: "Map.drop",
                struct: AnchorFixtures.StructFlow.Flow.Turn
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/struct_flow_test.exs:197: (test)

.................
```

## SF-L — a matched write in hand-written code is reported (two findings with the AST rule)

Run summary: `106 tests, 3 failures`

```

  1) test flow rows, flagged crew:784 the Map writers, struct/2 and put_in on a field typed as another struct (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:268
     Assertion with == failed
     code:  assert decider(findings, "r784") == [
              {"r784a/1", "Map.put"},
              {"r784b/1", "struct"},
              {"r784d/1", "Map.put"}
            ]
     left:  [
              {"r784a/1", "Map.put"},
              {"r784b/1", "struct"},
              {"r784c/1", "Map.update!"},
              {"r784d/1", "Map.put"}
            ]
     right: [
              {"r784a/1", "Map.put"},
              {"r784b/1", "struct"},
              {"r784d/1", "Map.put"}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:273: (test)

......................................................
```

## SF-M — a line holding literal struct syntax is reported too

Run summary: `106 tests, 2 failures`

```

  1) test check/2 the AST rule's sites are not reported again: a match in hand-written code, a line with literal struct syntax, and a path rooted at a matched value (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:152
     literal_line/1
     code: for name <- ~w(matched/1 literal_line/1 path_matched/1),
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:157: (test)

.......................
```

## SF-N — a macro-injected function reads as hand-written

Run summary: `106 tests, 2 failures`

```

  1) test check/2 the whole fixture: exactly these sites (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:187
     Assertion with == failed
     code:  assert keys(model) == [
              "flow|#{@ns}.Runtime.Decider.box/0|#{@ns}.Ext.Box|Map.put",
              "flow|#{@ns}.Runtime.Decider.field/1|#{inspect(@turn)}|Map.put",
              "flow|#{@ns}.Runtime.Decider.injected/1|#{inspect(@turn)}|Map.put",
              "flow|#{@ns}.Runtime.Decider.path_spec/0|#{inspect(@game)}|Map.update!",
              "flow|#{@ns}.Runtime.Decider.spec/0|#{inspect(@turn)}|Map.put",
              "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Game.touch/1|#{inspect(@turn)}|Map.put",
              "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Turn.touch/1|#{inspect(@turn)}|Map.put"
            ]
     left:  ["flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.box/0|AnchorFixtures.StructFlow.Rule.Ext.Box|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Turn.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put"]
     right: ["flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.box/0|AnchorFixtures.StructFlow.Rule.Ext.Box|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.injected/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1|AnchorFixtures.StructFlow.
     [...]
```

## SF-O — a site reports its first write in Core order, not the one it starts from

Run summary: `106 tests, 2 failures`

```

  1) test check/2 one finding per site: put_in on a spec-known Game reports Game, not also its turn (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:161
     Assertion with =~ failed
     code:  assert path.key =~ "|#{inspect(@game)}|Map.update!"
     left:  "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.update!"
     right: "|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!"
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:165: (test)

.
```

## SF-P — owned_namespaces does not limit the writes judged

Run summary: `106 tests, 1 failure`

```

  1) test check/2 owned_namespaces: a struct outside them is not judged, and its module is reported (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:168
     Expected false or nil, got true
     code: refute Enum.any?(owned, &(&1 =~ ".box/0|"))
     arguments:

         # 1
         ["flow|AnchorFixtures.StructFlow.Rule.Ext.Box|outside owned_namespaces",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.box/0|AnchorFixtures.StructFlow.Rule.Ext.Box|Map.put",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.injected/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
          "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Turn.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put"]

         # 2
         #Function<11.70887571/1 in Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest."test check/2 owned_namespaces: a struct outside them is not judged, and its module is reported"/1>

     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:176: (test)

.........
```

## SF-Q — a struct module outside owned_namespaces is not reported

Run summary: `106 tests, 1 failure`

```

  1) test check/2 owned_namespaces: a struct outside them is not judged, and its module is reported (Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:168
     Assertion with in failed
     code:  assert "flow|#{@ns}.Ext.Box|outside owned_namespaces" in owned
     left:  "flow|AnchorFixtures.StructFlow.Rule.Ext.Box|outside owned_namespaces"
     right: ["flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.field/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.injected/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.path_spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Game|Map.update!",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Decider.spec/0|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Game.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put",
             "flow|AnchorFixtures.StructFlow.Rule.Runtime.Proto.AnchorFixtures.StructFlow.Rule.Runtime.Turn.touch/1|AnchorFixtures.StructFlow.Rule.Runtime.Turn|Map.put"]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs:177: (test)

.........
```

## SF-R — the environment is not lexical: a clause's bindings leak into the next

Run summary: `106 tests, 1 failure`

```

  1) test writes/3: scopes a clause's rebinding of a name ends with the clause (Anchor.Domain.StructFlowTest)
     test/anchor/domain/struct_flow_test.exs:174
     match (=) failed
     The following variables were pinned:
       turn = AnchorFixtures.StructFlow.Flow.Turn
     code:  assert [%{struct: ^turn, op: "Map.put", how: {:spec, {^turn, :new, 0}}, line: 7}] =
              StructFlow.writes(core, index, @w)
     left:  [%{struct: ^turn, op: "Map.put", how: {:spec, {^turn, :new, 0}}, line: 7}]
     right: []
     stacktrace:
       test/anchor/domain/struct_flow_test.exs:184: (test)

........................
```

## SF-S — a field read's failure clauses count: the read is never known

Run summary: `106 tests, 9 failures`

```

  1) test flow rows, flagged crew:754 map update syntax on a field typed as another module's struct (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:257
     Assertion with == failed
     code:  assert decider(findings, "r754") == [{"r754/1", "map update"}]
     left:  []
     right: [{"r754/1", "map update"}]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:260: (test)

.
```

## SF-T — a map update records no write

Run summary: `106 tests, 18 failures`

```

  1) test flow rows, flagged crew:831 a local function's return, and a variable bound to a function's return (Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest)
     test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:294
     Assertion with == failed
     code:  assert decider(findings, "r831") == [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     left:  []
     right: [
              {"r831a/0", "map update"},
              {"r831b/0", "map update"},
              {"r831c/0", "map update"}
            ]
     stacktrace:
       test/anchor/domain/graph_rules/struct_owned_by_module_flow_crew_table_test.exs:297: (test)

.
```

## SF-U — owned_namespaces matches a name it only prefixes

Run summary: `106 tests, 1 failure`

```

  1) test owned_namespaces (crew:605-642) a namespace covers itself and its nested modules, not a name it prefixes (Anchor.Domain.Checks.StructOwnedByModuleTest)
     test/anchor/domain/checks/struct_owned_by_module_test.exs:646
     Assertion with == failed
     code:  assert triggers(source, @owned) == ["%App.Deep.Turn{", "%App{"]
     left:  ["%App.Deep.Turn{", "%AppOther.Turn{", "%App{"]
     right: ["%App.Deep.Turn{", "%App{"]
     stacktrace:
       test/anchor/domain/checks/struct_owned_by_module_test.exs:655: (test)

...............................................................................
```
