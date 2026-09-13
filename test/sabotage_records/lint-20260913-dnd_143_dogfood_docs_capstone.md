# Sabotage record — Lint pipeline composition capstone (DND-143)

- **Domain:** lint
- **Branch:** dnd-143-dogfood-docs-capstone
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Managers.Lint.run/4` (public entry) composing `Anchor.Adapters.ConfigFile` → `Anchor.Config` → `Anchor.Check.Source` → `Anchor.Domain.DependencyAnalyzer` → `Anchor.Domain.RuleMatching` / `GlobPattern` → `Anchor.Domain.Checks.NoDependency`
- **Suite run:** `mix test test/anchor/integration/gap_capstone_test.exs`
- **Merge base:** `git merge-base origin/main HEAD` = 338e509

This is the DND-143 capstone integration test (`GapCapstoneTest`). It drives the
REAL lint pipeline through its public Manager entry — the only injected boundary
is the config loader, whose `load/0` forwards to the REAL
`Anchor.Adapters.ConfigFile.load_from_path/1` parsing a real `.anchor.yml`-shaped
fixture. Because the per-unit behavior of each gap is OWNED and sabotaged by the
upstream unit tickets, the mutations here target the **composition / wiring** in
`Anchor.Managers.Lint` (the module this integration test newly exercises
end-to-end), and the per-gap detection/parse rows are recorded below as measured
zeros pointing at their upstream records rather than re-mutated here.

## Integration-specific mutations (on `Anchor.Managers.Lint`)

Each mutation was applied alone (with the rest of the tree intact) and reverted
with `git checkout -- lib/anchor/managers/lint.ex` (the Manager is committed
code, so the checkout restores the real implementation — not a blank).

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| M1 | `file_facts/2`: `module_names: Enum.map(DependencyAnalyzer.extract_module_names(ast), &to_string/1)` → `module_names: []` (starve the module-name facts the `pattern` selector reads) | **1** | `scenario 5: a pattern-selected rule (no paths key) selects and reports` — `match (=) failed` — `left: {:ok, [{^source_file, [%Anchor.Domain.Violation{trigger: "WaltUi.Billing.Adapters.Client"}]}]}` — `right: {:ok, [{%SourceFile<lib/app/domain/thing.ex>, []}]}` |
| M2 | `matching_rules/4`: `\|> Enum.filter(&RuleMatching.rule_matches_file?(&1, facts))` → `\|> Enum.reject(...)` (invert file selection — nothing that should match is selected) | **4** | scenarios 1, 3b, 4, 5 each `match (=) failed` with `right: {:ok, [{<file>, []}]}` (empty violations). E.g. scenario 1: `left: {:ok, [{^source_file, [%Anchor.Domain.Violation{trigger: "WaltUi.Contacts.Adapters.Repositories.Repository"}]}]}` — `right: {:ok, [{%SourceFile<lib/app/contacts/service.ex>, []}]}`; scenario 4 trigger `":telemetry"`; scenario 3b trigger `"Foo.Adapters.Loader"`. |

### What M1 isolates

Scenario 5 is the only scenario whose rule selects by module `pattern` (no
`paths` key → `paths: nil` via the real `parse_rule/1`, the Gap-D path). M1
empties the module-name facts, so the `pattern` selector can no longer match and
the rule is not selected → no violation. Scenarios 1–4 select by `paths` globs
(unaffected by `module_names`), so they stayed **green** under M1 — confirming M1
isolates exactly the fact-derivation the pattern selector depends on, the
integration wiring of Gap D.

### What M2 isolates

Inverting the file-selection filter makes the Manager select the files that
should NOT match and drop the ones that should, so every violation-expecting
scenario (1, 3b, 4, 5) reddens and both positive controls (2 Domain-only, 3a
inert-map-value) stay **green** (they already expect `[]`, and are still handed
`[]`). This proves the whole acquire → derive-facts → select → detect
composition through the Manager is load-bearing for the reported violations —
the integration guarantee this test exists to make.

M2 was first attempted as "force `matching_rules` to `[]`", which orphaned
`file_facts/2` and failed `--warnings-as-errors` compilation before any test ran
(ADR-002 compile-clean trap). The `Enum.filter → Enum.reject` inversion is the
minimal compile-clean form that drops selection while keeping every helper used.

## Measured zeros — per-gap detection/parse owned upstream

The following behaviors each scenario relies on are NOT re-mutated here; mutating
them lives in the upstream unit records, and doing so again would duplicate, not
add, coverage. Recorded explicitly as zeros for this file so the reader knows
where the protecting mutation is:

- **Gap A — `forbidden_patterns` match & dot-bounded negative** (scenarios 1, 2):
  owned by `no_dependency-20260913-dnd_142_gap_a_forbidden_patterns_match.md`
  (mutation A re-reds `NoDependency` rows 1/4/5, and the dot-bounded negative is
  itself a measured zero recorded there).
- **Gap A′ — `match: call` carve-out** (scenarios 3a/3b): owned by the same
  DND-142 record (mutations C1/C3 — inert map value not recorded, `:call` mode
  consulting the call set).
- **Gap B — leading-colon `:telemetry` atom token** (scenario 4): owned by
  `dependency_analyzer-20260913-dnd_141_gap_b_erlang_atom_targets.md` (mutation A
  bare-atom callee, mutation B `parse_modules` leading-colon token, mutation C
  `first_reference_line` atom branch).
- **Gap D — absent `paths` ⇒ `nil` and pattern fall-through** (scenario 5): owned
  by `config-20260913-dnd_140_gap_d_rule_selection.md` (parser) and
  `rule_matching-20260913-dnd_140_gap_d_rule_selection.md` (selection). M1 above
  additionally proves Gap D's *integration wiring* through the Manager.

## Notes

- Positive controls (scenarios 2 and 3a) held on every run; the integration
  suite returned to **6 tests, 0 failures** after each
  `git checkout -- lib/anchor/managers/lint.ex`, and the full suite is **384
  tests, 0 failures**.
- No production logic was added by DND-143 (all four gaps ship in DND-140/141/142);
  the mutations here are on the existing committed `Anchor.Managers.Lint`, so the
  checkout restores the real Manager rather than a pre-fix HEAD.
