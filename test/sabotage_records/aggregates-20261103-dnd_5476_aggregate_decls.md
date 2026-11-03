# Sabotage record — aggregate declarations (DND-5476)

- **Domain:** aggregates (one combined record for the ticket, as its QA plan directs; the mutations of `Anchor.Config`, `Anchor.Domain.GraphRules`, `Anchor.Domain.Model`, `Anchor.Domain.GraphReport` and `Anchor.Managers.Graph` are off-domain and labelled by their file)
- **Branch:** dnd-5476-aggregate-decls
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Aggregates.Config`, `Anchor.Domain.Aggregates.Index` (`build/2`, `table_of/2`, `aggregate_of/2`, `owners/2`), `Anchor.Domain.GraphRules.AggregateDeclarations`, `Anchor.Aggregate` (`__using__/1`), and the wiring in `Anchor.Config`, `Anchor.Domain.Model`, `Anchor.Domain.GraphRules`, `Anchor.Domain.GraphReport` and `Anchor.Managers.Graph`
- **Suite run:** on 98ee200, a driver applied each mutation to the source, ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside `test-slot`, and restored the source, bumping the file's mtime after each write so Mix recompiled it. After each pass the restored tree ran every file below green (`89 tests, 0 failures`). Every row is red.
- **Passes:** the first pass (AG-MERGE to MG-COUNT) is the QA plan's sabotage table and more. Four of its mutations were first written so that they also left an unused variable or attribute, which `warnings_as_errors` turned into a compile error; they were re-anchored to the same defect and re-run red (AG-UNK, AG-SKIP, CF-KEYS), or re-anchored after `mix format` moved the line (RL-SCOPE). A `mix test --trace` listing then showed 34 of the 77 tests never red; the second pass (CF-NIL to MC-LITERAL) breaks the branch each of those guards, CF-MODULE re-anchored once for the same compile-error reason. After it, all 77 tests of the five files have been seen red.
- **Test files:** `test/anchor/domain/aggregates/config_test.exs`, `test/anchor/domain/aggregates/index_test.exs`, `test/anchor/domain/graph_rules/aggregate_declarations_test.exs`, `test/anchor/aggregate_test.exs`, `test/anchor/integration/aggregate_declarations_integration_test.exs`; the RuleSchema registration (`aggregate_declarations: :graph`) is held by `graph_rules_test.exs` (GR-REG) and the README table drift test, and the load of the rule by its rows in `rule_checks_nothing_test.exs` (the shared `graph_common_rows/0`).

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| AG-MERGE | merge keeps only the first source's schemas (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I2: a config and an attribute declaration of one name merge |
| AG-CONF | conflicts are not recorded (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 2 failures` (red) | build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice; build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically |
| AG-NAS | the not_a_schema check is removed (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I7: a module with no __schema__/1 is not_a_schema |
| AG-MAL | a malformed attribute is accepted (its shape is not checked) (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 3 failures` (red) | build/2 I10: malformed attribute (an unknown key) contributes nothing; build/2 I10: malformed attribute (a key given twice) contributes nothing; build/2 I10: malformed attribute (a map) contributes nothing |
| AG-UNK | the unknown_schema check is removed (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I6: a schema naming no project module is unknown_schema |
| AG-OWNER | unknown owners are not reported (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I8: an owner naming no project module is unknown_owner |
| AG-EMPTY | empty aggregates are not reported (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I9: an aggregate with no schemas and no tables is empty_aggregate |
| AG-DYN | unknown tables are not counted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I11: a schema whose source is not a literal has an unknown table, and no issue |
| AG-ORDER | the claim goes to the last aggregate, not the first (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 2 failures` (red) | build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically; build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice |
| AG-DERIVED | a twice-claimed schema's table is reported again (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically |
| AG-UNREAD | an unreadable module is not known (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 a schema naming a module the graph could not build is not also unknown |
| AG-CALL | table_of calls the module instead of reading Core (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 12 failures` (red) | build/2 I10 positive control: the same attribute well formed declares S1; table_of/2 a catch-all clause before :source makes it unknown; build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically; build/2 I8: an owner naming no project module is unknown_owner; build/2 I11: a schema whose source is not a literal has an unknown table, and no issue; build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice; build/2 I1: a config aggregate maps its schemas and their tables; build/2 I2: a config and an attribute declaration of one name merge; table_of/2 T1: a literal source clause gives the table, past an earlier literal clause; build/2 I12: positive control: I6-I9 with the names corrected find nothing; table_of/2 T3: a computed source is unknown, read without loading the module; build/2 I3: an owner: false attribute adds its schema and no owner |
| AG-SKIP | a literal clause other than :source stops the read (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 4 failures` (red) | table_of/2 T1: a literal source clause gives the table, past an earlier literal clause; build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice; build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically; build/2 I11: a schema whose source is not a literal has an unknown table, and no issue |
| AG-TWICE | an attribute set twice is read as its first value (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 an attribute set twice is malformed |
| CF-KEYS | unknown keys in the section are accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: an unknown top key |
| CF-DUP | a duplicate name is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: a duplicate name |
| CF-NAME | any string is a name (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: a lower-case name |
| CF-TABLES | an empty table name is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: an empty table |
| CF-WIRE | Anchor.Config ignores the aggregates section (`lib/anchor/domain/config.ex`) | `config_test.exs` | `26 tests, 2 failures` (red) | Anchor.Config.parse_config/1 an aggregates section loads into :aggregates; Anchor.Config.parse_config/1 a malformed section fails the whole load with its Fix: |
| RL-ZERO | the zero-aggregate branch returns no violation (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 3 failures` (red) | check/2 R2: zero aggregates declared is one violation on .anchor.yml: it checks nothing; check/2 R2: the config's own path is where a config-site violation sits; check/2 a rule with no id keys by its type |
| RL-SCOPE | every attribute issue is in scope (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 1 failure` (red) | check/2 R3: an attribute issue outside the selector is not reported; a config one still is |
| RL-KEY | the key carries the site's line (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 1 failure` (red) | check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape |
| RL-SHAPE | a message does not end with the shape (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 1 failure` (red) | check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape |
| MC-OWNER | the macro emits owner: false (`lib/anchor/aggregate.ex`) | `aggregate_test.exs` | `13 tests, 3 failures` (red) | __using__/1 M2: the hand-written attribute reads the same as the macro's; __using__/1 M4 positive control: the same options with a literal name compile; __using__/1 M1: the macro persists exactly the attribute, owner true by default |
| MC-ALIAS | the macro does not expand aliases (`lib/anchor/aggregate.ex`) | `aggregate_test.exs` | `13 tests, 9 failures` (red) | __using__/1 M2: the hand-written attribute reads the same as the macro's; __using__/1 M4: schemas not a list raises ArgumentError naming the key and the shape; __using__/1 M5: the macro adds no function to the module; __using__/1 M3: aliases in scope resolve, and so does __MODULE__; __using__/1 M4: a non-literal schema raises ArgumentError naming the key and the shape; __using__/1 M4: a non-boolean owner raises ArgumentError naming the key and the shape; __using__/1 M4 positive control: the same options with a literal name compile; __using__/1 M1: the macro persists exactly the attribute, owner true by default; __using__/1 M4: an empty table raises ArgumentError naming the key and the shape |
| MC-KEYS | the macro accepts unknown keys (`lib/anchor/aggregate.ex`) | `aggregate_test.exs` | `13 tests, 1 failure` (red) | __using__/1 M4: an unknown key raises ArgumentError naming the key and the shape |
| MD-INDEX | the model never builds the index (`lib/anchor/domain/model.ex`) | `aggregate_declarations_integration_test.exs` | `2 tests, 2 failures` (red) | N1: the violating module's table claim is claimed twice, at the config and at it; N1: the compliant canary (macro form and config) gives no finding |
| GR-REG | aggregate_declarations is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `aggregate_declarations_integration_test.exs` | `14 tests, 3 failures` (red) | all/0 every module implements GraphRule, and their types are RuleSchema's graph types; N1: the compliant canary (macro form and config) gives no finding; N1: the violating module's table claim is claimed twice, at the config and at it |
| RP-NOTE | the summary omits the aggregate counts (`lib/anchor/domain/graph_report.ex`) | `aggregate_declarations_integration_test.exs` | `2 tests, 1 failure` (red) | N1: the compliant canary (macro form and config) gives no finding |
| MG-COUNT | the manager does not count the aggregates (`lib/anchor/managers/graph.ex`) | `aggregate_declarations_integration_test.exs` | `2 tests, 1 failure` (red) | N1: the compliant canary (macro form and config) gives no finding |
| CF-NIL | a bare section is refused (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C2: a bare section (nil) and an empty mapping have no declarations |
| CF-MAP | a section that is not a mapping is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: not a map |
| CF-DECLIST | a declare that is not a list is read as none (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 2 failures` (red) | parse/1 C3: refused: declare not a list; Anchor.Config.parse_config/1 a malformed section fails the whole load with its Fix: |
| CF-ENTRYMAP | an entry that is not a mapping is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: an entry not a map |
| CF-ENTRYKEYS | an unknown entry key is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: an unknown entry key |
| CF-NONAME | an entry with no name is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: an entry with no name |
| CF-NAMESTR | a name that is not a string is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: a name that is not a string |
| CF-MODULE | any string is a module name (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 4 failures` (red) | parse/1 C3: refused: an owner that is not a module; parse/1 C3: refused: repos not module names; parse/1 C3: refused: a schema glob; parse/1 C3: refused: a schema that is not a module |
| CF-MODLIST | a module list that is not a list is read as none (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: schemas a string |
| CF-TABLIST | tables that is not a list is read as none (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: tables a string |
| CF-FUNC | a function token is not parsed (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 2 failures` (red) | parse/1 C3: refused: a malformed write function; parse/1 C1: a full section parses every field as given |
| CF-FUNCSTR | a function token that is not a string is accepted (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: a malformed transaction function |
| CF-FUNCLIST | a function list that is not a list is read as none (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: write_functions not a list |
| CF-INDEX | every entry is named declare[1] (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | parse/1 C3: refused: the second entry malformed |
| CF-DEFAULT | an absent schemas key is not [] (`lib/anchor/domain/aggregates/config.ex`) | `config_test.exs` | `26 tests, 2 failures` (red) | parse/1 an entry with only a name and tables defaults schemas and owners to []; parse/1 C3: refused: the second entry malformed |
| CF-ABSENT | a document with no aggregates section gets an empty one (`lib/anchor/domain/config.ex`) | `config_test.exs` | `26 tests, 1 failure` (red) | Anchor.Config.parse_config/1 no aggregates section is nil (no declarations), never an empty section |
| AG-NONAME | an attribute with no name is accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (no name) contributes nothing |
| AG-STRNAME | a non-atom name is accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (a string name) contributes nothing |
| AG-ERLNAME | an Erlang atom name is accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (an Erlang atom name) contributes nothing |
| AG-SCHEMAS | schemas of any shape are accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (a schema that is a string) contributes nothing |
| AG-TABLES | tables of any shape are accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (a table that is an atom) contributes nothing |
| AG-OWNERBOOL | a non-boolean owner is accepted (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | build/2 I10: malformed attribute (owner not a boolean) contributes nothing |
| AG-UNDECL | an undeclared name has an owner (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | aggregate_of/2 and owners/2 an undeclared name has no owners |
| AG-NOCORE | a __schema__/1 with no Core body reads as a table (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 1 failure` (red) | table_of/2 a __schema__/1 with no Core body is unknown |
| AG-NOSCHEMA | a module with no __schema__/1 reads as unknown (`lib/anchor/domain/aggregates/index.ex`) | `index_test.exs` | `29 tests, 2 failures` (red) | build/2 I7: a module with no __schema__/1 is not_a_schema; table_of/2 T2: a module without __schema__/1, or none at all, is not a schema |
| RL-CLEAN | a clean index still says it checks nothing (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 3 failures` (red) | check/2 R3: an attribute issue outside the selector is not reported; a config one still is; check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape; check/2 R4: a clean index with an aggregate gives nothing |
| RL-SHAPETXT | the shape text drifts (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_test.exs` | `7 tests, 3 failures` (red) | check/2 R2: zero aggregates declared is one violation on .anchor.yml: it checks nothing; shape/1 S1: the documented declaration shape; check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape |
| MC-NONAME | a missing name is filled in (`lib/anchor/aggregate.ex`) | `aggregate_test.exs` | `13 tests, 1 failure` (red) | __using__/1 M4: no name raises ArgumentError naming the key and the shape |
| MC-LITERAL | any value is a module name (`lib/anchor/aggregate.ex`) | `aggregate_test.exs` | `13 tests, 3 failures` (red) | __using__/1 M4: a non-literal schema raises ArgumentError naming the key and the shape; __using__/1 M4: a variable name raises ArgumentError naming the key and the shape; __using__/1 M4: an atom name raises ArgumentError naming the key and the shape |

## AG-MERGE — merge keeps only the first source's schemas

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I2: a config and an attribute declaration of one name merge (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:132
     Assertion with == failed
     code:  assert schemas == Enum.sort([@s1, @s3])
     left:  [AnchorFixtures.Aggregates.IndexTest.S1]
     right: [AnchorFixtures.Aggregates.IndexTest.S1,
             AnchorFixtures.Aggregates.IndexTest.S3]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:142: (test)

........................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-CONF — conflicts are not recorded

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I5: an explicit table and a schema's table in two aggregates is claimed twice (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:205
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
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:214: (test)

........................
```

## AG-NAS — the not_a_schema check is removed

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I7: a module with no __schema__/1 is not_a_schema (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:260
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :not_a_schema, subject: @plain}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :not_a_schema,
                subject: AnchorFixtures.Aggregates.IndexTest.Plain
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:262: (test)

.......
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-MAL — a malformed attribute is accepted (its shape is not checked)

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (an unknown key) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

.........
```

## AG-UNK — the unknown_schema check is removed

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I6: a schema naming no project module is unknown_schema (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:243
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :unknown_schema, subject: Nope, aggregates: ["A"]}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_schema,
                subject: Nope,
                aggregates: ["A"]
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:246: (test)

...................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-OWNER — unknown owners are not reported

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I8: an owner naming no project module is unknown_owner (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:265
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :unknown_owner, subject: Ghost, aggregates: ["A"]}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_owner,
                subject: Ghost,
                aggregates: ["A"]
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:272: (test)

.........
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-EMPTY — empty aggregates are not reported

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I9: an aggregate with no schemas and no tables is empty_aggregate (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:276
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :empty_aggregate, subject: "A", site: :config}] = index.issues
     left:  [%Anchor.Domain.Aggregates.DeclarationIssue{kind: :empty_aggregate, subject: "A", site: :config}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:279: (test)

..................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-DYN — unknown tables are not counted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I11: a schema whose source is not a literal has an unknown table, and no issue (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:357
     Assertion with == failed
     code:  assert index.tables_unknown == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:364: (test)

...................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-ORDER — the claim goes to the last aggregate, not the first

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:163
     Assertion with == failed
     code:  assert Index.aggregate_of(index, @s1) == {:ok, "A"}
     left:  {:ok, "B"}
     right: {:ok, "A"}
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:185: (test)

....
```

## AG-DERIVED — a twice-claimed schema's table is reported again

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I4: a schema in two aggregates is claimed twice at each site, deterministically (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:163
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
                subject: "s1",
                site: :config,
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: AnchorFixtures.Aggregates.IndexTest.S1,
                site: :config,
                aggregates: ["A", "B"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :claimed_twice,
                subject: "s1",
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
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
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:168: (test)

..........................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-UNREAD — an unreadable module is not known

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 a schema naming a module the graph could not build is not also unknown (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:250
     Assertion with == failed
     code:  assert Index.build(config([{"A", [schemas: [Nope], owners: [Nope]]}]), graph).issues == []
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_owner,
                subject: Nope,
                site: :config,
                aggregates: ["A"],
                detail: nil
              },
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :unknown_schema,
                subject: Nope,
                site: :config,
                aggregates: ["A"],
                detail: nil
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:257: (test)

.
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-CALL — table_of calls the module instead of reading Core

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10 positive control: the same attribute well formed declares S1 (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:331
     ** (UndefinedFunctionError) function AnchorFixtures.Aggregates.IndexTest.S1.__schema__/1 is undefined (module AnchorFixtures.Aggregates.IndexTest.S1 is not available)
     code: Index.build(
     stacktrace:
       AnchorFixtures.Aggregates.IndexTest.S1.__schema__(:source)
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:140: Anchor.Domain.Aggregates.Index.table_of/2
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:310: anonymous fn/4 in Anchor.Domain.Aggregates.Index.schema_tables/3
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (stdlib 7.1) maps.erl:894: :maps.fold_1/4
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:307: Anchor.Domain.Aggregates.Index.schema_tables/3
       (anchor 0.1.0) lib/anchor/domain/aggregates/index.ex:83: Anchor.Domain.Aggregates.Index.build/2
       test/anchor/domain/aggregates/index_test.exs:333: (test)
```

## AG-SKIP — a literal clause other than :source stops the read

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test table_of/2 T1: a literal source clause gives the table, past an earlier literal clause (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:371
     Assertion with == failed
     code:  assert Index.table_of(graph(cores, schemas: [@s1]), @s1) == {:ok, "s1"}
     left:  :unknown
     right: {:ok, "s1"}
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:373: (test)

................
```

## AG-TWICE — an attribute set twice is read as its first value

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 an attribute set twice is malformed (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:342
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, detail: detail}] = Index.build(nil, graph).issues
     left:  [%Anchor.Domain.Aggregates.DeclarationIssue{kind: :malformed_attribute, detail: detail}]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:351: (test)

..........................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## CF-KEYS — unknown keys in the section are accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an unknown top key (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

......
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## CF-DUP — a duplicate name is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: a duplicate name (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
                 },
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "MyApp.Threads.ThreadSpace",
                   schemas: [],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.......................
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-NAME — any string is a name

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: a lower-case name (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "lower.case",
                   schemas: [MyApp.Threads.Thread,
                    MyApp.Threads.Message],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

........
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-TABLES — an empty table name is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an empty table (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
                   tables: [""],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

......................
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-WIRE — Anchor.Config ignores the aggregates section

`lib/anchor/domain/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test Anchor.Config.parse_config/1 an aggregates section loads into :aggregates (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:118
     match (=) failed
     code:  assert %Config{aggregates: %AggregatesConfig{declare: [%Declaration{}]}} =
              Config.parse_config(%{"rules" => [], "aggregates" => @section})
     left:  %Anchor.Config{
              aggregates: %Anchor.Domain.Aggregates.Config{declare: [%Anchor.Domain.Aggregates.Declaration{}]}
            }
     right: %Anchor.Config{
              rules: [],
              path: nil,
              architecture: nil,
              aggregates: %Anchor.Domain.Aggregates.Config{
                declare: [],
                repos: [],
                write_functions: [],
                transaction_functions: []
              },
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:119: (test)

..................
```

## RL-ZERO — the zero-aggregate branch returns no violation

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R2: zero aggregates declared is one violation on .anchor.yml: it checks nothing (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:126
     match (=) failed
     code:  assert [v] = AggregateDeclarations.check(model([], %{}), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:127: (test)

.
```

## RL-SCOPE — every attribute issue is in scope

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R3: an attribute issue outside the selector is not reported; a config one still is (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:143
     match (=) failed
     code:  assert [%{key: "aggregates|.anchor.yml|unknown_schema A Nope"}] = outside
     left:  [%{key: "aggregates|.anchor.yml|unknown_schema A Nope"}]
     right: [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Plain",
                message: "App.Plain in aggregate A is not an Ecto schema (no __schema__/1). Fix: list the schema module, or list its table under tables:: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: "lib/app/x.ex",
                kind: :rule,
                key: "aggregates|App.X|not_a_schema A App.Plain",
                rule_id: "aggregates",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: "Nope",
                message: "Nope in aggregate A names no module in this project. Fix: correct the module name or remove it: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :rule,
                key: "aggregates|.anchor.yml|unknown_schema A Nope",
                rule_id: "aggregates",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:160: (test)


Finished in 0.07 seconds (0.07s async, 0.00s sync)
7 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/aggregate_declarations.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## RL-KEY — the key carries the site's line

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:76
     aggregates|App.X:7|claimed_twice A,B "s"
     code: for v <- violations do
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:85: anonymous fn/2 in Anchor.Domain.GraphRules.AggregateDeclarationsTest."test check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:81: (test)

...
Finished in 0.09 seconds (0.09s async, 0.00s sync)
7 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/aggregate_declarations.ex" was set to the future, resetting to now
```

## RL-SHAPE — a message does not end with the shape

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:76
     schema App.S is claimed by A and B. Fix: list it in exactly one aggregate; the other reaches it through an outbox row consumed by the owner
     code: for v <- violations do
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:83: anonymous fn/2 in Anchor.Domain.GraphRules.AggregateDeclarationsTest."test check/2 R1: one violation per issue, at its site, keyed without lines, ending in the shape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:81: (test)


Finished in 0.07 seconds (0.07s async, 0.00s sync)
7 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/aggregate_declarations.ex" was set to the future, resetting to now
```

## MC-OWNER — the macro emits owner: false

`lib/anchor/aggregate.ex`, tests: test/anchor/aggregate_test.exs. First failing test, verbatim:

```
  1) test __using__/1 M2: the hand-written attribute reads the same as the macro's (Anchor.AggregateTest)
     test/anchor/aggregate_test.exs:42
     Assertion with == failed
     code:  assert macro == hand
     left:  [
              [
                name: AnchorFixtures.AggregateTest.Agg,
                schemas: [AnchorFixtures.AggregateTest.S],
                tables: ["t"],
                owner: false
              ]
            ]
     right: [
              [
                name: AnchorFixtures.AggregateTest.Agg,
                schemas: [AnchorFixtures.AggregateTest.S],
                tables: ["t"],
                owner: true
              ]
            ]
     stacktrace:
       test/anchor/aggregate_test.exs:58: (test)

..
```

## MC-ALIAS — the macro does not expand aliases

`lib/anchor/aggregate.ex`, tests: test/anchor/aggregate_test.exs. First failing test, verbatim:

```
  1) test __using__/1 M2: the hand-written attribute reads the same as the macro's (Anchor.AggregateTest)
     test/anchor/aggregate_test.exs:42
     ** (ArgumentError) use Anchor.Aggregate: name: must be a literal module name, got: AnchorFixtures.AggregateTest.Agg. Write: use Anchor.Aggregate, name: MyApp.Space, schemas: [MyApp.Schema], tables: ["table"], owner: true
     stacktrace:
       (anchor 0.1.0) lib/anchor/aggregate.ex:107: Anchor.Aggregate.refuse!/1
       (anchor 0.1.0) lib/anchor/aggregate.ex:64: Anchor.Aggregate.attribute!/1
       (anchor 0.1.0) expanding macro: Anchor.Aggregate.__using__/1
       nofile:2: AnchorFixtures.AggregateTest.M2Macro (module)
       (elixir 1.19.4) expanding macro: Kernel.use/2
       nofile:2: AnchorFixtures.AggregateTest.M2Macro (module)

.
```

## MC-KEYS — the macro accepts unknown keys

`lib/anchor/aggregate.ex`, tests: test/anchor/aggregate_test.exs. First failing test, verbatim:

```
  1) test __using__/1 M4: an unknown key raises ArgumentError naming the key and the shape (Anchor.AggregateTest)
     test/anchor/aggregate_test.exs:94
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn ->
     stacktrace:
       test/anchor/aggregate_test.exs:101: (test)

...
Finished in 0.1 seconds (0.1s async, 0.00s sync)
13 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/aggregate.ex" was set to the future, resetting to now
```

## MD-INDEX — the model never builds the index

`lib/anchor/domain/model.ex`, tests: test/anchor/integration/aggregate_declarations_integration_test.exs. First failing test, verbatim:

```
  1) test N1: the violating module's table claim is claimed twice, at the config and at it (Anchor.Integration.AggregateDeclarationsIntegrationTest)
     test/anchor/integration/aggregate_declarations_integration_test.exs:77
     match (=) failed
     code:  assert [config_site, rogue_site] = report.findings
     left:  [config_site, rogue_site]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "aggregate_declarations",
                type: :aggregate_declarations,
                label: "rule 1 (id: \"aggregate_declarations\", aggregate_declarations)",
                enforcement: :enforce,
                key: "aggregate_declarations|.anchor.yml|checks nothing",
                file: "<worktree>/test/fixtures/graph_canary/aggregate_declarations/.anchor.yml",
                line: nil,
                message: "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
              }
            ]
     stacktrace:
       test/anchor/integration/aggregate_declarations_integration_test.exs:83: (test)
```

## GR-REG — aggregate_declarations is not registered as a graph rule

`lib/anchor/domain/graph_rules.ex`, tests: test/anchor/domain/graph_rules_test.exs, test/anchor/integration/aggregate_declarations_integration_test.exs. First failing test, verbatim:

```
  1) test all/0 every module implements GraphRule, and their types are RuleSchema's graph types (Anchor.Domain.GraphRulesTest)
     test/anchor/domain/graph_rules_test.exs:61
     Assertion with == failed
     code:  assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
              RuleSchema.rule_types_for_engine(:graph)
     left:  [:context_acyclic, :layering]
     right: [:aggregate_declarations, :context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/graph_rules_test.exs:64: (test)

.........
```

## RP-NOTE — the summary omits the aggregate counts

`lib/anchor/domain/graph_report.ex`, tests: test/anchor/integration/aggregate_declarations_integration_test.exs. First failing test, verbatim:

```
  1) test N1: the compliant canary (macro form and config) gives no finding (Anchor.Integration.AggregateDeclarationsIntegrationTest)
     test/anchor/integration/aggregate_declarations_integration_test.exs:67
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 " <>
                "baselined); aggregates: 2 declared, 0 tables unknown"
     left:  "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined); aggregates: 2 declared, 0 tables unknown"
     stacktrace:
       test/anchor/integration/aggregate_declarations_integration_test.exs:72: (test)


Finished in 0.1 seconds (0.1s async, 0.00s sync)
2 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_report.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/graph_rules.ex" was set to the future, resetting to now
```

## MG-COUNT — the manager does not count the aggregates

`lib/anchor/managers/graph.ex`, tests: test/anchor/integration/aggregate_declarations_integration_test.exs. First failing test, verbatim:

```
  1) test N1: the compliant canary (macro form and config) gives no finding (Anchor.Integration.AggregateDeclarationsIntegrationTest)
     test/anchor/integration/aggregate_declarations_integration_test.exs:67
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 " <>
                "baselined); aggregates: 2 declared, 0 tables unknown"
     left:  "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined); aggregates: 2 declared, 0 tables unknown"
     stacktrace:
       test/anchor/integration/aggregate_declarations_integration_test.exs:72: (test)


Finished in 0.1 seconds (0.1s async, 0.00s sync)
2 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/graph_report.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/managers/graph.ex" was set to the future, resetting to now
```

## CF-NIL — a bare section is refused

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C2: a bare section (nil) and an empty mapping have no declarations (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:53
     match (=) failed
     code:  assert {:ok, %AggregatesConfig{declare: [], repos: []}} = AggregatesConfig.parse(nil)
     left:  {:ok, %Anchor.Domain.Aggregates.Config{declare: [], repos: []}}
     right: {:error,
             {:invalid_config,
              "aggregates must be a mapping, got: []. Fix: write aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:54: (test)

.........
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-MAP — a section that is not a mapping is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: not a map (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-DECLIST — a declare that is not a list is read as none

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: declare not a list (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

......
```

## CF-ENTRYMAP — an entry that is not a mapping is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an entry not a map (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "aggregates.declare[1]\"MyApp.Space\"",
                   schemas: [],
                   tables: [],
                   owners: [],
                   sites: []
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.....................
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-ENTRYKEYS — an unknown entry key is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an unknown entry key (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

......
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-NONAME — an entry with no name is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an entry with no name (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "aggregates.declare[1]",
                   schemas: [MyApp.Threads.Thread,
                    MyApp.Threads.Message],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

..........
Finished in 0.08 seconds (0.08s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-NAMESTR — a name that is not a string is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: a name that is not a string (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "3aggregates.declare[1]",
                   schemas: [MyApp.Threads.Thread,
                    MyApp.Threads.Message],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

..............
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-MODULE — any string is a module name

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: an owner that is not a module (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
                   owners: [:"Elixir.:ets"],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

..........
```

## CF-MODLIST — a module list that is not a list is read as none

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: schemas a string (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     match (=) failed
     code:  assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
     left:  {:error, {:invalid_config, message}}
     right: {:ok,
             %Anchor.Domain.Aggregates.Config{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{
                   name: "MyApp.Threads.ThreadSpace",
                   schemas: [],
                   tables: ["thread_reads"],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

......
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-TABLIST — tables that is not a list is read as none

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: tables a string (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
                   tables: [],
                   owners: [MyApp.Threads.ThreadStore],
                   sites: [:config]
                 }
               ],
               repos: [],
               write_functions: [],
               transaction_functions: []
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

...........
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-FUNC — a function token is not parsed

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: a malformed write function (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
               repos: [MyApp.Repo],
               write_functions: ["bad"],
               transaction_functions: ["GenSaas.UnitOfWork.transaction/3"]
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

..........
```

## CF-FUNCSTR — a function token that is not a string is accepted

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: a malformed transaction function (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
               repos: [MyApp.Repo],
               write_functions: [
                 %Anchor.Domain.FunctionRef{
                   module: MyApp.Repo,
                   function: :soft_delete,
                   arity: 2
                 }
               ],
               transaction_functions: [3]
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.........
Finished in 0.09 seconds (0.09s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-FUNCLIST — a function list that is not a list is read as none

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: write_functions not a list (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
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
               repos: [MyApp.Repo],
               write_functions: [],
               transaction_functions: [
                 %Anchor.Domain.FunctionRef{
                   module: GenSaas.UnitOfWork,
                   function: :transaction,
                   arity: 3
                 }
               ]
             }}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:140: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-INDEX — every entry is named declare[1]

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 C3: refused: the second entry malformed (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:111
     got: aggregates.declare[1].tables must be a list of non-empty table names, got: [1]. Fix: write each table as a string; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...]
     code: assert_refused(section, expected)
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:141: Anchor.Domain.Aggregates.ConfigTest.assert_refused/2
       test/anchor/domain/aggregates/config_test.exs:112: (test)

.........
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
```

## CF-DEFAULT — an absent schemas key is not []

`lib/anchor/domain/aggregates/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test parse/1 an entry with only a name and tables defaults schemas and owners to [] (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:58
     match (=) failed
     code:  assert {:ok, %{declare: [%Declaration{name: "A", schemas: [], owners: [], tables: ["t"]}]}} =
              AggregatesConfig.parse(section)
     left:  {:ok,
             %{
               declare: [
                 %Anchor.Domain.Aggregates.Declaration{name: "A", schemas: [], owners: [], tables: ["t"]}
               ]
             }}
     right: {:error,
             {:invalid_config,
              "aggregates.declare[1].schemas must be a list of exact module names: got: nil. Fix: name each module in full, as its defmodule spells it; aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...]"}}
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:61: (test)

..
```

## CF-ABSENT — a document with no aggregates section gets an empty one

`lib/anchor/domain/config.ex`, tests: test/anchor/domain/aggregates/config_test.exs. First failing test, verbatim:

```
  1) test Anchor.Config.parse_config/1 no aggregates section is nil (no declarations), never an empty section (Anchor.Domain.Aggregates.ConfigTest)
     test/anchor/domain/aggregates/config_test.exs:123
     match (=) failed
     code:  assert %Config{aggregates: nil} = Config.parse_config(%{"rules" => []})
     left:  %Anchor.Config{aggregates: nil}
     right: %Anchor.Config{
              rules: [],
              path: nil,
              architecture: nil,
              aggregates: %Anchor.Domain.Aggregates.Config{
                declare: [],
                repos: [],
                write_functions: [],
                transaction_functions: []
              },
              sabotage: nil
            }
     stacktrace:
       test/anchor/domain/aggregates/config_test.exs:124: (test)

.........
Finished in 0.07 seconds (0.07s async, 0.00s sync)
26 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/config.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/config.ex" was set to the future, resetting to now
```

## AG-NONAME — an attribute with no name is accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (no name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

.....................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/config.ex" was set to the future, resetting to now
```

## AG-STRNAME — a non-atom name is accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (a string name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

.................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-ERLNAME — an Erlang atom name is accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (an Erlang atom name) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

.............
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-SCHEMAS — schemas of any shape are accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (a schema that is a string) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
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
                kind: :empty_aggregate,
                subject: "A",
                site: {:attribute,
                 AnchorFixtures.Aggregates.IndexTest.X, "lib/x.ex",
                 1},
                aggregates: ["A"],
                detail: nil
              }
            ]
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

......
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-TABLES — tables of any shape are accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (a table that is an atom) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

..........
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-OWNERBOOL — a non-boolean owner is accepted

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I10: malformed attribute (owner not a boolean) contributes nothing (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:315
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :malformed_attribute,
                subject: AnchorFixtures.Aggregates.IndexTest.X,
                detail: got
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:322: (test)

.......
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-UNDECL — an undeclared name has an owner

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test aggregate_of/2 and owners/2 an undeclared name has no owners (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:416
     Assertion with == failed
     code:  assert Index.owners(%Index{}, "Nope") == []
     left:  ["Nope"]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:417: (test)

......................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-NOCORE — a __schema__/1 with no Core body reads as a table

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test table_of/2 a __schema__/1 with no Core body is unknown (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:387
     Assertion with == failed
     code:  assert Index.table_of(graph, @s1) == :unknown
     left:  {:ok, "t"}
     right: :unknown
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:390: (test)

......................
Finished in 0.3 seconds (0.3s async, 0.00s sync)
29 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/domain/aggregates/index.ex" was set to the future, resetting to now
```

## AG-NOSCHEMA — a module with no __schema__/1 reads as unknown

`lib/anchor/domain/aggregates/index.ex`, tests: test/anchor/domain/aggregates/index_test.exs. First failing test, verbatim:

```
  1) test build/2 I7: a module with no __schema__/1 is not_a_schema (Anchor.Domain.Aggregates.IndexTest)
     test/anchor/domain/aggregates/index_test.exs:260
     match (=) failed
     code:  assert [%DeclarationIssue{kind: :not_a_schema, subject: @plain}] = index.issues
     left:  [
              %Anchor.Domain.Aggregates.DeclarationIssue{
                kind: :not_a_schema,
                subject: AnchorFixtures.Aggregates.IndexTest.Plain
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/aggregates/index_test.exs:262: (test)

..............
```

## RL-CLEAN — a clean index still says it checks nothing

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R3: an attribute issue outside the selector is not reported; a config one still is (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:143
     match (=) failed
     code:  assert [%{key: "aggregates|.anchor.yml|unknown_schema A Nope"}] = outside
     left:  [%{key: "aggregates|.anchor.yml|unknown_schema A Nope"}]
     right: [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: "Nope",
                message: "Nope in aggregate A names no module in this project. Fix: correct the module name or remove it: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :rule,
                key: "aggregates|.anchor.yml|unknown_schema A Nope",
                rule_id: "aggregates",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: nil,
                trigger: "aggregate_declarations",
                message: "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]",
                filename: ".anchor.yml",
                kind: :rule,
                key: "aggregates|.anchor.yml|checks nothing",
                rule_id: "aggregates",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:160: (test)

..
```

## RL-SHAPETXT — the shape text drifts

`lib/anchor/domain/graph_rules/aggregate_declarations.ex`, tests: test/anchor/domain/graph_rules/aggregate_declarations_test.exs. First failing test, verbatim:

```
  1) test check/2 R2: zero aggregates declared is one violation on .anchor.yml: it checks nothing (Anchor.Domain.GraphRules.AggregateDeclarationsTest)
     test/anchor/domain/graph_rules/aggregate_declarations_test.exs:126
     Assertion with == failed
     code:  assert v.message ==
              "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml " <>
                "or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: " <> @shape
     left:  "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate name: <Aggregate>, schemas: [<Schema>...]"
     right: "aggregate_declarations checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]"
     stacktrace:
       test/anchor/domain/graph_rules/aggregate_declarations_test.exs:132: (test)

..
```

## MC-NONAME — a missing name is filled in

`lib/anchor/aggregate.ex`, tests: test/anchor/aggregate_test.exs. First failing test, verbatim:

```
  1) test __using__/1 M4: no name raises ArgumentError naming the key and the shape (Anchor.AggregateTest)
     test/anchor/aggregate_test.exs:94
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn ->
     stacktrace:
       test/anchor/aggregate_test.exs:101: (test)

..........
Finished in 0.1 seconds (0.1s async, 0.00s sync)
13 tests, 1 failure
warning: mtime (modified time) for "lib/anchor/aggregate.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/graph_rules/aggregate_declarations.ex" was set to the future, resetting to now
```

## MC-LITERAL — any value is a module name

`lib/anchor/aggregate.ex`, tests: test/anchor/aggregate_test.exs. First failing test, verbatim:

```
  1) test __using__/1 M4: a non-literal schema raises ArgumentError naming the key and the shape (Anchor.AggregateTest)
     test/anchor/aggregate_test.exs:94
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn ->
     stacktrace:
       test/anchor/aggregate_test.exs:101: (test)
```
