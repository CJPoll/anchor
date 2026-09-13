# Sabotage record — Managers.Lint orchestration wiring (measured-zero note)

- **Domain:** lint
- **Branch:** dnd-124-t4-managers-lint
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Managers.Lint` (`run/4` orchestration), `Anchor.Check.Base`
  (`%Violation{}` -> `Credo.Issue` mapping), `Anchor.Adapters.ConfigLoader` behaviour,
  `Anchor.Domain.Violation`
- **Suite run:** `mix test test/anchor/managers/lint_test.exs test/anchor/integration/lint_composition_test.exs test/anchor/domain/violation_test.exs`
- **Merge base:** a2fec6031f344391adbd05606c86ec5b1c73690a

## Why this is (mostly) a measured zero

T4 is a **wiring** ticket. It moves orchestration out of `Anchor.Check.Base`
(Framework) into `Anchor.Managers.Lint` (Manager) and introduces a `ConfigLoader`
behaviour + a `%Violation{}` Domain type. It authors **no new detection logic and
no new rule-selection/index logic**:

- **Rule selection** is `Anchor.Domain.RuleMatching` + `Anchor.Domain.GlobPattern`,
  authored and sabotage-recorded by **T2**
  (`rule_matching-20260913-...`, `glob_pattern-20260913-...`). The Manager only
  *calls* the same predicate `Base` called before; the composition is a
  byte-for-byte move.
- **Config parsing/loading** is `Anchor.Config` + `Anchor.Adapters.ConfigFile`,
  authored and sabotage-recorded by **T3** (`config-20260913-...`).
- **Per-check detection** bodies are unchanged from before T4 — each moved from
  `check_file/3` to `detect_violations/4` verbatim (create_issue -> build a
  `%Violation{}` with the identical message/line/trigger). Their characterization
  tests (owned by T1/T6.x) stay green through the `check_file/3` backward-compat
  shim, proving the moved bodies are behavior-identical.

So there is no *new* selection/index anchor to record here that T2/T3 do not
already cover. Per the T4 brief and ADR 003, this file records that fact.

## Anchors nonetheless measured (wiring has teeth)

Even though T4 adds no new detection logic, the new **wiring** is protected, and
that was verified by mutation rather than asserted. Each mutation was applied,
the suite run, the failure observed, then reverted (tree returned to
`236 tests, 0 failures`).

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | `Lint.matching_rules/4`: force `RuleMatching.rule_matches_file?/2` to `… or true` (skip per-file selection) | 2 | `lint_composition_test.exs` rows #4 and #7 — `assert {:ok, [{^source_file, []}]}` — `left: {:ok, [{^source_file, []}]}` / `right: {:ok, [{…, [%Violation{…}]}]}` (unselected files wrongly produced violations) |
| B | `Check.Base` `violations_to_issues/2`: map `trigger: violation.message` instead of `violation.trigger` | 3 | `must_use_module_test.exs` — `assert issue.trigger == "MyApp.Base"` — `left: "Module must use MyApp.Base"` / `right: "MyApp.Base"` (Violation->Issue field mapping) |

- **Config-load call (`config_loader.load()`)** is protected by the Manager's
  Hammox `expect/3` + `setup :verify_on_exit!` rather than a code mutation:
  `expect` self-proves on exit (ADR 002), so removing/bypassing the load call
  fails the unmet-expectation verification. (A direct mutation that bypasses the
  call also trips `--warnings-as-errors` via an unused `config_loader` binding, so
  the Hammox verification is the clean anchor.)

## Notes

- **Measured zeros made explicit (BUG 1 shadow).** The integration test's module
  `pattern` row (#4) and the Manager's module-graph test PIN *non-selection /
  empty-graph* behavior that is currently forced by the latent BUG 1 (`Credo.Code.ast/1`
  returns `{:ok, ast}`; `DependencyAnalyzer.extract_module_name/1` does not unwrap
  it, so `module_names` derives to `[""]` and `analyze_file/1.module` is `nil`).
  These rows are green *because of* the bug; a future BUG 1 fix (T5/follow-up)
  will flip them (row #4 -> a selection; the graph test -> a `MyApp.Repo`
  transitive violation on file A). They are deliberate characterization anchors,
  not proofs that selection/graphing *work* end-to-end today.
- The `uses_module` selector (rows #6/#7) DOES compose end-to-end through the real
  acquire (`extract_uses/1` traverses the `{:ok, ast}` tuple correctly), so those
  two rows are genuine end-to-end proofs of the acquire -> derive-facts -> select
  composition.
