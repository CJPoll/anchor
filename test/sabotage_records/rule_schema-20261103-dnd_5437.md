# Sabotage record — one engine per rule type (DND-5437)

- **Domain:** rule_schema
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleSchema` (`@engine_by_type`, its compile-time completeness check, `engine/1`, `rule_types_for_engine/1`) and the README Engine column
- **Tests:** `test/anchor/domain/rule_schema_test.exs` ("engine/1", and the extended README drift test)
- **Suite run:** each mutation applied alone to fecac77, then
  `MIX_ENV=test mix compile --force` and the `mix test` command named under it,
  then the file restored with `git checkout --`. The full suite (`mix test`)
  was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** fecac77

## Fail-first

`engine/1` and `rule_types_for_engine/1` are new; the README drift test existed and now also reads an Engine column, which 185ecc9's README lacks (so it parses no rows).

`mix test test/anchor/domain/rule_schema_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: `26 tests, 4 failures`.

```
  1) test engine/1 every shipped type has an engine, and today every one is :ast (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:217
     ** (UndefinedFunctionError) function Anchor.Domain.RuleSchema.engine/1 is undefined or private
     code: engines = Enum.map(RuleSchema.rule_types(), &RuleSchema.engine/1)

  2) test the positive case the README lists exactly the keys each rule type accepts, its relation and engine (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:188
     Assertion with == failed
     code:  assert rows |> Enum.map(&elem(&1, 0)) |> Enum.sort() == RuleSchema.rule_types()
     left:  []
     right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarding_arrow_in_with,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention]

  3) test engine/1 the engines partition the rule types: each type in exactly one (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:224
     ** (UndefinedFunctionError) function Anchor.Domain.RuleSchema.rule_types_for_engine/1 is undefined or private. Did you mean:

         * rule_types/0

     code: ast = RuleSchema.rule_types_for_engine(:ast)

  4) test engine/1 an unknown type raises: callers pass parsed types only (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:234
     Expected exception KeyError but got UndefinedFunctionError (function Anchor.Domain.RuleSchema.engine/1 is undefined or private)
     code: assert_raise KeyError, fn -> RuleSchema.engine(:no_such_type) end
```


S1 is the completeness proof AC6 asks for: deleting one type's engine fails compilation, so no runtime test is needed.

An earlier run of these mutations, without the forced recompile, let two edits of one file inside one second pass Mix's stale check, so a mutation ran on the previous mutation's beams (M4 recorded M3's failure, G2 recorded G1's). The critic caught it; every mutation here is from the forced-recompile run.

## Mutations

| # | Mutation | Result |
|---|---|---|
| S1 | delete struct_getter_convention from @engine_by_type | `compile error` |
| S2 | README Engine column says graph for one type | `26 tests, 1 failure` |
| S3 | rule_types_for_engine/1 ignores the engine | `26 tests, 1 failure` |

### S1: delete struct_getter_convention from @engine_by_type

- File mutated: `lib/anchor/domain/rule_schema.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/rule_schema_test.exs`
- Result: compilation fails

```
** (CompileError) Anchor.Domain.RuleSchema: @keys_by_type and @engine_by_type must name the same rule types; give every rule type an engine (:ast or :graph)
```

### S2: README Engine column says graph for one type

- File mutated: `README.md`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/rule_schema_test.exs`
- Result: `26 tests, 1 failure`

```
  1) test the positive case the README lists exactly the keys each rule type accepts, its relation and engine (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:188
     README engine for struct_getter_convention
     code: for type <- RuleSchema.rule_types() do
```

### S3: rule_types_for_engine/1 ignores the engine

- File mutated: `lib/anchor/domain/rule_schema.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/rule_schema_test.exs`
- Result: `26 tests, 1 failure`

```
  1) test engine/1 the engines partition the rule types: each type in exactly one (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:224
     Assertion with == failed
     code:  assert Enum.sort(ast ++ graph) == RuleSchema.rule_types()
     left:  [:alphabetized_functions, :alphabetized_functions,
             :case_on_bare_arg, :case_on_bare_arg, :max_file_length,
             :max_file_length, :module_pattern_restrictions,
             :module_pattern_restrictions, :must_use_module,
             :must_use_module, :no_comparison_in_if,
             :no_comparison_in_if, :no_direct_dependency,
             :no_direct_dependency, :no_discarding_arrow_in_with,
             :no_discarding_arrow_in_with,
             :no_transitive_dependency, :no_transitive_dependency,
             :no_tuple_match_in_head, :no_tuple_match_in_head,
             :single_control_flow, :single_control_flow,
             :struct_getter_convention, :struct_getter_convention]
     right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,
             :module_pattern_restrictions, :must_use_module,
             :no_comparison_in_if, :no_direct_dependency,
             :no_discarding_arrow_in_with,
             :no_transitive_dependency, :no_tuple_match_in_head,
             :single_control_flow, :struct_getter_convention]
```
