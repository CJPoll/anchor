# Sabotage record — the interface graph rule after merging main at 07aef9f

- **Domain:** interface
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.Interface` (`judge/2`, `fix/4`)
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

IF-N is the regression test of the narrowing bug: the mutation restores the unfixed line, and its red is the red in the fix commit. IF-O covers the `Fix:` of a context with no interface module, which no test named until then.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| IF-N | a dynamic call is judged against every exporter, not the narrowed targets (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `21 tests, 1 failure` (red) | check/2 over compiled fixtures (two apps) a behaviour-typed receiver reaches its implementers; an untyped one every exporter |
| IF-O | the no-interface Fix: names no remedy (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `22 tests, 1 failure` (red) | check/2 a callee whose context has no interface module: the Fix: says to give it one |

## IF-N — a dynamic call is judged against every exporter, not the narrowed targets

Run summary: `21 tests, 1 failure`

```text
  1) test check/2 over compiled fixtures (two apps) a behaviour-typed receiver reaches its implementers; an untyped one every exporter (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:384
     Assertion with == failed
     code:  assert keys == [
              "interface|#{@narrow_ns}.Billing.Runner.untyped/2|-> " <>
                "#{@narrow_ns}.Accounts.Domain.Worker.go/1"
            ]
     left:  ["interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.typed/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1",
             "interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.untyped/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1"]
     right: ["interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.untyped/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1"]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:416: (test)

................
```

## IF-O — the no-interface Fix: names no remedy

Run summary: `22 tests, 1 failure`

```text
  1) test check/2 a callee whose context has no interface module: the Fix: says to give it one (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:197
     Assertion with =~ failed
     code:  assert v.message =~
              "Fix: context App.Hidden has no interface module; give it one (a module of an " <>
                "interfaces.buckets bucket) and call that, or, if App.Hidden.Secret is meant " <>
                "to be public, add it to interfaces.exports (a reviewed change)."
     left:  "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Hidden.Secret.read/0, which is not part of context App.Hidden's interface. Fix: context App.Hidden has an interface module; give it one (a module of an interfaces.buckets bucket) and call that, or, if App.Hidden.Secret is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "Fix: context App.Hidden has no interface module; give it one (a module of an interfaces.buckets bucket) and call that, or, if App.Hidden.Secret is meant to be public, add it to interfaces.exports (a reviewed change)."
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:202: (test)

..............
```
