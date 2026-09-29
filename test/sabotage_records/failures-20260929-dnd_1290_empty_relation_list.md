# Sabotage record — floor and unchecked-rule messages (DND-1290)

- **Domain:** failures
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Failures.selection_floor_violation/4`,
  `unchecked_rule_violation/3` and `rule_label/1`, new in this run
- **Tests:** `test/anchor/managers/lint_test.exs` and the e2e rows, which assert
  the rule label, the count, the floor and the trailing `Fix:` line
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

The functions did not exist on 044f5ae; their fail-first is the Manager's (see
`lint-20260929-dnd_1290_empty_relation_list.md`).

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| Q | the floor message loses its `Fix:` line | 2 | `code: assert violation.message =~ ~r/Fix: [^\n]+\z/` / `left: "Anchor rule 2 (id: \"contexts\", must_use_module) selected 0 of the 1 file this check ran on, below its floor of 1 (min_files), so it checked nothing. Correct its selector (paths, pattern or uses_module) in /p/.anchor.yml ..."` |
