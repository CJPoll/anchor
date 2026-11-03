# Sabotage record — the runner's Fix: lines for a refused compile option and a public function with no Core (DND-5552, DND-5549)

- **Domain:** failures
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Failures.graph_unreadable/1` (`unreadable_text/2` for `{:core_v1_refused, {:option, _}}` and `{:no_core, _}`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/failures_graph_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy. After each run the driver printed `git status`, which listed only this branch's own edits, and the mutated text was grepped for after the batch: none was left.

Rows that stayed green, and why: every other row of the graph_unreadable table names a reason these mutations do not touch.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| RW-A | no row of its own for a refused compile option (the generic core_v1_refused text answers) (`lib/anchor/domain/failures.ex`) | 1 | graph_unreadable/1 {:core_v1_refused, {:option, {:plugins, [MyPlugin]}}}: on the beam path, naming the module, with its Fix: |
| RW-B | no row of its own for a public function with no Core (the catch-all answers) (`lib/anchor/domain/failures.ex`) | 1 | graph_unreadable/1 {:no_core, [run: 1, m: 2]}: on the beam path, naming the module, with its Fix: |

## RW-A — no row of its own for a refused compile option (the generic core_v1_refused text answers)

Run summary: `15 tests, 1 failure`

```

  1) test graph_unreadable/1 {:core_v1_refused, {:option, {:plugins, [MyPlugin]}}}: on the beam path, naming the module, with its Fix: (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:60
     Assertion with =~ failed
     code:  assert message =~ text
     left:  "MyApp.X the beam's backend could not produce Core Erlang ({:option, {:plugins, [MyPlugin]}}). Fix: recompile with the project's own Elixir; report the reason if it persists."
     right: "was compiled with the option {:plugins, [MyPlugin]}"
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:64: (test)

........
```

## RW-B — no row of its own for a public function with no Core (the catch-all answers)

Run summary: `15 tests, 1 failure`

```

  1) test graph_unreadable/1 {:no_core, [run: 1, m: 2]}: on the beam path, naming the module, with its Fix: (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:60
     Assertion with =~ failed
     code:  assert message =~ text
     left:  "MyApp.X could not be read ({:no_core, [run: 1, m: 2]}). Fix: this is an Anchor bug; file it with this line."
     right: "has no Core Erlang body for run/1, m/2"
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/failures_graph_test.exs:64: (test)

....
```

