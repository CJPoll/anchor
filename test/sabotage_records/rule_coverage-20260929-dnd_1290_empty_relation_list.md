# Sabotage record — rules that checked nothing in a run (DND-1290)

- **Domain:** rule_coverage
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleCoverage` (`below_floor/2`,
  `min_files/1`, `unchecked/2`), new in this run
- **Tests:** `test/anchor/managers/lint_test.exs` ("selection floor
  (min_files)", "a rule no enabled check reads"), through the Manager
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

The module did not exist on 044f5ae, so its fail-first is the Manager's; see
`lint-20260929-dnd_1290_empty_relation_list.md`.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| K | `below_floor/2` reports nothing (`and false`): the zero-files defect | 5 | `a module-selector rule counts the files it selects`: `code: assert {:ok, [_, _, config: [violation]]} =` / `right: {:ok, [{%SourceFile<lib/thing.ex>, []},` |
| L | `min_files/1` ignores `min_files` (always 1) | 1 | `min_files raises the floor`: `left: {:ok, [{^thing, []}, {^other, [_missing_use]}, config: [violation]]}` |
| P | `unchecked/2` returns [] | 2 | `the reporter names it as one fail-closed violation`: `code: assert {:ok, [{^thing, []}, config: [violation]]} =` (and the e2e row) |
