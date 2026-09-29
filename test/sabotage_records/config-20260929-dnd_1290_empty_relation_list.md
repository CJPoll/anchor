# Sabotage record — rule position, id and floor in the parser (DND-1290)

- **Domain:** config
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Config.parse_config/1` (`:index` on each parsed
  rule, `raw_rule_label/2`, `refuse_shared_ids/1`), `parse_rule/1` (`:id`,
  `:min_files`), the struct's `path`, and `Anchor.Adapters.ConfigFile`
  setting it; the data files `.anchor.yml`, `.anchor.example.yml` and the
  README's YAML blocks
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs` (id and
  position rows), `test/anchor/domain/config_test.exs`,
  `test/anchor/domain/config_fail_closed_test.exs`
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

## Fail-first run (unfixed 044f5ae)

```
 10) test two rules with the same id are refused, naming both positions (Anchor.Domain.RuleChecksNothingTest)
  5) test a refused rule with an id names the id beside its position (Anchor.Domain.RuleChecksNothingTest)
 13) test a parsed rule carries its position, id and floor (Anchor.Domain.RuleChecksNothingTest)
```

Each failed because `id` and `min_files` were unknown keys
(`rule 1: unknown key "id" in a ... rule`).

## Fixture changes, and why none hides the defect

The relation and single-selector rules made 17 existing config rows fail, each
because its rule had no relation (`%{"type" => "no_direct_dependency"}`) or
put `recursive` beside a placeholder `pattern`. Those rows test other keys.
The local `parse_rule/1` helpers in `config_test.exs` and
`config_fail_closed_test.exs` now also add a placeholder relation
(`forbidden_patterns` where the type has it, else its first relation key) only
when the rule names none of its own. Rows that assert a relation key's default
name a different key. Documents built for `parse_config/1` got an explicit
`forbidden_modules`. `rule_checks_nothing_test.exs` builds every rule without
a helper, so the refusals are tested on the raw maps.

`.anchor.yml`, `.anchor.example.yml` and all 21 README YAML blocks load
unchanged under the new schema (checked with a `mix run` probe over
`Anchor.Adapters.ConfigFile.load_from_path/1` and `Anchor.Config.parse_config/1`).

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| U | two rules sharing an id load (`> 99`) | 1 | `code: assert {:error, {:invalid_rule, reason}} =` / `Config.parse_config(%{"rules" => [rule, base(:case_on_bare_arg), rule]})` / `right: %Anchor.Config{` |
| V | a refused rule's label drops its id | 1 | `code: assert reason =~ ~s\|rule 1 (id: "bases"): \|` / `left: "rule 1: a must_use_module rule has no relation, so it checks nothing: ..."` |

## Review round (fail-first, then mutation)

Three or more rules sharing an id read "rules 1 and 2 and 4". Against the
pre-fix head:

```
  2) test three rules sharing an id are named in one list (Anchor.Domain.RuleChecksNothingTest)
     code:  assert reason =~ ~s(rules 1, 2 and 4 share the id "style")
     left:  "rules 1 and 2 and 4 share the id \"style\"; an id names one rule, so give each rule its own"
```

The default floor moved to one home (`RuleCoverage.default_min_files/0`, read
by `build_rule`). The `config_test.exs` fixture helper no longer calls
`String.to_existing_atom/1` on a type string, and `config_fail_closed_test.exs`
keeps its `parse_rule/1` clauses together (both from the critic).

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| Y | shared-id positions joined with " and " only | 1 | `three rules sharing an id are named in one list`: `Assertion with =~ failed` |
