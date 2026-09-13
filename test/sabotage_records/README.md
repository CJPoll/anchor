# Sabotage records

One file per sabotage run, named `<domain>-YYYYMMDD-<sanitized-branch>.md`, per
ADR 003 (`adrs/003-sabotage-records-one-file-per-run.md`). This directory holds
the recorded mutations that prove Anchor's tests actually fail when the code
they protect is broken. A test is not finished until you have watched it fail:
delete/mutate the thing the test exists to prove, run the suite, confirm the
failure names the right criterion, restore the code, and write the verbatim
failure string down here.

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

## Filename convention

`<domain>-YYYYMMDD-<sanitized-branch>.md` — three parts, two hyphens, no part
contains a hyphen. `<domain>` is the check or module under test with the
`Anchor.Check.` / `Anchor.` / `Anchor.Domain.` prefix dropped and lowercased to
`snake_case`. `YYYYMMDD` is the UTC date the run was performed.
`<sanitized-branch>` is the branch with every non-`[A-Za-z0-9]` run replaced by
`_`.

## Domain vocabulary in use

Derive `<domain>` from the check or module under test. Reuse a word already here
before coining a synonym.

- `config` — configuration parsing and loading: the pure parser
  (`Anchor.Config`), the pure candidate-path computation
  (`Anchor.Domain.ConfigPaths`), and the file adapter
  (`Anchor.Adapters.ConfigFile`). All three share this domain word.
- `glob_pattern` — `Anchor.Domain.GlobPattern` (glob / module-name pattern
  matching for rule selection).
- `rule_matching` — `Anchor.Domain.RuleMatching` (pure rule-selection predicate).
- `must_use_module` — the `must_use_module` check: the extracted Domain
  detection (`Anchor.Domain.Checks.MustUseModule`) and its thin Framework shell
  (`Anchor.Check.MustUseModule`).
- `no_dependency` — the "no forbidden direct dependency" check: its extracted
  pure detector (`Anchor.Domain.Checks.NoDependency`) and the
  `Anchor.Check.NoDependency` shell that delegates to it.
- `no_transitive_dependency` — the "no forbidden transitive dependency" check:
  its extracted pure detector (`Anchor.Domain.Checks.NoTransitiveDependency`,
  including `find_dependency_path` / `format_dependency_path` /
  `find_module_reference_line`) and the `Anchor.Check.NoTransitiveDependency`
  shell that delegates to it (declaring `needs_module_graph?/0`).
- `single_control_flow` — the "single control flow" check: its extracted pure
  detector (`Anchor.Domain.Checks.SingleControlFlow`, including
  `find_function_clauses` / `count_control_flow_structures` /
  `already_in_pipe_chain?`) and the `Anchor.Check.SingleControlFlow` shell that
  delegates to it.
