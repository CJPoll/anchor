# Sabotage record — the graph runner's fail-closed messages (DND-5440)

- **Domain:** failures
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** the graph functions of `Anchor.Domain.Failures` (DND-5440)
- **Suite run:** Each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red: a non-zero ExUnit result naming the test the mutation is meant to break.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| FA-A | the unclassified Fix: no longer points at explain (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs`, `classification_test.exs` | `30 tests, 2 failures` | every graph message is fail-closed, on its file, with its subject and a Fix: line; classify_all/3 an unclassified module is one issue on its file and defmodule line, with Fix: and explain |
| FA-B | walk_crashed falls to the generic unreadable text (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `13 tests, 1 failure` | graph_unreadable/1 {:walk_crashed, "FunctionClauseError: y"}: on the beam path, naming the module, with its Fix: |
| FA-C | duplicate_module falls to the generic text (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs` | `13 tests, 1 failure` | graph_unreadable/1 {:duplicate_module, "other/ebin/Elixir.MyApp.X.beam"}: on the beam path, naming the module, with its Fix: |

## FA-A — the unclassified Fix: no longer points at explain

Run summary: `30 tests, 2 failures`

```

  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:162
     unclassified: "mix anchor.explain lib/x.ex" in MyApp.X is in no architecture bucket. Fix: add a selector that matches lib/x.ex to the bucket this module belongs in (see the README for the candidates).
     code: for {name, violation, file, texts} <- rows() do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:167: anonymous fn/2 in Anchor.Domain.FailuresGraphTest."test every graph message is fail-closed, on its file, with its subject and a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_graph_test.exs:163: (test)

................
```

## FA-B — walk_crashed falls to the generic unreadable text

Run summary: `13 tests, 1 failure`

```

  1) test graph_unreadable/1 {:walk_crashed, "FunctionClauseError: y"}: on the beam path, naming the module, with its Fix: (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:49
     Assertion with =~ failed
     code:  assert message =~ text
     left:  "MyApp.X could not be read ({:walk_crashed, \"FunctionClauseError: y\"}). Fix: this is an Anchor bug; file it with this line."
     right: "Anchor crashed walking it (FunctionClauseError: y)"
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:53: (test)

....
```

## FA-C — duplicate_module falls to the generic text

Run summary: `13 tests, 1 failure`

```

  1) test graph_unreadable/1 {:duplicate_module, "other/ebin/Elixir.MyApp.X.beam"}: on the beam path, naming the module, with its Fix: (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:49
     Assertion with =~ failed
     code:  assert message =~ text
     left:  "MyApp.X could not be read ({:duplicate_module, \"other/ebin/Elixir.MyApp.X.beam\"}). Fix: this is an Anchor bug; file it with this line."
     right: "is in two ebins: _build/dev/lib/app/ebin/Elixir.MyApp.X.beam and other/ebin/Elixir.MyApp.X.beam (kept)"
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:53: (test)

...
```
