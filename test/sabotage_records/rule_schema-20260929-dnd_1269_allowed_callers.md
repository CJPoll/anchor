# Sabotage record — allowed_callers load validation (DND-1269)

- **Domain:** rule_schema
- **Branch:** dnd-1269-allowed-callers
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleSchema` (`@keys_by_type`,
  `@string_list_keys`, `validate_allowed_callers/1`);
  `Anchor.Domain.AllowedCallers.parse/1`; `Anchor.Config.parse_rule/1`
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs` (the
  `allowed_callers` rows), `test/anchor/domain/config_test.exs`
  ("parse_rule/1 — allowed_callers (DND-1269)"),
  `test/anchor/domain/rule_schema_test.exs`
- **Suite run:** `mix test` (800 tests); re-run one mutation with
  `mix test test/anchor/domain/rule_checks_nothing_test.exs test/anchor/domain/config_test.exs`
- **Merge base:** `origin/main` = c041060; **mutated tree:** 5ce9ad7 (the
  branch's final code)
- **Primary record (same run):** `no_dependency-20260929-dnd_1269_allowed_callers.md`

## Fail-first on unfixed c041060

Every `allowed_callers` row failed at the key allowlist:

```
no_direct_dependency / a match-all allowed_callers glob allows every caller, so the rule checks nothing: wrong reason (want "is a glob"): rule 1: unknown key "allowed_callers" in a no_direct_dependency rule
```

## Mutations

S1, S2 and S3 first left a function or a `cond` clause unreachable and did not
compile. The rewrites keep every function called. Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| S1 | no `allowed_callers` entry is validated | 2 of 800 | config test "a glob fails the load, naming the rule, the entry and the fix": `** (MatchError) no match of right hand side value: {:error, "is a glob, and a glob allows every module a later change gives a matching name ..."}` |
| S2 | a glob entry is not recognised as a glob | 2 of 800 | same test: `Assertion with =~ failed` / `left: "rule 1: \`allowed_callers\` entry \"MyApp.Adapters.*\" is not a module name; ..."` / `right: "rule 1: \`allowed_callers\` entry \"MyApp.Adapters.*\" is a glob"` |
| S3 | an Erlang module entry is not recognised | 1 of 800 | `no_direct_dependency / an allowed_callers Erlang module is never defined in source: wrong reason (want "an Erlang module"): rule 1: \`allowed_callers\` entry ":telemetry" is not a module name; ...` |
| S4 | `allowed_callers` is not an accepted key | 8 of 800 | same config test: `left: "rule 1: unknown key \"allowed_callers\" in a no_direct_dependency rule; ..."` / `right: "rule 1: \`allowed_callers\` entry \"MyApp.Adapters.*\" is a glob"` |
| S5 | `allowed_callers` is not a string-list key | 1 of 800 | `no_direct_dependency / allowed_callers that is a string: RAISED: protocol Enumerable not implemented for BitString`; `an allowed_callers nil entry (a bare \`-\` in YAML): RAISED: no function clause matching in Anchor.Domain.AllowedCallers.parse/1` |

S1 shows a second guard. With validation off, `Anchor.Config.parse_rule/1`
crashes on the `{:ok, module} = AllowedCallers.parse(token)` match instead of
loading a glob. The load still fails, so a glob can never be a working entry.
