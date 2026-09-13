# Sabotage record — Domain.DependencyAnalyzer (BUG 1, 3, 4)

- **Domain:** dependency_analyzer
- **Branch:** dnd-125-t5-dependency-analyzer
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.DependencyAnalyzer`
  (`extract_module_names/1`, `extract_direct_dependencies/1`, `extract_uses/1`,
  `module_dependencies/1`, `find_transitive_dependencies/3`), and the
  AST-acquisition boundary `Anchor.Check.Source` (BUG 1 unwrap).
- **Suite run:** `mix test test/anchor/domain/dependency_analyzer_test.exs`
  (whole-suite green bar: `mix test` → 265 tests, 0 failures)
- **Merge base:** daab5d93b5e29eb6906daa8baef24abe71c7218d

## What T5 authored (why this file has real teeth)

T5 is THE crux of the epic. It moves the analyzer into the Domain bucket (zero
`Credo.*`, no IO), unwraps Credo's `{:ok, ast}` exactly once at the Framework
edge (`Anchor.Check.Source`) so the Domain never sees the tuple again (BUG 1),
turns singular `extract_module_name/1` into plural `extract_module_names/1`
(pre-order DFS, fully qualified — BUG 4), and makes `__MODULE__` resolution
crash-free and quote-aware (BUG 3). Three mutations exercise the load-bearing
new logic; each was applied, the suite run, the failure observed, then reverted
(tree returned to `33 tests, 0 failures`).

| # | Mutation | Tests failed | Failure string (verbatim) |
|---|---|---|---|
| A | `module_nodes/2`: drop the pre-order recursion — `[{Module.concat(full), full, body} \| module_nodes(body, full)]` → `[{Module.concat(full), full, body}]` (never descend into a module's children) | 3 | `extract_module_names/1 nested siblings …` — `code: assert DependencyAnalyzer.extract_module_names(ast(src)) == [A, A.B, A.C]` — `left: [A]` / `right: [A, A.B, A.C]` (also the "pre-order DFS keeps a subtree contiguous" and "deeper DFS" rows: `left: [A]` vs `[A, A.D, A.C, A.C.E]` / `[A, A.D, A.D.F, A.C, A.C.E]`) |
| B | `record_alias/3` (`__MODULE__` resolution): name the wrong module — `Module.concat(scope.enclosing ++ tail)` → `Module.concat(tail)` (drop the enclosing prefix) | 1 | `extract_direct_dependencies/1 __MODULE__.Sub in ordinary code resolves to the enclosing submodule` — `code: assert Enclosing.Sub in deps` — `left: Enclosing.Sub` / `right: [Sub]` |
| C | `resolvable_self_reference?/2` (quote suppression): `Enum.all?(tail, &is_atom/1) and not scope.in_quote and scope.enclosing != nil` → drop `not scope.in_quote` (resolve `__MODULE__` even inside a `quote`) | 1 | `extract_direct_dependencies/1 __MODULE__ inside quote is opaque, not resolved to the enclosing module` — `code: refute Enclosing.Sub in deps` — `left: Enclosing.Sub` / `right: [Enclosing.Sub]` |

## Measured zeros made explicit (macro/quote static-analysis boundary)

Per the matrix "Scope & limitations" note and ADR 003, the macro/quote rows are
recorded here as **measured zeros**: they assert graceful degradation
(skip / no-crash / no-spurious-claim) rather than a moving detection anchor, so
no single line-mutation makes exactly one of them fail without also tripping a
positive row above. They are still executed and green.

- **`extract_module_names/1` rows 9–12** (`defmodule unquote(x)`, variable name,
  pure-DSL file, literal-alongside-dynamic) all assert `[]` or `[A]`. They are
  guarded by `literal_alias_parts/1` returning `:error` for any non-`__aliases__`
  or non-all-atom name, and by `top_defmodules/1` skipping `quote`. A mutation
  that made these emit a node (e.g. treating a dynamic name as literal) would
  first break the *positive* rows (1, 3–6), which is mutation A's territory or a
  broader `literal_alias_parts` change — so these rows carry no independent
  moving anchor. Recorded as measured zeros.
- **`extract_direct_dependencies/1` rows 6, 7, 9** (`@attr.Sub`, `var.Sub`,
  `%__MODULE__{}` inside `quote`) assert "no crash, no spurious dep" (`== []` /
  `refute … in deps`). The non-negotiable property is *absence*; there is no
  positive value to move. `record_alias/3`'s `cond` records a dependency only
  for an all-atom alias or a resolvable `__MODULE__` self-reference, so these
  degrade to no-op by construction. Recorded as measured zeros; mutation C is
  the one quote row that DOES move (row 8, `__MODULE__.Sub` inside `quote`),
  because it has an observable wrong value (`Enclosing.Sub`) to leak.

## Notes

- **BUG 1 is a boundary fix, not a Domain-visible one.** The unwrap lives in
  `Anchor.Check.Source.ast/1`; the Domain simply receives a bare AST. Its
  end-to-end effect is proved by the flipped characterization rows in
  `test/anchor/managers/lint_test.exs` (module-graph test → a real
  `MyApp.Repo` transitive violation, chain `A -> B -> MyApp.Repo`) and
  `test/anchor/integration/lint_composition_test.exs` (row #4 → module-`pattern`
  selection now composes). Those two rows were the T4 characterization anchors
  that pinned the BUG-1 shadow; T5 flips them.
- Three checks (`struct_getter_convention`, `case_on_bare_arg`,
  `max_file_length`) had defensively unwrapped `{:ok, ast}` themselves — a BUG-1
  accommodation. With the unwrap now centralized at the Framework edge, those
  clauses were removed (`struct_getter_convention` had *only* the tuple clause
  and was silently returning `[]` for every file until fixed); their existing
  characterization tests re-green unchanged, proving the caller updates are
  behavior-identical.
