# Sabotage record — modules compiled from outside the root are enforced (DND-5630)

- **Domain:** graph_runner (one combined record for this ticket: `ProjectFile` and the builder's
  `build/3` are the `builder` domain's, labelled below)
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.ProjectFile.place/2` (builder domain),
  `Anchor.Domain.Graph.Builder` (`project_file/2`, builder domain), `Anchor.Managers.Graph`
  (`read_beams/2`, `source_facts/3`, `outside_root_count/2`), `Anchor.Domain.GraphReport` (the
  `outside_root` count)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/domain/graph/project_file_test.exs test/anchor/managers/graph_test.exs
  test/anchor/domain/graph_report_test.exs test/mix/tasks/anchor_graph_test.exs
  test/anchor/domain/graph/builder_test.exs`, each mutation applied alone and restored byte-for-byte
  (sha256 compared) after its run.

DND-5588 left a module whose source sits outside the root out of the graph: counted, named in a
`[report]` note, and a run of only such modules was COULD NOT MEASURE. Its premise was wrong: the runner
reads only the project's own ebins, so such a module (`elixirc_paths: ["../shared"]`) is project code, and
a violation in it never blocked. Membership is now the ebin the beam came from. `ProjectFile.place/2` keys
every path against the root, through `..` for one outside it (`/work/shared/foo.ex` against `/work/my_app`
is `../shared/foo.ex`); the Manager keeps every beam, reads every module's `SourceFacts` by that key, and
counts the outside ones in the summary as `(<n> outside the root)` (JSON `outside_root`). The two
DND-5588 messages (`graph_all_outside_root/3`, `graph_module_outside_root/3`) are gone with their
README rows.

## The regression, on the unfixed code

The six files ran `93 tests, 21 failures` (the report and happy-path tests failed on the renamed count
key; these are the behaviour ones):

```
 14) test run/2 source paths outside the project root (DND-5588, DND-5630) an outside-root module no bucket selects fails the run on its ../ path (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:529
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1

 21) test a module compiled from outside the root is enforced on its ../ path (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:159
     Assertion with == failed
     code:  assert catch_exit(Graph.run([], opts())) == {:shutdown, 1}
     left:  {:shutdown, 3}
     right: {:shutdown, 1}
```

After: the five files run `78 tests, 0 failures`; the full suite `1798 tests, 1 failure`, the one an
untouched `InlinesTest` test that loads every Elixir module through `code_server` and timed out at the
2000 ms bound this run imposes (it passes under the default bound; see the batch report).

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `side/1` reads only `..` itself as outside (no `../` prefix) | the ProjectFile table and root test, all-outside, unclassified-outside, the task test | `78 tests, 5 failures` |
| B | an outside path keeps the beam's absolute path (DND-5588's key) | ProjectFile (2), the builder's outside test, five Manager outside tests, the task test | `78 tests, 9 failures` |
| C | the Manager drops beams whose source is under `/shared` (DND-5588's exclusion) | unclassified-outside, enforced-outside, all-outside, source-facts, positive control | `78 tests, 5 failures` |
| D | `source_facts/3` reads only inside files | all-outside, source-facts, the task test | `78 tests, 3 failures` |
| E | the builder keys an outside module by the beam's absolute path (builder domain) | the builder's outside test and six Manager and task tests | `78 tests, 7 failures` |
| F | a relative path is expanded with `Path.expand/2` (reads `~` as home) | the ProjectFile table's `~/x.ex` row | `78 tests, 1 failure` |
| G | the summary never notes `outside_root` | the report's count test, unclassified-outside, the task test | `78 tests, 3 failures` |

D also showed that the `SourceSource` port's return type, `%{String.t() => ...}`, is a *required*
key in Elixir typespecs, so Hammox refused the empty map a run with no source file returns. That is the
class DND-5636 fixes (an empty map is a measured "nothing"); it is fixed there.

## Failure strings (verbatim)

### A

```
  1) test the table (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:15
     "/work/shared/foo.ex"
     code: for {file, expected} <- [
```

### B

```
  1) test a root given with a trailing slash or a .. places the same (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:49
     Assertion with == failed
     code:  assert ProjectFile.place("/work/shared/x.ex", "/work/my_app/") == {:outside_root, "../shared/x.ex"}
     left:  {:outside_root, "/work/shared/x.ex"}
     right: {:outside_root, "../shared/x.ex"}
```

### C

```
  1) test run/2 source paths outside the project root (DND-5588, DND-5630) an outside-root module no bucket selects fails the run on its ../ path (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:529
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
```

### D

```
  1) test run/2 source paths outside the project root (DND-5588, DND-5630) a run whose every module is outside the root is measured, never COULD NOT MEASURE (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:593
     ** (Hammox.TypeMatchError) 
     Returned value %{} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
```

### E

```
  1) test run/2 source paths outside the project root (DND-5588, DND-5630) a run whose every module is outside the root is measured, never COULD NOT MEASURE (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:593
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
```

### F

```
  1) test the table (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:15
     "~/x.ex"
     code: for {file, expected} <- [
```

### G

```
  1) test render/2 modules outside the root (DND-5588, DND-5630) are counted in the summary and the JSON when there are any (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:178
     Assertion with == failed
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 12 modules (4 outside the root) in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
```
