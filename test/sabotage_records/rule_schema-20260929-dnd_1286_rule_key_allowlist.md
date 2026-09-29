# Sabotage record — per-rule-type key allowlist and selector (DND-1286)

- **Domain:** rule_schema
- **Branch:** dnd-1286-rule-key-allowlist
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleSchema` (`validate/2`, `known_keys/1`,
  `rule_types/0`, `common_keys/0`, `@keys_by_type`, the unknown-key reason and
  its hints, the selector shape and presence checks), and the README table
  "Keys each rule type accepts"
- **Suite run:** `mix test` (the whole suite, 559 tests)
- **Merge base:** `origin/main` = 8a7fde5
- **Sibling record (same run):** `config-20260929-dnd_1286_rule_key_allowlist.md`

## Fail-first run

The tests were written first and run against the unfixed code on 8a7fde5:
`559 tests, 22 failures`, every one a new DND-1286 test. The rows that show the
defect, verbatim (long rule maps cut with `...`):

```
  3) test an unknown key inside a rule a typo'd key fails the rule, for every rule type (Anchor.Domain.RuleSchemaTest)
     ** (MatchError) no match of right hand side value:
         %{
           match: :reference,
           type: :alphabetized_functions,
           mode: nil,
           pattern: "*.Domain.*",
           ...

  8) test a rule with no selector fails for every rule type, naming the selector keys (Anchor.Domain.RuleSchemaTest)
     ** (MatchError) no match of right hand side value:
         %{
           match: :reference,
           type: :alphabetized_functions,
           mode: nil,
           pattern: nil,
           ...
           paths: nil,

 17) test an unknown key inside a rule a key another rule type reads is unknown here, and the reason says where it belongs (Anchor.Domain.RuleSchemaTest)
     code:  assert {:error, {:invalid_rule, reason}} =
              Config.parse_rule(rule(:no_transitive_dependency, %{"match" => "call"}))
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              match: :call,
              type: :no_transitive_dependency,
              ...

 19) test a malformed selector a `paths` that is a string, not a list, fails (Anchor.Domain.RuleSchemaTest)
     code:  assert {:error, {:invalid_rule, reason}} =
              Config.parse_rule(%{"type" => "single_control_flow", "paths" => "lib/a.ex"})
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              ...
              paths: "lib/a.ex",

 21) test config load error (A7) an unknown key inside a rule is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 22) test config load error (A7) a rule with no selector is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     code:  assert [issue] = issues
     left:  [issue]
     right: []
```

Rows 21 and 22 are the live defect end to end: a `no_direct_dependency` rule
with `forbiden_patterns:`, and one with no selector, each ran through the real
`run_on_all_source_files/3` over a file calling `MyApp.Repo`, and each read
green. Row 17: `match` on a `no_transitive_dependency` rule parsed to
`match: :call`, which that check never reads.

The `known_keys/1`, `rule_types/0` and `common_keys/0` rows failed first only
because the module did not exist:

```
 18) test the positive case the allowlist covers exactly the rule types of Anchor.checks/0 (Anchor.Domain.RuleSchemaTest)
     ** (UndefinedFunctionError) function Anchor.Domain.RuleSchema.rule_types/0 is undefined (module Anchor.Domain.RuleSchema is not available)
```

The README-table row failed first because the table did not exist
(`** (MatchError) no match of right hand side value:` on the README split).
Mutations K, L, M and P prove those rows.

After the fix: `559 tests, 0 failures`.

## Mutations

Each mutation was applied alone, the whole suite run, and the file restored
with `git checkout HEAD -- <file>` from a commit holding the fix. Every one
reddened at least one test.

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| A | `validate/2` ignores `validate_keys/2` (`with _ <-`): the unknown-key defect | 10 | `code: assert {:error, {:invalid_rule, reason}} =` / `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :call,`; e2e: `left: [issue]` / `right: []` |
| B | `known_keys/1` ignores the type: the union of every type's keys | 4 | the `match`-on-`no_transitive_dependency` row: `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :call,` |
| C | loose comparison: a key sharing a known key's first four letters is accepted | 5 | `code: assert {:error, {:invalid_rule, reason}} =` / `right: %{` then `match: :reference,` (the near-miss and per-type typo rows, and the e2e row) |
| D | `validate/2` ignores `require_selector/1`: the no-selector defect | 4 | `a rule with no selector \`recursive\` alone is not a selector`: `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :reference,`; e2e: `left: [issue]` / `right: []` |
| E | `selects?/2`: an empty `paths` list counts as a selector | 1 | `an explicit empty \`paths\` is no selector`: `left: {:error, {:invalid_rule, reason}}` / `right: %{` |
| F | `validate/2` ignores `validate_selector_types/1` | 4 | `code: assert reason =~ "\`pattern\` must be a non-empty string"` / `left: "the rule has no selector, so it would select no file; ..."` |
| G | no did-you-mean suggestion (`@suggestion_threshold 1.01`) | 2 | `code: assert reason =~ ~s(did you mean "forbidden_patterns"?)` / `left: "unknown key \"forbiden_patterns\" in a no_direct_dependency rule; known keys for no_direct_dependency: ..."` |
| H | no "applies to" hint for another type's key | 1 | `code: assert reason =~ "\`match\` applies to: no_direct_dependency"` / `left: "unknown key \"match\" in a no_transitive_dependency rule; known keys for no_transitive_dependency: ..."` |
| I | only the first unknown key is named | 1 | `code: assert reason =~ ~s(unknown keys "alpha", "zeta")` / `left: "unknown keys \"alpha\" in a must_use_module rule; ..."` |
| J | the known keys are left out of the reason | 1 | `left: "unknown key \"forbiden_patterns\" in a no_direct_dependency rule (\"forbiden_patterns\": did you mean \"forbidden_patterns\"?); see the README"` |
| K | allowlist too narrow: `match` dropped from `no_direct_dependency` | 11 | README drift row: `README row for no_direct_dependency`; e2e: `left: "Anchor rejected /tmp/anchor_e2e_1927/.anchor.yml, so no Anchor rule was checked: rule 1: unknown key \"match\" in a no_direct_dependency rule; known keys for no_direct_dependency: ... Fix: correct ... to match the README section \"Config schema: rule keys at a glance\"."`; also both Gap A' capstone scenarios and the README-blocks row |
| L | allowlist too wide: `id` added to `must_use_module`, README not updated | 2 | `** (KeyError) key "id" not found in:` (the positive row has no documented value for it); the README drift row |
| M | a rule type with no check (`made_up_type: []`) | 4 | README row: `code: assert Map.keys(documented) \|> Enum.sort() == RuleSchema.rule_types()` / `left: [:alphabetized_functions, :case_on_bare_arg, :max_file_length, ...]` / `right: [:alphabetized_functions, :case_on_bare_arg, :made_up_type, :max_file_length, ...]`. Drift rows: `code: assert RuleSchema.rule_types() == check_types` / `left: [:alphabetized_functions, :case_on_bare_arg, :made_up_type,` / `right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,`; and `code: assert Enum.sort(Config.rule_types()) == check_types` with the same `left:`/`right:` |
| P | data: the README row for `no_transitive_dependency` deleted | 1 | `code: assert Map.keys(documented) \|> Enum.sort() == RuleSchema.rule_types()` / `left: [..., :no_discarding_arrow_in_with, :no_tuple_match_in_head, ...]` / `right: [..., :no_discarding_arrow_in_with, :no_transitive_dependency, :no_tuple_match_in_head, ...]` |

M and P ran before the review round rewrote the README row's first assertion
(it now compares the row list, so a duplicated row fails too). The strings
above are from that earlier assertion.

## Review round additions (fail-first)

The code review found that `paths: [""]` passed as a selector, though an empty
glob matches no file. A row was added and run against the pre-fix
`rule_schema.ex` (commit dbbc7c5): `560 tests, 3 failures`.

```
  2) test a malformed selector a `paths` list holding an empty string fails (Anchor.Domain.RuleSchemaTest)
     code:  assert {:error, {:invalid_rule, reason}} =
              Config.parse_rule(%{"type" => "single_control_flow", "paths" => [""]})
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              match: :reference,
              type: :single_control_flow,
```

The other two were the reworded message
(`left:  "\`paths\` must be a list of path-glob strings, got: \"lib/a.ex\""`).
After the fix (each `paths` entry must be a non-empty string): `560 tests, 0 failures`.

Two more mutations, on the review-round code (560 tests):

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| R | data: the README row for `case_on_bare_arg` duplicated (the old map-based parser merged it silently) | 1 | `code: assert rows \|> Enum.map(&elem(&1, 0)) \|> Enum.sort() == RuleSchema.rule_types()` / `left: [:alphabetized_functions, :case_on_bare_arg, :case_on_bare_arg,` / `right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,` |
| S | `paths` entries may be empty strings (`&is_binary/1`) | 1 | `code: assert {:error, {:invalid_rule, reason}} =` / `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :reference,` |

## Rows that stayed green, and why

- Under A, the selector rows stay green: they carry no unknown key.
- Under D, the unknown-key rows stay green: each of them carries a `pattern`.
- Under E, only the empty-`paths` row moves. The other selector rows use an
  absent selector, which `selects?/2` never sees as a list.
- Under B, the per-type typo row stays green: every typo in `@typos` is unknown
  to every type, so a union allowlist still rejects it. The cross-type rows
  (`match`, `same_context` on `no_transitive_dependency`) are what catch B.

## Traps

- The first runs of A, D, F, G, H and N printed no test count: each mutation
  left an unused function, variable or attribute, or an unreachable clause, and
  `mix test` compiles with `--warnings-as-errors`. That is a compile failure,
  not a test failure. Each was rewritten to compile cleanly (`with _ <-` in
  place of `:ok <-`, a threshold above 1.0, a `key == :never` filter) and
  re-run; the rows above are from the clean runs.
- Every mutated file was committed before its run, so the driver's
  `git checkout HEAD -- <file>` restored exactly the committed code.
  `git status --short` was clean after every batch.
