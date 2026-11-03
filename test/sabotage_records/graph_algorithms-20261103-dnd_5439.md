# Sabotage record — graph algorithms over a plain digraph (DND-5444)

- **Domain:** graph_algorithms
- **Branch:** dnd-5439 (batch branch for DND-5439 and DND-5444)
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphAlgorithms` (rows A-H), `Anchor.Domain.Digraph` (rows I-L)
- **Suite run:** `mix test test/anchor/domain/graph_algorithms_test.exs` (rows A-H, 26 tests);
  `mix test test/anchor/domain/digraph_test.exs` (rows I-L, 5 tests). Both green before and after every row.

Each mutation was applied alone to the committed code, the suite run, and the
file restored with `git checkout`. Failure strings are copied from the run.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | `compute/4`: the virtual root's successors are the first root only | 3: cases 9, 13, 17 | `code: assert doms.idom == %{r1: @vr, r2: @vr, s: @vr}` `left: %{s: :r1, r1: :"$anchor_virtual_root"}`; `code: assert doms.unreachable == Enum.reject(...)` `left: [1]` `right: []`; `code: assert pdoms.idom[:b] == @vx` `left: :w1` `right: :"$anchor_virtual_exit"` |
| B | `compute/4`: unreachable nodes get the virtual node as idom | 2: cases 11, 18 | `code: refute Map.has_key?(doms.idom, :x)` `Expected false or nil, got true`; `code: assert pdoms.idom == %{b: @vx, a: :b}` `left: %{c: :"$anchor_virtual_exit", a: :b, b: :"$anchor_virtual_exit"}` |
| C | `intersect/4`: walk the higher postorder number up (`>` for `<`) | 9: cases 6/14, 7, 8, 9, 10, 13, 17, 19, 28 | `** (ExUnit.TimeoutError) test timed out after 2000ms` on each (the walk climbs past the virtual root and never meets) |
| D | `post_dominators/2`: no `Digraph.reverse/1` | 4: cases 16, 17, 18, 19 | `code: assert pdoms.idom == %{w: @vx, a: :w, b: :w}` `left: %{w: :"$anchor_virtual_exit"}`; `code: assert pdoms.idom[:b] == @vx` `left: nil`; `code: assert pdoms.unreachable == [:c]` `left: [:a, :c]` |
| E | `union/3`: link the endpoints instead of their roots | 1: case 22b | `code: assert GraphAlgorithms.components(graph) == expected` `left: [[0], [1, 2]]` `right: [[0, 1, 2]]` |
| F | `sccs/1`: drop the final `Enum.reverse/1` (discovery order) | 3: cases 23, 25, 26 | `code: assert GraphAlgorithms.sccs(graph(a: :b, b: :a, b: :c)) == [[:c], [:a, :b]]` `left: [[:a, :b], [:c]]`; `code: assert GraphAlgorithms.sccs(g) == [[:c], [:b], [:a]]` `left: [[:a], [:b], [:c]]` |
| G | `cyclic_sccs/1`: every singleton is cyclic | 2: cases 24, 25 | `code: assert GraphAlgorithms.cyclic_sccs(g) == [[:a]]` `left: [[:a], [:b]]`; `code: assert GraphAlgorithms.cyclic_sccs(g) == []` `left: [[:c], [:b], [:a]]` |
| H | `climbs_to?/4`: return false at a node whose idom is the virtual node, before comparing it | 3: cases 6, 13, 19 | `code: assert GraphAlgorithms.dominates?(doms, :r, :c)` `Expected truthy, got false` |
| I | `Digraph.new/2`: an edge's target does not add a node | 4: cases 1, 2, 3, 4 | `** (KeyError) key :b not found in:`; case 4: `Expected exception ArgumentError but got KeyError` |
| J | `Digraph.reverse/1` returns the graph unchanged | 1: case 2 | `code: assert Digraph.successors(reversed, :c) == [:b]` `left: []` `right: [:b]` |
| K | `Digraph.subgraph/2` keeps an edge with one end kept | 1: case 3 | `code: assert Digraph.nodes(sub) == [:a, :b]` `left: [:a, :b, :c]` |
| L | `Digraph.new/2` refuses no reserved atom | 1: case 4 | `Expected exception ArgumentError but nothing was raised` |

## Rows that stayed green, and why

- Under C, cases 5, 15 (chains) and 16 stay green: every node there has one
  reachable predecessor, so `intersect/4` is never called. The mutation is
  caught on every graph with a join.
- Under E only the brute-force component row reddens: cases 20-22 are small
  enough that linking endpoints happens to link roots too.

## Traps

- **C, first run:** with ExUnit's default 60 s timeout and `max_cases: 32`,
  the looping tests spun many cores for minutes. The run was stopped by PID
  after about 400 s and re-measured with `--timeout 2000 --max-cases 2`; the
  row above is that re-run. A mutation that can loop is measured with a short
  timeout.
