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
