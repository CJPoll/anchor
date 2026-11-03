# Sabotage record — pure_patterns load validation (DND-5451)

- **Domain:** rule_schema
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleSchema` (`@keys_by_type`,
  `@relations_by_type`, `@string_list_keys`, `refuse_all_pure/1`)
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs`
  (`table(:no_discarded_pure_expression)`), `test/anchor/domain/rule_schema_test.exs`
- **Primary record (same run):** `no_discarded_pure_expression-20261103-dnd_5451_ast_batch.md`

Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| R4 | The match-all refusal never fires (`&(&1 == :never)`) | the type's table | `no_discarded_pure_expression / pure_patterns: ["*"] declares every module pure: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` and the same for `["**"]` |
| R2 | `pure_patterns` dropped from `@string_list_keys` | the type's table | `no_discarded_pure_expression / pure_patterns that is a string: RAISED: protocol Enumerable not implemented for BitString.`; `pure_patterns of empty strings: LOADED: ...`; `pure_patterns of a non-string: RAISED: no function clause matching in String.trim/2` |
