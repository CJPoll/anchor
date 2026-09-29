# Sabotage record — config wiring of the rule schema (DND-1286)

- **Domain:** config
- **Branch:** dnd-1286-rule-key-allowlist
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Config.parse_rule/1` (its call to
  `validate_schema/2`, and the mapping of the schema's reason onto
  `{:error, {:invalid_rule, reason}}`), `Anchor.Config.rule_types/0` (now read
  from `Anchor.Domain.RuleSchema`), `Anchor.Adapters.ConfigFile.load_from_path/1`
  over the README's YAML blocks, and the data files `.anchor.yml` and
  `.anchor.example.yml`
- **Suite run:** `mix test` (the whole suite, 559 tests)
- **Merge base:** `origin/main` = 8a7fde5
- **Sibling record (same run):** `rule_schema-20260929-dnd_1286_rule_key_allowlist.md`
  (the fail-first run is recorded there)

## Fixture changes, and why none widened the allowlist

The selector requirement made 36 existing Domain config rows and one adapter
row fail, each because its
rule had no selector (for example `Config.parse_rule(%{"type" =>
"no_direct_dependency"})`). Those rows test other keys, and the rules they built
select no file. They now go through a local `parse_rule/1` helper in
`config_test.exs` and `config_fail_closed_test.exs`, which adds `pattern: "*"`
only when the rule names no selector of its own. Rows that build a document for
`parse_config/1`, and the adapter's `load/0` fixture, got a selector inline.

Two rows would have kept passing for the wrong reason, so each now asserts its
reason:
- `an invalid same_context rule makes parse_config surface an error` asserted
  `{:invalid_rule, _reason}`. Its rule had no selector, so it failed on that,
  not on `same_context`. It now carries a `pattern` and asserts
  `reason =~ "same_context"`.
- The adapter's `an invalid same_context rule fails the load` row, the same
  way. It now asserts `reason =~ "same_context: true requires forbidden_patterns"`.

No key was added to the allowlist to keep a fixture green. The dogfood
`.anchor.yml`, `.anchor.example.yml` and every README YAML block that holds a
rule already used only the keys their types read, and each rule had a selector.
The new row "every rule in every README YAML block loads" pins that.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| N | `parse_rule/1` ignores `validate_schema/2` (`with _ <-`): the wiring removed | 18 | `code: assert {:error, {:invalid_rule, reason}} =` / `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :reference,`; both e2e rows: `left: [issue]` / `right: []` |
| O | `validate_schema/2` maps the schema's error to `:ok` | 18 | the same rows as N, the same strings |

The data files are covered by the DND-1265 row "the repo's .anchor.yml and
.anchor.example.yml both load" (mutation AF of the DND-1265 config record) and
the new README-blocks row. Mutation K of the sibling record (dropping `match`
from `no_direct_dependency`) reddens the README-blocks row, which proves it
reads the allowlist.

## Review round

`validate_new_keys/2` now takes the parsed type atom, and the `rule_type/1`
helper is gone. Since `parse_type/1` runs first, its clauses for a missing or
non-string type could no longer run. The `same_context` messages now name the
type the same way for `:no_direct_dependency` and `no_direct_dependency`. The
DND-1265 row "a mapping as the type fails with a reason, not a crash" still
guards the crash that helper once caused (mutation V of the DND-1265 record):
the type parse now rejects the mapping before any other validation runs.

## Traps

- N first printed no test count: deleting the `with` clause left
  `validate_schema/2` unused, and `mix test` compiles with
  `--warnings-as-errors`. It was rewritten as `_ <- validate_schema(rule, type)`
  and re-run.
