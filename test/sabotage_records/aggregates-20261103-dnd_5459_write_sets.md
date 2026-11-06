# Sabotage record — transaction write sets and `declare: none` (DND-5459, DND-5659)

- **Domain:** aggregates (one combined record for the branch, as ADR 003 directs for one branch, one day, one domain; the mutations of `Anchor.Config`, `Anchor.Domain.RuleSchema`, `Anchor.Domain.GraphRules`, `Anchor.Domain.Model`, `Anchor.Domain.GraphReport`, `Anchor.Domain.Failures`, `Anchor.Domain.GraphRules.*` and `Anchor.Managers.Graph` are off-domain and labelled by their file)
- **Branch:** dnd-5459-write-sets (a batch: DND-5459, then DND-5659, then the review-floor fixes)
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Aggregates.WriteSource` (trace rules 1-9, `key/2`), `WriteSites` (repos, writes, raw SQL, transactions, Multi tracing, `Multi.run` callbacks), `FunctionWalk`, `Scopes`, `NonTransactional`, `Inference`, `Analysis`, `Persistence`, `Aggregates.Config` (`declare: none`), `Aggregates.Index` (`:persists_under_none`), the graph rules `AggregateWriteSources` and `AggregateDeclarations`, and the wiring in `Anchor.Config`, `RuleSchema`, `GraphRules`, `Model`, `GraphReport`, `Failures` and `Anchor.Managers.Graph`
- **Suite run:** a driver applied each mutation to the source (one exact, unique anchor), ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside `test-slot`, kept every failure block of the run verbatim, and restored the source, bumping the file's mtime after each write so Mix recompiled it. After the pass `git status` showed only the intended edits. Every mutation below was run on 5a1523d (pass 7's on 3a0d3f3); every one is red by a failed assertion or a raise in the code under test, and its failure output is copied below as the run printed it.
- **Passes:**
  1. 45 mutations on 5380b87 (DND-5459's QA-plan sabotage table and one per guard). Not measured: WS-SPEC, WS-SCHEMACALL, WS-CAPTURED, WSI-RUNCAPTURE, NT-AIT, IN-ROOT and RL-NONE were compile errors under `warnings_as_errors` (an unused variable or function, or a clause the type checker proves dead), and WS-RETURN survived, because R13's helper was a local `defp`; a remote-helper test (`r15`) was added.
  2. 18 mutations: the re-anchored rows and the wiring. WS-CAPTURED survived (no test had a captured function whose parameter has a caller; `r16` was added); NT-AIT and MD-ROOTS were compile errors again.
  3. 3 mutations: WS-CAPTURED, NT-AIT re-anchored, MD-ROOTS against a new Model-level roots test.
  4. 23 mutations for DND-5659 on e005327. PS-REPOWRITE's first two forms were compile errors; its third form went red.
  5. The full set again on the branch head, to record every failure verbatim (the ADR-review finding that passes 1-4 recorded counts and test names only): the 55 DND-5459 rows (NT-MULTI, NT-AIT and CF-NEEDS re-anchored to the code as it now reads), the 23 DND-5659 rows, 14 new rows for tests that had no recorded red (W1, W2, R2, R11, R14, S1, S9, S12, S13, the counts test, F4, F7 and Z1), and 10 rows for the review-floor fixes' tests (nine red; WS-STRINGARG measured equivalent, see Not mutated).
  6. Pass 5 left four rows unmeasured. MD-ANALYSIS (`aggregate_analysis: nil` made `Managers.Graph.put_writes/2`'s clause provably dead, and its next form did the same), NT-RUNCAP (dropping the pipe step left a variable and a function unused) and WSI-RAWSQLADAPTER (dropping the module test left an attribute unused) were compile errors; each was re-anchored to the form recorded below, and went red. WS-STRINGARG survived: see Not mutated.
  7. 3 mutations for the critic's round-2 fix (render_yaml's evidence of persistence, and raw SQL on a Repo in `Persistence`), run on 3a0d3f3: all red.
- **Not mutated:** the parameter-stack check in `WriteSource.param/3` (`key in ctx.stack`): the 8-hop bound gives the same `"parameter cycle"` answer on every cycle, so removing it is an equivalent mutant. WS-STRINGARG (in `WriteSource.string?/1`, drop the `:cerl.type(node) == :binary` arm, so a string Core holds as a `:binary` node could be read as a table): it survived, 7 tests, 0 failures. Measured as equivalent on every input found: nine source forms of a string argument (a literal, `<>` of two literals, `<<"a", "b">>`, `~s()`, `::binary`, `::utf8`, interpolation of a literal and of a module attribute, and a second argument) all compile to a `:literal` node, never a `:binary` one, so no fixture can reach the arm. It is kept because it mirrors trace's own `:binary` rule (`write_source.ex`, `binary/1`), so a `:binary` prefix can never be a table either. Anchor's own `.anchor.yml` (the `aggregate_declarations` rule, enforced, with `declare: none`): its check is the gate's `MIX_ENV=dev mix anchor.graph` run; the `aggregates_none` canary proves the same config shape fails a module that persists.
- **Test files:** `test/anchor/domain/aggregates/{config,index,write_source,write_sites,scopes,non_transactional,inference,real_ecto}_test.exs`, `test/anchor/domain/graph_rules/{aggregate_write_sources,aggregate_declarations}_test.exs`, `test/anchor/integration/{aggregate_write_sources,aggregates_none}_integration_test.exs`, and the rows the branch adds to `failures_graph_test.exs`, `graph_report_aggregates_test.exs`, `rule_schema_test.exs` and `rule_checks_nothing_test.exs`.

## DND-5459: transaction write sets

| # | Mutation | Tests run | Result |
|---|---|---|---|
| WS-CALLERS | rule 7b (callers) dropped (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 2 failures` (red) |
| WS-UNION | an unresolved branch is ignorable in the union (rule 3) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 2 failures` (red) |
| WS-SPEC | @spec S.t() is not read (rule 7a) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| WS-RETURN | a remote project call is not traced into (rule 8) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| WS-SCHEMACALL | a call on a schema is not the schema (rule 4) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs`, `real_ecto_test.exs` | `24 tests, 2 failures` (red) |
| WS-CHANGESET | Ecto.Changeset calls are not traced (rule 5) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 2 failures` (red) |
| WS-QUERY | Ecto.Query builder calls are not traced (rule 6) (`lib/anchor/domain/aggregates/write_source.ex`) | `real_ecto_test.exs` | `7 tests, 2 failures` (red) |
| WS-QUERYSTRUCT | an %Ecto.Query{} map node is not traced to its from (`lib/anchor/domain/aggregates/write_source.ex`) | `real_ecto_test.exs` | `7 tests, 1 failure` (red) |
| WS-FROMEXPR | an %Ecto.Query.FromExpr{} map node is not traced to its source (`lib/anchor/domain/aggregates/write_source.ex`) | `real_ecto_test.exs` | `7 tests, 1 failure` (red) |
| WS-LITQUERY | a literal %Ecto.Query{} is not traced (`lib/anchor/domain/aggregates/write_source.ex`) | `real_ecto_test.exs` | `7 tests, 1 failure` (red) |
| WS-STRUCT | a struct literal of a schema is not the schema (rule 1) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 6 failures` (red) |
| WS-TABLE | a literal string is not a table (rule 2) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 2 failures` (red) |
| WS-KEY | a table is never keyed to its schema (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs`, `real_ecto_test.exs` | `24 tests, 2 failures` (red) |
| WS-CAPTURED | a captured function's parameter reads its callers (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| WSI-GET | Repo.get counts as a write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-MULTIARG | a Multi write's source is argument 2, not 3 (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-RUNLAMBDA | a Multi.run fn's repo parameter is not a repo (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs`, `scopes_test.exs` | `28 tests, 2 failures` (red) |
| WSI-RUNCAPTURE | a Multi.run capture's repo parameter is not a repo (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-WRITEFN | write_functions entries are not writes (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-DYNVAR | a call on a module variable is not a dynamic call (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-BEHAVIOUR | @behaviour Ecto.Repo does not make a repo (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs`, `real_ecto_test.exs` | `17 tests, 8 failures` (red) |
| WSI-NOREPO | no repo is not reported (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-HELPER | a project function on a Multi trace is ignored (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| WSI-TXFN | transaction_functions calls are not scopes (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| WSI-APPLYGAP | a call of a fun value is not a gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| WSI-ORDINAL | a scope's ordinal is its line (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 2 failures` (red) |
| WSI-UNTRACED | a transaction given an untraceable value has no gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| SC-CLOSURE | the closure stops following calls (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs`, `non_transactional_test.exs` | `28 tests, 4 failures` (red) |
| SC-CAPTURES | a captured transaction body is not followed (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| SC-UNRESOLVEDGAP | an unresolved write is not a gap (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| SC-BODY | a scope holds every write of its function (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| NT-OUTSIDE | writes inside a transaction count as non-transactional (`lib/anchor/domain/aggregates/non_transactional.ex`) | `non_transactional_test.exs` | `10 tests, 2 failures` (red) |
| NT-MULTI | a Multi step counts as non-transactional (`lib/anchor/domain/aggregates/non_transactional.ex`) | `non_transactional_test.exs` | `10 tests, 1 failure` (red) |
| IN-INCOMPLETE | incomplete scopes add no edges (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| IN-ROOT | the root ignores how many complete scopes hold it (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 2 failures` (red) |
| IN-YAML | render_yaml omits declare: (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 2 failures` (red) |
| IN-CAMEL | a table root is not camelized (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| IN-OUTSIDE | non-transactional writes are no vertices (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 3 failures` (red) |
| RL-SELECT | the selector is ignored (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 2 failures` (red) |
| RL-KEYLINE | the unresolved key carries the line (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 1 failure` (red) |
| RL-NOREPO | no repo reports nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 2 failures` (red) |
| RL-NONE | zero writes in the selection reports nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 1 failure` (red) |
| RL-INCOMPLETE | incomplete scopes are not reported (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`) | `aggregate_write_sources_test.exs`, `aggregate_write_sources_integration_test.exs` | `11 tests, 2 failures` (red) |
| CF-NEEDS | a rule needing the aggregates: section loads without one (`lib/anchor/domain/config.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 1 failure` (red) |
| RS-NEEDS | aggregate_write_sources does not need the section (`lib/anchor/domain/rule_schema.ex`) | `aggregate_write_sources_test.exs`, `rule_checks_nothing_test.exs` | `37 tests, 2 failures` (red) |
| RS-ENGINE | aggregate_write_sources runs on the ast engine (`lib/anchor/domain/rule_schema.ex`) | `rule_schema_test.exs`, `graph_rules_test.exs` | `45 tests, 4 failures` (red) |
| GR-REG | aggregate_write_sources is not registered (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `aggregate_write_sources_integration_test.exs` | `14 tests, 2 failures` (red) |
| MD-ANALYSIS | the model never builds the analysis (`lib/anchor/domain/model.ex`) | `aggregate_write_sources_integration_test.exs` | `2 tests, 2 failures` (red) |
| RP-WRITES | the summary omits the writes (`lib/anchor/domain/graph_report.ex`) | `graph_report_aggregates_test.exs`, `aggregate_write_sources_integration_test.exs` | `6 tests, 3 failures` (red) |
| MG-WRITES | the manager does not count the writes (`lib/anchor/managers/graph.ex`) | `aggregate_write_sources_integration_test.exs` | `2 tests, 2 failures` (red) |
| FL-NOREPO | the no-repo message loses its Fix (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `16 tests, 1 failure` (red) |
| FL-NONE | the checks-nothing message loses its Fix (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `16 tests, 1 failure` (red) |
| WSI-DELETEALL | delete_all is not a Repo write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 1 failure` (red) |
| WSI-INSERT | insert is not a Repo write (`lib/anchor/domain/aggregates/write_sites.ex`) | `write_sites_test.exs` | `10 tests, 3 failures` (red) |
| WS-SCHEMAMOD | a literal schema module is not its schema (rule 2) (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| WS-NOCALLER | the no-caller reason loses its words (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| WS-SEEN | an unresolved call does not name what was seen (`lib/anchor/domain/aggregates/write_source.ex`) | `write_source_test.exs` | `17 tests, 1 failure` (red) |
| SC-REMOTE | a scope follows only callees in its own module (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 5 failures` (red) |
| SC-INNER | a closure leaves out writes inside a callee's own transaction (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| SC-ENUMCAPTURE | a capture in a scope's body is not followed (`lib/anchor/domain/aggregates/scopes.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| WSI-DEPCALL | a call into a dependency is a dynamic-call gap (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 5 failures` (red) |
| AN-COUNTS | resolved is off by one (`lib/anchor/domain/aggregates/analysis.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| AN-INCOMPLETE | incomplete counts the complete scopes (`lib/anchor/domain/aggregates/analysis.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| IN-EVIDENCEORDER | a proposal's evidence keeps the input order (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| IN-EMPTYKEYS | an empty-keys scope is matched as a filter (the bug 8c8c78b fixed) (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |

### WS-CALLERS

rule 7b (callers) dropped (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) R10: a parameter with no spec is the union of its callers' arguments (rule 7b) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:132
     match (=) failed
     code:  assert %{sources: [schema: @s, schema: @t], unresolved: nil} = site(sites, :r10)
     left:  %{
              sources: [schema: AnchorFixtures.WriteSourceTest.S, schema: AnchorFixtures.WriteSourceTest.T],
              unresolved: nil
            }
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r10, 1},
              line: 59,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "parameter 1 of AnchorFixtures.WriteSourceTest.X.r10/1 has no @spec and no project caller",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:135: (test)

...........


  2) test resolve/3 (through WriteSites.find/2) R12: a parameter passed round a recursion is a parameter cycle, and terminates (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:143
     match (=) failed
     code:  assert %{sources: [], unresolved: "parameter cycle"} = site(sites, :r12a)
     left:  %{sources: [], unresolved: "parameter cycle"}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r12a, 2},
              line: 62,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "parameter 1 of AnchorFixtures.WriteSourceTest.X.r12a/2 has no @spec and no project caller",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:146: (test)

..
```

### WS-UNION

an unresolved branch is ignorable in the union (rule 3) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) R12: a parameter passed round a recursion is a parameter cycle, and terminates (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:143
     match (=) failed
     code:  assert %{sources: [], unresolved: "parameter cycle"} = site(sites, :r12a)
     left:  %{sources: [], unresolved: "parameter cycle"}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r12a, 2},
              line: 62,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a value that is never returned (every branch raises)",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:146: (test)

........


  2) test resolve/3 (through WriteSites.find/2) R8: one unresolvable branch makes the value unresolved (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:123
     match (=) failed
     code:  assert %{sources: [], unresolved: seen} = site(sites, :r8)
     left:  %{sources: [], unresolved: seen}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r8, 1},
              line: 53,
              op: :insert,
              via: :repo,
              sources: [schema: AnchorFixtures.WriteSourceTest.S],
              unresolved: nil,
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:124: (test)

.....
```

### WS-SPEC

@spec S.t() is not read (rule 7a) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R9: a parameter whose @spec is S.t() is S (rule 7a) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:128
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r9)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r9, 1},
              line: 57,
              op: :update,
              via: :repo,
              sources: [],
              unresolved: "parameter 1 of AnchorFixtures.WriteSourceTest.X.r9/1 has no @spec and no project caller",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:129: (test)

......
```

### WS-RETURN

a remote project call is not traced into (rule 8) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R13: a remote call into a project function is what it returns (rule 8) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:153
     match (=) failed
     code:  assert %{sources: [schema: @t], unresolved: nil} = site(sites, :r15)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.T], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r15, 0},
              line: 68,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "{AnchorFixtures.WriteSourceTest.X, :r15, 0}",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:156: (test)

.....
```

### WS-SCHEMACALL

a call on a schema is not the schema (rule 4) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `24 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) R6: a call on a schema module is the schema (rule 4) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:115
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r6)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r6, 2},
              line: 44,
              op: :update,
              via: :repo,
              sources: [],
              unresolved: "the result of AnchorFixtures.WriteSourceTest.S.changeset/2",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:116: (test)

...


  2) test E2: a from/2 query on a schema is the schema, written or piped (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:86
     match (=) failed
     code:  assert %{sources: [schema: @thread], unresolved: nil} = site(a, :e2)
     left:  %{sources: [schema: AnchorFixtures.RealEctoTest.Thread], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e2, 1},
              line: 27,
              op: :update_all,
              via: :repo,
              sources: [],
              unresolved: "the atom nil, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:87: (test)

.....
```

### WS-CHANGESET

Ecto.Changeset calls are not traced (rule 5) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 2 failures`.

```

  1) test resolve/3 (through WriteSites.find/2) R9: a parameter whose @spec is S.t() is S (rule 7a) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:128
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r9)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r9, 1},
              line: 57,
              op: :update,
              via: :repo,
              sources: [],
              unresolved: "the result of Ecto.Changeset.change/1",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:129: (test)

..


  2) test resolve/3 (through WriteSites.find/2) R5: a changeset built from a struct is the struct's schema (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:111
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r5)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r5, 0},
              line: 41,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "the result of Ecto.Changeset.change/2",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:112: (test)

..
```

### WS-QUERY

Ecto.Query builder calls are not traced (rule 6) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `7 tests, 2 failures`.

```

  1) test E6: a query call's literal argument is never the table; an unknown query stays unknown (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:102
     match (=) failed
     code:  assert %{sources: [schema: @thread], unresolved: nil} = site(a, :e6_known)
     left:  %{sources: [schema: AnchorFixtures.RealEctoTest.Thread], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e6_known, 0},
              line: 32,
              op: :delete_all,
              via: :repo,
              sources: [],
              unresolved: "the result of Ecto.Query.put_query_prefix/2",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:106: (test)

...


  2) test E5: a query built on a schema by Ecto.Query's builders is the schema (rule 6) (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:96
     match (=) failed
     code:  assert %{sources: [schema: @thread], unresolved: nil} = site(a, :e5)
     left:  %{sources: [schema: AnchorFixtures.RealEctoTest.Thread], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e5, 1},
              line: 30,
              op: :delete_all,
              via: :repo,
              sources: [],
              unresolved: "the result of Ecto.Query.Builder.Filter.apply/3",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:99: (test)

.
```

### WS-QUERYSTRUCT

an %Ecto.Query{} map node is not traced to its from (`lib/anchor/domain/aggregates/write_source.ex`). Result: `7 tests, 1 failure`.

```

  1) test E2: a from/2 query on a schema is the schema, written or piped (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:86
     match (=) failed
     code:  assert %{sources: [schema: @thread], unresolved: nil} = site(a, :e2)
     left:  %{sources: [schema: AnchorFixtures.RealEctoTest.Thread], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e2, 1},
              line: 27,
              op: :update_all,
              via: :repo,
              sources: [],
              unresolved: "x",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:87: (test)

....
```

### WS-FROMEXPR

an %Ecto.Query.FromExpr{} map node is not traced to its source (`lib/anchor/domain/aggregates/write_source.ex`). Result: `7 tests, 1 failure`.

```



  1) test E2: a from/2 query on a schema is the schema, written or piped (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:86
     match (=) failed
     code:  assert %{sources: [schema: @thread], unresolved: nil} = site(a, :e2)
     left:  %{sources: [schema: AnchorFixtures.RealEctoTest.Thread], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e2, 1},
              line: 27,
              op: :update_all,
              via: :repo,
              sources: [],
              unresolved: "x",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:87: (test)

......
```

### WS-LITQUERY

a literal %Ecto.Query{} is not traced (`lib/anchor/domain/aggregates/write_source.ex`). Result: `7 tests, 1 failure`.

```

  1) test E3: a from/2 query on a table is the table, keyed to its schema (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:91
     match (=) failed
     code:  assert %{sources: [table: "threads"], unresolved: nil} = site(a, :e3)
     left:  %{sources: [table: "threads"], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.RealEctoTest.E, :e3, 0},
              line: 29,
              op: :delete_all,
              via: :repo,
              sources: [],
              unresolved: "x",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:92: (test)

.
```

### WS-STRUCT

a struct literal of a schema is not the schema (rule 1) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 6 failures`.

```



  1) test resolve/3 (through WriteSites.find/2) R1: a struct literal is its schema (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:95
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r1)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r1, 0},
              line: 34,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.S{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:96: (test)




  2) test resolve/3 (through WriteSites.find/2) R7: branches union (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:119
     match (=) failed
     code:  assert %{sources: [schema: @s, schema: @t], unresolved: nil} = site(sites, :r7)
     left:  %{
              sources: [schema: AnchorFixtures.WriteSourceTest.S, schema: AnchorFixtures.WriteSourceTest.T],
              unresolved: nil
            }
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r7, 1},
              line: 48,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.T{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:120: (test)




  3) test resolve/3 (through WriteSites.find/2) R13: a remote call into a project function is what it returns (rule 8) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:153
     match (=) failed
     code:  assert %{sources: [schema: @t], unresolved: nil} = site(sites, :r15)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.T], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r15, 0},
              line: 68,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.T{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:156: (test)




  4) test resolve/3 (through WriteSites.find/2) R5: a changeset built from a struct is the struct's schema (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:111
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r5)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r5, 0},
              line: 41,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.S{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:112: (test)




  5) test resolve/3 (through WriteSites.find/2) R13: a call into a project function is what it returns (rule 8) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:149
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r13)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r13, 0},
              line: 66,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.S{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:150: (test)

..........


  6) test resolve/3 (through WriteSites.find/2) R10: a parameter with no spec is the union of its callers' arguments (rule 7b) (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:132
     match (=) failed
     code:  assert %{sources: [schema: @s, schema: @t], unresolved: nil} = site(sites, :r10)
     left:  %{
              sources: [schema: AnchorFixtures.WriteSourceTest.S, schema: AnchorFixtures.WriteSourceTest.T],
              unresolved: nil
            }
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r10, 1},
              line: 59,
              op: :insert,
              via: :repo,
              sources: [],
              unresolved: "a %AnchorFixtures.WriteSourceTest.S{} struct, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:135: (test)

.
```

### WS-TABLE

a literal string is not a table (rule 2) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 2 failures`.

```



  1) test resolve/3 (through WriteSites.find/2) R3: a literal table is a table (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:103
     match (=) failed
     code:  assert %{sources: [table: "t"], unresolved: nil} = site(sites, :r3)
     left:  %{sources: [table: "t"], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r3, 1},
              line: 36,
              op: :insert_all,
              via: :repo,
              sources: [],
              unresolved: "a literal value",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:104: (test)

..........


  2) test resolve/3 (through WriteSites.find/2) R4: {table, schema} is the table (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:107
     match (=) failed
     code:  assert %{sources: [table: "t"], unresolved: nil} = site(sites, :r4)
     left:  %{sources: [table: "t"], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r4, 1},
              line: 37,
              op: :insert_all,
              via: :repo,
              sources: [],
              unresolved: "a literal value",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:108: (test)

.....
```

### WS-KEY

a table is never keyed to its schema (`lib/anchor/domain/aggregates/write_source.ex`). Result: `24 tests, 2 failures`.

```

  1) test key/2 a table exactly one schema derives is that schema; two keep the table (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:177
     Assertion with == failed
     code:  assert WriteSource.key({:table, "t"}, tables) == {:schema, @t}
     left:  {:table, "t"}
     right: {:schema, AnchorFixtures.WriteSourceTest.T}
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:179: (test)

....


  2) test E3: a from/2 query on a table is the table, keyed to its schema (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:91
     Assertion with == failed
     code:  assert WriteSource.key({:table, "threads"}, a.tables) == {:schema, @thread}
     left:  {:table, "threads"}
     right: {:schema, AnchorFixtures.RealEctoTest.Thread}
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:93: (test)

....
```

### WS-CAPTURED

a captured function's parameter reads its callers (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

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

..
```

### WSI-GET

Repo.get counts as a write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W8: reads are not writes (positive control for W1) (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:156
     Assertion with == failed
     code:  assert in_function(sites, "w8") == []
     left:  [
              %Anchor.Domain.Aggregates.WriteSite{
                mfa: {AnchorFixtures.WriteSitesTest.W, :w8, 1},
                line: 66,
                op: :get,
                via: :repo,
                sources: [schema: AnchorFixtures.WriteSitesTest.S],
                unresolved: nil,
                scopes: [],
                run_callback?: false
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:157: (test)

........
```

### WSI-MULTIARG

a Multi write's source is argument 2, not 3 (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W3: each Multi write is a site via :multi, its source argument 3 (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:109
     Expected truthy, got false
     code: assert Enum.all?(w3, &(&1.via == :multi and &1.sources == [schema: @s]))
     arguments:

         # 1
         [
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 48,
             op: :insert,
             via: :multi,
             sources: [],
             unresolved: "the atom :a, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 49,
             op: :update,
             via: :multi,
             sources: [],
             unresolved: "the atom :b, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 50,
             op: :delete,
             via: :multi,
             sources: [],
             unresolved: "the atom :c, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 51,
             op: :insert_or_update,
             via: :multi,
             sources: [],
             unresolved: "the atom :d, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 52,
             op: :insert_all,
             via: :multi,
             sources: [],
             unresolved: "the atom :e, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 53,
             op: :update_all,
             via: :multi,
             sources: [],
             unresolved: "the atom :f, not a schema",
             scopes: [],
             run_callback?: false
           },
           %Anchor.Domain.Aggregates.WriteSite{
             mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
             line: 54,
             op: :delete_all,
             via: :multi,
             sources: [],
             unresolved: "the atom :g, not a schema",
             scopes: [],
             run_callback?: false
           }
         ]

         # 2
         #Function<5.56975147/1 in Anchor.Domain.Aggregates.WriteSitesTest."test find/2 W3: each Multi write is a site via :multi, its source argument 3"/1>

     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:123: (test)

..
```

### WSI-RUNLAMBDA

a Multi.run fn's repo parameter is not a repo (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `28 tests, 2 failures`.

```

  1) test find/2 W4: a Multi.run callback's repo argument writes via :run_callback_repo (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:126
     match (=) failed
     code:  assert [%{via: :run_callback_repo, op: :insert, sources: [schema: @s]}] = in_function(sites, "w4")
     left:  [%{via: :run_callback_repo, op: :insert, sources: [schema: AnchorFixtures.WriteSitesTest.S]}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:127: (test)

...........


  2) test build/3 S4: a Multi.run callback's writes are in the Multi's scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:154
     Expected truthy, got false
     code: assert MapSet.member?(scope.keys, {:schema, @u})
     arguments:

         # 1
         MapSet.new([])

         # 2
         {:schema, AnchorFixtures.ScopesTest.U}

     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:156: (test)

..............
```

### WSI-RUNCAPTURE

a Multi.run capture's repo parameter is not a repo (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W5: a Multi.run capture's repo parameter writes via :run_callback_repo (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:131
     match (=) failed
     code:  assert [%{via: :run_callback_repo, op: :update, sources: [schema: @s]}] = in_function(sites, "step")
     left:  [%{via: :run_callback_repo, op: :update, sources: [schema: AnchorFixtures.WriteSitesTest.S]}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:132: (test)

........
```

### WSI-WRITEFN

write_functions entries are not writes (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W6: a write_functions entry is a site via :write_function, its source argument 1 (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:136
     match (=) failed
     code:  assert [%{via: :write_function, op: :soft_delete, sources: [schema: @s]}] = in_function(sites, "w6")
     left:  [%{via: :write_function, op: :soft_delete, sources: [schema: AnchorFixtures.WriteSitesTest.S]}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:139: (test)

.......
```

### WSI-DYNVAR

a call on a module variable is not a dynamic call (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W7: a write on a module held in a variable is no site, and is a dynamic call (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:143
     match (=) failed
     code:  assert [%{what: "a call of insert/1 on a module held in a variable"}] =
              facts.functions[{@w, :w7, 2}].dynamic
     left:  [%{what: "a call of insert/1 on a module held in a variable"}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:152: (test)

........
```

### WSI-BEHAVIOUR

@behaviour Ecto.Repo does not make a repo (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `17 tests, 8 failures`.

```

  1) test repos/2 a module declaring @behaviour Ecto.Repo is a repo, and so is each listed one (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:166
     Assertion with == failed
     code:  assert WriteSites.repos(graph, %Config{}) == MapSet.new([@declared])
     left:  MapSet.new([])
     right: MapSet.new([AnchorFixtures.WriteSitesTest.DeclaredRepo])
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:174: (test)

.......


  2) test E3: a from/2 query on a table is the table, keyed to its schema (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:91
     no write in e3
     code: assert %{sources: [{:table, "threads"}], unresolved: nil} = site(a, :e3)
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:92: (test)




  3) test E1: a struct of a real schema is the schema, and its table is read from Core (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:74
     no write in e1
     code: assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e1)
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:78: (test)




  4) test E4: a real Multi pipeline's scope keys are exactly the written schemas (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:109
     match (=) failed
     code:  assert [scope] = Enum.filter(a.scopes, &(&1.mfa == {@e, :e4, 0}))
     left:  [scope]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:110: (test)




  5) test E2: a from/2 query on a schema is the schema, written or piped (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:86
     no write in e2
     code: assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e2)
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:87: (test)




  6) test E1: @behaviour Ecto.Repo makes the module a repo (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:82
     Assertion with == failed
     code:  assert a.repos == [@repo]
     left:  []
     right: [AnchorFixtures.RealEctoTest.Repo]
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:83: (test)




  7) test E5: a query built on a schema by Ecto.Query's builders is the schema (rule 6) (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:96
     no write in e5
     code: assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e5)
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:99: (test)




  8) test E6: a query call's literal argument is never the table; an unknown query stays unknown (Anchor.Domain.Aggregates.RealEctoTest)
     test/anchor/domain/aggregates/real_ecto_test.exs:102
     no write in e6
     code: assert %{sources: [], unresolved: seen} = site(a, :e6)
     stacktrace:
       test/anchor/domain/aggregates/real_ecto_test.exs:104: (test)
```

### WSI-NOREPO

no repo is not reported (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W9: no repo at all is {:error, :no_repo} (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:160
     Assertion with == failed
     code:  assert WriteSites.find(graph, %Config{repos: []}) == {:error, :no_repo}
     left:  {:ok,
             [
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :step, 2},
                 line: 60,
                 op: :update,
                 via: :run_callback_repo,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 48,
                 op: :insert,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 49,
                 op: :update,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 50,
                 op: :delete,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 51,
                 op: :insert_or_update,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 52,
                 op: :insert_all,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 53,
                 op: :update_all,
                 via: :multi,
                 sources: [schema: AnchorFixtures.WriteSitesTest.S],
                 unresolved: nil,
                 scopes: [],
                 run_callback?: false
               },
               %Anchor.Domain.Aggregates.WriteSite{
                 mfa: {AnchorFixtures.WriteSitesTest.W, :w3, 1},
                 line: 54,
                 op: :delete_all,
                 ...
               },
               ...
             ]}
     right: {:error, :no_repo}
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:161: (test)

.
```

### WSI-HELPER

a project function on a Multi trace is ignored (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

```

  1) test build/3 S3: a Multi traced through a helper that adds a step (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:149
     match (=) failed
     code:  assert %Scope{kind: :multi, complete?: true} = scope = one(a, :s3)
     left:  %Anchor.Domain.Aggregates.Scope{kind: :multi, complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s3, 0},
              ordinal: 1,
              line: 70,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s3, 0}, 70}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:150: (test)

........
```

### WSI-TXFN

transaction_functions calls are not scopes (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

```



  1) test build/3 S5: a transaction_functions call is a scope (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:159
     expected one scope in s5, got []
     code: assert %Scope{kind: :transaction_function, complete?: true} = scope = one(a, :s5)
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:160: (test)

.................
```

### WSI-APPLYGAP

a call of a fun value is not a gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

```

  1) test build/3 S6: a call of a fun parameter makes the scope incomplete, at its line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:164
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s6, 1}, line}]} = one(a, :s6)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s6, 1}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s6, 1},
              ordinal: 1,
              line: 81,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s6, 1},
                  line: 81,
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
       test/anchor/domain/aggregates/scopes_test.exs:165: (test)
```

### WSI-ORDINAL

a scope's ordinal is its line (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 2 failures`.

```

  1) test build/3 S11: two scopes in one function are ordinals 1 and 2 in Core order (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:194
     match (=) failed
     code:  assert [%Scope{ordinal: 1} = first, %Scope{ordinal: 2} = second] =
              a |> scopes(:s11) |> Enum.sort_by(& &1.ordinal)
     left:  [
              %Anchor.Domain.Aggregates.Scope{ordinal: 1} = first,
              %Anchor.Domain.Aggregates.Scope{ordinal: 2} = second
            ]
     right: [
              %Anchor.Domain.Aggregates.Scope{
                mfa: {AnchorFixtures.ScopesTest.X, :s11, 0},
                ordinal: 92,
                line: 92,
                kind: :fun,
                writes: [
                  %Anchor.Domain.Aggregates.WriteSite{
                    mfa: {AnchorFixtures.ScopesTest.X, :s11, 0},
                    line: 92,
                    op: :insert,
                    via: :repo,
                    sources: [schema: AnchorFixtures.ScopesTest.S],
                    unresolved: nil,
                    scopes: ~c"\\",
                    run_callback?: false
                  }
                ],
                keys: MapSet.new([
                  schema: AnchorFixtures.ScopesTest.S
                ]),
                complete?: true,
                gaps: []
              },
              %Anchor.Domain.Aggregates.Scope{
                mfa: {AnchorFixtures.ScopesTest.X, :s11, 0},
                ordinal: 93,
                line: 93,
                kind: :fun,
                writes: [
                  %Anchor.Domain.Aggregates.WriteSite{
                    mfa: {AnchorFixtures.ScopesTest.X, :s11, 0},
                    line: 93,
                    op: :insert,
                    via: :repo,
                    sources: [schema: AnchorFixtures.ScopesTest.T],
                    unresolved: nil,
                    scopes: ~c"]",
                    run_callback?: false
                  }
                ],
                keys: MapSet.new([
                  schema: AnchorFixtures.ScopesTest.T
                ]),
                complete?: true,
                gaps: []
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:195: (test)

..


  2) test build/3 S11: ordinals do not move when lines do (positive control: the lines do) (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:202
     Assertion with == failed
     code:  assert Enum.map(after_move, &{&1.ordinal, &1.keys}) == Enum.map(before, &{&1.ordinal, &1.keys})
     left:  [
              {95,
               MapSet.new([schema: AnchorFixtures.ScopesTest.S])},
              {96,
               MapSet.new([schema: AnchorFixtures.ScopesTest.T])}
            ]
     right: [
              {92,
               MapSet.new([schema: AnchorFixtures.ScopesTest.S])},
              {93,
               MapSet.new([schema: AnchorFixtures.ScopesTest.T])}
            ]
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:213: (test)

..........
```

### WSI-UNTRACED

a transaction given an untraceable value has no gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

```

  1) test build/3 S10: a Multi parameter with nothing to trace is incomplete at the call (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:189
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s10, 1}, line}]} = one(a, :s10)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, :s10, 1}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s10, 1},
              ordinal: 1,
              line: 89,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:190: (test)
```

### SC-CLOSURE

the closure stops following calls (`lib/anchor/domain/aggregates/scopes.ex`). Result: `28 tests, 4 failures`.

```

  1) test build/3 S8: recursion terminates, and the keys are the union (Anchor.Domain.Aggregates.ScopesTest)
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

.........


  2) test N1: a function's own writes and its callees' outside a transaction (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:60
     Assertion with == failed
     code:  assert nontx(a, :n1f).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:61: (test)




  3) test N3: a callee also called outside is not always in one; the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:73
     Assertion with == failed
     code:  assert nontx(a, :n3h).keys == keys([@t])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:76: (test)

.


  4) test N4: recursion terminates at the fixpoint (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:80
     Assertion with == failed
     code:  assert nontx(a, :n4a, 1).keys == keys([@s, @t])
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([
              schema: AnchorFixtures.NonTransactionalTest.S,
              schema: AnchorFixtures.NonTransactionalTest.T
            ])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:81: (test)

..........
```

### SC-CAPTURES

a captured transaction body is not followed (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 1 failure`.

```

  1) test build/3 S2: a captured function is the scope's body (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:144
     Assertion with == failed
     code:  assert scope.keys == keys([@u])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.U])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:146: (test)

..........
```

### SC-UNRESOLVEDGAP

an unresolved write is not a gap (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 1 failure`.

```

  1) test build/3 S7: an unresolved write in the closure makes the scope incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:170
     match (=) failed
     code:  assert %Scope{complete?: false, gaps: [unresolved_write: site]} = one(a, :s7)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: false, gaps: [unresolved_write: site]}
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s7, 1},
              ordinal: 1,
              line: 83,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s7, 1},
                  line: 83,
                  op: :insert,
                  via: :repo,
                  sources: [],
                  unresolved: "parameter 1 of AnchorFixtures.ScopesTest.X.s7/1 has no @spec and no project caller",
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:171: (test)

...........
```

### SC-BODY

a scope holds every write of its function (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 1 failure`.

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

...............
```

### NT-OUTSIDE

writes inside a transaction count as non-transactional (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `10 tests, 2 failures`.

```

  1) test N3: a callee also called outside is not always in one; the outside caller has its keys (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:73
     Assertion with == failed
     code:  assert nontx(a, :n3f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:77: (test)

.


  2) test N2: a callee called only inside a transaction adds nothing and is always in one (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:66
     Assertion with == failed
     code:  assert nontx(a, :n2f).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:69: (test)

.
```

### NT-MULTI

a Multi step counts as non-transactional (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `10 tests, 1 failure`.

```

  1) test a Multi step is never a non-transactional write (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:97
     Assertion with == failed
     code:  assert nontx(a, :n5).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:98: (test)

.
```

### IN-INCOMPLETE

incomplete scopes add no edges (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F2: an incomplete scope's resolved keys join one component (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:57
     Assertion with == failed
     code:  assert Inference.components(analysis) == [MapSet.new(schema: App.S, schema: App.X)]
     left:  [MapSet.new([schema: App.S]), MapSet.new([schema: App.X])]
     right: [MapSet.new([schema: App.S, schema: App.X])]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:59: (test)

.......
```

### IN-ROOT

the root ignores how many complete scopes hold it (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 2 failures`.

```

  1) test F3: the proposal names the root schema, its schemas and evidence (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:67
     Assertion with == failed
     code:  assert stu.name == "App.T"
     left:  "App.S"
     right: "App.T"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:70: (test)

.......


  2) test F3: the root is the key in the most complete scopes, and names the proposal (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:62
     match (=) failed
     code:  assert [%{name: "App.T", root: {:schema, App.T}}, %{name: "App.V"}, %{name: "App.W"}] =
              Inference.proposed_declarations(f1())
     left:  [%{name: "App.T", root: {:schema, App.T}}, %{name: "App.V"}, %{name: "App.W"}]
     right: [
              %{
                name: "App.S",
                root: {:schema, App.S},
                schemas: [App.S, App.T, App.U],
                tables: [],
                evidence: %{
                  scopes: [
                    {{App.Tx, :run, 0}, 1},
                    {{App.Tx, :run, 0}, 2}
                  ],
                  writes: 0
                }
              },
              %{
                name: "App.V",
                root: {:schema, App.V},
                schemas: [App.V],
                tables: [],
                evidence: %{
                  scopes: [{{App.Tx, :run, 0}, 3}],
                  writes: 0
                }
              },
              %{
                name: "App.W",
                root: {:schema, App.W},
                schemas: [App.W],
                tables: [],
                evidence: %{scopes: [], writes: 0}
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:63: (test)

.
```

### IN-YAML

render_yaml omits declare: (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 2 failures`.

```

  1) test F5: render_yaml parses under Aggregates.Config.parse/1 to the proposal (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:83
     match (=) failed
     code:  assert {:ok, %Config{declare: declare}} = Config.parse(section)
     left:  {:ok, %Anchor.Domain.Aggregates.Config{declare: declare}}
     right: {:error,
             {:invalid_config,
              "aggregates must be a mapping, got: [%{\"name\" => \"App.S\", \"schemas\" => [\"App.S\"], \"tables\" => [\"audit_log\"]}]. Fix: write aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:90: (test)

.........


  2) test F8: a proposal with unresolved writes beside it says so in the YAML (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:118
     match (=) failed
     code:  assert {:ok, %Config{declare: [_one]}} = Config.parse(section)
     left:  {:ok, %Anchor.Domain.Aggregates.Config{declare: [_one]}}
     right: {:error,
             {:invalid_config,
              "aggregates must be a mapping, got: [%{\"name\" => \"App.S\", \"schemas\" => [\"App.S\"], \"tables\" => []}]. Fix: write aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:127: (test)
```

### IN-CAMEL

a table root is not camelized (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F6: a table-only component is named by the camelized table (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:139
     match (=) failed
     code:  assert [%{name: "AuditLog", tables: ["audit_log"], schemas: []}] =
              Inference.proposed_declarations(analysis([], table: "audit_log"))
     left:  [%{name: "AuditLog", tables: ["audit_log"], schemas: []}]
     right: [
              %{
                name: "audit_log",
                root: {:table, "audit_log"},
                schemas: [],
                tables: ["audit_log"],
                evidence: %{scopes: [], writes: 0}
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:140: (test)

.........
```

### IN-OUTSIDE

non-transactional writes are no vertices (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 3 failures`.

```

  1) test F1: components of the co-write hypergraph (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:49
     Assertion with == failed
     code:  assert Inference.components(f1()) == [
              MapSet.new(schema: App.S, schema: App.T, schema: App.U),
              MapSet.new(schema: App.V),
              MapSet.new(schema: App.W)
            ]
     left:  [
              MapSet.new([
                schema: App.S,
                schema: App.T,
                schema: App.U
              ]),
              MapSet.new([schema: App.V])
            ]
     right: [
              MapSet.new([
                schema: App.S,
                schema: App.T,
                schema: App.U
              ]),
              MapSet.new([schema: App.V]),
              MapSet.new([schema: App.W])
            ]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:50: (test)

.......


  2) test F6: a table-only component is named by the camelized table (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:139
     match (=) failed
     code:  assert [%{name: "AuditLog", tables: ["audit_log"], schemas: []}] =
              Inference.proposed_declarations(analysis([], table: "audit_log"))
     left:  [%{name: "AuditLog", tables: ["audit_log"], schemas: []}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:140: (test)




  3) test F3: the root is the key in the most complete scopes, and names the proposal (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:62
     match (=) failed
     code:  assert [%{name: "App.T", root: {:schema, App.T}}, %{name: "App.V"}, %{name: "App.W"}] =
              Inference.proposed_declarations(f1())
     left:  [%{name: "App.T", root: {:schema, App.T}}, %{name: "App.V"}, %{name: "App.W"}]
     right: [
              %{
                name: "App.T",
                root: {:schema, App.T},
                schemas: [App.S, App.T, App.U],
                tables: [],
                evidence: %{
                  scopes: [
                    {{App.Tx, :run, 0}, 1},
                    {{App.Tx, :run, 0}, 2}
                  ],
                  writes: 0
                }
              },
              %{
                name: "App.V",
                root: {:schema, App.V},
                schemas: [App.V],
                tables: [],
                evidence: %{
                  scopes: [{{App.Tx, :run, 0}, 3}],
                  writes: 0
                }
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:63: (test)
```

### RL-SELECT

the selector is ignored (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `9 tests, 2 failures`.

```



  1) test check/2 V3: a selector that matches no write checks nothing, fail-closed (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:134
     match (=) failed
     code:  assert [violation] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:136: (test)

......


  2) test check/2 V1: a finding outside the selector is not reported (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:108
     Assertion with == failed
     code:  assert AggregateWriteSources.check(model(analysis), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "Repo.insert",
                message: "Repo.insert in Other.Thing.save/1 writes a value Anchor cannot trace to a schema or table (parameter 1 of App.Store.save/1 has no @spec and no project caller). Fix: pass a struct, changeset or schema the call can see; add @spec with Schema.t() for the parameter; or list a wrapper under aggregates.write_functions.",
                filename: ".anchor.yml",
                kind: :rule,
                key: "writes|Other.Thing.save/1|unresolved insert parameter 1 of App.Store.save/1 has no @spec and no project caller",
                rule_id: "writes",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 30,
                trigger: "transaction 1",
                message: "transaction 1 in Other.Thing.run/1 reaches 1 call(s) Anchor cannot resolve (first: App.Store.run/1 line 31), so its write set is incomplete. Fix: call a named function instead of a variable, or declare the behaviour so the callee is known; trace each write to a schema or table.",
                filename: ".anchor.yml",
                kind: :rule,
                key: "writes|Other.Thing.run/1|incomplete 1",
                rule_id: "writes",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:116: (test)

.
```

### RL-KEYLINE

the unresolved key carries the line (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `9 tests, 1 failure`.

```

  1) test check/2 V1: one unresolved write and one incomplete scope, keyed without lines, ending in Fix: (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:80
     Assertion with == failed
     code:  assert unresolved.key ==
              "writes|App.Store.save/1|unresolved insert parameter 1 of App.Store.save/1 has no " <>
                "@spec and no project caller"
     left:  "writes|App.Store.save/1|unresolved insert parameter 1 of App.Store.save/1 has no @spec and no project caller 12"
     right: "writes|App.Store.save/1|unresolved insert parameter 1 of App.Store.save/1 has no @spec and no project caller"
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:88: (test)

...
```

### RL-NOREPO

no repo reports nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `9 tests, 2 failures`.

```

  1) test check/2 V2: no repo is one fail-closed violation on .anchor.yml (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:119
     match (=) failed
     code:  assert [violation] = AggregateWriteSources.check(model(%Analysis{no_repo?: true}), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:120: (test)

...


  2) test check/2 V2: no analysis at all reads as no repo, never as clean (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:127
     match (=) failed
     code:  assert [%{kind: :fail_closed, message: message}] = AggregateWriteSources.check(model(nil), @rule)
     left:  [%{kind: :fail_closed, message: message}]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:128: (test)

..
```

### RL-NONE

zero writes in the selection reports nothing (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `9 tests, 1 failure`.

```

  1) test check/2 V3: a selector that matches no write checks nothing, fail-closed (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:134
     match (=) failed
     code:  assert [violation] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [violation]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:136: (test)

.
```

### RL-INCOMPLETE

incomplete scopes are not reported (`lib/anchor/domain/graph_rules/aggregate_write_sources.ex`). Result: `11 tests, 2 failures`.

```

  1) test check/2 V1: one unresolved write and one incomplete scope, keyed without lines, ending in Fix: (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:80
     match (=) failed
     code:  assert [unresolved, incomplete] = AggregateWriteSources.check(model(analysis), @rule)
     left:  [unresolved, incomplete]
     right: [
              %Anchor.Domain.Violation{
                line: 12,
                trigger: "Repo.insert",
                message: "Repo.insert in App.Store.save/1 writes a value Anchor cannot trace to a schema or table (parameter 1 of App.Store.save/1 has no @spec and no project caller). Fix: pass a struct, changeset or schema the call can see; add @spec with Schema.t() for the parameter; or list a wrapper under aggregates.write_functions.",
                filename: "lib/app/store.ex",
                kind: :rule,
                key: "writes|App.Store.save/1|unresolved insert parameter 1 of App.Store.save/1 has no @spec and no project caller",
                rule_id: "writes",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:83: (test)

......


  2) test I1: the violating module gives exactly the unresolved write and the incomplete transaction (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:78
     match (=) failed
     code:  assert [save, run] = Enum.sort_by(report.findings, & &1.line)
     left:  [save, run]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "aggregate_write_sources",
                type: :aggregate_write_sources,
                label: "rule 1 (id: \"aggregate_write_sources\", aggregate_write_sources)",
                enforcement: :enforce,
                key: "aggregate_write_sources|Aws.Violating.save/1|unresolved insert parameter 1 of Aws.Violating.save/1 has no @spec and no project caller",
                file: "lib/aws/violating.ex",
                line: 5,
                message: "Repo.insert in Aws.Violating.save/1 writes a value Anchor cannot trace to a schema or table (parameter 1 of Aws.Violating.save/1 has no @spec and no project caller). Fix: pass a struct, changeset or schema the call can see; add @spec with Schema.t() for the parameter; or list a wrapper under aggregates.write_functions."
              }
            ]
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:84: (test)

.
```

### CF-NEEDS

a rule needing the aggregates: section loads without one (`lib/anchor/domain/config.ex`). Result: `9 tests, 1 failure`.

```

  1) test V5: loading a rule with no aggregates: section is refused, the Fix naming the section (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:160
     match (=) failed
     code:  assert {:error, {:invalid_rule, message}} =
              Config.parse_config(%{"rules" => [@rule_yaml], "architecture" => @architecture})
     left:  {:error, {:invalid_rule, message}}
     right: %Anchor.Config{
              rules: [
                %{
                  id: "writes",
                  index: 1,
                  match: :reference,
                  type: :aggregate_write_sources,
                  mode: nil,
                  pattern: nil,
                  recursive: false,
                  bucket: nil,
                  paths: ["lib/**"],
                  min_files: 1,
                  min_modules: nil,
                  enforcement: :enforce,
                  baseline: nil,
                  uses_module: nil,
                  forbidden_modules: [],
                  forbidden_functions: [],
                  allowed_callers: [],
                  required_modules: [],
                  forbidden_patterns: [],
                  allowed_functions: [],
                  pure_patterns: [],
                  owned_namespaces: nil,
                  max_lines: nil,
                  same_context: false,
                  context_depth: 2
                }
              ],
              path: nil,
              architecture: %Anchor.Domain.Architecture{
                context_depth: 2,
                buckets: [
                  %Anchor.Domain.Architecture.Bucket{
                    name: "domain",
                    role: :domain,
                    selectors: [paths: ["lib/**"]],
                    min_modules: 1,
                    infer: true
                  }
                ],
                calls: %{"domain" => [{"domain", :any}]},
                interface_buckets: [],
                interface_exports: [],
                effects: [],
                roots: [],
                extract_pure_regions_from: [:managers, :framework]
              },
              aggregates: nil,
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:161: (test)

.......
```

### RS-NEEDS

aggregate_write_sources does not need the section (`lib/anchor/domain/rule_schema.ex`). Result: `37 tests, 2 failures`.

```



  1) test V5: loading a rule beside declare: none is refused, the Fix naming both ways out (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:172
     match (=) failed
     code:  assert {:error, {:invalid_rule, message}} =
              Config.parse_config(%{
                "rules" => [@rule_yaml],
                "architecture" => @architecture,
                "aggregates" => %{"declare" => "none", "reason" => "no database"}
              })
     left:  {:error, {:invalid_rule, message}}
     right: %Anchor.Config{
              rules: [
                %{
                  id: "writes",
                  index: 1,
                  match: :reference,
                  type: :aggregate_write_sources,
                  mode: nil,
                  pattern: nil,
                  recursive: false,
                  min_files: 1,
                  bucket: nil,
                  min_modules: nil,
                  enforcement: :enforce,
                  baseline: nil,
                  paths: ["lib/**"],
                  uses_module: nil,
                  forbidden_modules: [],
                  forbidden_functions: [],
                  allowed_callers: [],
                  required_modules: [],
                  forbidden_patterns: [],
                  allowed_functions: [],
                  pure_patterns: [],
                  owned_namespaces: nil,
                  max_lines: nil,
                  same_context: false,
                  context_depth: 2
                }
              ],
              path: nil,
              architecture: %Anchor.Domain.Architecture{
                context_depth: 2,
                buckets: [
                  %Anchor.Domain.Architecture.Bucket{
                    name: "domain",
                    role: :domain,
                    selectors: [paths: ["lib/**"]],
                    min_modules: 1,
                    infer: true
                  }
                ],
                calls: %{"domain" => [{"domain", :any}]},
                interface_buckets: [],
                interface_exports: [],
                effects: [],
                roots: [],
                extract_pure_regions_from: [:managers, :framework]
              },
              aggregates: %Anchor.Domain.Aggregates.Config{
                declare: [],
                none: "no database",
                repos: [],
                write_functions: [],
                transaction_functions: []
              },
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:173: (test)

.......


  2) test V5: loading a rule with no aggregates: section is refused, the Fix naming the section (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:160
     match (=) failed
     code:  assert {:error, {:invalid_rule, message}} =
              Config.parse_config(%{"rules" => [@rule_yaml], "architecture" => @architecture})
     left:  {:error, {:invalid_rule, message}}
     right: %Anchor.Config{
              rules: [
                %{
                  id: "writes",
                  index: 1,
                  match: :reference,
                  type: :aggregate_write_sources,
                  mode: nil,
                  pattern: nil,
                  recursive: false,
                  min_files: 1,
                  bucket: nil,
                  min_modules: nil,
                  enforcement: :enforce,
                  baseline: nil,
                  paths: ["lib/**"],
                  uses_module: nil,
                  forbidden_modules: [],
                  forbidden_functions: [],
                  allowed_callers: [],
                  required_modules: [],
                  forbidden_patterns: [],
                  allowed_functions: [],
                  pure_patterns: [],
                  owned_namespaces: nil,
                  max_lines: nil,
                  same_context: false,
                  context_depth: 2
                }
              ],
              path: nil,
              architecture: %Anchor.Domain.Architecture{
                context_depth: 2,
                buckets: [
                  %Anchor.Domain.Architecture.Bucket{
                    name: "domain",
                    role: :domain,
                    selectors: [paths: ["lib/**"]],
                    min_modules: 1,
                    infer: true
                  }
                ],
                calls: %{"domain" => [{"domain", :any}]},
                interface_buckets: [],
                interface_exports: [],
                effects: [],
                roots: [],
                extract_pure_regions_from: [:managers, :framework]
              },
              aggregates: nil,
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:161: (test)

............................
```

### RS-ENGINE

aggregate_write_sources runs on the ast engine (`lib/anchor/domain/rule_schema.ex`). Result: `45 tests, 4 failures`.

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :aggregate_write_sources,
             :context_acyclic, :layering]
     right: [:aggregate_declarations, :context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

.........................


  2) test the positive case the README lists exactly the keys each rule type accepts, its relation and engine (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:211
     README engine for aggregate_write_sources
     code: for type <- RuleSchema.rule_types() do
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:224: anonymous fn/2 in Anchor.Domain.RuleSchemaTest."test the positive case the README lists exactly the keys each rule type accepts, its relation and engine"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/rule_schema_test.exs:220: (test)

....


  3) test engine/1 every shipped type has an engine; the graph types are the graph rule modules' (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:241
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:graph) ==
              Anchor.Domain.GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort()
     left:  [:aggregate_declarations, :context_acyclic, :layering]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:249: (test)

.


  4) test the positive case the ast types are exactly the rule types of Anchor.checks/0 (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:203
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:ast) == check_types
     left:  [:aggregate_write_sources, :alphabetized_functions,
             :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention,
             :struct_owned_by_module]
     right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarded_pure_expression,
             :no_discarding_arrow_in_with, :no_forwarding_function,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention,
             :struct_owned_by_module]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:206: (test)

.
```

### GR-REG

aggregate_write_sources is not registered (`lib/anchor/domain/graph_rules.ex`). Result: `14 tests, 2 failures`.

```

  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:aggregate_declarations, :context_acyclic, :layering]
     right: [:aggregate_declarations, :aggregate_write_sources,
             :context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

.......


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
                outside_root: 0,
                writes: %{
                  complete: 1,
                  incomplete: 1,
                  resolved: 1,
                  unresolved: 1,
                  writes: 2,
                  scopes: 2
                },
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 0
            }
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:82: (test)
```

### MD-ANALYSIS

the model never builds the analysis (`lib/anchor/domain/model.ex`). Result: `2 tests, 2 failures`.

```



  1) test I1: the compliant canary gives no finding, and the summary counts its writes (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:67
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregate_write_sources/.anchor.yml",
                  line: nil,
                  message: "rule 1 (id: \"aggregate_write_sources\", aggregate_write_sources): no Ecto repo found: no module declares @behaviour Ecto.Repo and aggregates.repos is empty. Fix: list the repo under aggregates.repos."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 3,
                opaque: 0,
                apps: 1,
                rules: 1,
                outside_root: 0,
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:72: (test)




  2) test I1: the violating module gives exactly the unresolved write and the incomplete transaction (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:78
     match (=) failed
     code:  assert [save, run] = Enum.sort_by(report.findings, & &1.line)
     left:  [save, run]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregate_write_sources/.anchor.yml",
                line: nil,
                message: "rule 1 (id: \"aggregate_write_sources\", aggregate_write_sources): no Ecto repo found: no module declares @behaviour Ecto.Repo and aggregates.repos is empty. Fix: list the repo under aggregates.repos."
              }
            ]
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:84: (test)
```

### RP-WRITES

the summary omits the writes (`lib/anchor/domain/graph_report.ex`). Result: `6 tests, 3 failures`.

```



  1) test the write analysis's counts are in the summary and the JSON (Anchor.Domain.GraphReportAggregatesTest)
     test/anchor/domain/graph_report_aggregates_test.exs:42
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.GraphReport.writes_note/1

     The following arguments were given to Anchor.Domain.GraphReport.writes_note/1:

         # 1
         %{complete: 2, incomplete: 1, resolved: 5, writes: 7, unresolved: 2, scopes: 3}

     Attempted function clauses (showing 2 out of 2):

         defp writes_note(-nil-)
         defp writes_note(writes) when -writes == nil-

     code: assert GraphReport.summary(report) ==
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:224: Anchor.Domain.GraphReport.writes_note/1
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:218: Anchor.Domain.GraphReport.summary/1
       test/anchor/domain/graph_report_aggregates_test.exs:46: (test)

...


  2) test I1: the violating module gives exactly the unresolved write and the incomplete transaction (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:78
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.GraphReport.writes_note/1

     The following arguments were given to Anchor.Domain.GraphReport.writes_note/1:

         # 1
         %{complete: 1, incomplete: 1, resolved: 1, writes: 2, unresolved: 1, scopes: 2}

     Attempted function clauses (showing 2 out of 2):

         defp writes_note(-nil-)
         defp writes_note(writes) when -writes == nil-

     code: assert GraphReport.summary(report) =~
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:224: Anchor.Domain.GraphReport.writes_note/1
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:218: Anchor.Domain.GraphReport.summary/1
       test/anchor/integration/aggregate_write_sources_integration_test.exs:95: (test)




  3) test I1: the compliant canary gives no finding, and the summary counts its writes (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:67
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.GraphReport.writes_note/1

     The following arguments were given to Anchor.Domain.GraphReport.writes_note/1:

         # 1
         %{complete: 1, incomplete: 0, resolved: 1, writes: 1, unresolved: 0, scopes: 1}

     Attempted function clauses (showing 2 out of 2):

         defp writes_note(-nil-)
         defp writes_note(writes) when -writes == nil-

     code: assert GraphReport.summary(report) =~
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:224: Anchor.Domain.GraphReport.writes_note/1
       (anchor 0.1.0) lib/anchor/domain/graph_report.ex:218: Anchor.Domain.GraphReport.summary/1
       test/anchor/integration/aggregate_write_sources_integration_test.exs:74: (test)
```

### MG-WRITES

the manager does not count the writes (`lib/anchor/managers/graph.ex`). Result: `2 tests, 2 failures`.

```



  1) test I1: the violating module gives exactly the unresolved write and the incomplete transaction (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:78
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; writes: 2 found, 1 resolved, 1 unresolved; transactions: 2, 1 complete, 1 incomplete"
     left:  "anchor.graph: 4 modules in 1 apps, 1 rules, 2 violations (0 report-only, 0 baselined)"
     right: "; writes: 2 found, 1 resolved, 1 unresolved; transactions: 2, 1 complete, 1 incomplete"
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:95: (test)




  2) test I1: the compliant canary gives no finding, and the summary counts its writes (Anchor.Integration.AggregateWriteSourcesIntegrationTest)
     test/anchor/integration/aggregate_write_sources_integration_test.exs:67
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~
              "; writes: 1 found, 1 resolved, 0 unresolved; transactions: 1, 1 complete, 0 incomplete"
     left:  "anchor.graph: 3 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "; writes: 1 found, 1 resolved, 0 unresolved; transactions: 1, 1 complete, 0 incomplete"
     stacktrace:
       test/anchor/integration/aggregate_write_sources_integration_test.exs:74: (test)
```

### FL-NOREPO

the no-repo message loses its Fix (`lib/anchor/domain/failures.ex`). Result: `16 tests, 1 failure`.

```

  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:268
     aggregate_no_repo
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       test/anchor/domain/failures_graph_test.exs:271: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:269: (test)

...........
```

### FL-NONE

the checks-nothing message loses its Fix (`lib/anchor/domain/failures.ex`). Result: `16 tests, 1 failure`.

```

  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:268
     aggregate_writes_none
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       test/anchor/domain/failures_graph_test.exs:271: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:269: (test)

.............
```

### WSI-DELETEALL

delete_all is not a Repo write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 1 failure`.

```

  1) test find/2 W1: each Repo write name is a site via :repo, with its op and line (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:89
     Assertion with == failed
     code:  assert length(w1) == 11
     left:  10
     right: 11
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:91: (test)

......
```

### WSI-INSERT

insert is not a Repo write (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `10 tests, 3 failures`.

```



  1) test find/2 W1: each Repo write name is a site via :repo, with its op and line (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:89
     Assertion with == failed
     code:  assert length(w1) == 11
     left:  10
     right: 11
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:91: (test)

....


  2) test find/2 W4: a Multi.run callback's repo argument writes via :run_callback_repo (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:126
     match (=) failed
     code:  assert [%{via: :run_callback_repo, op: :insert, sources: [schema: @s]}] = in_function(sites, "w4")
     left:  [%{via: :run_callback_repo, op: :insert, sources: [schema: AnchorFixtures.WriteSitesTest.S]}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:127: (test)

...


  3) test find/2 W2: an alias, a pipe and an @repo attribute are all :repo sites (Anchor.Domain.Aggregates.WriteSitesTest)
     test/anchor/domain/aggregates/write_sites_test.exs:102
     Assertion with == failed
     code:  assert [:w2_alias, :w2_attribute, :w2_pipe] ==
              sites |> in_function("w2_") |> Enum.map(&elem(&1.mfa, 1)) |> Enum.sort()
     left:  [:w2_alias, :w2_attribute, :w2_pipe]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/write_sites_test.exs:103: (test)
```

### WS-SCHEMAMOD

a literal schema module is not its schema (rule 2) (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R2: a schema module is its schema (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:99
     match (=) failed
     code:  assert %{sources: [schema: @s], unresolved: nil} = site(sites, :r2)
     left:  %{sources: [schema: AnchorFixtures.WriteSourceTest.S], unresolved: nil}
     right: %Anchor.Domain.Aggregates.WriteSite{
              mfa: {AnchorFixtures.WriteSourceTest.X, :r2, 1},
              line: 35,
              op: :insert_all,
              via: :repo,
              sources: [],
              unresolved: "the atom AnchorFixtures.WriteSourceTest.S, not a schema",
              scopes: [],
              run_callback?: false
            }
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:100: (test)

........
```

### WS-NOCALLER

the no-caller reason loses its words (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R11: a parameter with no spec and no caller is unresolved, saying so (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:138
     Assertion with == failed
     code:  assert seen == "parameter 1 of #{inspect(@x)}.r11/1 has no @spec and no project caller"
     left:  "parameter 1 of AnchorFixtures.WriteSourceTest.X.r11/1 is unknown"
     right: "parameter 1 of AnchorFixtures.WriteSourceTest.X.r11/1 has no @spec and no project caller"
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:140: (test)

.......
```

### WS-SEEN

an unresolved call does not name what was seen (`lib/anchor/domain/aggregates/write_source.ex`). Result: `17 tests, 1 failure`.

```

  1) test resolve/3 (through WriteSites.find/2) R14: anything else is unresolved, naming what was seen and no line (Anchor.Domain.Aggregates.WriteSourceTest)
     test/anchor/domain/aggregates/write_source_test.exs:169
     Assertion with == failed
     code:  assert seen == "the result of Map.new/0"
     left:  "the result of a call (Map.new/0)"
     right: "the result of Map.new/0"
     stacktrace:
       test/anchor/domain/aggregates/write_source_test.exs:171: (test)

...........
```

### SC-REMOTE

a scope follows only callees in its own module (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 5 failures`.

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

.


  2) test build/3 S1: a fun scope holds its own writes and a callee's in another module (Anchor.Domain.Aggregates.ScopesTest)
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

...........


  3) test build/3 S3: a Multi traced through a helper that adds a step (Anchor.Domain.Aggregates.ScopesTest)
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




  4) test build/3 S8: recursion terminates, and the keys are the union (Anchor.Domain.Aggregates.ScopesTest)
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




  5) test build/3 S12: a capture passed to Enum is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:219
     Assertion with == failed
     code:  assert one(a, :s12).keys == keys([@s])
     left:  MapSet.new([])
     right: MapSet.new([schema: AnchorFixtures.ScopesTest.S])
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:220: (test)
```

### SC-INNER

a closure leaves out writes inside a callee's own transaction (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 1 failure`.

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
```

### SC-ENUMCAPTURE

a capture in a scope's body is not followed (`lib/anchor/domain/aggregates/scopes.ex`). Result: `18 tests, 1 failure`.

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

### WSI-DEPCALL

a call into a dependency is a dynamic-call gap (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 5 failures`.

```

  1) test build/3 S12: a capture passed to Enum is followed (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:219
     Expected truthy, got false
     code: assert one(a, :s12).complete?
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:221: (test)

..


  2) test build/3 S3: a Multi traced through a helper that adds a step (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:149
     match (=) failed
     code:  assert %Scope{kind: :multi, complete?: true} = scope = one(a, :s3)
     left:  %Anchor.Domain.Aggregates.Scope{kind: :multi, complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s3, 0},
              ordinal: 1,
              line: 70,
              kind: :multi,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Builder, :add_t,
                   1},
                  line: 46,
                  op: :insert,
                  via: :multi,
                  sources: [schema: AnchorFixtures.ScopesTest.T],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                },
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s3, 0},
                  line: 68,
                  op: :insert,
                  via: :multi,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [1],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([
                schema: AnchorFixtures.ScopesTest.S,
                schema: AnchorFixtures.ScopesTest.T
              ]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s3, 0}, 67}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:150: (test)

.....


  3) test raw SQL S14: raw SQL in s15 makes its scope incomplete, at the call's line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:241
     match (=) failed
     The following variables were pinned:
       name = :s15
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, ^name, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s15, 0},
              ordinal: 1,
              line: 105,
              kind: :multi,
              writes: [],
              keys: MapSet.new([]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s15, 0}, 103},
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.X, :s15, 0}, 104}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:246: (test)




  4) test build/3 S8: recursion terminates, and the keys are the union (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:175
     match (=) failed
     code:  assert %Scope{complete?: true} = scope = one(a, :s8)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s8, 0},
              ordinal: 1,
              line: 85,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Helper, :a, 1},
                  line: 39,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.S],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                },
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.Helper, :b, 1},
                  line: 41,
                  op: :insert,
                  via: :repo,
                  sources: [schema: AnchorFixtures.ScopesTest.T],
                  unresolved: nil,
                  scopes: [],
                  run_callback?: false
                }
              ],
              keys: MapSet.new([
                schema: AnchorFixtures.ScopesTest.S,
                schema: AnchorFixtures.ScopesTest.T
              ]),
              complete?: false,
              gaps: [
                {:dynamic_call,
                 {AnchorFixtures.ScopesTest.Helper, :a, 1}, 40}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:176: (test)

.


  5) test build/3 S13: a call into a dependency is not followed, and the scope stays complete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:224
     match (=) failed
     code:  assert %Scope{complete?: true, gaps: []} = scope = one(a, :s13)
     left:  %Anchor.Domain.Aggregates.Scope{complete?: true, gaps: []} = scope
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s13, 1},
              ordinal: 1,
              line: 98,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s13, 1},
                  line: 98,
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
                 {AnchorFixtures.ScopesTest.X, :s13, 1}, 98}
              ]
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:227: (test)

.
```

### AN-COUNTS

resolved is off by one (`lib/anchor/domain/aggregates/analysis.ex`). Result: `18 tests, 1 failure`.

```

  1) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:254
     Assertion with == failed
     code:  assert a.counts.resolved == a.counts.writes - 1
     left:  16
     right: 17
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:259: (test)

............
```

### AN-INCOMPLETE

incomplete counts the complete scopes (`lib/anchor/domain/aggregates/analysis.ex`). Result: `18 tests, 1 failure`.

```

  1) test counts: writes found, resolved, unresolved; scopes, complete, incomplete (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:254
     Assertion with == failed
     code:  assert a.counts.incomplete == Enum.count(a.scopes, &(not &1.complete?))
     left:  12
     right: 6
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:256: (test)

..............
```

### IN-EVIDENCEORDER

a proposal's evidence keeps the input order (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F4: reversed input gives identical output (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:76
     Assertion with == failed
     code:  assert Inference.proposed_declarations(reversed) == Inference.proposed_declarations(f1())
     left:  [
              %{
                name: "App.T",
                root: {:schema, App.T},
                tables: [],
                schemas: [App.S, App.T, App.U],
                evidence: %{
                  scopes: [
                    {{App.Tx, :run, 0}, 2},
                    {{App.Tx, :run, 0}, 1}
                  ],
                  writes: 0
                }
              },
              %{
                name: "App.V",
                root: {:schema, App.V},
                tables: [],
                schemas: [App.V],
                evidence: %{
                  scopes: [{{App.Tx, :run, 0}, 3}],
                  writes: 0
                }
              },
              %{
                name: "App.W",
                root: {:schema, App.W},
                tables: [],
                schemas: [App.W],
                evidence: %{scopes: [], writes: 0}
              }
            ]
     right: [
              %{
                name: "App.T",
                root: {:schema, App.T},
                tables: [],
                schemas: [App.S, App.T, App.U],
                evidence: %{
                  scopes: [
                    {{App.Tx, :run, 0}, 1},
                    {{App.Tx, :run, 0}, 2}
                  ],
                  writes: 0
                }
              },
              %{
                name: "App.V",
                root: {:schema, App.V},
                tables: [],
                schemas: [App.V],
                evidence: %{
                  scopes: [{{App.Tx, :run, 0}, 3}],
                  writes: 0
                }
              },
              %{
                name: "App.W",
                root: {:schema, App.W},
                tables: [],
                schemas: [App.W],
                evidence: %{scopes: [], writes: 0}
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:78: (test)

........
```

### IN-EMPTYKEYS

an empty-keys scope is matched as a filter (the bug 8c8c78b fixed) (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F7: a scope with no resolved key adds no edge and does not crash (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:132
     ** (MatchError) no match of right hand side value:

         []

     code: assert Inference.components(analysis) == [MapSet.new(schema: App.S)]
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/aggregates/inference.ex:45: anonymous fn/2 in Anchor.Domain.Aggregates.Inference.components/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/domain/aggregates/inference.ex:44: Anchor.Domain.Aggregates.Inference.components/1
       test/anchor/domain/aggregates/inference_test.exs:135: (test)

......
```

## DND-5659: `aggregates: declare: none`

| # | Mutation | Tests run | Result |
|---|---|---|---|
| CF-REASON | none without a reason is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 2 failures` (red) |
| CF-BLANK | a blank reason is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 1 failure` (red) |
| CF-ALONE | none beside repos and functions is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 3 failures` (red) |
| CF-EMPTY | an explicit declare: [] is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 1 failure` (red) |
| CF-STRAYREASON | a reason without none is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 2 failures` (red) |
| CF-NONEVALUE | none does not keep the given reason (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs`, `aggregates_none_integration_test.exs` | `42 tests, 3 failures` (red) |
| PS-SCHEMA | __schema__/1 does not make a module persist (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs`, `aggregates_none_integration_test.exs` | `42 tests, 2 failures` (red) |
| PS-BEHAVIOUR | @behaviour Ecto.Repo does not make a module persist (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-ATTR | @anchor_aggregate does not contradict none (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-REPOWRITE | a Repo write is not a persistence call (re-anchored twice: the first two forms were compile errors) (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-MULTI | Ecto.Multi is not a persistence module (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-ADAPTER | an Ecto adapter is not a persistence module (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-DYNAMIC | a dynamic call is read as a callee (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| PS-FIRST | the reason names the call with the highest line (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 4 failures` (red) |
| PS-ORDER | a call is the reason before a schema export (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `40 tests, 1 failure` (red) |
| IX-GATE | persists_under_none is made only without none (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `40 tests, 32 failures` (red) |
| IX-FIELD | the index does not keep none (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs`, `non_transactional_test.exs`, `aggregates_none_integration_test.exs` | `52 tests, 4 failures` (red) |
| IX-SITE | a persisting module's issue sits at an attribute site (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `40 tests, 5 failures` (red) |
| RL-NOTHING | none still reports checks-nothing (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs`, `aggregates_none_integration_test.exs` | `13 tests, 5 failures` (red) |
| RL-SELECT | a persisting module is reported whatever the selector (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `11 tests, 1 failure` (red) |
| RL-FIX | the message's Fix does not say to declare the aggregate (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs`, `aggregates_none_integration_test.exs` | `13 tests, 2 failures` (red) |
| MD-NONE | Model builds the write analysis under none (`lib/anchor/domain/model.ex`) | `non_transactional_test.exs` | `10 tests, 1 failure` (red) |
| IF-YAML | nothing written renders declare: [] (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| CF-NONEDEFAULT | a section without none has a none value (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `40 tests, 1 failure` (red) |

### CF-REASON

none without a reason is accepted (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 2 failures`.

```

  1) test parse/1, declare: none Z2: refused: none with a reason that is not a string (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "none",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

..........


  2) test parse/1, declare: none Z2: refused: none without a reason (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "none",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

........
```

### CF-BLANK

a blank reason is accepted (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 1 failure`.

```

  1) test parse/1, declare: none Z2: refused: none with an empty reason (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "  ",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

................
```

### CF-ALONE

none beside repos and functions is accepted (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 3 failures`.

```

  1) test parse/1, declare: none Z2: refused: none with write_functions (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "Anchor reads beams and YAML; it has no database",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

.....................


  2) test parse/1, declare: none Z2: refused: none with transaction_functions (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "Anchor reads beams and YAML; it has no database",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

...


  3) test parse/1, declare: none Z2: refused: none with repos (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "Anchor reads beams and YAML; it has no database",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

.........
```

### CF-EMPTY

an explicit declare: [] is accepted (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 1 failure`.

```

  1) test parse/1, declare: none Z2: refused: an empty declare list (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: nil,
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

......
```

### CF-STRAYREASON

a reason without none is accepted (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 2 failures`.

```

  1) test parse/1, declare: none Z2: refused: a reason with no declare (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: nil,
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

...


  2) test parse/1, declare: none Z2: refused: a reason without none (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:163
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
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:164: (test)

...............
```

### CF-NONEVALUE

none does not keep the given reason (`lib/anchor/domain/aggregates/config.ex`). Result: `42 tests, 3 failures`.

```

  1) test Anchor.Config.parse_config/1 Z1: an aggregates: declare: none section loads with its reason (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:178
     match (=) failed
     code:  assert %Config{aggregates: %AggregatesConfig{none: "no database"}} =
              Config.parse_config(%{
                "rules" => [],
                "aggregates" => %{"declare" => "none", "reason" => "no database"}
              })
     left:  %Anchor.Config{aggregates: %Anchor.Domain.Aggregates.Config{none: "no database"}}
     right: %Anchor.Config{
              rules: [],
              path: nil,
              architecture: nil,
              aggregates: %Anchor.Domain.Aggregates.Config{
                declare: [],
                none: "NO DATABASE",
                repos: [],
                write_functions: [],
                transaction_functions: []
              },
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:179: (test)

..


  2) test parse/1, declare: none Z1: none with a reason parses to a section with no declarations and that reason (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:125
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{none: @reason, declare: [], repos: []}} =
              AggregatesConfig.parse(%{"declare" => "none", "reason" => @reason})
     left:  {:ok,
             %Anchor.Domain.Aggregates.Config{
               none: "Anchor reads beams and YAML; it has no database",
               declare: [],
               repos: []
             }}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               none: "ANCHOR READS BEAMS AND YAML; IT HAS NO DATABASE",
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:126: (test)

....................................


  3) test Z6: none over a project with an Ecto schema fails, naming the schema module (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:74
     Assertion with =~ failed
     code:  assert finding.message =~
              "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but " <>
                ".anchor.yml says aggregates: declare: none (the canary persists nothing). " <>
                "Fix: declare the aggregate and remove declare: none"
     left:  "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (THE CANARY PERSISTS NOTHING). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
     right: "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (the canary persists nothing). Fix: declare the aggregate and remove declare: none"
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:89: (test)
```

### PS-SCHEMA

__schema__/1 does not make a module persist (`lib/anchor/domain/aggregates/persistence.ex`). Result: `42 tests, 2 failures`.

```

  1) test build/2 under declare: none N6: one issue per module: the schema export wins over a call (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:521
     match (=) failed
     code:  assert [%{subject: @s1, detail: "it exports __schema__/1 (an Ecto schema)"}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Multi.insert/3 (line 4)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:527: (test)

..........


  2) test build/2 under declare: none N2: a module exporting __schema__/1 persists, at its module (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:471
     match (=) failed
     code:  assert [
              %DeclarationIssue{
                kind: :persists_under_none,
                subject: @s1,
                aggregates: [],
                site: {:module, @s1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                aggregates: [],
                site: {:module, AnchorFixtures.Aggregates.IndexTest.S1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:474: (test)

..........................
```

### PS-BEHAVIOUR

@behaviour Ecto.Repo does not make a module persist (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N3: a module declaring @behaviour Ecto.Repo persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:485
     match (=) failed
     code:  assert [%{subject: @repo, detail: "it declares @behaviour Ecto.Repo"}] =
              persists(Index.build(none(), graph))
     left:  [%{subject: AnchorFixtures.Aggregates.IndexTest.Repo, detail: "it declares @behaviour Ecto.Repo"}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:489: (test)

................
```

### PS-ATTR

@anchor_aggregate does not contradict none (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N5: a module declaring @anchor_aggregate contradicts none (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:515
     match (=) failed
     code:  assert [%{subject: @x, detail: "it declares @anchor_aggregate"}] = persists(index)
     left:  [%{subject: AnchorFixtures.Aggregates.IndexTest.X, detail: "it declares @anchor_aggregate"}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:518: (test)

..
```

### PS-REPOWRITE

a Repo write is not a persistence call (re-anchored twice: the first two forms were compile errors) (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N4: a module making a Repo write persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

.
```

### PS-MULTI

Ecto.Multi is not a persistence module (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N4: a module making an Ecto.Multi step persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Multi.insert/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

..............
```

### PS-ADAPTER

an Ecto adapter is not a persistence module (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N4: a module making an Ecto adapter persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Adapters.SQL.query/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

.....................
```

### PS-DYNAMIC

a dynamic call is read as a callee (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N1: none over modules that persist nothing has no issue, and keeps the reason (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:452
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Aggregates.Persistence.call?/1

     The following arguments were given to Anchor.Domain.Aggregates.Persistence.call?/1:

         # 1
         {:dynamic, :insert, 2, :variable}

     Attempted function clauses (showing 1 out of 1):

         def call?(-{module, _name, _arity} = mfa-)

     code: index = Index.build(none(), graph)
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/aggregates/persistence.ex:50: Anchor.Domain.Aggregates.Persistence.call?/1
       (elixir 1.19.4) lib/enum.ex:4445: Enum.filter_list/2
       (anchor 0.1.0) lib/anchor/domain/aggregates/persistence.ex:67: Anchor.Domain.Aggregates.Persistence.first_calls/1
       (anchor 0.1.0) lib/anchor/domain/aggregates/persistence.ex:40: Anchor.Domain.Aggregates.Persistence.modules/1
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:391: Anchor.Domain.Aggregates.Index.none_issues/2
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:105: Anchor.Domain.Aggregates.Index.build/2
       test/anchor/domain/aggregates/index_test.exs:465: (test)

......
```

### PS-FIRST

the reason names the call with the highest line (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 4 failures`.

```

  1) test build/2 under declare: none N4: a module making an Ecto adapter persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Adapters.SQL.query/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Adapters.SQL.query/3 (line 9)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

.......................


  2) test build/2 under declare: none N4: a module making a Repo write persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 9)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

........


  3) test build/2 under declare: none N4: a module making Ecto.Repo itself persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Repo.all/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Repo.all/2 (line 9)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




  4) test build/2 under declare: none N4: a module making an Ecto.Multi step persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Multi.insert/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Multi.insert/3 (line 9)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

....
```

### PS-ORDER

a call is the reason before a schema export (`lib/anchor/domain/aggregates/persistence.ex`). Result: `40 tests, 1 failure`.

```

  1) test build/2 under declare: none N6: one issue per module: the schema export wins over a call (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:521
     match (=) failed
     code:  assert [%{subject: @s1, detail: "it exports __schema__/1 (an Ecto schema)"}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Multi.insert/3 (line 4)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:527: (test)
```

### IX-GATE

persists_under_none is made only without none (`lib/anchor/domain/aggregates/index.ex`). Result: `40 tests, 32 failures`.

```



  1) test build/2 I6: a schema naming no project module is unknown_schema (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:265
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :unknown_schema, subject: Nope, aggregates: ["A"]}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_schema,
                subject: Nope,
                aggregates: ["A"]
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_schema,
                subject: Nope,
                site: :config,
                aggregates: ["A"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:268: (test)




  2) test build/2 I8: an owner naming no project module is unknown_owner (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:287
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :unknown_owner, subject: Ghost, aggregates: ["A"]}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_owner,
                subject: Ghost,
                aggregates: ["A"]
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_owner,
                subject: Ghost,
                site: :config,
                aggregates: ["A"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:294: (test)




  3) test build/2 I10: malformed attribute (an Erlang atom name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "name must be a module-name atom, got: :a"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)




  4) test build/2 under declare: none N5: a module declaring @anchor_aggregate contradicts none (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:515
     match (=) failed
     code:  assert [%{subject: @x, detail: "it declares @anchor_aggregate"}] = persists(index)
     left:  [%{subject: AnchorFixtures.Aggregates.IndexTest.X, detail: "it declares @anchor_aggregate"}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:518: (test)




  5) test build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:165
     match (=) failed
     code:  assert [
              %DeclarationIssue{kind: :claimed_twice, subject: @s1, aggregates: ["A", "B"], site: :config},
              %DeclarationIssue{
                kind: :claimed_twice,
                subject: @s1,
                aggregates: ["A", "B"],
                site: {:attribute, @x, "lib/x.ex", 1}
              }
            ] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                aggregates: ["A", "B"],
                site: :config
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                aggregates: ["A", "B"],
                site: {:attribute, AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex", 1}
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: :config,
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:170: (test)




  6) test build/2 I10: malformed attribute (no name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it has no name"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)

.


  7) test build/2 I10: malformed attribute (owner not a boolean) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "owner must be true or false, got: :yes"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)




  8) test build/2 I10 positive control: the same attribute well formed declares S1 (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:353
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:360: (test)

.


  9) test build/2 under declare: none N6: one issue per module: the schema export wins over a call (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:521
     match (=) failed
     code:  assert [%{subject: @s1, detail: "it exports __schema__/1 (an Ecto schema)"}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:527: (test)




 10) test build/2 I12: positive control: I6-I9 with the names corrected find nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:305
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S2,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S2,
                 "lib/s2.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:314: (test)

.


 11) test build/2 under declare: none N4: a module making Ecto.Repo itself persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Repo.all/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




 12) test build/2 under declare: none N4: a module making an Ecto adapter persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Adapters.SQL.query/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




 13) test build/2 I3: an owner: false attribute adds its schema and no owner (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:152
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S4,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S4,
                 "lib/s4.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:162: (test)




 14) test build/2 I10: malformed attribute (a key given twice) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "a key is given twice"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)




 15) test build/2 under declare: none N2: a module exporting __schema__/1 persists, at its module (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:471
     match (=) failed
     code:  assert [
              %DeclarationIssue{
                kind: :persists_under_none,
                subject: @s1,
                aggregates: [],
                site: {:module, @s1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                aggregates: [],
                site: {:module, AnchorFixtures.Aggregates.IndexTest.S1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:474: (test)




 16) test build/2 an attribute set twice is malformed (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:366
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, detail: detail}] = Index.build(nil, graph).issues
     left:  [%Anchor.Domain.Aggregates.DeclarationIssue{kind: :malformed_attribute, detail: detail}]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it is set more than once; a module declares one aggregate"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:375: (test)




 17) test build/2 under declare: none N4: a module making an Ecto.Multi step persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Multi.insert/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




 18) test build/2 I2: a config and an attribute declaration of one name merge (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:134
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S3,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S3,
                 "lib/s3.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Store,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Store,
                 "lib/store.ex", 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:149: (test)




 19) test build/2 a schema naming a module the graph could not build is not also unknown (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:272
     Assertion with == failed
     code:  assert Index.build(config([{"A", [schemas: [Nope], owners: [Nope]]}]), graph).issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:279: (test)




 20) test build/2 under declare: none N7: without none, the same modules are not persists_under_none (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:531
     Assertion with == failed
     code:  assert persists(Index.build(nil, graph)) == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Multi.insert/3 (line 4)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:537: (test)




 21) test build/2 I10: malformed attribute (an unknown key) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "unknown key(s) :extra"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)

..


 22) test build/2 I1: a config aggregate maps its schemas and their tables (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:123
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S2,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S2,
                 "lib/s2.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:130: (test)




 23) test build/2 I5: a table a third aggregate lists, past a schema claimed twice, is claimed by all (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:245
     match (=) failed
     code:  assert [_config, _x] =
              for %{subject: @s1} = issue <- index.issues do
                issue
              end
     left:  [_config, _x]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: :config,
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:262: (test)




 24) test build/2 I10: malformed attribute (a table that is an atom) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "tables must be a list of non-empty strings, got: [:atom]"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)

..


 25) test build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:207
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :claimed_twice, subject: "s1", aggregates: ["A", "B"], site: :config}] =
              index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: "s1",
                aggregates: ["A", "B"],
                site: :config
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: "s1",
                site: :config,
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:216: (test)




 26) test build/2 under declare: none N3: a module declaring @behaviour Ecto.Repo persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:485
     match (=) failed
     code:  assert [%{subject: @repo, detail: "it declares @behaviour Ecto.Repo"}] =
              persists(Index.build(none(), graph))
     left:  [%{subject: AnchorFixtures.Aggregates.IndexTest.Repo, detail: "it declares @behaviour Ecto.Repo"}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:489: (test)




 27) test build/2 I10: malformed attribute (a schema that is a string) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "schemas must be a list of module atoms, got: [\"S1\"]"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)




 28) test build/2 I11: a schema whose source is not a literal has an unknown table, and no issue (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:381
     Assertion with == failed
     code:  assert index.issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Dyn,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.Dyn,
                 "lib/dyn.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:389: (test)




 29) test build/2 I9: an aggregate with no schemas and no tables is empty_aggregate (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:298
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :empty_aggregate, subject: "A", site: :config}] = index.issues
     left:  [%Anchor.Domain.Aggregates.DeclarationIssue{kind: :empty_aggregate, subject: "A", site: :config}]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :empty_aggregate,
                subject: "A",
                site: :config,
                aggregates: ["A"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:301: (test)




 30) test build/2 I10: malformed attribute (a string name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "name must be a module-name atom, got: \"A\""
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)

.


 31) test build/2 under declare: none N4: a module making a Repo write persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




 32) test build/2 I10: malformed attribute (a map) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:337
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it is not a keyword list, got: %{name: A, schemas: [AnchorFixtures.Aggregates.IndexTest.S1]}"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                site: {:module,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: [],
                detail: "it declares @anchor_aggregate"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:344: (test)
```

### IX-FIELD

the index does not keep none (`lib/anchor/domain/aggregates/index.ex`). Result: `52 tests, 4 failures`.

```

  1) test Z5: under declare: none the Model builds no write analysis, and the index keeps none (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:149
     Assertion with == failed
     code:  assert index.none == "no database"
     left:  nil
     right: "no database"
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:168: (test)

..


  2) test Z6: none over a project with an Ecto schema fails, naming the schema module (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:74
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "aggregate_declarations",
                type: :aggregate_declarations,
                label: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations)",
                enforcement: :enforce,
                key: "aggregate_declarations|AggNone.Thread|persists_under_none - AggNone.Thread",
                file: "lib/agg_none/thread.ex",
                line: 1,
                message: "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregates_none/.anchor.yml",
                line: nil,
                message: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
              }
            ]
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:80: (test)




  3) test Z6: none over a project that persists nothing is clean, not checks-nothing (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:66
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregates_none/.anchor.yml",
                  line: nil,
                  message: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 1,
                opaque: 0,
                apps: 1,
                rules: 1,
                outside_root: 0,
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:71: (test)

..................


  4) test build/2 under declare: none N1: none over modules that persist nothing has no issue, and keeps the reason (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:452
     Assertion with == failed
     code:  assert index.none == @reason
     left:  nil
     right: "no database"
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:467: (test)

..........................
```

### IX-SITE

a persisting module's issue sits at an attribute site (`lib/anchor/domain/aggregates/index.ex`). Result: `40 tests, 5 failures`.

```

  1) test build/2 under declare: none N2: a module exporting __schema__/1 persists, at its module (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:471
     match (=) failed
     code:  assert [
              %DeclarationIssue{
                kind: :persists_under_none,
                subject: @s1,
                aggregates: [],
                site: {:module, @s1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                aggregates: [],
                site: {:module, AnchorFixtures.Aggregates.IndexTest.S1, "lib/s1.ex", 1},
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.S1,
                 "lib/s1.ex", 1},
                aggregates: [],
                detail: "it exports __schema__/1 (an Ecto schema)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:474: (test)

...........


  2) test build/2 under declare: none N4: a module making Ecto.Repo itself persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Repo.all/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Repo.all/2 (line 7)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

....


  3) test build/2 under declare: none N4: a module making a Repo write persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls AnchorFixtures.Aggregates.IndexTest.Repo.insert/2 (line 7)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)




  4) test build/2 under declare: none N4: a module making an Ecto adapter persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Adapters.SQL.query/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Adapters.SQL.query/3 (line 7)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

...........


  5) test build/2 under declare: none N4: a module making an Ecto.Multi step persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:504
     match (=) failed
     The following variables were pinned:
       detail = "it calls Ecto.Multi.insert/3 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :persists_under_none,
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.Caller,
                 "lib/caller.ex", 1},
                aggregates: [],
                detail: "it calls Ecto.Multi.insert/3 (line 7)"
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:510: (test)

......
```

### RL-NOTHING

none still reports checks-nothing (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`). Result: `13 tests, 5 failures`.

```



  1) test check/2 under declare: none Z4: a module that persists is one violation at its module, naming it, with the Fix (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:214
     match (=) failed
     code:  assert [v] = AggregateDeclarations.check(none_model([@persists]), @rule)
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "App.Store",
                message: "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml says aggregates: declare: none (no database). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: "lib/app/store.ex",
                kind: :rule,
                key: "aggregates|App.Store|persists_under_none - App.Store",
                rule_id: "aggregates",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"aggregates\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:215: (test)

..


  2) test check/2 under declare: none Z4: a persisting module outside the selector is not reported (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:227
     Assertion with == failed
     code:  assert AggregateDeclarations.check(none_model([@persists]), rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"aggregates\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:229: (test)

..


  3) test check/2 under declare: none Z3: none with nothing persisting is clean: no checks-nothing violation (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:210
     Assertion with == failed
     code:  assert AggregateDeclarations.check(none_model([]), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: nil,
                message: "rule (id: \"aggregates\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :fail_closed,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:211: (test)

....


  4) test Z6: none over a project with an Ecto schema fails, naming the schema module (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:74
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "aggregate_declarations",
                type: :aggregate_declarations,
                label: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations)",
                enforcement: :enforce,
                key: "aggregate_declarations|AggNone.Thread|persists_under_none - AggNone.Thread",
                file: "lib/agg_none/thread.ex",
                line: 1,
                message: "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (the canary persists nothing). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregates_none/.anchor.yml",
                line: nil,
                message: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
              }
            ]
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:80: (test)




  5) test Z6: none over a project that persists nothing is clean, not checks-nothing (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:66
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: nil,
                  type: nil,
                  label: "anchor.graph",
                  enforcement: :enforce,
                  key: nil,
                  file: "/home/cjpoll/.local/worktrees/anchor/dnd-5459-write-sets/test/fixtures/graph_canary/aggregates_none/.anchor.yml",
                  line: nil,
                  message: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 1,
                opaque: 0,
                apps: 1,
                rules: 1,
                outside_root: 0,
                apply_sites: nil,
                no_core: 0
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:71: (test)
```

### RL-SELECT

a persisting module is reported whatever the selector (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`). Result: `11 tests, 1 failure`.

```

  1) test check/2 under declare: none Z4: a persisting module outside the selector is not reported (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:227
     Assertion with == failed
     code:  assert AggregateDeclarations.check(none_model([@persists]), rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "App.Store",
                message: "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml says aggregates: declare: none (no database). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: "lib/app/store.ex",
                kind: :rule,
                key: "aggregates|App.Store|persists_under_none - App.Store",
                rule_id: "aggregates",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:229: (test)
```

### RL-FIX

the message's Fix does not say to declare the aggregate (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`). Result: `13 tests, 2 failures`.

```

  1) test check/2 under declare: none Z4: a module that persists is one violation at its module, naming it, with the Fix (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:214
     Assertion with == failed
     code:  assert v.message ==
              "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml " <>
                "says aggregates: declare: none (no database). Fix: declare the aggregate and " <>
                "remove declare: none: " <> @shape
     left:  "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml says aggregates: declare: none (no database). Fix: delete the module and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
     right: "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml says aggregates: declare: none (no database). Fix: declare the aggregate and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:221: (test)

.


  2) test Z6: none over a project with an Ecto schema fails, naming the schema module (Anchor.Integration.AggregatesNoneIntegrationTest)
     test/anchor/integration/aggregates_none_integration_test.exs:74
     Assertion with =~ failed
     code:  assert finding.message =~
              "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but " <>
                ".anchor.yml says aggregates: declare: none (the canary persists nothing). " <>
                "Fix: declare the aggregate and remove declare: none"
     left:  "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (the canary persists nothing). Fix: delete the module and remove declare: none: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
     right: "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (the canary persists nothing). Fix: declare the aggregate and remove declare: none"
     stacktrace:
       test/anchor/integration/aggregates_none_integration_test.exs:89: (test)
```

### MD-NONE

Model builds the write analysis under none (`lib/anchor/domain/model.ex`). Result: `10 tests, 1 failure`.

```

  1) test Z5: under declare: none the Model builds no write analysis, and the index keeps none (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:149
     match (=) failed
     code:  assert {%Anchor.Domain.Model{aggregate_analysis: nil, aggregates: index}, _issues} =
              Anchor.Domain.Model.build(graph, config, %{})
     left:  {%Anchor.Domain.Model{aggregate_analysis: nil, aggregates: index}, _issues}
     right: {%Anchor.Domain.Model{
               graph: %Anchor.Domain.Graph{
                 modules: %{
                   AnchorFixtures.NonTransactionalTest.N => %Anchor.Domain.Graph.ModuleNode{
                     module: AnchorFixtures.NonTransactionalTest.N,
                     app: :fixtures,
                     source_file: "lib/fixture.ex",
                     line: 1,
                     struct_fields: nil,
                     behaviours: [],
                     attributes: [],
                     specs: %{},
                     types: %{},
                     functions: %{
                       {:f, 0} => %Anchor.Domain.Graph.FunctionNode{
                         module: AnchorFixtures.NonTransactionalTest.N,
                         name: :f,
                         arity: 0,
                         kind: :def,
                         line: 2,
                         core: {:c_fun,
                          [
                            {:function, {:f, 0}},
                            {2, 7},
                            {:file, ~c"lib/fixture.ex"}
                          ], [],
                          {:c_case,
                           [
                             {:function, {:f, 0}},
                             {2, 7},
                             {:file, ~c"lib/fixture.ex"}
                           ],
                           {:c_values,
                            [
                              {:function, {:f, 0}},
                              {2, 7},
                              {:file, ~c"lib/fixture.ex"}
                            ], []},
                           [
                             {:c_clause,
                              [{2, 7}, {:file, ~c"lib/fixture.ex"}],
                              [], {:c_literal, [], true},
                              {:c_literal,
                               [{2, 7}, {:file, ~c"lib/fixture.ex"}],
                               :ok}},
                             {:c_clause, [:compiler_generated], [],
                              {:c_literal, [], true}, ...}
                           ]}},
                         ...
                       }
                     },
                     ...
                   }
                 },
                 ...
               },
               ...
             }, ...}
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:165: (test)
```

### IF-YAML

nothing written renders declare: [] (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F5: nothing written renders declare: none with a reason, which parses (DND-5659) (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:96
     match (=) failed
     code:  assert {:ok, %Config{declare: [], none: reason}} = Config.parse(section)
     left:  {:ok, %Anchor.Domain.Aggregates.Config{declare: [], none: reason}}
     right: {:error,
             {:invalid_config,
              "aggregates.declare is an empty list, which says nothing on purpose. Fix: write declare: none with reason: \"<why this repo persists nothing>\" and no other key, or list the aggregates: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:99: (test)

.....
```

### CF-NONEDEFAULT

a section without none has a none value (`lib/anchor/domain/aggregates/config.ex`). Result: `40 tests, 1 failure`.

```

  1) test parse/1, declare: none Z1: a section without none has none: nil (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:130
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{none: nil}} = AggregatesConfig.parse(@section)
     left:  {:ok, %Anchor.Domain.Aggregates.Config{none: nil}}
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
               none: "none",
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
       test/anchor/domain/aggregates/config_test.exs:131: (test)

.........................
```

## Review-floor fixes (after both tickets' critic PASS)

| # | Mutation | Tests run | Result |
|---|---|---|---|
| NT-RUNCB | an inline Multi.run callback's write counts as outside a transaction (`lib/anchor/domain/aggregates/non_transactional.ex`) | `non_transactional_test.exs` | `10 tests, 1 failure` (red) |
| NT-RUNCAP | a capture passed as a Multi.run callback is a call outside a transaction (`lib/anchor/domain/aggregates/non_transactional.ex`) | `non_transactional_test.exs` | `10 tests, 1 failure` (red) |
| FW-FNAME | a let-bound local fun name reads as an unbound variable (`lib/anchor/domain/aggregates/function_walk.ex`) | `non_transactional_test.exs` | `10 tests, 1 failure` (red) |
| WSI-RAWSQL | query and query! are not raw SQL (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 3 failures` (red) |
| WSI-RAWSQLADAPTER | Ecto.Adapters.SQL is not raw SQL (`lib/anchor/domain/aggregates/write_sites.ex`) | `scopes_test.exs` | `18 tests, 1 failure` (red) |
| IN-NOREPO | no repo renders a proposal (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| IN-UNRESOLVEDNONE | writes found but none resolved renders declare: none (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| IN-NOTE | the unresolved note is not a YAML comment (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `12 tests, 1 failure` (red) |
| CFG-NONERULE | aggregate_write_sources beside declare: none loads (`lib/anchor/domain/config.ex`) | `aggregate_write_sources_test.exs` | `9 tests, 1 failure` (red) |
| IN-EVIDENCESCOPES | a transaction with no write site is not evidence (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| IN-EVIDENCEOUTSIDE | an unattributable call outside a transaction is not evidence (`lib/anchor/domain/aggregates/inference.ex`) | `inference_test.exs` | `14 tests, 1 failure` (red) |
| PS-RAWSQL | raw SQL on a Repo is not a persistence call (`lib/anchor/domain/aggregates/persistence.ex`) | `index_test.exs` | `41 tests, 1 failure` (red) |

### NT-RUNCB

an inline Multi.run callback's write counts as outside a transaction (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `10 tests, 1 failure`.

```

  1) test N5: a literal-repo write in an inline Multi.run callback is never non-transactional (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:85
     Assertion with == failed
     code:  assert nontx(a, :n6).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.S])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:88: (test)

....
```

### NT-RUNCAP

a capture passed as a Multi.run callback is a call outside a transaction (`lib/anchor/domain/aggregates/non_transactional.ex`). Result: `10 tests, 1 failure`.

```

  1) test N5: a captured Multi.run callback's writes are never non-transactional to the builder (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:91
     Assertion with == failed
     code:  assert nontx(a, :n7).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:93: (test)

......
```

### FW-FNAME

a let-bound local fun name reads as an unbound variable (`lib/anchor/domain/aggregates/function_walk.ex`). Result: `10 tests, 1 failure`.

```

  1) test N5: a captured Multi.run callback's writes are never non-transactional to the builder (Anchor.Domain.Aggregates.NonTransactionalTest)
     test/anchor/domain/aggregates/non_transactional_test.exs:91
     Assertion with == failed
     code:  assert nontx(a, :n7).keys == MapSet.new()
     left:  MapSet.new([schema: AnchorFixtures.NonTransactionalTest.T])
     right: MapSet.new([])
     stacktrace:
       test/anchor/domain/aggregates/non_transactional_test.exs:93: (test)

.....
```

### WSI-RAWSQL

query and query! are not raw SQL (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 3 failures`.

```

  1) test raw SQL S14: raw SQL in s16 makes its scope incomplete, at the call's line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:241
     match (=) failed
     The following variables were pinned:
       name = :s16
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, ^name, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s16, 0},
              ordinal: 1,
              line: 108,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:246: (test)




  2) test raw SQL S14: raw SQL in s15 makes its scope incomplete, at the call's line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:241
     match (=) failed
     The following variables were pinned:
       name = :s15
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, ^name, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s15, 0},
              ordinal: 1,
              line: 105,
              kind: :multi,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:246: (test)

...


  3) test raw SQL S14: raw SQL in s14 makes its scope incomplete, at the call's line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:241
     match (=) failed
     The following variables were pinned:
       name = :s14
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, ^name, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s14, 0},
              ordinal: 1,
              line: 100,
              kind: :fun,
              writes: [
                %Anchor.Domain.Aggregates.WriteSite{
                  mfa: {AnchorFixtures.ScopesTest.X, :s14, 0},
                  line: 100,
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
       test/anchor/domain/aggregates/scopes_test.exs:246: (test)

....
```

### WSI-RAWSQLADAPTER

Ecto.Adapters.SQL is not raw SQL (`lib/anchor/domain/aggregates/write_sites.ex`). Result: `18 tests, 1 failure`.

```

  1) test raw SQL S14: raw SQL in s16 makes its scope incomplete, at the call's line (Anchor.Domain.Aggregates.ScopesTest)
     test/anchor/domain/aggregates/scopes_test.exs:241
     match (=) failed
     The following variables were pinned:
       name = :s16
     code:  assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} = one(a, name)
     left:  %Anchor.Domain.Aggregates.Scope{
              complete?: false,
              gaps: [{:dynamic_call, {AnchorFixtures.ScopesTest.X, ^name, 0}, line}]
            }
     right: %Anchor.Domain.Aggregates.Scope{
              mfa: {AnchorFixtures.ScopesTest.X, :s16, 0},
              ordinal: 1,
              line: 108,
              kind: :fun,
              writes: [],
              keys: MapSet.new([]),
              complete?: true,
              gaps: []
            }
     stacktrace:
       test/anchor/domain/aggregates/scopes_test.exs:246: (test)

......
```

### IN-NOREPO

no repo renders a proposal (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F8: no repo is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:113
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(%Analysis{no_repo?: true})
     left:  {:error, why}
     right: {:ok,
             "aggregates:\n  declare: none\n  reason: \"anchor found no transaction and no write in this project\"\n"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:114: (test)

...
```

### IN-UNRESOLVEDNONE

writes found but none resolved renders declare: none (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F8: writes found but none resolved is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:105
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(unresolved)
     left:  {:error, why}
     right: {:ok,
             "aggregates:\n  declare: none\n  reason: \"anchor found no transaction and no write in this project\"\n"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:108: (test)

..
```

### IN-NOTE

the unresolved note is not a YAML comment (`lib/anchor/domain/aggregates/inference.ex`). Result: `12 tests, 1 failure`.

```

  1) test F8: a proposal with unresolved writes beside it says so in the YAML (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:118
     Assertion with =~ failed
     code:  assert yaml =~ "# 1 of 3 write(s) unresolved: this proposal may miss tables"
     left:  "1 of 3 write(s) unresolved: this proposal may miss tables\naggregates:\n  declare:\n    - name: App.S\n      schemas: [App.S]\n      tables: []\n      # owners: proposed by aggregate_owner_writes\n"
     right: "# 1 of 3 write(s) unresolved: this proposal may miss tables"
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:125: (test)

.....
```

### CFG-NONERULE

aggregate_write_sources beside declare: none loads (`lib/anchor/domain/config.ex`). Result: `9 tests, 1 failure`.

```

  1) test V5: loading a rule beside declare: none is refused, the Fix naming both ways out (Anchor.Domain.GraphRules.AggregateWriteSourcesTest)
     test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:172
     match (=) failed
     code:  assert {:error, {:invalid_rule, message}} =
              Config.parse_config(%{
                "rules" => [@rule_yaml],
                "architecture" => @architecture,
                "aggregates" => %{"declare" => "none", "reason" => "no database"}
              })
     left:  {:error, {:invalid_rule, message}}
     right: %Anchor.Config{
              rules: [
                %{
                  id: "writes",
                  index: 1,
                  match: :reference,
                  type: :aggregate_write_sources,
                  mode: nil,
                  pattern: nil,
                  recursive: false,
                  enforcement: :enforce,
                  min_files: 1,
                  bucket: nil,
                  min_modules: nil,
                  baseline: nil,
                  paths: ["lib/**"],
                  uses_module: nil,
                  forbidden_modules: [],
                  forbidden_functions: [],
                  allowed_callers: [],
                  required_modules: [],
                  forbidden_patterns: [],
                  allowed_functions: [],
                  pure_patterns: [],
                  owned_namespaces: nil,
                  max_lines: nil,
                  same_context: false,
                  context_depth: 2
                }
              ],
              path: nil,
              architecture: %Anchor.Domain.Architecture{
                context_depth: 2,
                buckets: [
                  %Anchor.Domain.Architecture.Bucket{
                    name: "domain",
                    role: :domain,
                    selectors: [paths: ["lib/**"]],
                    min_modules: 1,
                    infer: true
                  }
                ],
                calls: %{"domain" => [{"domain", :any}]},
                interface_buckets: [],
                interface_exports: [],
                effects: [],
                roots: [],
                extract_pure_regions_from: [:managers, :framework]
              },
              aggregates: %Anchor.Domain.Aggregates.Config{
                declare: [],
                none: "no database",
                repos: [],
                write_functions: [],
                transaction_functions: []
              },
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_write_sources_test.exs:173: (test)

.....
```

### IN-EVIDENCESCOPES

a transaction with no write site is not evidence (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F8: a transaction with no write site, only a gap, is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:114
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(gap_only)
     left:  {:error, why}
     right: {:ok,
             "aggregates:\n  declare: none\n  reason: \"anchor found no transaction and no write in this project\"\n"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:120: (test)

.
```

### IN-EVIDENCEOUTSIDE

an unattributable call outside a transaction is not evidence (`lib/anchor/domain/aggregates/inference.ex`). Result: `14 tests, 1 failure`.

```

  1) test F8: a gap outside every transaction is an error, never declare: none (Anchor.Domain.Aggregates.InferenceTest)
     test/anchor/domain/aggregates/inference_test.exs:124
     match (=) failed
     code:  assert {:error, why} = Inference.render_yaml(outside)
     left:  {:error, why}
     right: {:ok,
             "aggregates:\n  declare: none\n  reason: \"anchor found no transaction and no write in this project\"\n"}
     stacktrace:
       test/anchor/domain/aggregates/inference_test.exs:130: (test)

............
```

### PS-RAWSQL

raw SQL on a Repo is not a persistence call (`lib/anchor/domain/aggregates/persistence.ex`). Result: `41 tests, 1 failure`.

```



  1) test build/2 under declare: none N4: a module making raw SQL on a Repo it does not define persists (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:506
     match (=) failed
     The following variables were pinned:
       detail = "it calls MyDep.Repo.query!/2 (line 7)"
     code:  assert [%{subject: @caller, site: {:module, @caller, _file, 1}, detail: ^detail}] =
              persists(Index.build(none(), graph))
     left:  [
              %{
                subject: AnchorFixtures.Aggregates.IndexTest.Caller,
                site: {:module, AnchorFixtures.Aggregates.IndexTest.Caller, _file, 1},
                detail: ^detail
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:512: (test)

........................................
```
