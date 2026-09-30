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

## Rows that stayed green on unfixed 87269a3, and why

Moving the match-all check from a private `String.trim/2` test to
`GlobPattern.wildcard_only?/1` changes no load result. So the `***` refused row,
the `*?`/`*!` positive row and the `paths`/`pattern`/`forbidden_patterns`
metacharacter positive rows all passed before the fix too: loading never
compiled a glob. They pin the load side; the matcher side of the same defect
failed first in `glob_pattern_test.exs`, the check suites and the e2e suite
(primary record). Mutation H reddens the refused rows; no mutation of the load
path reddens the metacharacter positive rows, since no load-time code reads a
glob's characters beyond `wildcard_only?/1` (mutation G in the primary record
reddens the `*?` row). That is a measured zero for those three positive rows,
recorded here on purpose: they guard against a future load-time glob check that
refuses a legitimate metacharacter.

The first attempt at H (`fn _ -> false end`) left the `GlobPattern` alias
unused and failed compilation under `--warnings-as-errors`; it was rewritten
warning-free and re-run. The `wildcard_only?/1` mutations (F, G) are in the
primary record.
