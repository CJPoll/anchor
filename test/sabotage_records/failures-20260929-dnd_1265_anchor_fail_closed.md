# Sabotage record — fail-closed messages (DND-1265)

- **Domain:** failures
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Failures.config_violation/1`,
  `Anchor.Domain.Failures.unparseable_violation/2`
- **Suite run:** `mix test` (the whole suite, 530 tests)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `lint-`, `base-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

`Anchor.Domain.Failures` is new in this change, so its own rows failed first
with `Anchor.Domain.Failures.config_violation/1 is undefined`. The behaviour it
carries was proven fail-first through the e2e rows (see the base record).

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| K | the not-found message joins no searched paths | 2 | `assert violation.message =~ "Searched: /p/apps/a/.anchor.yml, /p/.anchor.yml."` / `left: "Anchor found no .anchor.yml, so no Anchor rule was checked. Searched: . Fix: create .anchor.yml at one of the searched paths ...` ; e2e: `right: "Searched: /tmp/anchor_e2e_1676/.anchor.yml"` |
| L | the unparseable message loses its `Fix:` line | 4 | `assert violation.message =~ "Fix:"` / `left: "Anchor could not parse this file, so no Anchor rule was checked against it: missing terminator: end."` / `right: "Fix:"` (also the Lint, check_file and e2e rows) |

No measured zeros.
