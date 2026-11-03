# Sabotage record — SourceFacts literal defmodules and uses (DND-5438)

- **Domain:** source_facts
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.SourceFacts` (`from_source/2`)
- **Suite run:** `mix test test/anchor/domain/graph/source_facts_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run: only the unmutated edits of the branch showed). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| SF-A | descend into quote bodies (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a defmodule or use inside a quote is macro output, not a literal of this file |
| SF-B | do not qualify nested modules (`lib/anchor/domain/graph/source_facts.ex`) | 2 | from_source/2 nested modules are qualified through nesting, in source order; from_source/2 a literal use is scoped to its own module's body |

## SF-A — descend into quote bodies

Run summary: `7 tests, 1 failure`

```
  1) test from_source/2 a defmodule or use inside a quote is macro output, not a literal of this file (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:60
     match (=) failed
     code:  assert %{defmodules: ["Mac"], uses: %{"Mac" => []}} = SourceFacts.from_source("a.ex", text)
     left:  %{defmodules: ["Mac"], uses: %{"Mac" => []}}
     right: %{
              uses: %{"Mac" => ["Agent"], "Mac.Generated" => []},
              defmodules: ["Mac", "Mac.Generated"]
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:73: (test)
```

## SF-B — do not qualify nested modules

Run summary: `7 tests, 2 failures`

```
  1) test from_source/2 nested modules are qualified through nesting, in source order (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:17
     match (=) failed
     code:  assert %{defmodules: ["A", "A.B", "C"]} = SourceFacts.from_source("a.ex", text)
     left:  %{defmodules: ["A", "A.B", "C"]}
     right: %{
              uses: %{"A" => [], "B" => [], "C" => []},
              defmodules: ["A", "B", "C"]
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:28: (test)
.
```

```
  2) test from_source/2 a literal use is scoped to its own module's body (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:32
     Assertion with == failed
     code:  assert uses["A.B"] == ["Agent"]
     left:  nil
     right: ["Agent"]
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:45: (test)
```
