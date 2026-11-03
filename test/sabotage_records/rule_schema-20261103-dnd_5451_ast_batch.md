# Sabotage record — load validation of the three AST rule types (DND-5451, DND-5452, DND-5453)

- **Domain:** rule_schema
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleSchema` (`@keys_by_type`,
  `@relations_by_type`, `@string_list_keys`, `refuse_all_pure/1`,
  `validate_owned_namespaces/1`)
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs`
  (`table(:no_discarded_pure_expression)`, `table(:no_forwarding_function)`,
  `table(:struct_owned_by_module)`), `test/anchor/domain/rule_schema_test.exs`
- **Suite run:** from the worktree root,
  `mix test test/anchor/domain/rule_checks_nothing_test.exs` for every row
- **Primary records (same run):** `no_discarded_pure_expression-20261103-dnd_5451_ast_batch.md`,
  `no_forwarding_function-20261103-dnd_5451_ast_batch.md`, `struct_owned_by_module-20261103-dnd_5451_ast_batch.md`

Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| R4 | The match-all refusal never fires (`&(&1 == :never)`) | the type's table | `no_discarded_pure_expression / pure_patterns: ["*"] declares every module pure: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` and the same for `["**"]` |
| R2 | `pure_patterns` dropped from `@string_list_keys` | the type's table | `no_discarded_pure_expression / pure_patterns that is a string: RAISED: protocol Enumerable not implemented for BitString.`; `pure_patterns of empty strings: LOADED: ...`; `pure_patterns of a non-string: RAISED: no function clause matching in String.trim/2` |
| key | `pure_patterns` accepted on `no_forwarding_function` (`no_forwarding_function: ~w(pure_patterns)`) | `table(:no_forwarding_function)` | `no_forwarding_function / an unknown key (pure_patterns belongs to another type): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` |
| empty | `owned_namespaces: []` accepted (the clause matches `[:never]`) | `table(:struct_owned_by_module)` | `struct_owned_by_module / owned_namespaces: [] checks no struct: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` |
| grammar | A non-module entry accepted (the refusal matches only `""`) | `table(:struct_owned_by_module)` | `struct_owned_by_module / an owned_namespaces glob: RAISED: no match of right hand side value:`; `struct_owned_by_module / an owned_namespaces Erlang module: RAISED: no match of right hand side value:`; `struct_owned_by_module / a malformed owned_namespaces entry after a valid one: RAISED: no match of right hand side value:` |
