# Sabotage records: graph runner (branch dnd-5648-graph-followups)

- **Domain:** graph_runner
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- One section per ticket of the batch, in commit order.

## DND-5655: an absolute apps_path is keyed or refused, never raised

**Code under test:** `Anchor.Domain.Graph.ProjectFile.source_dirs/2`, its call in `Anchor.Managers.Graph.run/2`, and `Anchor.Domain.Failures.graph_apps_path_outside/3`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). AP-R is the new tests on the unfixed code: the Manager raised `ArgumentError` (`the directory must be relative to the root, got: "/proj/apps/alpha"`) with no `Fix:` line. With every source restored: `74 tests, 0 failures` over project_file, the graph Manager, failures and task tests.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AP-R | regression: the unfixed code, with the new tests (`lib/anchor/managers/graph.ex`) | `project_file_test.exs`, `graph_test.exs` | `47 tests, 5 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine; place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app; place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |
| AP-A | the Manager does not key the app directories (`lib/anchor/managers/graph.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one |
| AP-B | an absolute dir under the root is kept absolute (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative; run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one |
| AP-C | a dir outside the root is keyed through .. instead of refused (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |
| AP-D | a sibling sharing the root's prefix reads as under it (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 1 failure` (red) | place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app |
| AP-E | the root itself is not made "." (`lib/anchor/domain/graph/project_file.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 1 failure` (red) | place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine |
| AP-F | the refusal has no Fix: line (`lib/anchor/domain/failures.ex`) | `project_file_test.exs`, `graph_test.exs`, `failures_graph_test.exs` | `63 tests, 2 failures` (red) | every graph message is fail-closed, on its file, with its subject and a Fix: line; run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise |

### AP-R: regression: the unfixed code, with the new tests

Run summary: `47 tests, 5 failures`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:105
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(%{alpha: "/work/my_app"}, @root) == {:ok, %{alpha: "."}}
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/work/my_app"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:106: (test)

...



  2) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/elsewhere/alpha", beta: "apps/beta", gamma: "/work/my_app/../x"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:99: (test)







  3) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:90
     ** (UndefinedFunctionError) function Anchor.Domain.Graph.ProjectFile.source_dirs/2 is undefined or private
     code: assert ProjectFile.source_dirs(
     stacktrace:
       (anchor 0.1.0) Anchor.Domain.Graph.ProjectFile.source_dirs(%{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"}, "/work/my_app")
       test/anchor/domain/graph/project_file_test.exs:91: (test)

...................................



  4) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:59: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:293: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:290: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:216: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)







  5) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.411.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:196: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:114: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

...
```

### AP-A: the Manager does not key the app directories

Run summary: `63 tests, 2 failures`

```text


  1) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.364.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:210: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:115: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

.........................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:99: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:307: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:304: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:230: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)

.....
```

### AP-B: an absolute dir under the root is kept absolute

Run summary: `63 tests, 2 failures`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir under the root is made relative (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:90
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"},
              @root
            ) == {:ok, %{alpha: "apps/alpha", beta: "apps/beta"}}
     left:  {:ok, %{alpha: "/work/my_app/apps/alpha", beta: "apps/beta"}}
     right: {:ok, %{alpha: "apps/alpha", beta: "apps/beta"}}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:91: (test)

.................................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path under the root keys as its relative one (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:808
     ** (ArgumentError) the directory must be relative to the root, got: "/proj/apps/alpha"
     code: report = Graph.run(request, deps())
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/project_file.ex:99: Anchor.Domain.Graph.ProjectFile.place/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:307: anonymous fn/2 in Anchor.Managers.Graph.source_facts/3
       (elixir 1.19.4) lib/enum.ex:4497: Enum.flat_map_list/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:304: Anchor.Managers.Graph.source_facts/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:230: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_test.exs:828: (test)

.......................
```

### AP-C: a dir outside the root is keyed through .. instead of refused

Run summary: `63 tests, 2 failures`

```text






  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{
                alpha: "/elsewhere/alpha",
                beta: "apps/beta",
                gamma: "/work/my_app/../x",
                delta: "/work/my_app_other/delta"
              },
              @root
            ) ==
              {:error,
               alpha: "/elsewhere/alpha", delta: "/work/my_app_other/delta", gamma: "/work/my_app/../x"}
     left:  {:ok,
             %{
               alpha: "../../elsewhere/alpha",
               beta: "apps/beta",
               gamma: "../x",
               delta: "../my_app_other/delta"
             }}
     right: {:error,
             [
               alpha: "/elsewhere/alpha",
               delta: "/work/my_app_other/delta",



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.436.0>
     code: report = Graph.run(request, deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:210: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:115: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_test.exs:845: (test)

.........
```

### AP-D: a sibling sharing the root's prefix reads as under it

Run summary: `63 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: an absolute dir outside the root is refused, naming each app (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:98
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(
              %{
                alpha: "/elsewhere/alpha",
                beta: "apps/beta",
                gamma: "/work/my_app/../x",
                delta: "/work/my_app_other/delta"
              },
              @root
            ) ==
              {:error,
               alpha: "/elsewhere/alpha", delta: "/work/my_app_other/delta", gamma: "/work/my_app/../x"}
     left:  {:error, [alpha: "/elsewhere/alpha", gamma: "/work/my_app/../x"]}
     right: {:error,
             [
               alpha: "/elsewhere/alpha",
               delta: "/work/my_app_other/delta",
               gamma: "/work/my_app/../x"
             ]}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:99: (test)

.......................................................
```

### AP-E: the root itself is not made "."

Run summary: `63 tests, 1 failure`

```text


  1) test place/3 with the directory the compiler ran in source_dirs/2: the root itself, or none, is fine (Anchor.Domain.Graph.ProjectFileTest)
     test/anchor/domain/graph/project_file_test.exs:116
     Assertion with == failed
     code:  assert ProjectFile.source_dirs(%{alpha: "/work/my_app"}, @root) == {:ok, %{alpha: "."}}
     left:  {:ok, %{alpha: "/work/my_app"}}
     right: {:ok, %{alpha: "."}}
     stacktrace:
       test/anchor/domain/graph/project_file_test.exs:117: (test)

...........................................................
```

### AP-F: the refusal has no Fix: line

Run summary: `63 tests, 2 failures`

```text


  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:274
     graph_apps_path_outside
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       test/anchor/domain/failures_graph_test.exs:277: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:275: (test)

........................



  2) test run/2 a two-app umbrella (DND-5637) an absolute apps_path outside the root is COULD NOT MEASURE with a Fix:, never a raise (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:833
     Assertion with =~ failed
     code:  assert message =~ "Fix: "
     left:  "COULD NOT MEASURE: the apps_path of :alpha is /elsewhere/alpha, outside the project root /proj, so its source paths cannot be keyed against the root. Set apps_path in the umbrella's mix.exs to a directory under the project root (Mix's default, \"apps\"), and run mix anchor.graph from that root."
     right: "Fix: "
     stacktrace:
       test/anchor/managers/graph_test.exs:853: (test)

........................
```

