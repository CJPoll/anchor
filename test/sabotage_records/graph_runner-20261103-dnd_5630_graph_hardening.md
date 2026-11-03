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

---

# Sabotage record — umbrella source paths keyed from the umbrella root (DND-5637)

- **Domain:** graph_runner (one combined record: `ProjectFile.place/3` and the builder's
  `source_dirs:` are the `builder` domain's, labelled below)
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.ProjectFile.place/3` (builder domain),
  `Anchor.Domain.Graph.Builder` (`project_file/3`, builder domain), `Anchor.Managers.Graph`
  (`place/2`, `source_facts/3`), `Mix.Tasks.Anchor.Graph` (`Request.source_dirs`)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/domain/graph/project_file_test.exs test/anchor/managers/graph_test.exs
  test/mix/tasks/anchor_graph_test.exs test/anchor/domain/graph/builder_test.exs`, each mutation applied
  alone and restored byte-for-byte (sha256 compared) after its run.

## The premise, measured

The ticket's premise was unverified. A real two-app umbrella (`apps_path: "apps"`, apps `alpha` and
`beta`, each `build_path: "../../_build"`) built with `mix compile` on Elixir 1.19.4 / OTP 28 writes
app-relative paths; `file` is absolute:

```
_build/dev/lib/alpha/ebin/Elixir.Alpha.beam relative_file=lib/alpha.ex file=<umbrella>/apps/alpha/lib/alpha.ex
_build/dev/lib/beta/ebin/Elixir.Beta.B.beam relative_file=lib/beta/b.ex file=<umbrella>/apps/beta/lib/beta/b.ex
apps_paths: %{beta: "apps/beta", alpha: "apps/alpha"}
```

So the premise held: `mix anchor.graph` at the umbrella root read `lib/alpha.ex` against the root (a source
read of the wrong file, or `:enoent`), and an `apps/alpha/**` selector matched nothing. The task now passes
`Mix.Project.apps_paths/0` as `Request.source_dirs`, and every relative path is read against its app's
directory and keyed from the umbrella root (`apps/alpha/lib/alpha.ex`). `:relative_file` stays the input
(not the absolute `:file`), so a checkout built elsewhere still keys the same.

## The regression, on the unfixed code

With `Request.source_dirs` added and nothing reading it, the three files ran `45 tests, 6 failures`:

```
  5) test run/2 a two-app umbrella (DND-5637) each app's paths are keyed umbrella-root-relative (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:668
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.GraphTest."test run/2 a two-app umbrella (DND-5637) each app's paths are keyed umbrella-root-relative"/1
         # 1
         "/proj"
         # 2
         ["lib/alpha.ex", "lib/beta/b.ex"]

  6) test an umbrella's app-relative source paths are keyed from the umbrella root (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:213
     ** (FunctionClauseError) no function clause matching in anonymous fn/1 in Mix.Tasks.Anchor.GraphTest."test an umbrella's app-relative source paths are keyed from the umbrella root"/1
         # 1
         [anchor: "/home/cjpoll/.local/worktrees/anchor/dnd-5630-graph-hardening/_build/test/lib/anchor/ebin"]
```

After: the four files and the integration tests run `82 tests, 1 failure`, the one
`CfaSelfTest`, a whole-program analysis of Anchor's own code, timing out at the 2000 ms bound this run
imposes (untouched; it passes under the default bound).

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `place/3` reads a relative path against the root, ignoring the directory (builder domain) | place/3's umbrella row, the Manager umbrella test, the task umbrella test | `67 tests, 3 failures` |
| B | the Manager reads every path against the root (no `source_dirs`) | the Manager and task umbrella tests | `67 tests, 2 failures` |
| C | the builder keys every path against the root (builder domain) | the Manager and task umbrella tests | `67 tests, 2 failures` |
| D | the task passes no `source_dirs` | the task umbrella test | `67 tests, 1 failure` |
| E | an absolute directory is accepted | "an absolute directory is refused" | `67 tests, 1 failure` |

## Failure strings (verbatim)

### A

```
     test/anchor/domain/graph/project_file_test.exs:67
     Assertion with == failed
     code:  assert ProjectFile.place("lib/alpha.ex", @root, "apps/alpha") ==
              {:inside_root, "apps/alpha/lib/alpha.ex"}
     left:  {:inside_root, "lib/alpha.ex"}
     right: {:inside_root, "apps/alpha/lib/alpha.ex"}
```

### B

```
     test/anchor/managers/graph_test.exs:672
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.GraphTest."test run/2 a two-app umbrella (DND-5637) each app's paths are keyed umbrella-root-relative"/1
         # 1
         "/proj"
```

### C

```
     test/anchor/managers/graph_test.exs:672
     Assertion with == failed
     code:  assert Enum.map(report.findings, &{&1.rule_id, &1.file}) == [
              {"alpha", "apps/alpha/lib/alpha.ex"},
              {"beta", "apps/beta/lib/beta/b.ex"}
            ]
     left:  [
              nil: "lib/alpha.ex",
              nil: "lib/beta/b.ex",
```

### D

```
  1) test an umbrella's app-relative source paths are keyed from the umbrella root (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:213
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Mix.Tasks.Anchor.GraphTest."test an umbrella's app-relative source paths are keyed from the umbrella root"/1
         # 1
         "/home/cjpoll/.local/worktrees/anchor/dnd-5630-graph-hardening"
```

### E

```
  1) test place/3 with the directory the compiler ran in an absolute directory is refused: it is relative to the root (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:88
     Expected exception ArgumentError but nothing was raised
```

---

# Sabotage record — the project root is in the graph artifact's key (DND-5638)

- **Domain:** graph_runner
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphKey.key/5` (now root, beams, sources, config, version) and
  `Anchor.Managers.Graph` (`write_artifact/5`: the root it passes)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph_key_test.exs
  test/anchor/managers/graph_test.exs`, each mutation applied alone and restored byte-for-byte (sha256
  compared) after its run.

The key covered the beams, the source facts, the config and the version, but not the root. The graph's
facts name source paths relative to the root, so two checkouts with the same build output shared a key while
their paths meant different files. The root is now the key's second framed part. It is the root's real
path as the task gives it: `File.cwd!/0` is `getcwd(3)`'s physical path, symlinks resolved by the kernel,
and the Manager passes it through `Path.expand/1` (a trailing slash or `..` keys the same). Domain does
no IO to resolve a symlink.

## The regression, on the unfixed code

The two files ran `42 tests, 12 failures`: the eleven `GraphKey` tests on the new `key/5`
(`UndefinedFunctionError ... key/5 is undefined or private. Did you mean: * key/4`) and the Manager's:

```
 12) test run/2 graph artifact the key changes with the project root (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:740
     Refute with == failed, both sides are exactly equal
     code: refute key.("/checkout-a") == key.("/checkout-b")
     left: "0839eb03d9608415835e7934bf5cac180b9c6acd15477e248c9d10ef044ef1c3"
```

After: the two files, the task test and the canary run `53 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `key/5` ignores the root | "the same inputs under different roots give different keys", the Manager's root test | `42 tests, 2 failures` |
| B | the root and the version are hashed unframed | "moving bytes between the root and the version changes the key" | `42 tests, 1 failure` |
| C | the Manager passes a constant root | the Manager's root test | `42 tests, 1 failure` |

B first survived: the framing test moved bytes so that the unframed concatenations still differed. It now
uses `("/work", "v1")` against `("work", "v1/")`, whose unframed `version <> root` is `v1/work` for both,
and B fails it.

## Failure strings (verbatim)

### A

```
  1) test root the same inputs under different roots give different keys (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:90
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key("/work/a", @entries, [], "c", "v") == GraphKey.key("/work/b", @entries, [], "c", "v")
     left: "5ca8004a98abf62affcf25b006a3811a2183e415a5a95834bca44c3a650e1119"
```

### B

```
  1) test root moving bytes between the root and the version changes the key (the root is framed) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:100
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key("/work", [], [], "", "v1") == GraphKey.key("work", [], [], "", "v1/")
     left: "d60826c6091f3051d702910fe94b612aa358bbe3ceed5f70dc4d136d278b7c63"
```

### C

```
  1) test run/2 graph artifact the key changes with the project root (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:740
     Refute with == failed, both sides are exactly equal
     code: refute key.("/checkout-a") == key.("/checkout-b")
     left: "e286f6af3a45068580caa6caeb09e9a77951ca4c677be368825e147d09bea47e"
```

---

# Sabotage record — an empty uses map is a measured "uses nothing" (DND-5636)

- **Domain:** graph_runner
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** the types `Anchor.Domain.Graph.SourceFacts.t/0` (`uses`) and
  `Anchor.Adapters.SourceSource.read/2`'s return, as Hammox checks them at the port
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/adapters/source_reader_test.exs test/anchor/managers/graph_test.exs
  test/anchor/domain/graph/source_facts_test.exs`, each mutation applied alone and restored byte-for-byte
  (sha256 compared) after its run.

A source file with no literal `defmodule` (a DSL file whose modules are macro output) has
`uses: %{}`. `SourceFacts.t/0` typed it `%{String.t() => [String.t()]}`; in an Elixir typespec a bare
non-literal key is *required*, so the type said "at least one entry" and Hammox refused the empty map at
the `SourceSource` port. An empty map is a measured "uses nothing", distinct from unknown (an unparseable
file, `{:error, :unparseable}`, which the builder reads as `generated?: :unknown`). The key is now
`optional(String.t())`. The same class held for the port's own return map, which a read of no paths makes
empty (seen in DND-5630's mutation D), and for the builder's `source_facts` and `Request.source_dirs`
specs; each is `optional` now.

## The regression, on the unfixed code

The two files ran `34 tests, 2 failures`:

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     Returned value %{"lib/broken.ex" => {:error, :unparseable}, "lib/dsl.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Map value %{uses: %{}, defmodules: [], nonliteral_defmodule?: false} for key "lib/dsl.ex" does not match map value type Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.

  2) test run/2 source facts with no uses an empty uses map is read as facts, an unparseable file as unknown (Anchor.Managers.GraphTest)
     Returned value %{"lib/my_app/domain/user.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}, "lib/my_app/managers/accounts.ex" => {:error, :unparseable}} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
```

After: the three files and the task test run `55 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `SourceFacts.t/0`'s `uses` key is required again | the adapter's port-type test, the Manager's no-uses test | `47 tests, 2 failures` |
| B | the port's return map key is required again | the adapter's port-type test (the read of no paths) | `47 tests, 1 failure` |

## Failure strings (verbatim)

### A

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:36
     ** (Hammox.TypeMatchError) 
     Returned value %{"lib/broken.ex" => {:error, :unparseable}, "lib/dsl.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}} does not match type %{ optional(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Map value %{uses: %{}, defmodules: [], nonliteral_defmodule?: false} for key "lib/dsl.ex" does not match map value type Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.
```

### B

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:36
     ** (Hammox.TypeMatchError) 
     Returned value %{} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Could not find a map entry matching required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.
```
