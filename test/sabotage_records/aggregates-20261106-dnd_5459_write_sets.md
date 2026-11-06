# Sabotage record — the merge of main and `Scopes` selections (DND-5459, DND-5659)

- **Domain:** aggregates (`Anchor.Domain.GraphRules` is off-domain and labelled by its file)
- **Branch:** dnd-5459-write-sets
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Aggregates.Inference.render_yaml/1` (it never proposes `declare: none`, critic round 3), `Scopes` and `NonTransactional` (the selections that replace the predicates a caller passed in), `WriteSites.captured/2`, and the `@rules` list main's merge changed
- **Earlier record:** `aggregates-20261103-dnd_5459_write_sets.md` holds the runs of 2026-11-03. Its rows SC-CLOSURE, SC-CAPTURES, SC-BODY, SC-REMOTE, SC-INNER, SC-ENUMCAPTURE, NT-OUTSIDE, NT-MULTI, NT-RUNCB, GR-REG, IN-EVIDENCESCOPES and IN-EVIDENCEOUTSIDE are run again here against the code as it now stands. Its rows IF-YAML and IN-UNRESOLVEDNONE mutated code that critic round 3 deleted, so they have no successor.
- **Suite run:** the same driver: one exact, unique anchor per mutation, `mix test --timeout 2000 --max-cases 2 <its test files>` inside `test-slot`, every failure block kept verbatim, the source restored with its mtime bumped. After each pass `git status` showed only the intended edits.
- **Passes:** 23 mutations on 1441579. Four survived, each a test that was missing: SC-ALLTAGS (no outer scope reached a call inside a callee's own transaction), NT-MULTI (no write sat directly in a transaction body in the non-transactional fixture), NT-VIAWF (no `write_functions` write in that fixture) and WSC-RUN (no `Multi.run` callback given by module and name). 8c23d38 adds those tests, and the four rows below are their red runs on it.
- **Not mutated:** the merge's other conflict resolutions, which keep both sides' lines; the gate's `MIX_ENV=dev mix anchor.graph` checks them, and main's own record covers its rules.
- **Test files:** `test/anchor/domain/aggregates/{inference,scopes,non_transactional,write_sites,write_source}_test.exs`, `test/anchor/domain/graph_rules_test.exs`, `test/anchor/integration/aggregate_write_sources_integration_test.exs`.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| IN-NONEPROPOSAL | nothing to propose is an :ok, not an error (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 4 failures` (red) |
| IN-EVIDENCEREPO | the error does not name the repos (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| IN-EVIDENCESCHEMAS | the error does not count one schema (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| IN-BYHAND | the no-repo error does not say none is a person's call (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| IN-EVIDENCESCOPES | a transaction is not named in the error (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| IN-EVIDENCEOUTSIDE | an unattributable call outside a transaction is not named in the error (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| SC-CLOSURE | the closure stops following calls (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 4 failures` (red) |
| SC-CAPTURES | a captured transaction body is not followed (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| SC-REMOTE | a scope follows only callees in its own module (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 5 failures` (red) |
| SC-ENUMCAPTURE | a capture in a scope's body is not followed (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| SC-INNER | a closure leaves out writes inside a callee's own transaction (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| SC-BODY | a scope holds a write of another transaction in its function (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| SC-BODYTAGS | a scope follows a call or dynamic call outside its body (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| SC-ALLTAGS | the full closure keeps only calls outside a body (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `31 tests, 1 failure` (red after the added test) |
| NT-OUTSIDE | calls inside a transaction count as non-transactional (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 2 failures` (red) |
| NT-MULTI | a write inside a transaction body counts as outside (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `31 tests, 2 failures` (red after the added test) |
| NT-RUNCB | an inline Multi.run callback's write counts as outside a transaction (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| NT-VIA | a Multi step's write counts as outside a transaction (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 1 failure` (red) |
| NT-VIAWF | a write_functions write does not count as outside (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `31 tests, 1 failure` (red after the added test) |
| NT-SELECTION | the non-transactional summary asks for everything (`lib/anchor/domain/aggregates/non_transactional.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 4 failures` (red) |
| WSC-RUN | a Multi.run capture is left out of the captured set (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_source_test.exs` | `18 tests, 1 failure` (red after the added test) |
| WSC-CAPTURES | a capture is left out of the captured set (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs`, `non_transactional_test.exs`, `write_source_test.exs` | `37 tests, 1 failure` (red) |
| GR-REG | aggregate_write_sources is not registered (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `aggregate_write_sources_integration_test.exs` | `14 tests, 2 failures` (red) |

## IN-NONEPROPOSAL

nothing to propose is an :ok, not an error (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 4 failures`.

```

  1) test F8: writes found but none resolved is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:123
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(unresolved)
     left:  {:error, why}
     right: {:ok,
             "nothing traced to a schema or table (repo(s) ; 2 write(s) found, 2 unresolved), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:126: (test)




  2) test F8: a transaction with no write site, only a gap, is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:133
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(gap_only)
     left:  {:error, why}
     right: {:ok,
             "nothing traced to a schema or table (repo(s) ; 1 transaction(s)), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:139: (test)

......


  3) test F8: a gap outside every transaction is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:143
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(outside)
     left:  {:error, why}
     right: {:ok,
             "nothing traced to a schema or table (repo(s) ; 1 call(s) Anchor cannot attribute outside a transaction), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:149: (test)




  4) test F5: a repo and a schema with no write is an error naming them, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:100
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(analysis)
     left:  {:error, why}
     right: {:ok,
             "nothing traced to a schema or table (repo(s) AnchorFixtures.InferenceTest.Repo; 1 schema(s)), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:114: (test)

..
```

## IN-EVIDENCEREPO

the error does not name the repos (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F5: a repo and a schema with no write is an error naming them, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:100
     Assertion with =~ failed
     code:  assert why =~ "repo(s) #{inspect(repo)}"
     left:  "nothing traced to a schema or table (repos; 1 schema(s)), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"
     right: "repo(s) AnchorFixtures.InferenceTest.Repo"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:115: (test)

..
```

## IN-EVIDENCESCHEMAS

the error does not count one schema (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F5: a repo and a schema with no write is an error naming them, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:100
     Assertion with =~ failed
     code:  assert why =~ "1 schema(s)"
     left:  "nothing traced to a schema or table (repo(s) AnchorFixtures.InferenceTest.Repo), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"
     right: "1 schema(s)"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:116: (test)

..........
```

## IN-BYHAND

the no-repo error does not say none is a person's call (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F8: no repo is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:153
     Assertion with =~ failed
     code:  assert why =~ "write declare: none by hand"
     left:  "no Ecto repo found, so there is nothing to propose. Fix: list the repo under aggregates.repos; if the project persists nothing, declare: none with a reason"
     right: "write declare: none by hand"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:156: (test)

.......
```

## IN-EVIDENCESCOPES

a transaction is not named in the error (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F8: a transaction with no write site, only a gap, is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:133
     Assertion with =~ failed
     code:  assert why =~ "1 transaction(s)"
     left:  "nothing traced to a schema or table (repo(s) ), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"
     right: "1 transaction(s)"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:140: (test)

........
```

## IN-EVIDENCEOUTSIDE

an unattributable call outside a transaction is not named in the error (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F8: a gap outside every transaction is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:143
     Assertion with =~ failed
     code:  assert why =~ "1 call(s) Anchor cannot attribute"
     left:  "nothing traced to a schema or table (repo(s) ), so there is nothing to propose; a repo means the project persists, so declare: none does not fit. Fix: resolve the writes (aggregate_write_sources lists them) and propose again"
     right: "1 call(s) Anchor cannot attribute"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:150: (test)

.....
```

## SC-CLOSURE

the closure stops following calls (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 4 failures`.

```

  1) test N3: a callee also called outside is not always in one; the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:72
     Assertion with == failed
     code:  assert nontx(a, :n3h).keys == keys([@t])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:75: (test)

.


  2) test N4: recursion terminates at the fixpoint (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:79
     Assertion with == failed
     code:  assert nontx(a, :n4a, 1).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:80: (test)

.


  3) test build/3 S8: recursion terminates, and the keys are the union (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:175
     Assertion with == failed
     code:  assert scope.keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:177: (test)

...........


  4) test N1: a function's own writes and its callees' outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:59
     Assertion with == failed
     code:  assert nontx(a, :n1f).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:60: (test)

..........
```

## SC-CAPTURES

a captured transaction body is not followed (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test build/3 S2: a captured function is the scope's body (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:144
     Assertion with == failed
     code:  assert scope.keys == keys([@u])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.U])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:146: (test)

..............
```

## SC-REMOTE

a scope follows only callees in its own module (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 5 failures`.

```

  1) test build/3 S8: recursion terminates, and the keys are the union (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:175
     Assertion with == failed
     code:  assert scope.keys == keys([@s, @t])
     left:  MapSet.new([])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:177: (test)

.


  2) test build/3 S12: a capture passed to Enum is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:219
     Assertion with == failed
     code:  assert one(a, :s12).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:220: (test)

..............


  3) test build/3 S9: an outer scope holds a callee's inner transaction; the inner one is its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:180
     Assertion with == failed
     code:  assert one(a, :s9).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:183: (test)




  4) test build/3 S1: a fun scope holds its own writes and a callee's in another module (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:138
     Assertion with == failed
     code:  assert scope.keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:140: (test)

.


  5) test build/3 S3: a Multi traced through a helper that adds a step (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:149
     Assertion with == failed
     code:  assert scope.keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:151: (test)
```

## SC-ENUMCAPTURE

a capture in a scope's body is not followed (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test build/3 S12: a capture passed to Enum is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:219
     Assertion with == failed
     code:  assert one(a, :s12).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:220: (test)

.......
```

## SC-INNER

a closure leaves out writes inside a callee's own transaction (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test build/3 S9: an outer scope holds a callee's inner transaction; the inner one is its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:180
     Assertion with == failed
     code:  assert one(a, :s9).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:183: (test)

...................
```

## SC-BODY

a scope holds a write of another transaction in its function (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test build/3 S11: two scopes in one function are ordinals 1 and 2 in Core order (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:194
     Assertion with == failed
     code:  assert first.keys == keys([@s])
     left:  MapSet.new([
              schema: AnchorFixtures.ScopesTest.S,
              schema: AnchorFixtures.ScopesTest.T
            ])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:198: (test)

..........
```

## SC-BODYTAGS

a scope follows a call or dynamic call outside its body (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test build/3 S5: a transaction_functions call is a scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:159
     match (=) failed
     code:  assert %Scope{kind: :transaction_function, complete?: true} = scope = one(a, :s5)
     left:  %Anchor.Domain.Aggregates.Scope{kind: :transaction_function, complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s5, 0},
              ordinal: 1,
              line: 79,
              kind: :transaction_function,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s5, 0},
                  line: 79,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.UoW, :transaction, 2},
                 50}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:160: (test)

..................
```

## SC-ALLTAGS

the full closure keeps only calls outside a body (`lib/anchor/domain/aggregates/scopes.ex`). Result: `31 tests, 1 failure`.

First run, before the added test: `28 tests, 0 failures` (survived).

```

  1) test build/3 an outer scope follows the calls inside a callee's inner transaction (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:192
     Assertion with == failed
     code:  assert one(a, :s17).keys == keys([@t])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.T])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:193: (test)

..........
```

## NT-OUTSIDE

calls inside a transaction count as non-transactional (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 2 failures`.

```

  1) test N3: a callee also called outside is not always in one; the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:72
     Assertion with == failed
     code:  assert nontx(a, :n3f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:76: (test)




  2) test N2: a callee called only inside a transaction adds nothing and is always in one (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:65
     Assertion with == failed
     code:  assert nontx(a, :n2f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:68: (test)

..............
```

## NT-MULTI

a write inside a transaction body counts as outside (`lib/anchor/domain/aggregates/scopes.ex`). Result: `31 tests, 2 failures`.

First run, before the added test: `28 tests, 0 failures` (survived).

```



  1) test a write directly in a transaction body is never non-transactional (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:102
     Assertion with == failed
     code:  assert nontx(a, :n8).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:103: (test)

..............


  2) test a write_functions write outside a transaction is non-transactional; inside it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:106
     Assertion with == failed
     code:  assert nontx(analysis, :n10).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:112: (test)

...............
```

## NT-RUNCB

an inline Multi.run callback's write counts as outside a transaction (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test N5: a literal-repo write in an inline Multi.run callback is never non-transactional (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:84
     Assertion with == failed
     code:  assert nontx(a, :n6).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:87: (test)

.......................
```

## NT-VIA

a Multi step's write counts as outside a transaction (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 1 failure`.

```

  1) test a Multi step is never a non-transactional write (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:96
     Assertion with == failed
     code:  assert nontx(a, :n5).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:97: (test)

.....................
```

## NT-VIAWF

a write_functions write does not count as outside (`lib/anchor/domain/aggregates/scopes.ex`). Result: `31 tests, 1 failure`.

First run, before the added test: `28 tests, 0 failures` (survived).

```

  1) test a write_functions write outside a transaction is non-transactional; inside it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:106
     Assertion with == failed
     code:  assert nontx(analysis, :n9).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:111: (test)

..........
```

## NT-SELECTION

the non-transactional summary asks for everything (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `28 tests, 4 failures`.

```

  1) test N3: a callee also called outside is not always in one; the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:72
     Assertion with == failed
     code:  assert nontx(a, :n3f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:76: (test)




  2) test a Multi step is never a non-transactional write (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:96
     Assertion with == failed
     code:  assert nontx(a, :n5).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:97: (test)

.


  3) test N5: a literal-repo write in an inline Multi.run callback is never non-transactional (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:84
     Assertion with == failed
     code:  assert nontx(a, :n6).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:87: (test)




  4) test N2: a callee called only inside a transaction adds nothing and is always in one (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:65
     Assertion with == failed
     code:  assert nontx(a, :n2f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:68: (test)

....
```

## WSC-RUN

a Multi.run capture is left out of the captured set (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

First run, before the added test: `20 tests, 0 failures` (survived).

```

  1) test resolve/3 (through WriteSites.find/2) R10: a Multi.run callback given by module and name has callers Anchor cannot see (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:173
     match (=) failed
     code:  assert %{sources: [], unresolved: seen} = site(sites, :r17)
     left:  %{sources: [], unresolved: seen}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r17, 3},
              line: 72,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:176: (test)

.............
```

## WSC-CAPTURES

a capture is left out of the captured set (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `37 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R10: a parameter of a captured function has callers Anchor cannot see (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:159
     match (=) failed
     code:  assert %{sources: [], unresolved: seen} = site(sites, :r16)
     left:  %{sources: [], unresolved: seen}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r16, 1},
              line: 69,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:162: (test)

............................
```

## GR-REG

aggregate_write_sources is not registered (`lib/anchor/domain/graph_rules.ex`). Result: `14 tests, 2 failures`.

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:62
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :context_acyclic, :effects_match_bucket,
             :layering, :struct_owned_by_module_flow]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :context_acyclic, :effects_match_bucket, :layering,
             :struct_owned_by_module_flow]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:65: (test)

......


  2) test I1: the violating module gives exactly the unresolved write and the incomplete transaction (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:78
     match (=) failed
     code:  assert %GraphReport{exit_code: 1, could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 1, could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 4,
                opaque: 0,
                apps: 1,
                rules: 0,
                writes: %{
                  complete: 1,
                  incomplete: 1,
                  resolved: 1,
                  unresolved: 1,
                  scopes: 2,
                  writes: 2
                },
                outside_root: 0,
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 0
            }
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:82: (test)
```
