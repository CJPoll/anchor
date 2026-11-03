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
`Anchor.Check.` / `Anchor.` / `Anchor.Domain.` / `Anchor.Managers.` prefix
dropped and lowercased to `snake_case`. `YYYYMMDD` is the UTC date the run was
performed.
`<sanitized-branch>` is the branch with every non-`[A-Za-z0-9]` run replaced by
`_`.

## Domain vocabulary in use

Derive `<domain>` from the check or module under test. Reuse a word already here
before coining a synonym.

- `config` — configuration parsing and loading: the pure parser
  (`Anchor.Config`), the pure candidate-path computation
  (`Anchor.Domain.ConfigPaths`), and the file adapter
  (`Anchor.Adapters.ConfigFile`). All three share this domain word.
- `lint` — `Anchor.Managers.Lint`, the pipeline-composition Manager (the public
  lint entry that composes config loading, AST acquisition, fact derivation, rule
  selection, and detection). Used for end-to-end/integration runs that mutate the
  Manager wiring rather than a single check's Domain detection.
- `base` — `Anchor.Check.Base`, the shared Framework layer every check `use`s:
  mapping violations to Credo issues and choosing the run's shared-failure
  reporter (DND-1265).
- `failures` — `Anchor.Domain.Failures`, the text of every fail-closed report
  (missing or invalid config, unparseable file, a check that crashed on a file).
- `source` — `Anchor.Check.Source`, the AST/source acquisition edge.
- `sabotage_scope` — `mix anchor.sabotage scope` (DND-5472): the diff parser
  (`Anchor.Domain.Sabotage.DiffHunks`), the function spans
  (`Anchor.Domain.Sabotage.FunctionSpans`), the mapping and its counts
  (`Anchor.Domain.Sabotage.Scope`), the git adapter
  (`Anchor.Adapters.GitChangeSource`) and the environment the git adapters run
  with (`Anchor.Adapters.GitEnv`, DND-5581; `GitStatus`'s use of it is
  `sabotage`'s), the `scope/2` Manager path and the task.
- `effects` — effect inference and the `effects_match_bucket` graph rule
  (DND-5447): `Anchor.Domain.EffectPrimitives`' inference half,
  `Anchor.Domain.Roots`, `Anchor.Domain.Effects`,
  `Anchor.Domain.GraphRules.EffectsMatchBucket`, and their wiring in the graph
  runner.
- `struct_flow` — the `struct_owned_by_module_flow` graph rule (DND-5454):
  `Anchor.Domain.StructTypes`, `Anchor.Domain.StructFlow`,
  `Anchor.Domain.GraphRules.StructOwnedByModuleFlow`, and the scope it shares
  with the AST rule, `Anchor.Domain.StructOwnership`.
- `sabotage` — the causal sabotage generator (DND-5471): every
  `Anchor.Domain.Sabotage.*` module that makes mutants (`Mutator`,
  `Operators`, `OrphanCheck`, `SourceTree`, `Patch`, `MutantId`,
  `EffectCalls`, `Mutant`, `Skipped`), and the runner (DND-5473):
  `mix anchor.sabotage run`/`restore`, its Domain (`Config`, `TestMirror`,
  `TestSelection`, `Plan`, `TestRun`, `Outcome`, `Journal`, `Run`, `Report`,
  `BoundedOutput`, `NoMutant`),
  `Anchor.Managers.Sabotage.Runner`, the adapters `SourcePatcher`,
  `GitStatus` and `TestRunner`, and `Anchor.Sabotage.ExUnitFormatter`.
  `sabotage_scope` stays the word for the diff scope.
- `dependency_analyzer` — `Anchor.Domain.DependencyAnalyzer`, the pure AST
  walk behind every dependency fact (module names, references, calls, uses,
  the module graph).
- `beam_reader` — `Anchor.Adapters.BeamReader` (DND-5438): reading `.beam`
  files and decoding each through `:beam_lib` and its debug-info backend
  (`elixir_v1`, `core_v1`), and the decode error values.
- `core_walker` — `Anchor.Domain.Graph.CoreWalker` (DND-5438): call and
  struct-use edges read from a function's Core Erlang.
- `builder` — `Anchor.Domain.Graph.Builder` (DND-5438): the causal graph built
  from decoded beams and source facts (module facts, `generated?`,
  `unreadable`), with the `Anchor.Domain.Graph` queries, and
  `Anchor.Domain.Graph.ProjectFile` (DND-5588): a beam's source path placed
  against the project root.
- `inlines` — `Anchor.Domain.Graph.Inlines` and `Inlines.Derive` (DND-5551):
  the stdlib calls Elixir inlines before Core, derived from `:elixir_rewrite`,
  their two spellings in `Graph.calls_to/2`, and the inlined `Map.put` the
  walker reads from a map update.
- `graph_runner` — `mix anchor.graph` (DND-5440): the Manager
  (`Anchor.Managers.Graph`), the task, the model (`Anchor.Domain.Model`), the
  rule registry and floors (`Anchor.Domain.GraphRules`), the report
  (`Anchor.Domain.GraphReport`), the artifact key (`Anchor.Domain.GraphKey`),
  the `SourceReader` and `GraphArtifact` adapters, and the canary tree. Its
  changes to modules that have a word of their own are filed under that word
  (`classification`, `failures`, `rule_coverage`, `architecture`, `builder`).
- `source_facts` — `Anchor.Domain.Graph.SourceFacts` (DND-5438): the literal
  `defmodule`s and `use`s of a source file.
- `glob_pattern` — `Anchor.Domain.GlobPattern` (glob / module-name pattern
  matching for rule selection).
- `rule_matching` — `Anchor.Domain.RuleMatching` (pure rule-selection predicate).
- `rule_schema` — `Anchor.Domain.RuleSchema` (DND-1286): the per-rule-type key
  allowlist, the selector every rule needs, and the README table that mirrors
  the allowlist. Since DND-1290 also the relation each type needs and the rest
  of "a rule that loads but checks nothing".
- `function_ref` — `Anchor.Domain.FunctionRef` (DND-1267): the
  `forbidden_functions` token grammar and the comparison of a call (or an
  unresolvable call) with a token.
- `architecture` — `Anchor.Domain.Architecture` and its `Bucket` and `Selector`
  (DND-5437): the `architecture:` section of `.anchor.yml`, parsed fail-closed,
  and a selector matched against a module's facts.
- `classification` — `Anchor.Domain.Classification` (DND-5437): which bucket a
  module is in (exactly one, no precedence), its context, and each bucket's
  count against its `min_modules` floor.
- `rule_coverage` — `Anchor.Domain.RuleCoverage` (DND-1290): which rules
  checked nothing in a run (below their `min_files` floor, or of a type no
  enabled check reads).
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
- `no_discarded_pure_expression` — the `no_discarded_pure_expression` rule
  (DND-5451, proposal F1): its pure detector
  (`Anchor.Domain.Checks.NoDiscardedPureExpression`, the definition of pure,
  the stdlib pure set and `pure_patterns`) and the
  `Anchor.Check.NoDiscardedPureExpression` shell that delegates to it.
- `no_forwarding_function` — the `no_forwarding_function` rule (DND-5452,
  proposal F4, same module): its pure detector
  (`Anchor.Domain.Checks.NoForwardingFunction`) and the
  `Anchor.Check.NoForwardingFunction` shell that delegates to it.
- `struct_owned_by_module` — the `struct_owned_by_module` rule (DND-5453, the
  in-file port of crew's StructOnlyChangedByOwnModule): its pure detector
  (`Anchor.Domain.Checks.StructOwnedByModule`, owners, pattern positions,
  known variables, `owned_namespaces`) and the `Anchor.Check.StructOwnedByModule`
  shell that delegates to it.
- `data_flow` — `Anchor.Domain.DataFlow` and its `DataFlow.*` modules
  (DND-5439): def-use over one clause's source AST, backward slices with
  control dependence, dead expressions, single-exit regions, the orphan check
  and the unsliceable forms (`receive`, the process dictionary, `var!`,
  `binding()`).
- `graph_algorithms` — `Anchor.Domain.GraphAlgorithms` (DND-5444):
  dominators and post-dominators from a virtual root/exit, union-find
  components, Tarjan SCCs, the condensation and cyclic SCCs.
- `cfa` — the 0-CFA (DND-5497): `Anchor.Domain.Cfa`, `Cfa.Eval` and
  `Cfa.Value`, with the Core labels it reads (`Anchor.Domain.Core`) and the
  library invokers table (`Anchor.Domain.HigherOrder`), in one record.
- `demand` — the demand (absence) analysis (DND-5498): `Anchor.Domain.Demand`,
  `Demand.Lattice`, `Demand.Transfer` and `Demand.Param`, with the effect and
  pure-call tables it reads (`Anchor.Domain.EffectPrimitives`,
  `Anchor.Domain.PureCalls`), in one record.
- `digraph` — `Anchor.Domain.Digraph` (DND-5444), the plain immutable graph
  value the graph algorithms run over.
- `baseline` — report, baseline, enforce (DND-5441): `Anchor.Domain.Baseline`,
  `Enforcement` and `ViolationKey`, the engine common keys in `RuleSchema`,
  report-mode detection in `Managers.Lint` and `Check.Base`, the ratchet in
  `Managers.Graph`, `BaselineFile`, `GitShow` and the task's baseline flags.
- `layering` — the `layering` graph rule (DND-5442):
  `Anchor.Domain.GraphRules.Layering`, `CallMatrix`, `DynamicCalls`,
  `ViolationKey.mfa/1`, its registration and Config's architecture check of
  graph rules and known types.
- `context_acyclic` — the `context_acyclic` graph rule (DND-5445):
  `Anchor.Domain.ContextGraph`, `GraphRules.ContextAcyclic`,
  `ViolationKey.graph_key/2` and its registration.
- `dialyzer_boundary` — the DND-5499 spike runner
  `test/fixtures/dialyzer_boundary/run.exs` (not a check: it measures what
  Dialyzer reports for clause reachability on the fixtures beside it, so F8
  reports only what Dialyzer misses).
