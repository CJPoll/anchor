# Sabotage record — the crashed-analysis message (DND-5574)

- **Domain:** failures
- **Branch:** dnd-5574-cfa-wiring
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Failures.rule_cfa_crashed/5`. The rest of the same run is filed under `graph_runner-20261103-dnd_5574_cfa_wiring.md`.
- **Suite run:** one `test-slot` held a driver that, per mutation, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and restored the file with `git checkout`; `git status --short` after the run was clean. Every row is red: a non-zero ExUnit result naming the tests the mutation is meant to break. The failure strings below are copied from that run's output (the assertion block of each row's first failing test, up to eight lines).

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| FA-A | the crashed-analysis message loses its Fix: (`lib/anchor/domain/failures.ex`) | `failures_graph_test.exs`, `graph_cfa_test.exs` | `22 tests, 5 failures` | every graph message is fail-closed, on its file, with its subject and a Fix: line; fail closed an analysis that raises: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that exits: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that returns no %Cfa{}: each rule that needs it is one issue and is not run; the others run |

## Failure strings (verbatim, the first failing test of each row)

### FA-A — the crashed-analysis message loses its Fix:

```
rule_cfa_crashed
code: for {name, violation, file, texts} <- rows() do
```
