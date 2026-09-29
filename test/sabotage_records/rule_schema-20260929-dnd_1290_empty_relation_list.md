# Sabotage record — a rule that loads but checks nothing (DND-1290)

- **Domain:** rule_schema
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleSchema` (`validate/2` and its new
  steps: `require_single_selector/1`, `validate_recursive/1`,
  `validate_floor/1`, `validate_id/1`, `validate_string_lists/1`,
  `require_relation/2`, `refuse_allow_all/1`; `@relations_by_type`,
  `relation_keys/1`), and the README relation column
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs` (one table per
  rule type), `test/anchor/domain/rule_schema_test.exs` (README drift row)
- **Suite run:** `mix test` (the whole suite, 608 tests)
- **Merge base:** `origin/main` = 044f5ae
- **Fix commit:** d3f8a54
- **Sibling records (same run):** `glob_pattern-`, `rule_coverage-`, `lint-`,
  `failures-`, `base-` and `config-20260929-dnd_1290_empty_relation_list.md`

## Fail-first run

The tests were written first and run against the unfixed code on 044f5ae. One
line of production code changed first: `Anchor.Config` gained `path: nil` in
its struct, because the new Lint tests build `%Config{path: ...}` and the test
files would not compile without it (the first run failed with
`** (KeyError) key :path not found` / `expanding struct: Anchor.Config.__struct__/1`).
With that field alone: `608 tests, 37 failures`.

The per-type tables list every failing row, so one run shows the whole class.
Excerpt (the rule maps are cut to `...`):

```
no_direct_dependency / no relation: LOADED: %Anchor.Config{rules: [%{match: :reference, type: :no_direct_dependency, ...}], ...}
no_direct_dependency / forbidden_modules: []: LOADED: ...
no_direct_dependency / forbidden_patterns: []: LOADED: ...
no_direct_dependency / both empty: LOADED: ...
no_direct_dependency / forbidden_modules of empty strings: LOADED: ...
no_direct_dependency / forbidden_modules of blank strings: LOADED: ...
no_direct_dependency / forbidden_patterns of empty strings: LOADED: ...
no_direct_dependency / a nil entry (a bare `-` in YAML): LOADED: ...
no_direct_dependency / forbidden_modules that is a string: RAISED: no function clause matching in Anchor.Config.parse_modules/1
no_transitive_dependency / no relation: LOADED: %Anchor.Config{rules: [%{match: :reference, type: :no_transitive_dependency, ...}], ...}
must_use_module / no relation: LOADED: %Anchor.Config{rules: [%{match: :reference, type: :must_use_module, ...}], ...}
must_use_module / required_modules: []: LOADED: ...
must_use_module / required_modules of empty strings: LOADED: ...
must_use_module / required_modules that is a string: RAISED: no function clause matching in Anchor.Config.parse_modules/1
module_pattern_restrictions / allowed_functions: ["*"] allows every function: LOADED: ...
module_pattern_restrictions / allowed_functions: ["**"] allows every function: LOADED: ...
module_pattern_restrictions / allowed_functions that is a string: LOADED: ...
single_control_flow / paths and pattern (only paths was read): LOADED: %Anchor.Config{rules: [%{match: :reference, type: :single_control_flow, ...}], ...}
single_control_flow / pattern and uses_module (only pattern was read): LOADED: ...
single_control_flow / recursive without paths (read by nothing): LOADED: ...
single_control_flow / recursive that is not a boolean: LOADED: ...
single_control_flow / min_files: 0 (no floor): wrong reason (want "`min_files` must be a positive integer"): rule 1: unknown key "min_files" in a single_control_flow rule; ...
```

The selector, `recursive`, `min_files` and `id` rows failed the same way for
all 12 rule types. The positive rows carrying `min_files` and `id` were refused
as unknown keys. `relation_keys/1` did not exist
(`** (UndefinedFunctionError) function Anchor.Domain.RuleSchema.relation_keys/1 is undefined or private`).

After the fix: `608 tests, 0 failures`.

## Mutations

Each mutation was applied alone to the fix commit, the whole suite run, and the
file restored byte for byte. Every one reddened at least one test; there are no
measured zeros. A, B and D first ran as compile failures (`mix test` compiles
with warnings-as-errors, and a dead clause warned). Each was rewritten
warning-free (`Enum.take(..., 0)` in place of a literal) and re-run.

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| A | `require_relation/2` sees no relation keys (`case Enum.take(relation_keys(type), 0)`): the empty-relation defect | 5 | `no_transitive_dependency / no relation: LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}`, then `forbidden_modules: []`, `forbidden_patterns: []`, `both empty`, each `LOADED` |
| B | `require_single_selector/1` sees one selector (`Enum.take(selectors(rule), 1)`) | 12 | `no_tuple_match_in_head / paths and pattern (only paths was read): LOADED: ...` and `pattern and uses_module (only pattern was read): LOADED: ...` |
| C | `recursive` accepted without `paths` (`or true`) | 12 | `must_use_module / recursive without paths (read by nothing): LOADED: ...` |
| D | `validate_string_lists/1` checks no key | 4 | `module_pattern_restrictions / allowed_functions that is a string: RAISED: protocol Enumerable not implemented for BitString` |
| E | `match_all?/1` always false | 1 | `module_pattern_restrictions / allowed_functions: ["*"] allows every function: LOADED: ...` |
| F | `min_files: 0` accepted (`< 1` became `< 0`) | 12 | `no_direct_dependency / min_files: 0 (no floor): LOADED: ...` |
| G | `must_use_module` has no relation in `@relations_by_type` | 5 | `a refused rule with an id names the id beside its position`: `left: {:error, {:invalid_rule, reason}}` / `right: %Anchor.Config{` then `id: "bases",` |
| H | blank strings pass as list entries (no `String.trim`) | 2 | `no_transitive_dependency / forbidden_modules of blank strings: LOADED: ...` |
| I | data: the README relation cell for `no_transitive_dependency` drops `forbidden_patterns` | 1 | `README relation for no_transitive_dependency` |

Two guards are compile-time, so they are not suite mutations: a type missing
from `@relations_by_type`, and a relation key missing from its type's
`@keys_by_type` or from `@relation_descriptions`, each raise a `CompileError`
naming the fix.
