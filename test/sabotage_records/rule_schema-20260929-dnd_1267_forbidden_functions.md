# Sabotage record — forbidden_functions in the rule schema (DND-1267)

- **Domain:** rule_schema (with one `config` mutation, labelled C1, per the
  README's one-combined-record rule for a key that spans both)
- **Branch:** dnd-1267-forbidden-functions
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleSchema`: `@keys_by_type`,
  `@relations_by_type`, `@string_list_keys`, `validate_function_refs/1`,
  `refuse_unread_match/1`; and `Anchor.Config.build_rule/4`'s
  `forbidden_functions`
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs`,
  `test/anchor/domain/rule_schema_test.exs`, `test/anchor/domain/config_test.exs`,
  `test/anchor/e2e/checks_e2e_test.exs`
- **Suite run:** `mix test` (689 tests)
- **Merge base:** `origin/main` = bfa7aa7; **fix commit:** the DND-1267 commit on
  this branch
- **Primary record (same run):** `dependency_analyzer-20260929-dnd_1267_forbidden_functions.md`

## Fail-first

On unfixed bfa7aa7, `rule_checks_nothing_test.exs`, the `no_direct_dependency`
table (verbatim, rule maps cut):

```
no_direct_dependency / no relation: wrong reason (want "forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty"): rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; ...
no_direct_dependency / positive: forbidden_functions alone: refused: {:error, {:invalid_rule, "rule 1: unknown key \"forbidden_functions\" in a no_direct_dependency rule; known keys for no_direct_dependency: context_depth, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module"}}
```

The `match` refusal (review round) was run against the round-1 schema first:

```
no_direct_dependency / match on a rule with only forbidden_functions (nothing reads it): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
```

## Mutations

Failure strings are verbatim.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| R1 | `validate_function_refs/1` accepts every token | 2 of 689 | `no_direct_dependency / a forbidden_functions entry naming a module only: RAISED: no match of right hand side value:` (the unvalidated token reaches `Config.build_rule`) |
| R2 | `forbidden_functions` dropped from `@relations_by_type` | 5 of 689 | `no_direct_dependency / no relation: wrong reason (want "forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty"): rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; ...` |
| R3 | `refuse_unread_match/1` accepts every `match` | 1 of 689 | `no_direct_dependency / match on a rule with only forbidden_functions (nothing reads it): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` |
| R4 | `forbidden_functions` dropped from `@string_list_keys` | 1 of 689 | `no_direct_dependency / forbidden_functions of empty strings: wrong reason (want "`forbidden_functions` must be a list of non-empty strings"): rule 1: `forbidden_functions` entry "" is not a function reference: it names no module; ...` |
| C1 | `Config` parses `forbidden_functions` into `[]` | 2 of 689 | test "parse_rule/1 — forbidden_functions (DND-1267) parses each token into a function reference": `Assertion with == failed`; the e2e test: `Assertion with == failed` |

`@keys_by_type` is not mutated here: dropping `forbidden_functions` from it
makes the compile-time relation check raise (`relation key forbidden_functions
of no_direct_dependency must be in its @keys_by_type list`), which
`rule_schema.ex` does by design; there is no suite to run.

The first attempt at R1 deleted the `with` step, which left
`validate_function_refs/1` unused and failed compilation under
`--warnings-as-errors`; it was rewritten warning-free and re-run.
