# Sabotage record — the write walker's default deny (DND-5889)

- **Domain:** aggregates (`Anchor.Domain.HigherOrder`, `Anchor.Domain.GraphReport` and `GraphRules.AggregateWriteSources` are off-domain and labelled by their file)
- **Branch:** dnd-5889-default-deny-walker
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Aggregates.WriteSites` (the default of `project_call/8`, `multi_read/7`, `transaction_function/6`), `NoWrite`, `Scopes`, `Analysis`, `Config`, `Inference`, `GraphReport.summary/1`, `AggregateWriteSources`, `HigherOrder`
- **Suite run:** a driver: one exact, unique anchor per mutation, `mix test --timeout 2000 --max-cases 2 <its test files>` inside `test-slot`, every failure block kept (cut at 3500 bytes), the source restored from bytes with its mtime moved past the last write. `git status` was clean after the run.
- **Passes:** 53 mutations on the ticket's last code. All red. `0 failures, 23 invalid` is `setup_all` crashing, so the file ran no test: that is red. Rows that first failed to compile were rewritten and re-run; none of those runs counts.
- **Not mutated:** every entry of the no-write list. `NW-ENUM`, `NW-QUERYABLE`, `NW-CHANGESET` and `NW-GENSERVER` stand for the class: an entry is an assumption the count and a critic hold (the design says so), and no test asserts a measurement's number.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| DD-DEFAULT | restore the dropping default: an unlisted call reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs`, `scopes_test.exs` | `109 tests, 9 failures` (red) |
| DD-CAPTURE | a capture of an unlisted function is dropped (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 7 failures` (red) |
| DD-CAPTAGS | a capture given as a body is not inside it (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 2 failures` (red) |
| DD-HOCAPTURE | a capture of a listed function that runs its argument is cleared (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-RUN5 | Multi.run/5 on a dependency reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-RUN5PROJECT | Multi.run/5 on a project function is unread (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-TXDEP | a dependency's listed transaction function is also unread (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-ONEOUTCOME | a gap on a handed function is also cleared (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-FUNARG | a function handed to a listed module is not checked (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 2 failures` (red) |
| DD-NAMED | a place HigherOrder names counts as an unread function too (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 9 failures` (red) |
| DD-DATA | any argument to a listed module counts as a function (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 12 failures` (red) |
| DD-APPLYARGS | an apply/3 of a listed function with arguments is cleared (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-ZEROARGS | an apply/3 with no arguments counts as unread (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 6 failures` (red) |
| DD-CLEARED | a cleared call is not counted (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 2 failures` (red) |
| DD-UNREADMARK | an unread call is a plain dynamic gap, with no name (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs`, `scopes_test.exs` | `109 tests, 19 failures` (red) |
| DD-GENERATED | a function use Ecto.Repo generates counts as followed (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-WFSITE | a dependency's write function is also an unread call (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-MULTINAME | an Ecto.Multi name nothing knows reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-MULTIREAD | Multi.new is unread (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs`, `real_ecto_test.exs` | `50 tests, 7 failures` (red) |
| DD-MULTIFUN | a function handed to a Multi read is not checked (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-OTHERPROCESS | a function in another process is no gap outside a transaction (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs`, `non_transactional_test.exs` | `56 tests, 2 failures` (red) |
| DD-PARTLY | an untraced argument beside a traced body is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-LITERAL | a literal beside a traced body counts as untraced (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| DD-LISTWIRED | aggregates.no_write_modules never reaches the walker (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 2 failures` (red) |
| NW-GENSERVER | GenServer on the list (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs`, `write_sites_default_test.exs` | `42 tests, 4 failures` (red) |
| NW-ENUM | Enum off the list (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs`, `write_sites_default_test.exs` | `42 tests, 8 failures` (red) |
| NW-QUERYABLE | Ecto.Queryable off the list: real Ecto expansion gives a gap (`lib/anchor/domain/aggregates/no_write.ex`) | `real_ecto_test.exs` | `13 tests, 1 failure` (red) |
| NW-CHANGESET | Ecto.Changeset off the list (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs`, `real_ecto_test.exs` | `18 tests, 2 failures` (red) |
| NW-GIVESBACK | a function given to Keyword.get/3 is a gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| NW-GIVESBACKTABLE | any listed function counts as handing back (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs`, `write_sites_default_test.exs` | `42 tests, 3 failures` (red) |
| NW-PROCESS | every function of a module held by function is cleared (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs` | `5 tests, 1 failure` (red) |
| HO-LOGGER | HigherOrder loses the row: {Logger, :__do_log__, 4} => [{1, 0}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-TRAVERSE | HigherOrder loses the row: {Ecto.Changeset, :traverse_errors, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-UPDATE | HigherOrder loses the row: {Ecto.Changeset, :update_change, 3} => [{2, 1}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-VALIDATE3 | HigherOrder loses the row: {Ecto.Changeset, :validate_change, 3} => [{2, 2}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-VALIDATE4 | HigherOrder loses the row: {Ecto.Changeset, :validate_change, 4} => [{3, 2}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-MAPSET | HigherOrder loses the row: {MapSet, :new, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| HO-MAPJOIN | HigherOrder loses the row: {Enum, :map_join, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| NW-LISTED | a listed module is not cleared (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs` | `5 tests, 1 failure` (red) |
| NW-LISTEDFN | listing a module held by function clears nothing more (`lib/anchor/domain/aggregates/no_write.ex`) | `no_write_test.exs` | `5 tests, 1 failure` (red) |
| SC-NONTX | an unread call is no gap with no transaction around it (`lib/anchor/domain/aggregates/scopes.ex`) | `write_sites_default_test.exs`, `non_transactional_test.exs` | `56 tests, 8 failures` (red) |
| SC-GAPORDER | an unread gap has no sort order (`lib/anchor/domain/aggregates/scopes.ex`) | `write_sites_default_test.exs` | `37 tests, 0 failures, 37 invalid` (red) |
| AN-CLEARED | the cleared calls are not summed (`lib/anchor/domain/aggregates/analysis.ex`) | `write_sites_default_test.exs`, `real_ecto_test.exs` | `50 tests, 2 failures` (red) |
| AN-UNREAD | the unread calls by callee are empty (`lib/anchor/domain/aggregates/analysis.ex`) | `write_sites_default_test.exs` | `37 tests, 2 failures` (red) |
| AN-DEDUPE | a call read twice at one line counts twice (`lib/anchor/domain/aggregates/analysis.ex`) | `write_sites_default_test.exs` | `37 tests, 1 failure` (red) |
| CF-PARSE | no_write_modules is parsed and dropped (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `48 tests, 2 failures` (red) |
| CF-ERLANG | an Erlang module is refused under no_write_modules (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `48 tests, 1 failure` (red) |
| CF-ERLANGCHAR | any character passes in an Erlang name (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `48 tests, 1 failure` (red) |
| CF-KEY | no_write_modules is an unknown key (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `48 tests, 8 failures` (red) |
| GR-CLEARED | the summary does not print the cleared count (`lib/anchor/domain/graph_report.ex`) | `graph_report_aggregates_test.exs` | `4 tests, 1 failure` (red) |
| GR-NARROW | the summary keeps the run-wide sentence (`lib/anchor/domain/graph_report.ex`) | `graph_report_aggregates_test.exs` | `4 tests, 1 failure` (red) |
| IN-NARROW | the proposal keeps the run-wide sentence (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `17 tests, 1 failure` (red) |
| RU-UNREAD | the rule's message does not name the unread call (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_integration_test.exs` | `2 tests, 1 failure` (red) |

## DD-DEFAULT

restore the dropping default: an unlisted call reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `109 tests, 9 failures`.

```
  1) test a call the walker does not read a function run in another process is a gap with no transaction around it too (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:231
     Assertion with == failed
     code:  assert whats(nontx(a, :d17, 1).gaps) == ["unread: call of GenServer.call/2"]
     left:  []
     right: ["unread: call of GenServer.call/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:235: (test)

.

  2) test a call the walker does not read row 9: reached through two project calls, a gap on the scope that reaches it only (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:212
     match (=) failed
     code:  assert [{:unread, {@d, :second, 0}, _line, what}] = one(a, :d9).gaps
     left:  [{:unread, {AnchorFixtures.WriteSitesDefaultTest.D, :second, 0}, _line, what}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:215: (test)

.

  3) test a call the walker does not read row 10: with no transaction, a gap on the root's nontx and on no scope (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:220
     match (=) failed
     code:  assert [{:unread, {@d, :d10, 1}, _line, what}] = nontx(a, name, arity).gaps
     left:  [{:unread, {AnchorFixtures.WriteSitesDefaultTest.D, :d10, 1}, _line, what}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:222: anonymous fn/3 in Anchor.Domain.Aggregates.WriteSitesDefaultTest."test a call the walker does not read row 10: with no transaction, a gap on the root's nontx and on no scope"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/aggregates/write_sites_default_test.exs:221: (test)

.........

  4) test a call the walker does not read the counts hold the cleared calls and the unread ones by callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:238
     Assertion with == failed
     code:  assert a.counts.unread_by_callee["unread: call of GenServer.call/2"] == 2
     left:  nil
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:240: (test)



  5) test a call the walker does not read row 4: an unlisted dependency call is a gap at its line, naming it; the scope is incomplete (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:152
     match (=) failed
     The following variables were pinned:
       line = 40
     code:  assert %Scope{no_gap_noticed?: false, gaps: [{:unread, {@d, :d4, 1}, ^line, what}]} = one(a, :d4)
     left:  %Anchor.Domain.Aggregates.Scope{
              no_gap_noticed?: false,
              gaps: [{:unread, {AnchorFixtures.WriteSitesDefaultTest.D, :d4, 1}, ^line, what}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d4, 1},
              ordinal: 1,
              line: 40,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:156: (test)

....

  6) test an apply with a lit
```

## DD-CAPTURE

a capture of an unlisted function is dropped (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 7 failures`.

```
  1) test exactly one outcome per call a capture read twice at one line counts once in unread_by_callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:355
     Assertion with == failed
     code:  assert a.counts.unread_by_callee[String.replace(lib_call("only_here/1"), "call of", "capture of")] == 1
     left:  nil
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:356: (test)



  2) test a capture of a listed function that runs its argument is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:298
     Assertion with == failed
     code:  assert whats(one(a, :d12c).gaps) == ["unread: capture of Enum.map/2"]
     left:  []
     right: ["unread: capture of Enum.map/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:299: (test)



  3) test a capture of an unlisted dependency is a gap; of a listed function it is cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:290
     Assertion with == failed
     code:  assert whats(one(a, :d12a).gaps) == [lib_call("save/1") |> String.replace("call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.save/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:291: (test)

.

  4) test a capture of an Ecto.Multi step or a generated repo function is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:302
     Assertion with == failed
     code:  assert whats(one(a, :d12d).gaps) == ["unread: capture of Ecto.Multi.insert/3"]
     left:  []
     right: ["unread: capture of Ecto.Multi.insert/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:303: (test)

...

  5) test a dependency's function a transaction or a Multi runs Multi.run/5 on one is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:323
     Assertion with == failed
     code:  assert whats(one(a, :d21c).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:324: (test)

..

  6) test a dependency's function a transaction or a Multi runs a capture of one as a Multi.run callback is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:317
     Assertion with == failed
     code:  assert whats(one(a, :d21b).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:318: (test)

.

  7) test a dependency's function a transaction or a Multi runs a capture of one as the transaction's body is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:309
     Assertion with == failed
     code:  assert whats(one(a, :d21a).gaps) == [String.replace(lib_ca
```

## DD-CAPTAGS

a capture given as a body is not inside it (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 2 failures`.

```
  1) test a dependency's function a transaction or a Multi runs a capture of one as a Multi.run callback is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:317
     Assertion with == failed
     code:  assert whats(one(a, :d21b).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:318: (test)

.

  2) test a dependency's function a transaction or a Multi runs a capture of one as the transaction's body is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:309
     Assertion with == failed
     code:  assert whats(one(a, :d21a).gaps) == [String.replace(lib_call("run/0"), "call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.run/0"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:310: (test)

.......
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-HOCAPTURE

a capture of a listed function that runs its argument is cleared (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a capture of a listed function that runs its argument is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:298
     Assertion with == failed
     code:  assert whats(one(a, :d12c).gaps) == ["unread: capture of Enum.map/2"]
     left:  []
     right: ["unread: capture of Enum.map/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:299: (test)

....
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-RUN5

Multi.run/5 on a dependency reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a dependency's function a transaction or a Multi runs Multi.run/5 on one is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:323
     Assertion with == failed
     code:  assert whats(one(a, :d21c).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:324: (test)

.............................
Finished in 0.5 seconds (0.5s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-RUN5PROJECT

Multi.run/5 on a project function is unread (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a dependency's function a transaction or a Multi runs positive control: Multi.run/5 on a project function is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:329
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d21d)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d21d,
               0},
              ordinal: 1,
              line: 101,
              kind: :multi,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d21d, 0},
                 101,
                 "unread: capture of AnchorFixtures.WriteSitesDefaultTest.D.own_step/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:330: (test)

...............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-TXDEP

a dependency's listed transaction function is also unread (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a dependency's function a transaction or a Multi runs a dependency's listed transaction function is read as a scope, never unread (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:333
     Expected truthy, got false
     code: assert Enum.all?(scopes, &(&1.gaps == []))
     arguments:

         # 1
         [
           %Anchor.Domain.Aggregates.Scope{
             mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d22, 0},
             ordinal: 1,
             line: 103,
             kind: :transaction_function,
             writes: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d22, 0},
                 line: 103,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.WriteSitesDefaultTest.S
                 ],
                 unresolved: nil,
                 scopes: [2, 1],
                 run_callback?: false
               }
             ],
             keys: MapSet.new([
               schema: AnchorFixtures.WriteSitesDefaultTest.S
             ]),
             no_gap_noticed?: true,
             gaps: []
           },
           %Anchor.Domain.Aggregates.Scope{
             mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d22, 0},
             ordinal: 2,
             line: 103,
             kind: :fun,
             writes: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d22, 0},
                 line: 103,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.WriteSitesDefaultTest.S
                 ],
                 unresolved: nil,
                 scopes: [2, 1],
                 run_callback?: false
               }
             ],
             keys: MapSet.new([
               schema: AnchorFixtures.WriteSitesDefaultTest.S
             ]),
             no_gap_noticed?: false,
             gaps: [
               {:unread,
                {AnchorFixtures.WriteSitesDefaultTest.D, :d22, 0}, 103,
                "unread: call of AnchorFixtures.WriteSitesDefaultTest.Lib.tx/1"}
             ]
           }
         ]

         # 2
         #Function<4.1553967/1 in Anchor.Domain.Aggregates.WriteSitesDefaultTest."test a dependency's function a transaction or a Multi runs a dependency's listed transaction function is read as a scope, never unread"/1>

     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:340: (test)

....................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-ONEOUTCOME

a gap on a handed function is also cleared (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test exactly one outcome per call an unknown function handed to a listed function is a gap, and is not also cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:347
     match (=) failed
     code:  assert %{cleared: 0, dynamic: [_gap]} = facts.functions[{@d, :d23, 2}]
     left:  %{cleared: 0, dynamic: [_gap]}
     right: %{
              dynamic: [
                %{
                  line: 104,
                  tags: [1],
                  what: "the function handed to Enum.map/2",
                  write?: false
                }
              ],
              computed: [],
              sites: [],
              txs: [
                %{
                  line: 104,
                  kind: :fun,
                  ordinal: 1,
                  captures: [],
                  gaps: []
                }
              ],
              calls: [],
              cleared: 1,
              def_line: 104,
              public?: true
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:352: (test)

..................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-FUNARG

a function handed to a listed module is not checked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 2 failures`.

```
  1) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15b).gaps) == ["unread: a function handed to Ecto.Multi.put/3"]
     left:  []
     right: ["unread: a function handed to Ecto.Multi.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:278: (test)



  2) test a call the walker does not read row 8: a function given to a listed module where HigherOrder names no place is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:192
     Assertion with == failed
     code:  assert whats(one(a, :d8a).gaps) == ["unread: a function handed to Keyword.put/3"]
     left:  []
     right: ["unread: a function handed to Keyword.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:194: (test)

...................................
Finished in 0.5 seconds (0.5s async, 0.00s sync)
37 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-NAMED

a place HigherOrder names counts as an unread function too (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 9 failures`.

```
  1) test a function a listed function runs where it is called d20e: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20e,
               1},
              ordinal: 1,
              line: 94,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20e, 1},
                 94,
                 "unread: a function handed to Ecto.Changeset.validate_change/4"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

...

  2) test a function a listed function runs where it is called d20f: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20f,
               1},
              ordinal: 1,
              line: 95,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20f, 1},
                 95, "unread: a function handed to MapSet.new/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

..

  3) test a function a listed function runs where it is called d20g: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20g,
               1},
              ordinal: 1,
              line: 96,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20g, 1},
                 96, "unread: a function handed to Enum.map_join/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

..

  4) test a capture of an unlisted dependency is a gap; of a listed function it is cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:290
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d12b)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domai
```

## DD-DATA

any argument to a listed module counts as a function (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 12 failures`.

```
  1) test a call the walker does not read row 10: with no transaction, a gap on the root's nontx and on no scope (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:220
     Assertion with == failed
     code:  assert nontx(a, :d10_clean, 1).gaps == []
     left:  [
              {:unread,
               {AnchorFixtures.WriteSitesDefaultTest.D, :d10_clean,
                1}, 61, "unread: a function handed to Enum.count/1"}
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:228: (test)

....

  2) test a call the walker does not read row 5: every cleared call is counted, none from a form read another way (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:168
     Assertion with == failed
     code:  assert facts.functions[{@d, :d5, 1}].cleared == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:174: (test)



  3) test a function a listed function runs where it is called d20f: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20f,
               1},
              ordinal: 1,
              line: 95,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20f, 1},
                 95, "unread: a function handed to MapSet.new/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

.

  4) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d15c)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d15c,
               1},
              ordinal: 1,
              line: 84,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d15c, 1},
                 84,
                 "unread: a function handed to Ecto.Multi.put/3"},
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d15c, 1},
                 84,
                 "unread: a function handed to Ecto.Multi.to_list/1"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:279: (test)

..

  5) test a function a listed function runs where it is called d20d: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_si
```

## DD-APPLYARGS

an apply/3 of a listed function with arguments is cleared (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test an apply with a literal module and name of a listed function with arguments is a gap: Anchor has no argument nodes (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:367
     Assertion with == failed
     code:  assert whats(one(a, :d13b).gaps) == ["unread: a function handed to Map.put/3"]
     left:  []
     right: ["unread: a function handed to Map.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:370: (test)

.......
Finished in 0.5 seconds (0.5s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-ZEROARGS

an apply/3 with no arguments counts as unread (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 6 failures`.

```
  1) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15).gaps) == ["unread: call of Ecto.Multi.not_a_function/1"]
     left:  ["unread: a function handed to Ecto.Multi.new/0",
             "unread: call of Ecto.Multi.not_a_function/1"]
     right: ["unread: call of Ecto.Multi.not_a_function/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:277: (test)

.

  2) test a dependency's function a transaction or a Multi runs Multi.run/5 on one is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:323
     Assertion with == failed
     code:  assert whats(one(a, :d21c).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  ["unread: a function handed to Ecto.Multi.new/0",
             "unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:324: (test)

.......

  3) test an apply with a literal module and name of a listed function with no arguments is cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:373
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d13c)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d13c,
               0},
              ordinal: 1,
              line: 77,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d13c, 0},
                 77, "unread: a function handed to Enum.to_list/0"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:374: (test)

..........

  4) test the forms DND-5459 reads stay row 11: a repo write, a Multi step, a listed write function, raw SQL: sites as before (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:261
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d11b,
               0},
              ordinal: 1,
              line: 64,
              kind: :multi,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.WriteSitesDefaultTest.D,
                   :d11b, 0},
                  line: 64,
                  op: :insert,
                  via: :multi,
                  sources: [
                    schema: AnchorFixtures.WriteSitesDefaultTest.S
                  ],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.n
```

## DD-CLEARED

a cleared call is not counted (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 2 failures`.

```
  1) test a call the walker does not read row 5: every cleared call is counted, none from a form read another way (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:168
     Assertion with == failed
     code:  assert facts.functions[{@d, :d5, 1}].cleared == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:174: (test)

.............................

  2) test a call the walker does not read the counts hold the cleared calls and the unread ones by callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:238
     Assertion with >= failed
     code:  assert a.counts.cleared >= 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:239: (test)

.....
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-UNREADMARK

an unread call is a plain dynamic gap, with no name (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `109 tests, 19 failures`.

```
  1) test a call the walker does not read row 6: GenServer.call/2 is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:180
     Assertion with == failed
     code:  assert whats(one(a, :d6).gaps) == ["unread: call of GenServer.call/2"]
     left:  []
     right: ["unread: call of GenServer.call/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:181: (test)



  2) test exactly one outcome per call a capture read twice at one line counts once in unread_by_callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:355
     Assertion with == failed
     code:  assert a.counts.unread_by_callee[String.replace(lib_call("only_here/1"), "call of", "capture of")] == 1
     left:  nil
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:356: (test)

..

  3) test a project function the analysis does not walk a macro's own function is a gap, never a call to nowhere (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:255
     Assertion with == failed
     code:  assert whats(one(a, :d19).gaps) == ["unread: call of #{inspect(@macros)}.MACRO-m/2"]
     left:  []
     right: ["unread: call of AnchorFixtures.WriteSitesDefaultTest.Macros.MACRO-m/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:256: (test)

...

  4) test a call the walker does not read row 9: reached through two project calls, a gap on the scope that reaches it only (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:212
     match (=) failed
     code:  assert [{:unread, {@d, :second, 0}, _line, what}] = one(a, :d9).gaps
     left:  [{:unread, {AnchorFixtures.WriteSitesDefaultTest.D, :second, 0}, _line, what}]
     right: [
              {:dynamic_call,
               {AnchorFixtures.WriteSitesDefaultTest.D, :second, 0},
               57}
            ]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:215: (test)



  5) test a call the walker does not read a function run in another process is a gap with no transaction around it too (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:231
     Assertion with == failed
     code:  assert whats(nontx(a, :d17, 1).gaps) == ["unread: call of GenServer.call/2"]
     left:  []
     right: ["unread: call of GenServer.call/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:235: (test)



  6) test a capture of an unlisted dependency is a gap; of a listed function it is cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:290
     Assertion with == failed
     code:  assert whats(one(a, :d12a).gaps) == [lib_call("save/1") |> String.replace("call of", "capture of")]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.save/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:291: (test)



  7) test a call the walker does not read row 4: an unlisted dependency call is a gap at its line, naming it; the scope is incomplete (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_defau
```

## DD-GENERATED

a function use Ecto.Repo generates counts as followed (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a capture of an Ecto.Multi step or a generated repo function is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:302
     Assertion with == failed
     code:  assert whats(one(a, :d12e).gaps) == ["unread: capture of #{inspect(@repo)}.all/1"]
     left:  []
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Repo.all/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:304: (test)

..............................
Finished in 0.5 seconds (0.5s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-WFSITE

a dependency's write function is also an unread call (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test the forms DND-5459 reads stay row 11: a repo write, a Multi step, a listed write function, raw SQL: sites as before (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:261
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d11c,
               0},
              ordinal: 1,
              line: 65,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.WriteSitesDefaultTest.D,
                   :d11c, 0},
                  line: 65,
                  op: :soft_delete,
                  via: :write_function,
                  sources: [
                    schema: AnchorFixtures.WriteSitesDefaultTest.S
                  ],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([
                schema: AnchorFixtures.WriteSitesDefaultTest.S
              ]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d11c, 0},
                 65,
                 "unread: call of AnchorFixtures.WriteSitesDefaultTest.Lib.soft_delete/1"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:270: anonymous fn/3 in Anchor.Domain.Aggregates.WriteSitesDefaultTest."test the forms DND-5459 reads stay row 11: a repo write, a Multi step, a listed write function, raw SQL: sites as before"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/aggregates/write_sites_default_test.exs:269: (test)

..................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-MULTINAME

an Ecto.Multi name nothing knows reads as no write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15).gaps) == ["unread: call of Ecto.Multi.not_a_function/1"]
     left:  []
     right: ["unread: call of Ecto.Multi.not_a_function/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:277: (test)

..........................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-MULTIREAD

Multi.new is unread (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `50 tests, 7 failures`.

```
  1) test DND-5889: Ecto's own expansion, and what `use Ecto.Schema` generates, is no gap (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:180
     Assertion with == failed
     code:  assert a.counts.unread_by_callee == %{}
     left:  %{"unread: call of Ecto.Multi.new/0" => 1}
     right: %{}
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:183: (test)

....

  2) test E4: a real Multi pipeline's scope keys are exactly the written schemas (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:188
     Expected truthy, got false
     code: assert scope.no_gap_noticed?
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:191: (test)

........

  3) test a dependency's function a transaction or a Multi runs positive control: Multi.run/5 on a project function is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:329
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d21d)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d21d,
               0},
              ordinal: 1,
              line: 101,
              kind: :multi,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d21d, 0},
                 101, "unread: call of Ecto.Multi.new/0"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:330: (test)

...

  4) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15).gaps) == ["unread: call of Ecto.Multi.not_a_function/1"]
     left:  ["unread: call of Ecto.Multi.new/0",
             "unread: call of Ecto.Multi.not_a_function/1"]
     right: ["unread: call of Ecto.Multi.not_a_function/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:277: (test)

.

  5) test a dependency's function a transaction or a Multi runs a capture of one as a Multi.run callback is a gap of that transaction (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:317
     Assertion with == failed
     code:  assert whats(one(a, :d21b).gaps) == [String.replace(lib_call("step/2"), "call of", "capture of")]
     left:  ["unread: call of Ecto.Multi.new/0",
             "unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     right: ["unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.step/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:318: (test)

..

  6) test the forms DND-5459 reads stay row 11: a repo write, a Multi step, a listed write function, raw SQL: sites as before (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:261
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Ag
```

## DD-MULTIFUN

a function handed to a Multi read is not checked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15b).gaps) == ["unread: a function handed to Ecto.Multi.put/3"]
     left:  []
     right: ["unread: a function handed to Ecto.Multi.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:278: (test)

........................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-OTHERPROCESS

a function in another process is no gap outside a transaction (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `56 tests, 2 failures`.

```
  1) test the gaps with no transaction read around them are counted (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:305
     Expected truthy, got false
     code: assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n26, 0}, _line}, &1))
     arguments:

         # 1
         [
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n41, 2}, 95},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n42, 2}, 96},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, 59},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n40, 1}, 94},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n9, 0}, 129},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n54, 2}, 72},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n52, 1}, 70},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n32, 1}, 99},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n13, 1}, 60},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n39, 2}, 93},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n34, 2}, 101},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n50, 1}, 68},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n38, 2}, 92},
           {:dynamic_call,
            {AnchorFixtures.NonTransactionalTest.N, :n36, 1}, 90},
           {:dynamic_call, ...},
           ...
         ]

         # 2
         #Function<7.16135393/1 in Anchor.Domain.Aggregates.NonTransactionalTest."test the gaps with no transaction read around them are counted"/1>

     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:314: (test)

.......................

  2) test a call the walker does not read a function run in another process is a gap with no transaction around it too (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:231
     match (=) failed
     code:  assert [{:dynamic_call, {@d, :d18, 0}, _line}] = nontx(a, :d18, 0).gaps
     left:  [{:dynamic_call, {AnchorFixtures.WriteSitesDefaultTest.D, :d18, 0}, _line}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:234: (test)

.....................
Finished in 0.5 seconds (0.5s async, 0.00s sync)
56 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-PARTLY

an untraced argument beside a traced body is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a transaction_functions call row 14: one argument traced and one not is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:379
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@d, :d14a, 1}, _}]} = one(a, :d14a)
     left:  %Anchor.Domain.Aggregates.Scope{
              no_gap_noticed?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.WriteSitesDefaultTest.D, :d14a, 1}, _}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d14a,
               1},
              ordinal: 1,
              line: 79,
              kind: :transaction_function,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.WriteSitesDefaultTest.D,
                   :d14a, 1},
                  line: 79,
                  op: :insert,
                  via: :repo,
                  sources: [
                    schema: AnchorFixtures.WriteSitesDefaultTest.S
                  ],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([
                schema: AnchorFixtures.WriteSitesDefaultTest.S
              ]),
              no_gap_noticed?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:380: (test)

....................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-LITERAL

a literal beside a traced body counts as untraced (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a transaction_functions call row 14: positive control: the other argument a literal is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:384
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, keys: keys} = one(a, :d14b)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, keys: keys}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d14b,
               0},
              ordinal: 1,
              line: 80,
              kind: :transaction_function,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.WriteSitesDefaultTest.D,
                   :d14b, 0},
                  line: 80,
                  op: :insert,
                  via: :repo,
                  sources: [
                    schema: AnchorFixtures.WriteSitesDefaultTest.S
                  ],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([
                schema: AnchorFixtures.WriteSitesDefaultTest.S
              ]),
              no_gap_noticed?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d14b, 0},
                 80}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:385: (test)

............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## DD-LISTWIRED

aggregates.no_write_modules never reaches the walker (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 2 failures`.

```
  1) test a call the walker does not read row 8: positive controls: data to a listed module, a function HigherOrder names (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:204
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d8d)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d8d, 1},
              ordinal: 1,
              line: 48,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d8d, 1},
                 48,
                 "unread: call of AnchorFixtures.WriteSitesDefaultTest.Listed.run/1"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:207: (test)

........

  2) test a call the walker does not read row 8: a function given to a listed module where HigherOrder names no place is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:192
     Assertion with == failed
     code:  assert whats(one(a, :d8c).gaps) == ["unread: a function handed to #{inspect(@listed)}.run/1"]
     left:  ["unread: call of AnchorFixtures.WriteSitesDefaultTest.Listed.run/1"]
     right: ["unread: a function handed to AnchorFixtures.WriteSitesDefaultTest.Listed.run/1"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:197: (test)

.............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## NW-GENSERVER

GenServer on the list (`lib/anchor/domain/aggregates/no_write.ex`). Result: `42 tests, 4 failures`.

```
  1) test member?/2 what hands work to another process, or runs code, is never cleared (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:23
     {GenServer, :call, 2} must be a gap
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:42: anonymous fn/2 in Anchor.Domain.Aggregates.NoWriteTest."test member?/2 what hands work to another process, or runs code, is never cleared"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/aggregates/no_write_test.exs:24: (test)

...

  2) test a call the walker does not read row 6: GenServer.call/2 is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:180
     Assertion with == failed
     code:  assert whats(one(a, :d6).gaps) == ["unread: call of GenServer.call/2"]
     left:  []
     right: ["unread: call of GenServer.call/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:181: (test)

...........................

  3) test a call the walker does not read a function run in another process is a gap with no transaction around it too (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:231
     Assertion with == failed
     code:  assert whats(nontx(a, :d17, 1).gaps) == ["unread: call of GenServer.call/2"]
     left:  []
     right: ["unread: call of GenServer.call/2"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:235: (test)

.......

  4) test a call the walker does not read the counts hold the cleared calls and the unread ones by callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:238
     Assertion with == failed
     code:  assert a.counts.unread_by_callee["unread: call of GenServer.call/2"] == 2
     left:  nil
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:240: (test)


Finished in 0.4 seconds (0.4s async, 0.00s sync)
42 tests, 4 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## NW-ENUM

Enum off the list (`lib/anchor/domain/aggregates/no_write.ex`). Result: `42 tests, 8 failures`.

```
  1) test member?/2 a pure library call is cleared (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:10
     Expected truthy, got false
     code: assert NoWrite.member?({Enum, :count, 1}, [])
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:11: (test)

...

  2) test a call the walker does not read row 10: with no transaction, a gap on the root's nontx and on no scope (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:220
     Assertion with == failed
     code:  assert nontx(a, :d10_clean, 1).gaps == []
     left:  [
              {:unread,
               {AnchorFixtures.WriteSitesDefaultTest.D, :d10_clean,
                1}, 61, "unread: call of Enum.count/1"}
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:228: (test)

.............

  3) test a function a listed function runs where it is called d20g: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20g,
               1},
              ordinal: 1,
              line: 96,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20g, 1},
                 96, "unread: call of Enum.map_join/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

............

  4) test an apply with a literal module and name of a listed function with no arguments is cleared (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:373
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d13c)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d13c,
               0},
              ordinal: 1,
              line: 77,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d13c, 0},
                 77, "unread: call of Enum.to_list/0"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:374: (test)



  5) test a call the walker does not read row 5: every cleared call is counted, none from a form read another way (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:168
     Assertion with == failed
     code:  assert facts.functions[{@d, :d5, 1}].cleared == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:174: (test)



  6) test a call the walker does not read row 5: a call on the no-write list is no gap (Anchor.Domain.Aggrega
```

## NW-QUERYABLE

Ecto.Queryable off the list: real Ecto expansion gives a gap (`lib/anchor/domain/aggregates/no_write.ex`). Result: `13 tests, 1 failure`.

```
  1) test DND-5889: Ecto's own expansion, and what `use Ecto.Schema` generates, is no gap (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:180
     Assertion with == failed
     code:  assert a.counts.unread_by_callee == %{}
     left:  %{"unread: call of Ecto.Queryable.to_query/1" => 1}
     right: %{}
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:183: (test)

.....
Finished in 0.1 seconds (0.1s async, 0.00s sync)
13 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## NW-CHANGESET

Ecto.Changeset off the list (`lib/anchor/domain/aggregates/no_write.ex`). Result: `18 tests, 2 failures`.

```
  1) test member?/2 a pure library call is cleared (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:10
     Expected truthy, got false
     code: assert NoWrite.member?({Ecto.Changeset, :change, 1}, [])
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:14: (test)

.......

  2) test DND-5889: Ecto's own expansion, and what `use Ecto.Schema` generates, is no gap (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:180
     Assertion with == failed
     code:  assert a.counts.unread_by_callee == %{}
     left:  %{
              "unread: call of Ecto.Changeset.apply_changes/1" => 1,
              "unread: call of Ecto.Changeset.change/1" => 3,
              "unread: call of Ecto.Changeset.get_change/2" => 1,
              "unread: call of Ecto.Changeset.validate_required/2" => 1
            }
     right: %{}
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:183: (test)

......
Finished in 0.1 seconds (0.1s async, 0.00s sync)
18 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## NW-GIVESBACK

a function given to Keyword.get/3 is a gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```
  1) test a call the walker does not read row 8: positive controls: data to a listed module, a function HigherOrder names (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:204
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true} = one(a, :d8f)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d8f, 1},
              ordinal: 1,
              line: 50,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d8f, 1},
                 50, "unread: a function handed to Keyword.get/3"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:209: (test)

...............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```

## NW-GIVESBACKTABLE

any listed function counts as handing back (`lib/anchor/domain/aggregates/no_write.ex`). Result: `42 tests, 3 failures`.

```
  1) test gives_back?/1 a function that returns its default, never runs it; any other is not (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:60
     Expected false or nil, got true
     code: refute NoWrite.gives_back?({Keyword, :put, 3})
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:63: (test)

............................

  2) test the forms DND-5459 reads stay the rest of Ecto.Multi reads; a name it does not know is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:276
     Assertion with == failed
     code:  assert whats(one(a, :d15b).gaps) == ["unread: a function handed to Ecto.Multi.put/3"]
     left:  []
     right: ["unread: a function handed to Ecto.Multi.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:278: (test)

...

  3) test a call the walker does not read row 8: a function given to a listed module where HigherOrder names no place is a gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:192
     Assertion with == failed
     code:  assert whats(one(a, :d8a).gaps) == ["unread: a function handed to Keyword.put/3"]
     left:  []
     right: ["unread: a function handed to Keyword.put/3"]
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:194: (test)

......
Finished in 0.4 seconds (0.4s async, 0.00s sync)
42 tests, 3 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/write_sites.ex" was set to the future, resetting to now
```
## NW-PROCESS

every function of a module held by function is cleared (`lib/anchor/domain/aggregates/no_write.ex`). Result: `5 tests, 1 failure`.

```
  1) test member?/2 what hands work to another process, or runs code, is never cleared (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:23
     {:erlang, :send, 2} must be a gap
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:42: anonymous fn/2 in Anchor.Domain.Aggregates.NoWriteTest."test member?/2 what hands work to another process, or runs code, is never cleared"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/aggregates/no_write_test.exs:24: (test)

..
Finished in 0.03 seconds (0.03s async, 0.00s sync)
5 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## HO-LOGGER

HigherOrder loses the row: {Logger, :__do_log__, 4} => [{1, 0}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20a: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20a,
               0},
              ordinal: 1,
              line: 90,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20a, 0},
                 90,
                 "unread: a function handed to Logger.__do_log__/4"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

...............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## HO-TRAVERSE

HigherOrder loses the row: {Ecto.Changeset, :traverse_errors, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20b: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20b,
               1},
              ordinal: 1,
              line: 91,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20b, 1},
                 91,
                 "unread: a function handed to Ecto.Changeset.traverse_errors/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

......
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## HO-UPDATE

HigherOrder loses the row: {Ecto.Changeset, :update_change, 3} => [{2, 1}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20c: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20c,
               1},
              ordinal: 1,
              line: 92,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20c, 1},
                 92,
                 "unread: a function handed to Ecto.Changeset.update_change/3"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

..................................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## HO-VALIDATE3

HigherOrder loses the row: {Ecto.Changeset, :validate_change, 3} => [{2, 2}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20d: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20d,
               1},
              ordinal: 1,
              line: 93,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20d, 1},
                 93,
                 "unread: a function handed to Ecto.Changeset.validate_change/3"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

..................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## HO-VALIDATE4

HigherOrder loses the row: {Ecto.Changeset, :validate_change, 4} => [{3, 2}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20e: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20e,
               1},
              ordinal: 1,
              line: 94,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20e, 1},
                 94,
                 "unread: a function handed to Ecto.Changeset.validate_change/4"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)


Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## HO-MAPSET

HigherOrder loses the row: {MapSet, :new, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20f: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20f,
               1},
              ordinal: 1,
              line: 95,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20f, 1},
                 95, "unread: a function handed to MapSet.new/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

.............................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## HO-MAPJOIN

HigherOrder loses the row: {Enum, :map_join, 2} => [{1, 1}], (`lib/anchor/domain/higher_order.ex`). Result: `37 tests, 1 failure`.

```
  1) test a function a listed function runs where it is called d20g: HigherOrder names its place, so it is no gap (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:248
     match (=) failed
     code:  assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{no_gap_noticed?: true, gaps: []}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.WriteSitesDefaultTest.D, :d20g,
               1},
              ordinal: 1,
              line: 96,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              no_gap_noticed?: false,
              gaps: [
                {:unread,
                 {AnchorFixtures.WriteSitesDefaultTest.D, :d20g, 1},
                 96, "unread: a function handed to Enum.map_join/2"}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:249: (test)

..............
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
```

## NW-LISTED

a listed module is not cleared (`lib/anchor/domain/aggregates/no_write.ex`). Result: `5 tests, 1 failure`.

```
  1) test member?/2 a module under aggregates.no_write_modules is cleared; with no list it is not (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:46
     Expected truthy, got false
     code: assert NoWrite.member?({Lib, :save, 1}, [Lib])
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:47: (test)


Finished in 0.03 seconds (0.03s async, 0.00s sync)
5 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/higher_order.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## NW-LISTEDFN

listing a module held by function clears nothing more (`lib/anchor/domain/aggregates/no_write.ex`). Result: `5 tests, 1 failure`.

```
  1) test member?/2 listing a module held by function clears its other functions (Anchor.Domain.Aggregates.NoWriteTest)
     test/anchor/domain/aggregates/no_write_test.exs:52
     Expected truthy, got false
     code: assert NoWrite.member?({:erlang, :send, 2}, [:erlang])
     stacktrace:
       test/anchor/domain/aggregates/no_write_test.exs:53: (test)


Finished in 0.03 seconds (0.03s async, 0.00s sync)
5 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/no_write.ex" was set to the future, resetting to now
```

## SC-NONTX

an unread call is no gap with no transaction around it (`lib/anchor/domain/aggregates/scopes.ex`). Result: `56 tests, 8 failures`.

```
  1) test a captured run callback's own entry is empty; a direct caller still has its writes (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:268
     Assertion with == failed
     code:  assert nontx(a, :n19_direct).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:271: (test)

.....

  2) test N3: a callee also called outside: the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:150
     Assertion with == failed
     code:  assert nontx(a, :n3h).keys == keys([@t])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:152: (test)

.

  3) test the gaps with no transaction read around them are counted (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:305
     Expected truthy, got false
     code: assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n17h, 0}, _line}, &1))
     arguments:

         # 1
         []

         # 2
         #Function<6.16135393/1 in Anchor.Domain.Aggregates.NonTransactionalTest."test the gaps with no transaction read around them are counted"/1>

     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:312: (test)



  4) test a capture beside a body capture of one function is outside the transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:156
     Assertion with == failed
     code:  assert nontx(a, :n47_run).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:159: (test)



  5) test N1: a function's own writes and its callees' outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:138
     Assertion with == failed
     code:  assert nontx(a, :n1f).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:139: (test)

...

  6) test N4: recursion terminates at the fixpoint (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:172
     Assertion with == failed
     code:  assert nontx(a, :n4a, 1).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:173: (test)

...................

  7) test a call the walker does not read a function run in another process is a gap with no transaction around it too (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:231
```

## SC-GAPORDER

an unread gap has no sort order (`lib/anchor/domain/aggregates/scopes.ex`). Result: `37 tests, 0 failures, 37 invalid`.

```
Compiling 16 files (.ex)
Generated anchor app
Running ExUnit with seed: 338915, max_cases: 2

?????????????????????????????????????

  0) Anchor.Domain.Aggregates.WriteSitesDefaultTest: failure on setup_all callback, all tests have been invalidated
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Aggregates.Scopes.gap_order/1

     The following arguments were given to Anchor.Domain.Aggregates.Scopes.gap_order/1:

         # 1
         {:unread, {AnchorFixtures.WriteSitesDefaultTest.D, :d12a, 1}, 69, "unread: capture of AnchorFixtures.WriteSitesDefaultTest.Lib.save/1"}

     Attempted function clauses (showing 2 out of 2):

         defp gap_order(-{:dynamic_call, mfa, line}-)
         defp gap_order(-{:unresolved_write, %Anchor.Domain.Aggregates.WriteSite{} = site}-)

     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/aggregates/scopes.ex:182: Anchor.Domain.Aggregates.Scopes.gap_order/1
       (elixir 1.19.4) lib/enum.ex:3347: anonymous fn/2 in Enum.sort_by/3
       (elixir 1.19.4) lib/enum.ex:1696: anonymous fn/3 in Enum.map/2
       (elixir 1.19.4) lib/enum.ex:4570: anonymous fn/3 in Enum.map/2
       (elixir 1.19.4) lib/enum.ex:5023: Enumerable.List.reduce/3
       (elixir 1.19.4) lib/enum.ex:4570: Enum.map/2
       (elixir 1.19.4) lib/enum.ex:3347: Enum.sort_by/3
       (anchor 0.1.0) lib/anchor/domain/aggregates/scopes.ex:128: Anchor.Domain.Aggregates.Scopes.scope/5
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (elixir 1.19.4) lib/enum.ex:4500: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/domain/aggregates/analysis.ex:113: Anchor.Domain.Aggregates.Analysis.analyse/3
       test/anchor/domain/aggregates/write_sites_default_test.exs:131: Anchor.Domain.Aggregates.WriteSitesDefaultTest.__ex_unit_setup_all_0/1
       test/anchor/domain/aggregates/write_sites_default_test.exs:1: Anchor.Domain.Aggregates.WriteSitesDefaultTest.__ex_unit__/2


Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 0 failures, 37 invalid
warning: mtime (modified time) for "lib/anchor/domain/aggregates/scopes.ex" was set to the future, resetting to now
```

## AN-CLEARED

the cleared calls are not summed (`lib/anchor/domain/aggregates/analysis.ex`). Result: `50 tests, 2 failures`.

```
  1) test DND-5889: Ecto's own expansion, and what `use Ecto.Schema` generates, is no gap (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:180
     Assertion with > failed, both sides are exactly equal
     code: assert a.counts.cleared > 0
     left: 0
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:185: (test)

.....................

  2) test a call the walker does not read the counts hold the cleared calls and the unread ones by callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:238
     Assertion with >= failed
     code:  assert a.counts.cleared >= 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:239: (test)

.......................
Finished in 0.4 seconds (0.4s async, 0.00s sync)
50 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/analysis.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/scopes.ex" was set to the future, resetting to now
```

## AN-UNREAD

the unread calls by callee are empty (`lib/anchor/domain/aggregates/analysis.ex`). Result: `37 tests, 2 failures`.

```
  1) test exactly one outcome per call a capture read twice at one line counts once in unread_by_callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:355
     Assertion with == failed
     code:  assert a.counts.unread_by_callee[String.replace(lib_call("only_here/1"), "call of", "capture of")] == 1
     left:  nil
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:356: (test)

.....

  2) test a call the walker does not read the counts hold the cleared calls and the unread ones by callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:238
     Assertion with == failed
     code:  assert a.counts.unread_by_callee["unread: call of GenServer.call/2"] == 2
     left:  nil
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:240: (test)

..........
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/analysis.ex" was set to the future, resetting to now
```

## AN-DEDUPE

a call read twice at one line counts twice (`lib/anchor/domain/aggregates/analysis.ex`). Result: `37 tests, 1 failure`.

```
  1) test exactly one outcome per call a capture read twice at one line counts once in unread_by_callee (Anchor.Domain.Aggregates.WriteSitesDefaultTest)
     test/anchor/domain/aggregates/write_sites_default_test.exs:355
     Assertion with == failed
     code:  assert a.counts.unread_by_callee[String.replace(lib_call("only_here/1"), "call of", "capture of")] == 1
     left:  2
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/write_sites_default_test.exs:356: (test)

...........
Finished in 0.4 seconds (0.4s async, 0.00s sync)
37 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/analysis.ex" was set to the future, resetting to now
```

## CF-PARSE

no_write_modules is parsed and dropped (`lib/anchor/domain/aggregates/config.ex`). Result: `48 tests, 2 failures`.

```
  1) test parse/1, no_write_modules (DND-5889) an Erlang module is written with its colon (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:141
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{no_write_modules: [:ets, Jason]}} =
              AggregatesConfig.parse(%{"no_write_modules" => [":ets", "Jason"]})
     left:  {:ok, %Anchor.Domain.Aggregates.Config{no_write_modules: [:ets, Jason]}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: nil,
               no_write_modules: [],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:142: (test)

......

  2) test parse/1, no_write_modules (DND-5889) the modules are stored, and absent is an empty list (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:134
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{no_write_modules: [Jason, MyApp.Pure]}} =
              AggregatesConfig.parse(%{"no_write_modules" => ["Jason", "MyApp.Pure"]})
     left:  {:ok, %Anchor.Domain.Aggregates.Config{no_write_modules: [Jason, MyApp.Pure]}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: nil,
               no_write_modules: [],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:135: (test)

......................................
Finished in 0.1 seconds (0.1s async, 0.00s sync)
48 tests, 2 failures
warning: mtime (modified time) for "lib/anchor/domain/aggregates/analysis.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-ERLANG

an Erlang module is refused under no_write_modules (`lib/anchor/domain/aggregates/config.ex`). Result: `48 tests, 1 failure`.

```
  1) test parse/1, no_write_modules (DND-5889) an Erlang module is written with its colon (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:141
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{no_write_modules: [:ets, Jason]}} =
              AggregatesConfig.parse(%{"no_write_modules" => [":ets", "Jason"]})
     left:  {:ok, %Anchor.Domain.Aggregates.Config{no_write_modules: [:ets, Jason]}}
     right: {:error,
             {:invalid_config,
              "aggregates.no_write_modules must be a list of module names, got: \":ets\". Fix: name each module in full, as its defmodule spells it, and an Erlang module with its colon (\":ets\"); aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:142: (test)

..............................
Finished in 0.1 seconds (0.1s async, 0.00s sync)
48 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-ERLANGCHAR

any character passes in an Erlang name (`lib/anchor/domain/aggregates/config.ex`). Result: `48 tests, 1 failure`.

```
  1) test parse/1 C3: refused: no_write_modules a bad Erlang name (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:127
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "MyApp.Threads.ThreadSpace",
                   schemas: [MyApp.Threads.Thread,
                    MyApp.Threads.Message],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               none: nil,
               no_write_modules: [:"not a module"],
               repos: [MyApp.Repo],
               write_functions: [
                 %Anchor.Domain.FunctionRef{
                   module: MyApp.Repo,
                   function: :soft_delete,
                   arity: 2
                 }
               ],
               transaction_functions: [
                 %Anchor.Domain.FunctionRef{
                   module: GenSaas.UnitOfWork,
                   function: :transaction,
                   arity: 3
                 }
               ]
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:237: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:128: (test)

................................
Finished in 0.1 seconds (0.1s async, 0.00s sync)
48 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-KEY

no_write_modules is an unknown key (`lib/anchor/domain/aggregates/config.ex`). Result: `48 tests, 8 failures`.

```
  1) test parse/1 C3: refused: no_write_modules a bad Erlang name (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:127
     got: aggregates: unknown key(s) "no_write_modules". Fix: remove or correct it; the keys are declare, reason, repos, transaction_functions, write_functions; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(section, expected)
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:238: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:128: (test)

.............

  2) test parse/1, no_write_modules (DND-5889) it says something persists, so it cannot stand beside declare: none (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:146
     got: aggregates: unknown key(s) "no_write_modules". Fix: remove or correct it; the keys are declare, reason, repos, transaction_functions, write_functions; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:238: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:147: (test)

.....

  3) test parse/1 C3: refused: no_write_modules not module names (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:127
     got: aggregates: unknown key(s) "no_write_modules". Fix: remove or correct it; the keys are declare, reason, repos, transaction_functions, write_functions; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(section, expected)
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:238: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:128: (test)

....

  4) test parse/1 C3: refused: no_write_modules not a list (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:127
     got: aggregates: unknown key(s) "no_write_modules". Fix: remove or correct it; the keys are declare, reason, repos, transaction_functions, write_functions; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(section, expected)
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:238: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:128: (test)

.........

  5) test parse/1 C3: refused: no_write_modules a bad Erlang start (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:127
     got: aggregates: unknown key(s) "no_write_modules". Fix: remove or correct it; the keys are declare, reason, repos, transaction_functions, write_functions; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(section, expected)
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:238: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:128: (test)

......

  6) test parse/1 C3: refused: no_write_modules an empty colon (Anchor.Dom
```

## GR-CLEARED

the summary does not print the cleared count (`lib/anchor/domain/graph_report.ex`). Result: `4 tests, 1 failure`.

```
  1) test the write analysis's counts are in the summary and the JSON (Anchor.Domain.GraphReportAggregatesTest)
     test/anchor/domain/graph_report_aggregates_test.exs:43
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 " <>
                "baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 " <>
                "no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; " <>
                "9 dependency calls cleared by the no-write list; not read: the modules under " <>
                "aggregates.no_write_modules, the built-in no-write list and dependencies' own " <>
                "internals"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; not read: the modules under aggregates.no_write_modules, the built-in no-write list and dependencies' own internals"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; 9 dependency calls cleared by the no-write list; not read: the modules under aggregates.no_write_modules, the built-in no-write list and dependencies' own internals"
     stacktrace:
       test/anchor/domain/graph_report_aggregates_test.exs:58: (test)

..
Finished in 0.02 seconds (0.02s async, 0.00s sync)
4 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/graph_report.ex" was set to the future, resetting to now
```

## GR-NARROW

the summary keeps the run-wide sentence (`lib/anchor/domain/graph_report.ex`). Result: `4 tests, 1 failure`.

```
  1) test the write analysis's counts are in the summary and the JSON (Anchor.Domain.GraphReportAggregatesTest)
     test/anchor/domain/graph_report_aggregates_test.exs:43
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 " <>
                "baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 " <>
                "no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; " <>
                "9 dependency calls cleared by the no-write list; not read: the modules under " <>
                "aggregates.no_write_modules, the built-in no-write list and dependencies' own " <>
                "internals"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; 9 dependency calls cleared by the no-write list; forms not listed in the README are not read"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; 9 dependency calls cleared by the no-write list; not read: the modules under aggregates.no_write_modules, the built-in no-write list and dependencies' own internals"
     stacktrace:
       test/anchor/domain/graph_report_aggregates_test.exs:58: (test)


Finished in 0.02 seconds (0.02s async, 0.00s sync)
4 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_report.ex" was set to the future, resetting to now
```

## IN-NARROW

the proposal keeps the run-wide sentence (`lib/anchor/domain/aggregates/inference.ex`). Result: `17 tests, 1 failure`.

```
  1) test every proposal says on its first line what it does not read (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:175
     Expected truthy, got false
     code: assert String.starts_with?(yaml, read_note)
     arguments:

         # 1
         "# read from the forms Anchor recognises; a write in any other form is not in this proposal\naggregates:\n  declare:\n    - name: App.S\n      schemas: [App.S]\n      tables: []\n      # owners: proposed by aggregate_owner_writes\n"

         # 2
         "# not read: the modules under aggregates.no_write_modules, the built-in no-write list and dependencies' own internals; a write there is not in this proposal\n"

     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:182: (test)

.............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
17 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/inference.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/graph_report.ex" was set to the future, resetting to now
```

## RU-UNREAD

the rule's message does not name the unread call (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `2 tests, 1 failure`.

```
  1) test I1: the violating module gives exactly the unresolved write and the incomplete transactions (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:79
     Assertion with =~ failed
     code:  assert ask.message =~ "unread: call of GenServer.call/2 in Aws.Violating.ask/1"
     left:  "transaction 1 in Aws.Violating.ask/1 reaches 1 call(s) it does not read (first: ), so its write set is incomplete. Fix: call a named function instead of a variable, or declare the behaviour so the callee is known; list a dependency that cannot write under aggregates.no_write_modules, or one that writes under aggregates.write_functions; trace each write to a schema or table."
     right: "unread: call of GenServer.call/2 in Aws.Violating.ask/1"
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:98: (test)


Finished in 0.09 seconds (0.09s async, 0.00s sync)
2 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/inference.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/aggregate_write_sources.ex" was set to the future, resetting to now
```
