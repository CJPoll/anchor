# Sabotage record — the graph messages for code outside the root (DND-5588, DND-5585)

- **Domain:** failures
- **Branch:** dnd-5581-hardening-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Failures.graph_module_outside_root/3` and `graph_all_outside_root/3`
  (DND-5588), and the `Fix:` of `graph_artifact_not_written/2` (DND-5585)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph/builder_test.exs
  test/anchor/managers/graph_test.exs test/anchor/domain/graph_report_test.exs
  test/anchor/domain/graph/project_file_test.exs test/anchor/domain/failures_graph_test.exs`, the mutation
  applied alone and restored byte-for-byte (`cmp`) after its run. Without it: `77 tests, 0 failures`.

`failures_graph_test.exs` has a row for each new message. The `graph_artifact_not_written` row's `Fix:` text
changed with DND-5585 (it named `_build/<env>/anchor`, which a `MIX_BUILD_PATH` build is not): against the
old text that row fails its `=~` on the new `Fix:` string.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| K | `graph_module_outside_root/3` drops "outside the project root <root>" from its text | the message table, the Manager's outside-the-root | `77 tests, 2 failures` |

## Failure strings (verbatim)

### K

```
  1) test every graph message is fail-closed, on its file, with its subject and a Fix: line (Anchor.Domain.FailuresGraphTest)
     test/anchor/domain/failures_graph_test.exs:191
     graph_module_outside_root: "MyApp.Shared was compiled from /shared/lib/shared.ex, outside the project root /proj" in MyApp.Shared was compiled from /shared/lib/shared.ex, so it is left out of the graph and no rule judged it. Fix: move its source under /proj, or run mix anchor.graph from the root that holds it.
```
