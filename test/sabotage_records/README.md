# Sabotage records

One file per sabotage run, named `<domain>-YYYYMMDD-<sanitized-branch>.md`, per
ADR 003 (`adrs/003-sabotage-records-one-file-per-run.md`). This directory holds
the recorded mutations that prove Anchor's tests actually fail when the code
they protect is broken.

- **Discovery is the filesystem**, not an index. There is deliberately no
  contents list here (an append-only index is the rebase-conflict artifact ADR
  003 removes). Find records by domain, module, or theme:

  ```bash
  ls test/sabotage_records/config-*                     # by domain
  grep -rl 'parse_mode' test/sabotage_records/          # by module/function
  grep -rn 'measured zero' test/sabotage_records/       # by theme
  ```

- **Read the matching records before weakening a check** — especially rows
  recording a measured **zero**, which flag a claim no test protects.

## Domain vocabulary in use

Derive `<domain>` from the check or module under test (drop the `Anchor.` /
`Anchor.Check.` prefix, lowercase to `snake_case`). Reuse a word already here
before coining a synonym.

- `config` — configuration parsing and loading: the pure parser
  (`Anchor.Config`), the pure candidate-path computation
  (`Anchor.Domain.ConfigPaths`), and the file adapter
  (`Anchor.Adapters.ConfigFile`). All three share this domain word.
