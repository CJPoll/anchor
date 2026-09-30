# Sabotage record — the one match-all allowed_functions glob (DND-1292)

- **Domain:** rule_schema
- **Branch:** dnd-1292-glob-escape
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.RuleSchema.refuse_allow_all/1`, which
  now asks `Anchor.Domain.GlobPattern.wildcard_only?/1`
- **Tests:** `test/anchor/domain/rule_checks_nothing_test.exs`
  (`module_pattern_restrictions` table: the `*`, `**`, `***` refused rows and
  the `*?`/`*!` positive row; the metacharacter positive rows for `paths`,
  `pattern` and `forbidden_patterns`)
- **Suite run:** `mix test`, the whole suite (661 tests)
- **Merge base:** `origin/main` = 87269a3; **fix commit:** b005db3
- **Primary record (same run):** `glob_pattern-20260929-dnd_1292_glob_escape.md`

## The change

Since DND-1292 every glob character but `*` is a literal, so an
`allowed_functions` entry matches every function name only when it is made of
wildcards alone. `RuleSchema` refuses such an entry through
`GlobPattern.wildcard_only?/1`, the same module that compiles the glob, rather
than its own string check. `*?` was a match-all before the fix and loaded; it
now means "the predicates" and loads correctly.

## Mutations

| # | Mutation | Tests failed | First failure |
|---|---|---|---|
| H | `refuse_allow_all/1` finds nothing (`&(GlobPattern.wildcard_only?(&1) and false)`) | 1 of 661 | `module_pattern_restrictions: every rule that checks nothing is refused…` / `allowed_functions: ["*"] allows every function: LOADED: %Anchor.Config{…}` |

The first attempt at H (`fn _ -> false end`) left the `GlobPattern` alias
unused and failed compilation under `--warnings-as-errors`; it was rewritten
warning-free and re-run. The `wildcard_only?/1` mutations (F, G) are in the
primary record.
