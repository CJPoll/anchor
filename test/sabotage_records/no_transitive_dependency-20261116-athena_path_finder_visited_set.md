# Sabotage record — the transitive path finder expands each module once

- **Domain:** no_transitive_dependency
- **Branch:** athena/path-finder-visited-set
- **Date:** 2026-11-16
- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.find_dependency_path/3`
  (now public: the path, and the number of modules the search expanded) and
  `detect_violations/3`, which reports that path in its message
- **Suite run:** `mix test test/anchor/domain/checks/no_transitive_dependency_test.exs`

The path finder kept only the modules on the current branch as visited, so it
re-walked every shared subtree once per route into it: exponential in depth on a
layered graph, and a credo run over a large tree did not finish once a violation
existed. It now shares one visited set across every branch. The tests count
expansions through a counter kept apart from the visited set; none of them time
anything.

The fixture `layered_graph(width, depth)`: `Root` depends on every module of
layer 1 and then on `Bridge`; each layer depends on all of the next; `Bridge`
depends on `Forbidden`. The route to `Forbidden` is tried last.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | The unfixed algorithm: the visited set passed down each branch and dropped when the branch returns (per-branch, not shared), with the same counter | 3 of the 4 counting tests (run without the 4^30-route test, which the unfixed code does not return from) | `left: {[Root, Bridge, Forbidden], 26}` `right: {[Root, Bridge, Forbidden], 9842}`; `left: {nil, 26}` `right: {nil, 9843}` (that row now expects 27, see below); `left: {[S, B, D, Forbidden], 5}` `right: {[S, B, D, Forbidden], 6}` |
| B | Stop counting (`expanded: expanded + 1` -> `expanded: expanded`) | 4 | `left: {[Root, Bridge, Forbidden], 26}` `right: {[Root, Bridge, Forbidden], 0}` (and `0` on the other three counting rows) |
| C | Search the dependencies in reverse order (`Enum.reduce_while(deps, ...)` -> `Enum.reduce_while(Enum.reverse(deps), ...)`) | 4 | `left: {[S, A, C, Forbidden], 3}` `right: {[S, B, Forbidden], 2}` (the two-route row); the counting rows see fewer expansions, e.g. `right: {[Root, Bridge, Forbidden], 2}` |

## Notes

- **A** is the defect itself. The paths are equal on both sides of every failure:
  the fix changes how much is searched, not which path is reported.
- The unreachable-target row expects 27, not 26: when `Forbidden` is not the
  target it is expanded too (it has no entry, so no dependencies). Under A that
  row reported 9843.
- **C** pins the reported path to the first in dependency order. Before the
  two-route row was added, reversing the order failed only on counts: every
  other fixture has one route to the target.
- Not run: removing the visited-set check entirely. Without it a cycle never
  terminates (the cycle rows would not return), and the shared set's effect is
  already what A measures.
