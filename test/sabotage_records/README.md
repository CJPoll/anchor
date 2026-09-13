# Sabotage records

This directory holds one file per sabotage run, per ADR 003
(`adrs/003-sabotage-records-one-file-per-run.md`). A test is not finished until
you have watched it fail: delete/mutate the thing the test exists to prove, run
the suite, confirm the failure names the right criterion, restore the code, and
write the verbatim failure string down here.

## Filename convention

`<domain>-YYYYMMDD-<sanitized-branch>.md` — three parts, two hyphens, no part
contains a hyphen. `<domain>` is the check or module under test with the
`Anchor.Check.` / `Anchor.` / `Anchor.Domain.` prefix dropped and lowercased.
`YYYYMMDD` is the UTC date the run was performed. `<sanitized-branch>` is the
branch with every non-`[A-Za-z0-9]` run replaced by `_`.

Discovery is the filesystem: `ls <domain>-*`, `grep -rl <module>`, etc. There is
no index file — this README describes only the convention and the vocabulary.

## Domain vocabulary in use

- `glob_pattern` — `Anchor.Domain.GlobPattern` (glob / module-name pattern
  matching for rule selection).
- `rule_matching` — `Anchor.Domain.RuleMatching` (pure rule-selection predicate).
