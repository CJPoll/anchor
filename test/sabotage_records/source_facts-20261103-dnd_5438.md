# Sabotage record — SourceFacts literal defmodules and uses (DND-5438)

- **Domain:** source_facts
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Graph.SourceFacts` (`from_source/2`)
- **Suite run:** `mix test test/anchor/domain/graph/source_facts_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run, and the tree was clean).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| SF-A | descend into quote bodies (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a defmodule or use inside a quote is macro output, not a literal of this file |
| SF-B | do not qualify nested modules (`lib/anchor/domain/graph/source_facts.ex`) | 2 | from_source/2 a literal use is scoped to its own module's body; from_source/2 nested modules are qualified through nesting, in source order |
| SF-C | join alias parts with / (`lib/anchor/domain/graph/source_facts.ex`) | 2 | from_source/2 a variable named like a special form is read as a variable; from_source/2 a top-level module is a literal defmodule |
| SF-D | a DSL call (defthing) is read as a defmodule (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a module a macro emits is not a literal defmodule |
| SF-E | an atom module name is not kept as written (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a module named by an atom keeps its name |
| SF-F | unparseable text reads as empty facts (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 unparseable text is an error, never empty facts |
| SF-G | __MODULE__.Child is not resolved against the enclosing module (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 __MODULE__ at the head of a nested name resolves to the enclosing module |
| SF-H | the file never says it has a non-literal defmodule (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a computed name, and every module inside it, is not collected; the file says so |
| SF-I | a module nested in a non-literal one is named (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a computed name, and every module inside it, is not collected; the file says so |
| SF-J | a variable named use is read as a use (`lib/anchor/domain/graph/source_facts.ex`) | 1 | from_source/2 a variable named like a special form is read as a variable |

## SF-A — descend into quote bodies

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a defmodule or use inside a quote is macro output, not a literal of this file (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:65
     match (=) failed
     code:  assert %{defmodules: ["Mac"], uses: %{"Mac" => []}} = SourceFacts.from_source("a.ex", text)
     left:  %{defmodules: ["Mac"], uses: %{"Mac" => []}}
     right: %{
              uses: %{"Mac" => ["Agent"], "Mac.Generated" => []},
              defmodules: ["Mac", "Mac.Generated"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:78: (test)
```

## SF-B — do not qualify nested modules

Run summary: `10 tests, 2 failures`

```
  1) test from_source/2 a literal use is scoped to its own module's body (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:37
     Assertion with == failed
     code:  assert uses["A.B"] == ["Agent"]
     left:  nil
     right: ["Agent"]
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:50: (test)
..
```

```
  2) test from_source/2 nested modules are qualified through nesting, in source order (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:22
     match (=) failed
     code:  assert %{defmodules: ["A", "A.B", "C"]} = SourceFacts.from_source("a.ex", text)
     left:  %{defmodules: ["A", "A.B", "C"]}
     right: %{
              uses: %{"A" => [], "B" => [], "C" => []},
              defmodules: ["A", "B", "C"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:33: (test)
```

## SF-C — join alias parts with /

Run summary: `10 tests, 2 failures`

```
  1) test from_source/2 a variable named like a special form is read as a variable (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:121
     variable __CALLER__
     code: for name <- @variable_names do
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:134: anonymous fn/2 in Anchor.Domain.Graph.SourceFactsTest."test from_source/2 a variable named like a special form is read as a variable"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph/source_facts_test.exs:122: (test)
.
```

```
  2) test from_source/2 a top-level module is a literal defmodule (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:16
     match (=) failed
     code:  assert %{defmodules: ["A.B"], uses: %{"A.B" => []}} =
              SourceFacts.from_source("a.ex", "defmodule A.B do end")
     left:  %{defmodules: ["A.B"], uses: %{"A.B" => []}}
     right: %{
              uses: %{"A/B" => []},
              defmodules: ["A/B"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:17: (test)
```

## SF-D — a DSL call (defthing) is read as a defmodule

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a module a macro emits is not a literal defmodule (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:54
     match (=) failed
     code:  assert %{defmodules: ["A"]} = SourceFacts.from_source("a.ex", text)
     left:  %{defmodules: ["A"]}
     right: %{
              uses: %{":x" => [], "A" => []},
              defmodules: ["A", ":x"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:61: (test)
```

## SF-E — an atom module name is not kept as written

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a module named by an atom keeps its name (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:81
     match (=) failed
     code:  assert %{defmodules: ["erl_style"], nonliteral_defmodule?: false} =
              SourceFacts.from_source("a.ex", "defmodule :erl_style do\nend\n")
     left:  %{defmodules: ["erl_style"], nonliteral_defmodule?: false}
     right: %{
              uses: %{"ERL_STYLE" => []},
              defmodules: ["ERL_STYLE"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:82: (test)
```

## SF-F — unparseable text reads as empty facts

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 unparseable text is an error, never empty facts (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:145
     match (=) failed
     code:  assert {:error, :unparseable} = SourceFacts.from_source("a.ex", "defmodule A do")
     left:  {:error, :unparseable}
     right: %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:146: (test)
```

## SF-G — __MODULE__.Child is not resolved against the enclosing module

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 __MODULE__ at the head of a nested name resolves to the enclosing module (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:86
     Assertion with == failed
     code:  assert SourceFacts.from_source("a.ex", text) == %{
              defmodules: ["A", "A.Child"],
              uses: %{"A" => [], "A.Child" => ["Agent"]},
              nonliteral_defmodule?: false
            }
     left:  %{
              uses: %{"A" => [], "Child" => ["Agent"]},
              defmodules: ["A", "Child"],
              nonliteral_defmodule?: false
            }
     right: %{
              uses: %{"A" => [], "A.Child" => ["Agent"]},
              defmodules: ["A", "A.Child"],
              nonliteral_defmodule?: false
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:95: (test)
```

## SF-H — the file never says it has a non-literal defmodule

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a computed name, and every module inside it, is not collected; the file says so (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:103
     Assertion with == failed
     code:  assert SourceFacts.from_source("a.ex", text) == %{
              defmodules: ["A"],
              uses: %{"A" => []},
              nonliteral_defmodule?: true
            }
     left:  %{
              uses: %{"A" => []},
              defmodules: ["A"],
              nonliteral_defmodule?: false
            }
     right: %{
              uses: %{"A" => []},
              defmodules: ["A"],
              nonliteral_defmodule?: true
            }
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:115: (test)
```

## SF-I — a module nested in a non-literal one is named

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a computed name, and every module inside it, is not collected; the file says so (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:103
     ** (ArgumentError) construction of binary failed: segment 1 of type 'binary': expected a binary but got: :nonliteral
     code: assert SourceFacts.from_source("a.ex", text) ==
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/graph/source_facts.ex:132: Anchor.Domain.Graph.SourceFacts.qualify/2
       (anchor 0.1.0) lib/anchor/domain/graph/source_facts.ex:126: Anchor.Domain.Graph.SourceFacts.module_name/2
       (anchor 0.1.0) lib/anchor/domain/graph/source_facts.ex:68: Anchor.Domain.Graph.SourceFacts.walk/3
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) lib/anchor/domain/graph/source_facts.ex:51: Anchor.Domain.Graph.SourceFacts.collect/1
       test/anchor/domain/graph/source_facts_test.exs:115: (test)
```

## SF-J — a variable named use is read as a use

Run summary: `10 tests, 1 failure`

```
  1) test from_source/2 a variable named like a special form is read as a variable (Anchor.Domain.Graph.SourceFactsTest)
     test/anchor/domain/graph/source_facts_test.exs:121
     variable use
     code: for name <- @variable_names do
     stacktrace:
       test/anchor/domain/graph/source_facts_test.exs:134: anonymous fn/2 in Anchor.Domain.Graph.SourceFactsTest."test from_source/2 a variable named like a special form is read as a variable"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/graph/source_facts_test.exs:122: (test)
```

## Traps

- A first run of BR-B, BR-C, CW-H and SF-B failed to compile under `warnings_as_errors` (an unreachable clause, an unused alias, unused variables) and printed no ExUnit summary; the driver records `NO SUMMARY` for such a run, and each mutation was rewritten to compile and re-run. Read a sabotage run's test count, never its exit code alone.
