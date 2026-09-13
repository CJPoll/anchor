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

- **A mission may direct ONE combined record for a multi-domain run.** ADR 003
  otherwise splits a run by domain (one file each). When a mission explicitly
  directs a single record for a change that spans several domains, it is filed
  under the **primary** domain, every off-domain mutation is labelled inside it,
  and each touched test file's `Sabotage record:` comment points there — so
  `ls`-by-domain may miss it, but `grep -rl '<Module>'` will not. Precedent:
  `dependency_analyzer-*-dnd_141_*` (config + analyzer) and
  `no_dependency-*-dnd_142_*` (config + analyzer + both dependency checks).

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
- `module_pattern_restrictions` — the `module_pattern_restrictions` check: the
  extracted Domain detection (`Anchor.Domain.Checks.ModulePatternRestrictions`,
  including `allowed_functions` glob support and `pattern`/`uses_module`
  selection) and its thin Framework shell
  (`Anchor.Check.ModulePatternRestrictions`).
- `no_transitive_dependency` — the "no forbidden transitive dependency" check:
  its extracted pure detector (`Anchor.Domain.Checks.NoTransitiveDependency`,
  including `find_dependency_path` / `format_dependency_path` /
  `find_module_reference_line`) and the `Anchor.Check.NoTransitiveDependency`
  shell that delegates to it (declaring `needs_module_graph?/0`).
- `case_on_bare_arg` — the "no case on a bare function argument" check: its
  extracted pure detector (`Anchor.Domain.Checks.CaseOnBareArg`, including
  defaulted-argument (`\`) recognition) and the `Anchor.Check.CaseOnBareArg`
  shell that delegates to it.
- `single_control_flow` — the "single control flow" check: its extracted pure
  detector (`Anchor.Domain.Checks.SingleControlFlow`, including
  `find_function_clauses` / `count_control_flow_structures` /
  `already_in_pipe_chain?`) and the `Anchor.Check.SingleControlFlow` shell that
  delegates to it.
- `no_discarding_arrow_in_with` — the "no discarding arrow in with" check:
  its extracted pure detector (`Anchor.Domain.Checks.NoDiscardingArrowInWith`,
  including `extract_with_clauses` / `check_with_clauses` /
  `is_discarding_pattern?`) and the `Anchor.Check.NoDiscardingArrowInWith`
  shell that delegates to it.
- `no_comparison_in_if` — the "no direct comparisons in `if`/`unless`" check:
  its extracted pure detector (`Anchor.Domain.Checks.NoComparisonInIf`,
  including `find_if_with_comparisons` / `has_comparison?`, with `unless`
  brought into scope alongside `if`) and the `Anchor.Check.NoComparisonInIf`
  shell that delegates to it.
- `alphabetized_functions` — the "alphabetized functions" check: its extracted
  pure detector (`Anchor.Domain.Checks.AlphabetizedFunctions`, including
  `extract_functions` with `defguard`/`defguardp` support and multi-clause
  collapse, the `:all`/`:public_only`/`:separate` mode dispatch read from the T3
  atom key, `find_ordering_issues` / `find_structural_violations` and message
  building) and the `Anchor.Check.AlphabetizedFunctions` shell that delegates to
  it.
- `max_file_length` — the `max_file_length` check: its extracted pure detector
  (`Anchor.Domain.Checks.MaxFileLength`, including `count_code_lines` /
  `is_code_line?` / doc-range extraction / `get_max_lines` / message building,
  reading the maximum from the atom `:max_lines` key T3 surfaces — the BUG 2
  fix) and the `Anchor.Check.MaxFileLength` shell that acquires lines via
  `Anchor.Check.Source` and delegates to it.
- `no_tuple_match_in_head` — the "no `:ok`/`:error` tuple match in a function
  head" check: its extracted pure, AST-based detector
  (`Anchor.Domain.Checks.NoTupleMatchInHead`, including `find_function_clauses`
  / `flaggable_arg?` / `result_tuple?`, with per-argument judgment and
  match-assignment (`=`) operand recognition, replacing the previous
  regex-on-source implementation) and the `Anchor.Check.NoTupleMatchInHead`
  shell that delegates to it.
- `struct_getter_convention` — the "struct getter convention" check: its
  extracted pure detector (`Anchor.Domain.Checks.StructGetterConvention`,
  including `alias_map` / `resolve_struct_module` alias resolution (with `:as`
  and `A.{B, C}` forms), the enclosing-struct naming rule gated on a literal
  `defstruct`, and the foreign-struct `location_violation` that recovers the
  real module name) and the `Anchor.Check.StructGetterConvention` shell that
  delegates to it.
