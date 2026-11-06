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

# Second run: what the analysis cannot follow is a gap

26 mutations on ab9867b, for critic round 4's class: a scope read complete, or a write resolved, when Anchor had not seen the write. Four survived, each a case no fixture held, and the tests added up to 702ac28 turn them red (the rows say which). WSF-TRAILING, WSF-REPOREAD and WSF-REPOFOLLOW's first forms were compile errors under `warnings_as_errors` (an unused function or variable), and were re-anchored; the rows hold the forms that ran.

**Not mutated:** `WriteSource.binary/2`'s query-argument clause: the 2026-11-03 record measured nine source forms of a string, all compiled to a `:literal` node, so no fixture reaches a `:binary` one (it replaces that record's WS-STRINGARG, whose `string?/1` is gone). `classify`'s `{:literal_fun, ...}` `:error` arm: a fun literal in a beam is always external, so `external/1` cannot return `:error` there; it stays a gap so an unexpected shape is never dropped.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| FS-STRINGVAR | a string through a variable is the table (`lib/anchor/domain/aggregates/write_source.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| FS-QUERYSTRUCT | a query map's from: keeps the query-argument rule (`lib/anchor/domain/aggregates/write_source.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red after the added test) |
| FS-QUERYLITERAL | a literal query's from: keeps the query-argument rule (`lib/anchor/domain/aggregates/write_source.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red after the added test) |
| WSF-LAMBDARUN | a fn from outside the body is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-DEFINEDIN | a fn's own body counts as outside (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-FUNEVENT | where a fn is defined is not recorded (`lib/anchor/domain/aggregates/function_walk.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-HANDED | a function-taking call is not read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 4 failures` (red) |
| WSF-HANDEDBINDING | a fun parameter handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-HANDEDLAMBDA | a fn from outside the body handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-HANDEDERROR | a function value made by a call is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-LAST | the first non-literal argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-TRAILING | a trailing literal is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `49 tests, 1 failure` (red after the added test) |
| WSF-FIRSTARG | the first argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-CAPTUREWRITE | a capture of a write is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-CAPTUREWF | a capture of a write_functions write is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-MAKEFUN | a capture on a computed module is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-REPOCB | an unknown function on a callback's repo is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-REPOCBREAD | a read on a callback's repo is a gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-REPOREAD | a generated repo function is followed (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `49 tests, 1 failure` (red after the added test) |
| WSF-REPOFOLLOW | a function written on a repo is not followed (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-REPOUNSEEN | a repo function Anchor cannot see is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |
| WSF-ONREPO | a local call in a function written on a repo is not read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-ONREPOWRITE | a generated write's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-ONREPORAW | a raw SQL function's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-ONREPOGEN | a generated function's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 2 failures` (red) |
| WSF-LIST | a callback of Ecto.Repo is not listed (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs`, `real_ecto_test.exs` | `47 tests, 1 failure` (red) |

## FS-STRINGVAR

a string through a variable is the table (`lib/anchor/domain/aggregates/write_source.ex`). Result: `47 tests, 2 failures`.

```

  1) test E6: a query call's literal argument is never the table; an unknown query stays unknown (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:106
     match (=) failed
     code:  assert %{sources: [], unresolved: seen} = site(a, :e6)
     left:  %{sources: [], unresolved: seen}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e6, 1},
              line: 31,
              op: :delete_all,
              via: :repo,
              sources: [table: "tenant_a"],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:108: (test)

....


  2) test E6: a string reaching a query call through a variable is never the table either (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:113
     match (=) failed
     code:  assert %{sources: [], unresolved: seen} = site(a, :e6_prefix)
     left:  %{sources: [], unresolved: seen}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e6_prefix, 2},
              line: 34,
              op: :delete_all,
              via: :repo,
              sources: [table: "tenant_a"],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:116: (test)

.......................................
```

## FS-QUERYSTRUCT

a query map's from: keeps the query-argument rule (`lib/anchor/domain/aggregates/write_source.ex`). Result: `47 tests, 1 failure`.

First run, before the added test: `47 tests, 0 failures` (survived).

```

  1) test E6: a table named by from/2 still reaches through a query call (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:124
     match (=) failed
     code:  assert %{sources: [table: "threads"], unresolved: nil} = site(a, :e6_prefixed_pin)
     left:  %{sources: [table: "threads"], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e6_prefixed_pin,
               1},
              line: 38,
              op: :delete_all,
              via: :repo,
              sources: [],
              unresolved: "an Ecto query Anchor cannot trace to a schema or table",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:127: (test)

.....................................
```

## FS-QUERYLITERAL

a literal query's from: keeps the query-argument rule (`lib/anchor/domain/aggregates/write_source.ex`). Result: `47 tests, 1 failure`.

First run, before the added test: `47 tests, 0 failures` (survived).

```

  1) test E6: a table named by from/2 still reaches through a query call (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:124
     match (=) failed
     code:  assert %{sources: [table: "threads"], unresolved: nil} = site(a, :e6_prefixed)
     left:  %{sources: [table: "threads"], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e6_prefixed, 0},
              line: 36,
              op: :delete_all,
              via: :repo,
              sources: [],
              unresolved: "an Ecto query Anchor cannot trace to a schema or table",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:126: (test)

...........................................
```

## WSF-LAMBDARUN

a fn from outside the body is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 a fn from outside the body handed to Enum in it makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:289
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s22, 1}, _line}]} = one(a, :s22)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s22, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s22, 1},
              ordinal: 1,
              line: 137,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:292: (test)

.


  2) test build/3 a fn defined outside the body and called in it makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:265
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s18, 0}, line}]} = one(a, :s18)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s18, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s18, 0},
              ordinal: 1,
              line: 126,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:268: (test)

................
```

## WSF-DEFINEDIN

a fn's own body counts as outside (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 an inline fn handed to Enum in the body is walked, with no gap of its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:296
     match (=) failed
     code:  assert [unresolved_write: %{mfa: {@x, :s23, 1}}] = one(a, :s23).gaps
     left:  [unresolved_write: %{mfa: {AnchorFixtures.ScopesTest.X, :s23, 1}}]
     right: [
              {:dynamic_call,
               {AnchorFixtures.ScopesTest.X, :s23, 1}, 140},
              {:unresolved_write,
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.ScopesTest.X, :s23, 1},
                 line: 140,
                 op: :insert,
                 via: :repo,
                 sources: [],
                 unresolved: "parameter 1 of an anonymous function",
                 scopes: [1],
                 run_callback?: false
               }}
            ]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:299: (test)

..............


  2) test build/3 a fn defined and called in the body is in the scope (positive control) (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:272
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s19)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s19, 0},
              ordinal: 1,
              line: 129,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s19, 0},
                  line: 129,
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
                 {AnchorFixtures.ScopesTest.X, :s19, 0}, 129}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:273: (test)

..
```

## WSF-FUNEVENT

where a fn is defined is not recorded (`lib/anchor/domain/aggregates/function_walk.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 an inline fn handed to Enum in the body is walked, with no gap of its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:296
     match (=) failed
     code:  assert [unresolved_write: %{mfa: {@x, :s23, 1}}] = one(a, :s23).gaps
     left:  [unresolved_write: %{mfa: {AnchorFixtures.ScopesTest.X, :s23, 1}}]
     right: [
              {:dynamic_call,
               {AnchorFixtures.ScopesTest.X, :s23, 1}, 140},
              {:unresolved_write,
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.ScopesTest.X, :s23, 1},
                 line: 140,
                 op: :insert,
                 via: :repo,
                 sources: [],
                 unresolved: "parameter 1 of an anonymous function",
                 scopes: [1],
                 run_callback?: false
               }}
            ]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:299: (test)

...........


  2) test build/3 a fn defined and called in the body is in the scope (positive control) (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:272
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s19)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s19, 0},
              ordinal: 1,
              line: 129,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s19, 0},
                  line: 129,
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
                 {AnchorFixtures.ScopesTest.X, :s19, 0}, 129}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:273: (test)

....................
```

## WSF-HANDED

a function-taking call is not read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 4 failures`.

```

  1) test build/3 a function value made by a call, handed to Enum, makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:324
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s30, 1}, _line}]} = one(a, :s30)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s30, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s30, 1},
              ordinal: 1,
              line: 158,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Helper, :write_s,
                   1},
                  line: 38,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:327: (test)

........


  2) test build/3 a fun parameter handed to Enum in the body makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:277
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s20, 2}, _line}]} = one(a, :s20)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s20, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
              ordinal: 1,
              line: 131,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
                  line: 131,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:278: (test)

.....


  3) test build/3 the function is found before a trailing literal (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:331
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s31, 2}, _line}]} = one(a, :s31)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s31, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s31, 2},
              ordinal: 1,
              line: 160,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:332: (test)

.


  4) test build/3 a fn from outside the body handed to Enum in it makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:289
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s22, 1}, _line}]} = one(a, :s22)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s22, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s22, 1},
              ordinal: 1,
              line: 137,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:292: (test)
```

## WSF-HANDEDBINDING

a fun parameter handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 a fun parameter handed to Enum in the body makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:277
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s20, 2}, _line}]} = one(a, :s20)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s20, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
              ordinal: 1,
              line: 131,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
                  line: 131,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:278: (test)




  2) test build/3 the function is found before a trailing literal (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:331
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s31, 2}, _line}]} = one(a, :s31)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s31, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s31, 2},
              ordinal: 1,
              line: 160,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:332: (test)

.................
```

## WSF-HANDEDLAMBDA

a fn from outside the body handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a fn from outside the body handed to Enum in it makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:289
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s22, 1}, _line}]} = one(a, :s22)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s22, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s22, 1},
              ordinal: 1,
              line: 137,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:292: (test)

...............................
```

## WSF-HANDEDERROR

a function value made by a call is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a function value made by a call, handed to Enum, makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:324
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s30, 1}, _line}]} = one(a, :s30)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s30, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s30, 1},
              ordinal: 1,
              line: 158,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Helper, :write_s,
                   1},
                  line: 38,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:327: (test)
```

## WSF-LAST

the first non-literal argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 an inline fn handed to Enum in the body is walked, with no gap of its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:296
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s29)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s29, 2},
              ordinal: 1,
              line: 156,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s29, 2}, 156}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:300: (test)

..................................
```

## WSF-TRAILING

a trailing literal is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `49 tests, 1 failure`.

First run, before the added test: `47 tests, 0 failures` (survived).

```

  1) test build/3 an inline fn before a trailing literal is walked, with no gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:340
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s36)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s36, 1},
              ordinal: 1,
              line: 168,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s36, 1}, 168}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:341: (test)

...................................
```

## WSF-FIRSTARG

the first argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a function-taking call's first argument is data (positive control) (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:336
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s32)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s32, 1},
              ordinal: 1,
              line: 162,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s32, 1},
                  line: 162,
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
                 {AnchorFixtures.ScopesTest.X, :s32, 1}, 162}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:337: (test)

.............................
```

## WSF-CAPTUREWRITE

a capture of a write is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 a capture of a Repo write makes the scope incomplete: its source is unseen (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:303
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s24, 1}, _line}]} = one(a, :s24)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s24, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s24, 1},
              ordinal: 1,
              line: 142,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:306: (test)

................


  2) test build/3 a capture of a write_functions write makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:340
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s33, 1}, _line}]} = one(a, :s33)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s33, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s33, 1},
              ordinal: 1,
              line: 164,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:341: (test)

.......
```

## WSF-CAPTUREWF

a capture of a write_functions write is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a capture of a write_functions write makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:340
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s33, 1}, _line}]} = one(a, :s33)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s33, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s33, 1},
              ordinal: 1,
              line: 164,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:341: (test)

..............
```

## WSF-MAKEFUN

a capture on a computed module is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a capture on a computed module, handed to a project function, is a gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:345
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s34, 1}, _line}]} = one(a, :s34)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s34, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s34, 1},
              ordinal: 1,
              line: 166,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:346: (test)

...............
```

## WSF-REPOCB

an unknown function on a callback's repo is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 an unknown function on a Multi.run callback's repo makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:360
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s27, 0}, _line}]} = one(a, :s27)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s27, 0}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s27, 0},
              ordinal: 1,
              line: 151,
              kind: :multi,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:363: (test)

..............................
```

## WSF-REPOCBREAD

a read on a callback's repo is a gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a Multi.run callback's repo reads leave the scope complete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:350
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s35)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s35, 0},
              ordinal: 1,
              line: 171,
              kind: :multi,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s35, 0},
                  line: 170,
                  op: :insert,
                  via: :run_callback_repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: true
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s35, 0}, 170}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:351: (test)

...
```

## WSF-REPOREAD

a generated repo function is followed (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `49 tests, 1 failure`.

First run, before the added test: `47 tests, 0 failures` (survived).

```

  1) test build/3 a function Ecto generates needs no body in the beam: no gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:344
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s37)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s37, 0},
              ordinal: 1,
              line: 170,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s37, 0}, 170}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:345: (test)

............................
```

## WSF-REPOFOLLOW

a function written on a repo is not followed (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:437
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  3
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:442: (test)

..............................


  2) test build/3 a function written on a repo is followed: its own writes are in the scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:310
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s25)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s25, 0},
              ordinal: 1,
              line: 144,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s25, 0}, 144}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:313: (test)
```

## WSF-REPOUNSEEN

a repo function Anchor cannot see is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test build/3 a repo function Anchor cannot see makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:355
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s26, 0}, _line}]} = one(a, :s26)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s26, 0}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s26, 0},
              ordinal: 1,
              line: 146,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:356: (test)

.....
```

## WSF-ONREPO

a local call in a function written on a repo is not read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:317
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  []
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:320: (test)

...................


  2) test build/3 a function written on a repo is followed: its own writes are in the scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:310
     Assertion with == failed
     code:  assert scope.keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:314: (test)

.....
```

## WSF-ONREPOWRITE

a generated write's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:317
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :insert, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :update, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:320: (test)

........


  2) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:437
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  15
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:442: (test)

..
```

## WSF-ONREPORAW

a raw SQL function's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:437
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  3
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:442: (test)

.................


  2) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:317
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :query, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:320: (test)
```

## WSF-ONREPOGEN

a generated function's local call is read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 2 failures`.

```

  1) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:437
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  3
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:442: (test)

.........


  2) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:317
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :reload, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:320: (test)

..............
```

## WSF-LIST

a callback of Ecto.Repo is not listed (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `47 tests, 1 failure`.

```

  1) test every callback of Ecto.Repo is a write, raw SQL, or known to write nothing (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:124
     Assertion with == failed
     code:  assert Ecto.Repo.behaviour_info(:callbacks) |> Keyword.keys() |> Enum.reject(&MapSet.member?(known, &1)) ==
              []
     left:  [:transact]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:128: (test)

......................................
```

# Third run: a traced value keeps every path it can take

5 mutations of `WriteSource` for critic round 5's findings (a `try` handler, every `@spec` clause) and rule 4, swept with them. A sixth, TR-RAW (dropping `:raw_raise` from the primops that raise), survived with 25 tests, 0 failures: Core held no such primop in any `rescue`, `after` or `reraise` form the fixtures hold, so the arm was deleted rather than kept untested. An unknown primop stays unresolved.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| TR-HANDLER | a try's handler is not traced (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `25 tests, 2 failures` (red) |
| SP-ANY | one @spec clause naming a schema is enough (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `25 tests, 1 failure` (red) |
| SP-FIRST | only the first @spec clause counts (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `25 tests, 2 failures` (red) |
| RL4-RETURN | a call on a schema is always the schema (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `25 tests, 1 failure` (red) |
| RL4-FALLBACK | a schema's untraceable function is not the schema (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `25 tests, 2 failures` (red) |

## TR-HANDLER

a try's handler is not traced (`lib/anchor/domain/aggregates/write_source.ex`). Result: `25 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) a try handler that returns what Anchor cannot trace makes the write unresolved (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:255
     match (=) failed
     code:  assert %{sources: [], unresolved: "the result of Map.new/0"} = site(sites, :r19)
     left:  %{sources: [], unresolved: "the result of Map.new/0"}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r19, 1},
              line: 100,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:258: (test)

...........


  2) test resolve/3 (through WriteSites.find/2) a try's value is its body's and its handler's, like the clauses of a case (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:249
     match (=) failed
     code:  assert %{sources: [schema: @s, schema: @t], unresolved: nil} = site(sites, :r18)
     left:  %{
              sources: [schema: AnchorFixtures.WriteSourceTest.S, schema: AnchorFixtures.WriteSourceTest.T],
              unresolved: nil
            }
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r18, 1},
              line: 89,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:252: (test)

....
```

## SP-ANY

one @spec clause naming a schema is enough (`lib/anchor/domain/aggregates/write_source.ex`). Result: `25 tests, 1 failure`.

```



  1) test resolve/3 (through WriteSites.find/2) a @spec clause naming no schema falls through to the callers (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:270
     match (=) failed
     code:  assert %{sources: [schema: @t], unresolved: nil} = site(sites, :r22)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.T], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r22, 1},
              line: 133,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:271: (test)

........................
```

## SP-FIRST

only the first @spec clause counts (`lib/anchor/domain/aggregates/write_source.ex`). Result: `25 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) a @spec clause naming no schema falls through to the callers (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:270
     match (=) failed
     code:  assert %{sources: [schema: @t], unresolved: nil} = site(sites, :r22)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.T], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r22, 1},
              line: 133,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:271: (test)

.....


  2) test resolve/3 (through WriteSites.find/2) every @spec clause counts: two schemas are both the parameter's (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:266
     match (=) failed
     code:  assert %{sources: [schema: @s, schema: @t], unresolved: nil} = site(sites, :r21)
     left:  %{
              sources: [schema: AnchorFixtures.WriteSourceTest.S, schema: AnchorFixtures.WriteSourceTest.T],
              unresolved: nil
            }
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r21, 1},
              line: 129,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:267: (test)

........
```

## RL4-RETURN

a call on a schema is always the schema (`lib/anchor/domain/aggregates/write_source.ex`). Result: `25 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) a schema's function that returns another schema is that schema, not its own (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:274
     match (=) failed
     code:  assert %{sources: [schema: @t], unresolved: nil} = site(sites, :r23)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.T], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r23, 0},
              line: 78,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.W],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:277: (test)

......................
```

## RL4-FALLBACK

a schema's untraceable function is not the schema (`lib/anchor/domain/aggregates/write_source.ex`). Result: `25 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) R6: a call on a schema module is the schema (rule 4) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:185
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r6)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r6, 2},
              line: 50,
              op: :update,
              via: :repo,
              sources: [],
              unresolved: "AnchorFixtures.WriteSourceTest.S",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:186: (test)

...


  2) test resolve/3 (through WriteSites.find/2) a schema's function Anchor cannot trace is the schema (rule 4) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:280
     match (=) failed
     code:  assert %{sources: [schema: @w], unresolved: nil} = site(sites, :r24)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.W], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r24, 0},
              line: 79,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "AnchorFixtures.WriteSourceTest.W",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:281: (test)

...................
```

# Fourth run: a capture from its call, one table, writes outside

15 mutations for critic round 6's findings. These replace the second run's WSF-HANDED, WSF-HANDEDBINDING, WSF-HANDEDLAMBDA, WSF-HANDEDERROR, WSF-LAST, WSF-TRAILING and WSF-FIRSTARG, whose code (`@function_taking` and reading the last non-literal argument) is gone: `Anchor.Domain.HigherOrder` is the one table now. AN-COUNT survived its first run (14 tests, 0 failures), because no fixture reached a gap through a caller; `n16` was added, and the row holds the red run.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| WSG-CAPTUREUSE | a capture handed to a library is not followed from the call (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 2 failures` (red) |
| WSG-TABLE | a function HigherOrder knows is not read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 8 failures` (red) |
| WSG-INDEX | the wrong argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 5 failures` (red) |
| WSG-NOARGS | an apply hiding its arguments is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 1 failure` (red) |
| WSG-LITERAL | a literal in an invoked position is a gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 1 failure` (red) |
| WSG-HANDEDBINDING | a fun parameter handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 3 failures` (red) |
| WSG-RAWFLAG | raw SQL on a repo is not flagged as a write (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs` | `14 tests, 1 failure` (red) |
| WSG-COMPUTEDFLAG | a write on a computed module is not flagged (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs` | `14 tests, 1 failure` (red) |
| WSG-READFLAG | a read on a computed module is flagged (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs` | `14 tests, 1 failure` (red) |
| AN-OUTSIDE | unattributed holds writes inside a transaction too (`lib/anchor/domain/aggregates/analysis.ex`) | `non_transactional_test.exs` | `14 tests, 1 failure` (red) |
| AN-COUNT | the gaps outside a transaction are not counted (`lib/anchor/domain/aggregates/analysis.ex`) | `non_transactional_test.exs` | `14 tests, 1 failure` (red) |
| RL-UNATTRIBUTED | unattributed writes are not reported (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `12 tests, 2 failures` (red) |
| RL-UNATTSELECT | unattributed writes ignore the selector (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `12 tests, 1 failure` (red) |
| RL-ONLYRAW | selected raw SQL alone reads as checking nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `12 tests, 1 failure` (red) |
| RP-NOTE | the summary does not count the gaps (`lib/anchor/domain/graph_report.ex`) | `graph_report_aggregates_test.exs` | `4 tests, 1 failure` (red) |

## WSG-CAPTUREUSE

a capture handed to a library is not followed from the call (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 2 failures`.

```

  1) test build/3 a capture from outside the body, handed to Enum in it, is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:381
     Assertion with == failed
     code:  assert scope.keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:383: (test)




  2) test build/3 a capture of a write from outside the body, handed in it, is a gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:386
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s39, 1}, _line}]} = one(a, :s39)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s39, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s39, 1},
              ordinal: 1,
              line: 179,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:387: (test)

.................
```

## WSG-TABLE

a function HigherOrder knows is not read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 8 failures`.

```

  1) test build/3 a fun parameter handed to Enum in the body makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:314
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s20, 2}, _line}]} = one(a, :s20)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s20, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
              ordinal: 1,
              line: 131,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
                  line: 131,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:315: (test)




  2) test build/3 an apply of a function-taking call hides its arguments, so it is a gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:396
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s41, 2}, _line}]} = one(a, :s41)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s41, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s41, 2},
              ordinal: 1,
              line: 186,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:397: (test)

.......


  3) test build/3 a function value made by a call, handed to Enum, makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:361
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s30, 1}, _line}]} = one(a, :s30)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s30, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s30, 1},
              ordinal: 1,
              line: 158,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Helper, :write_s,
                   1},
                  line: 38,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:364: (test)

..........


  4) test build/3 a capture of a write from outside the body, handed in it, is a gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:386
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s39, 1}, _line}]} = one(a, :s39)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s39, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s39, 1},
              ordinal: 1,
              line: 179,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:387: (test)

..


  5) test build/3 every function HigherOrder knows takes a function: Enum.into/3 (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:391
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s40, 2}, _line}]} = one(a, :s40)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s40, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s40, 2},
              ordinal: 1,
              line: 182,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:392: (test)

.......


  6) test build/3 a capture from outside the body, handed to Enum in it, is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:381
     Assertion with == failed
     code:  assert scope.keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:383: (test)




  7) test build/3 a fn from outside the body handed to Enum in it makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:326
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s22, 1}, _line}]} = one(a, :s22)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s22, 1}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s22, 1},
              ordinal: 1,
              line: 137,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:329: (test)




  8) test build/3 the function is found before a trailing literal (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:368
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s31, 2}, _line}]} = one(a, :s31)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s31, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s31, 2},
              ordinal: 1,
              line: 160,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:369: (test)

.....
```

## WSG-INDEX

the wrong argument is read as the function (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 5 failures`.

```

  1) test build/3 every function HigherOrder knows takes a function: Enum.into/3 (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:391
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s40, 2}, _line}]} = one(a, :s40)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s40, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s40, 2},
              ordinal: 1,
              line: 182,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:392: (test)

.


  2) test build/3 S12: a capture passed to Enum is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:467
     Expected truthy, got false
     code: assert one(a, :s12).complete?
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:469: (test)

.....


  3) test build/3 an inline fn handed to Enum in the body is walked, with no gap of its own (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:333
     match (=) failed
     code:  assert [unresolved_write: %{mfa: {@x, :s23, 1}}] = one(a, :s23).gaps
     left:  [unresolved_write: %{mfa: {AnchorFixtures.ScopesTest.X, :s23, 1}}]
     right: [
              {:dynamic_call,
               {AnchorFixtures.ScopesTest.X, :s23, 1}, 140},
              {:unresolved_write,
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.ScopesTest.X, :s23, 1},
                 line: 140,
                 op: :insert,
                 via: :repo,
                 sources: [],
                 unresolved: "parameter 1 of an anonymous function",
                 scopes: [1],
                 run_callback?: false
               }}
            ]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:336: (test)

..


  4) test build/3 an inline fn before a trailing literal is walked, with no gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:373
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s36)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s36, 1},
              ordinal: 1,
              line: 168,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s36, 1}, 168}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:374: (test)

.


  5) test build/3 a capture from outside the body, handed to Enum in it, is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:381
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s38)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s38, 1},
              ordinal: 1,
              line: 174,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s38, 1}, 174}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:382: (test)

.........
```

## WSG-NOARGS

an apply hiding its arguments is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 1 failure`.

```

  1) test build/3 an apply of a function-taking call hides its arguments, so it is a gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:396
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s41, 2}, _line}]} = one(a, :s41)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s41, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s41, 2},
              ordinal: 1,
              line: 186,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:397: (test)

...................
```

## WSG-LITERAL

a literal in an invoked position is a gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 1 failure`.

```

  1) test build/3 an inline fn before a trailing literal is walked, with no gap (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:373
     match (=) failed
     code:  assert %Scope{complete?: true} = one(a, :s36)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s36, 1},
              ordinal: 1,
              line: 168,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s36, 1}, 168}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:374: (test)

...................
```

## WSG-HANDEDBINDING

a fun parameter handed over is no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 3 failures`.

```

  1) test build/3 every function HigherOrder knows takes a function: Enum.into/3 (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:391
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s40, 2}, _line}]} = one(a, :s40)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s40, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s40, 2},
              ordinal: 1,
              line: 182,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:392: (test)

..........


  2) test build/3 a fun parameter handed to Enum in the body makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:314
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s20, 2}, _line}]} = one(a, :s20)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s20, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
              ordinal: 1,
              line: 131,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s20, 2},
                  line: 131,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([schema: AnchorFixtures.ScopesTest.S]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:315: (test)

..................


  3) test build/3 the function is found before a trailing literal (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:368
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s31, 2}, _line}]} = one(a, :s31)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s31, 2}, _line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s31, 2},
              ordinal: 1,
              line: 160,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:369: (test)

..........
```

## WSG-RAWFLAG

raw SQL on a repo is not flagged as a write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `14 tests, 1 failure`.

```

  1) test unattributed: raw SQL and a write on a computed module, outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:123
     match (=) failed
     code:  assert [%{mfa: {@n, :n11, 0}, what: raw, line: line}, %{mfa: {@n, :n12, 1}, what: computed}] =
              a.unattributed
     left:  [
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n11, 0}, what: raw, line: line},
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, what: computed}
            ]
     right: [
              %{
                line: 59,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n12,
                 1},
                what: "a call of insert/1 on a module held in a variable"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:126: (test)

.....
```

## WSG-COMPUTEDFLAG

a write on a computed module is not flagged (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `14 tests, 1 failure`.

```

  1) test unattributed: raw SQL and a write on a computed module, outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:123
     match (=) failed
     code:  assert [%{mfa: {@n, :n11, 0}, what: raw, line: line}, %{mfa: {@n, :n12, 1}, what: computed}] =
              a.unattributed
     left:  [
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n11, 0}, what: raw, line: line},
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, what: computed}
            ]
     right: [
              %{
                line: 58,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n11,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:126: (test)

..........
```

## WSG-READFLAG

a read on a computed module is flagged (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `14 tests, 1 failure`.

```

  1) test unattributed: raw SQL and a write on a computed module, outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:123
     match (=) failed
     code:  assert [%{mfa: {@n, :n11, 0}, what: raw, line: line}, %{mfa: {@n, :n12, 1}, what: computed}] =
              a.unattributed
     left:  [
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n11, 0}, what: raw, line: line},
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, what: computed}
            ]
     right: [
              %{
                line: 58,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n11,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 59,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n12,
                 1},
                what: "a call of insert/1 on a module held in a variable"
              },
              %{
                line: 60,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n13,
                 1},
                what: "a call of get/2 on a module held in a variable"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:126: (test)

..........
```

## AN-OUTSIDE

unattributed holds writes inside a transaction too (`lib/anchor/domain/aggregates/analysis.ex`). Result: `14 tests, 1 failure`.

```

  1) test unattributed: raw SQL and a write on a computed module, outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:123
     match (=) failed
     code:  assert [%{mfa: {@n, :n11, 0}, what: raw, line: line}, %{mfa: {@n, :n12, 1}, what: computed}] =
              a.unattributed
     left:  [
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n11, 0}, what: raw, line: line},
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, what: computed}
            ]
     right: [
              %{
                line: 58,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n11,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 59,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n12,
                 1},
                what: "a call of insert/1 on a module held in a variable"
              },
              %{
                line: 61,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n14,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 62,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n15,
                 1},
                what: "a call of insert/1 on a module held in a variable"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:126: (test)

.........
```

## AN-COUNT

the gaps outside a transaction are not counted (`lib/anchor/domain/aggregates/analysis.ex`). Result: `14 tests, 1 failure`.

```

  1) test the gaps outside every transaction are counted (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:136
     Assertion with == failed
     code:  assert a.counts.outside_gaps == length(gaps)
     left:  5
     right: 4
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:139: (test)

.
```

## RL-UNATTRIBUTED

unattributed writes are not reported (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `12 tests, 2 failures`.

```

  1) test check/2 raw SQL outside a transaction is reported, keyed without its line, with a Fix (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:114
     match (=) failed
     code:  assert [finding] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [finding]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:117: (test)

...


  2) test check/2 selected modules holding only raw SQL have writes: no checks-nothing failure (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:136
     match (=) failed
     code:  assert [%{line: 40}] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [%{line: 40}]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:139: (test)

...
```

## RL-UNATTSELECT

unattributed writes ignore the selector (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `12 tests, 1 failure`.

```

  1) test check/2 unattributed writes outside the selector are not reported (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:129
     Assertion with == failed
     code:  assert AggregateWriteSources.check(model(analysis), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 40,
                trigger: "raw SQL (App.Repo.query!/1) Anchor cannot attribute",
                message: "Other.Thing.purge/0 writes, or may write, outside any transaction in a way no schema or table names: raw SQL (App.Repo.query!/1) Anchor cannot attribute. Fix: write through a schema with Repo, or name the module the call is on.",
                filename: ".anchor.yml",
                kind: :rule,
                key: "writes|Other.Thing.purge/0|unattributed raw SQL (App.Repo.query!/1) Anchor cannot attribute",
                rule_id: "writes",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:133: (test)

.......
```

## RL-ONLYRAW

selected raw SQL alone reads as checking nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `12 tests, 1 failure`.

```

  1) test check/2 selected modules holding only raw SQL have writes: no checks-nothing failure (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:136
     match (=) failed
     code:  assert [%{line: 40}] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [%{line: 40}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"writes\", aggregate_write_sources) checks nothing: no write found in paths [\"lib/app/**\"]. Fix: correct the selector or aggregates.repos.",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:139: (test)

......
```

## RP-NOTE

the summary does not count the gaps (`lib/anchor/domain/graph_report.ex`). Result: `4 tests, 1 failure`.

```



  1) test the write analysis's counts are in the summary and the JSON (Anchor.Domain.GraphReportAggregatesTest)
     test/anchor/domain/graph_report_aggregates_test.exs:42
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 " <>
                "baselined); writes: 7 found, 5 resolved, 2 unresolved; transactions: 3, 2 " <>
                "complete, 1 incomplete; 4 gaps outside a transaction"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 found, 5 resolved, 2 unresolved; transactions: 3, 2 complete, 1 incomplete"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); writes: 7 found, 5 resolved, 2 unresolved; transactions: 3, 2 complete, 1 incomplete; 4 gaps outside a transaction"
     stacktrace:
       test/anchor/domain/graph_report_aggregates_test.exs:55: (test)

...
```

# Fifth run: outside means outside on every path

7 mutations for critic round 7's finding and the claims its notes questioned. These replace the second run's WSF-ONREPO, WSF-ONREPOWRITE, WSF-ONREPORAW and WSF-ONREPOGEN, whose `written_on_repo?/2` is gone. AN-ALWAYS's first form, deleting the filter, was a compile error under `warnings_as_errors` (an unused parameter) and was re-anchored. WSH-GENWRITE, WSH-GENRAW and WSH-GENOTHER fail the same three tests because each test's fixture holds all three kinds of generated function; each run's output names the function it found.

| # | Mutation | Tests run | Result |
|---|---|---|---|
| AN-ALWAYS | raw SQL reached only inside a transaction is reported (`lib/anchor/domain/aggregates/analysis.ex`) | `non_transactional_test.exs` | `16 tests, 1 failure` (red) |
| NT-RUNEMPTY | a captured run callback keeps its own entry (`lib/anchor/domain/aggregates/non_transactional.ex`) | `non_transactional_test.exs` | `16 tests, 1 failure` (red) |
| WSH-GENERATED | what Ecto generates on a repo is walked (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs`, `scopes_test.exs` | `59 tests, 3 failures` (red) |
| WSH-GENWRITE | a generated write is walked (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs`, `scopes_test.exs` | `59 tests, 3 failures` (red) |
| WSH-GENRAW | generated raw SQL is walked (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs`, `scopes_test.exs` | `59 tests, 3 failures` (red) |
| WSH-GENOTHER | a generated read is walked (`lib/anchor/domain/aggregates/write_sites.ex`) | `non_transactional_test.exs`, `scopes_test.exs` | `59 tests, 3 failures` (red) |
| WSH-ONREPO | a local call in a function written on a repo is not read (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `43 tests, 2 failures` (red) |

## AN-ALWAYS

raw SQL reached only inside a transaction is reported (`lib/anchor/domain/aggregates/analysis.ex`). Result: `16 tests, 1 failure`.

```



  1) test unattributed: raw SQL and a write on a computed module, outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:133
     match (=) failed
     code:  assert [%{mfa: {@n, :n11, 0}, what: raw, line: line}, %{mfa: {@n, :n12, 1}, what: computed}] =
              a.unattributed
     left:  [
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n11, 0}, what: raw, line: line},
              %{mfa: {AnchorFixtures.NonTransactionalTest.N, :n12, 1}, what: computed}
            ]
     right: [
              %{
                line: 58,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n11,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 59,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n12,
                 1},
                what: "a call of insert/1 on a module held in a variable"
              },
              %{
                line: 66,
                mfa: {AnchorFixtures.NonTransactionalTest.N, :n17h,
                 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.Repo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 69,
                mfa: {AnchorFixtures.NonTransactionalTest.N,
                 :n18_step, 2},
                what: "raw SQL (repo.query!/1 in a Multi.run callback) Anchor cannot attribute"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:136: (test)

...............
```

## NT-RUNEMPTY

a captured run callback keeps its own entry (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `16 tests, 1 failure`.

```

  1) test a captured run callback's own entry is empty; a direct caller still has its writes (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:146
     Assertion with == failed
     code:  assert nontx(a, :n7_step, 2).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:148: (test)

..............
```

## WSH-GENERATED

what Ecto generates on a repo is walked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `59 tests, 3 failures`.

```

  1) test a function written on a repo is read; what Ecto generates on it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:152
     match (=) failed
     The following variables were pinned:
       sql_repo = AnchorFixtures.NonTransactionalTest.SqlRepo
     code:  assert [%{mfa: {^sql_repo, :purge, 0}}] =
              Enum.filter(analysis.unattributed, &(elem(&1.mfa, 0) == sql_repo))
     left:  [%{mfa: {^sql_repo, :purge, 0}}]
     right: [
              %{
                line: 83,
                mfa: {AnchorFixtures.NonTransactionalTest.SqlRepo,
                 :purge, 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.SqlRepo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 79,
                mfa: {AnchorFixtures.NonTransactionalTest.SqlRepo,
                 :query!, 1},
                what: "raw SQL (Ecto.Adapters.SQL.query!/3) Anchor cannot attribute"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:170: (test)

....................


  2) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:502
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  17
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:507: (test)

....................


  3) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:354
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :insert, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :query, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :reload, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :update, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:357: (test)

.............
```

## WSH-GENWRITE

a generated write is walked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `59 tests, 3 failures`.

```

  1) test a function written on a repo is read; what Ecto generates on it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:152
     Expected false or nil, got true
     code: refute Map.has_key?(analysis.nontx, {sql_repo, :insert, 1})
     arguments:

         # 1
         %{
           {AnchorFixtures.NonTransactionalTest.Repo, :delete!, 1} => %{
             keys: MapSet.new([]),
             gaps: [
               unresolved_write: %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.Repo,
                  :delete!, 1},
                 line: 19,
                 op: :delete!,
                 via: :repo,
                 sources: [],
                 unresolved: "parameter 1 of AnchorFixtures.NonTransactionalTest.Repo.delete!/1 has no @spec and no project caller",
                 scopes: [],
                 run_callback?: false
               }
             ],
             sites: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.Repo,
                  :delete!, 1},
                 line: 19,
                 op: :delete!,
                 via: :repo,
                 sources: [],
                 unresolved: "parameter 1 of AnchorFixtures.NonTransactionalTest.Repo.delete!/1 has no @spec and no project caller",
                 scopes: [],
                 run_callback?: false
               }
             ],
             complete?: false
           },
           {AnchorFixtures.NonTransactionalTest.N, :n3g, 0} => %{
             keys: MapSet.new([
               schema: AnchorFixtures.NonTransactionalTest.T
             ]),
             gaps: [],
             sites: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.N, :n3g, 0},
                 line: 42,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.NonTransactionalTest.T
                 ],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               }
             ],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n4b, 1} => %{
             keys: MapSet.new([
               schema: AnchorFixtures.NonTransactionalTest.S,
               schema: AnchorFixtures.NonTransactionalTest.T
             ]),
             gaps: [],
             sites: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.N, :n4a, 1},
                 line: 44,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.NonTransactionalTest.S
                 ],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.N, :n4b, 1},
                 line: 46,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.NonTransactionalTest.T
                 ],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               }
             ],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n19_step, 2} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.Repo, ...} => %{...},
           ...
         }

         # 2
         {AnchorFixtures.NonTransactionalTest.SqlRepo, :insert, 1}

     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:175: (test)

...........


  2) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:354
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :insert, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :update, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:357: (test)

................................


  3) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:502
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  15
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:507: (test)

..........
```

## WSH-GENRAW

generated raw SQL is walked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `59 tests, 3 failures`.

```

  1) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:354
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :query, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:357: (test)




  2) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:502
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  3
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:507: (test)

..........


  3) test a function written on a repo is read; what Ecto generates on it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:152
     match (=) failed
     The following variables were pinned:
       sql_repo = AnchorFixtures.NonTransactionalTest.SqlRepo
     code:  assert [%{mfa: {^sql_repo, :purge, 0}}] =
              Enum.filter(analysis.unattributed, &(elem(&1.mfa, 0) == sql_repo))
     left:  [%{mfa: {^sql_repo, :purge, 0}}]
     right: [
              %{
                line: 83,
                mfa: {AnchorFixtures.NonTransactionalTest.SqlRepo,
                 :purge, 0},
                what: "raw SQL (AnchorFixtures.NonTransactionalTest.SqlRepo.query!/1) Anchor cannot attribute"
              },
              %{
                line: 79,
                mfa: {AnchorFixtures.NonTransactionalTest.SqlRepo,
                 :query!, 1},
                what: "raw SQL (Ecto.Adapters.SQL.query!/3) Anchor cannot attribute"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:170: (test)

...........................
```

## WSH-GENOTHER

a generated read is walked (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `59 tests, 3 failures`.

```

  1) test a function written on a repo is read; what Ecto generates on it is not (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:152
     Expected false or nil, got true
     code: refute Map.has_key?(analysis.nontx, {sql_repo, :get, 2})
     arguments:

         # 1
         %{
           {AnchorFixtures.NonTransactionalTest.N, :n19, 0} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n15, 1} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n17, 0} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.Repo, :transaction, 1} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n14, 0} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n5, 0} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.S, :__schema__, 1} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.Repo, :transaction, 2} => %{
             keys: MapSet.new([]),
             gaps: [],
             sites: [],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n3g, 0} => %{
             keys: MapSet.new([
               schema: AnchorFixtures.NonTransactionalTest.T
             ]),
             gaps: [],
             sites: [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.NonTransactionalTest.N, :n3g, 0},
                 line: 42,
                 op: :insert,
                 via: :repo,
                 sources: [
                   schema: AnchorFixtures.NonTransactionalTest.T
                 ],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               }
             ],
             complete?: true
           },
           {AnchorFixtures.NonTransactionalTest.N, :n9, 0} => %{
             keys: MapSet.new([]),
             gaps: [
               {:dynamic_call,
                {AnchorFixtures.NonTransactionalTest.N, :n9, 0}, 75}
             ],
             sites: [],
             ...
           },
           ...
         }

         # 2
         {AnchorFixtures.NonTransactionalTest.SqlRepo, :get, 2}

     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:173: (test)

...............................


  2) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:502
     Assertion with == failed
     code:  assert a.counts.unresolved == 2
     left:  3
     right: 2
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:507: (test)

........


  3) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:354
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  [
              {AnchorFixtures.ScopesTest.CustomRepo, :reload, 1},
              {AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}
            ]
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:357: (test)

.........
```

## WSH-ONREPO

a local call in a function written on a repo is not read (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `43 tests, 2 failures`.

```

  1) test build/3 a function written on a repo is followed: its own writes are in the scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:347
     Assertion with == failed
     code:  assert scope.keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:351: (test)

........


  2) test build/3 only a function written on a repo is read for its calls, not what Ecto generates (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:354
     Assertion with == failed
     code:  assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) == [
              {@custom_repo, :soft, 1}
            ]
     left:  []
     right: [{AnchorFixtures.ScopesTest.CustomRepo, :soft, 1}]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:357: (test)

...........................
```
