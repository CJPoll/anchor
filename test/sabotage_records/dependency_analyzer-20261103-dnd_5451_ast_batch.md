# Sabotage record — DependencyAnalyzer.resolved_modules/1 (DND-5451)

- **Domain:** dependency_analyzer
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.DependencyAnalyzer.resolved_modules/1`
  and the positions it records (`record_position/3` in `step/3` for a literal
  `defmodule`, `visit/3` for an alias and a bare `__MODULE__`, `visit_remote/8`
  for an alias or `__MODULE__` callee)
- **Tests:** `test/anchor/domain/dependency_analyzer_resolved_modules_test.exs`;
  `test/anchor/domain/checks/no_discarded_pure_expression_test.exs` reads it
- **Primary record (same run):** `no_discarded_pure_expression-20261103-dnd_5451_ast_batch.md`

Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| DA1 | A `defmodule` name is not recorded (`defined_name(...) && :error`) | the defmodule row; D14 | `code: assert at(source, 1, 11) == App.Outer` `left: nil` `right: App.Outer`; D14: `left: [%{trigger: "add(a, b)"}]` `right: []` |
| DA2 | A bare `__MODULE__` is not recorded | 2 rows | `code: assert at(source, 3, 17) == App.Outer.Inner` `left: nil` `right: App.Outer.Inner` |
| DA3 | An alias callee is not recorded | 3 analyzer rows, 9 detection rows | `code: assert at(source, 3, 17) == App.Calc` `left: nil` `right: App.Calc`; D1: `left: [violation]` `right: []` |
| DA5 | The column is dropped from the key | 8 of 9 rows | `code: assert at(source, 3, 17) == App.Calc` `left: nil` `right: App.Calc` |

## Equivalent mutant

`record_position(acc, node, {_ok, module})` in place of `{:ok, module}` passed:
every other resolution is the atom `:error` or `:unresolved`, never a tuple,
so the two heads match the same values. Not a gap.
