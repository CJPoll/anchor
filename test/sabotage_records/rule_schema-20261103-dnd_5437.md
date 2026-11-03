# Sabotage record — one engine per rule type (DND-5437)

- **Domain:** rule_schema
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleSchema` (`@engine_by_type`, its compile-time completeness check, `engine/1`, `rule_types_for_engine/1`) and the README Engine column
- **Tests:** `test/anchor/domain/rule_schema_test.exs` ("engine/1", the README drift row)
- **Suite run:** targeted `mix test <files>` per mutation; full `mix test` green before and after (876 tests, 0 failures)
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 3e2861e

Fail-first: the code under test is new in this run (absent on 185ecc9), so each
new test first failed as an undefined module or function; the mutations below
are its proof. Each mutation was applied alone to 3e2861e, the named tests run,
and the file restored with `git checkout --`.

S1 is the completeness proof AC6 asks for: deleting one type's engine fails compilation, so no runtime test is needed.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing test) |
|---|---|---|---|
| S1 | delete struct_getter_convention from @engine_by_type | compile fails | `** (CompileError) Anchor.Domain.RuleSchema: @keys_by_type and @engine_by_type must name the same rule types; give every rule type an engine (:ast or :graph)` |
| S2 | README Engine column says graph for one type | 1 failure (`26 tests, 1 failure`) | `the positive case the README lists exactly the keys each rule type accepts, its relation and engine (Anchor.Domain.RuleSchemaTest)`: `README engine for struct_getter_convention` |
| S3 | rule_types_for_engine/1 ignores the engine | 1 failure (`26 tests, 1 failure`) | `engine/1 the engines partition the rule types: each type in exactly one (Anchor.Domain.RuleSchemaTest)`: `Assertion with == failed` |
