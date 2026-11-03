# Sabotage record — the Dialyzer-boundary spike runner (DND-5499)

- **Domain:** dialyzer_boundary
- **Branch:** dnd-5499
- **Date:** 2026-11-03
- **Code under test:** `test/fixtures/dialyzer_boundary/run.exs`, the spike
  runner that compiles the fixtures beside it, runs `:dialyzer.run/1` on those
  beams only, and prints one verdict per claim
- **Tests:** none in `mix test` (a spike adds no ExUnit test: Dialyzer is not an
  Anchor dependency). The runner's own checks are the subject: its positive
  controls (claim 2's warning, claim 3 at N = 3) and its refusal to read an
  empty run as a result
- **Suite run:** `elixir test/fixtures/dialyzer_boundary/run.exs`
- **Merge base:** `origin/main` = 185ecc9

## Positive controls (the unsabotaged run)

The runner observes warnings, so a silent claim is evidence and not a dead run:

```
AnchorSpike.Private: private.ex:11:8: The pattern
          'c' can never match the type
          'a' | 'b'
AnchorSpike.Widened3: widened_3.ex:7:8: The pattern
          'never' can never match the type
          'a1' | 'a2' | 'a3'
```

## Mutations

Each mutation ran from a copy of the fixture directory outside the tree
(`run.exs` reads the fixtures beside it), on the runner as committed after the
review-floor fixes.

| # | Mutation | Result |
|---|---|---|
| M1 | `compile/2` analyses an empty file list (`files = []` in place of the fixture and generated paths) | No module line and no claim line; `COULD NOT MEASURE: 0 beams compiled`, exit 1. It does not report four CONFIRMED claims |
| M2 | (found, not planted) `claim_lines/2` read the positive control at `N = 2` after the sweep was changed to start at 3 | `** (FunctionClauseError) no function clause matching in AnchorSpike.Runner.claim4/2`, exit 1, no claim line. Fixed by reading the control at the sweep's first N |
| M3 | `AnchorSpike.Private.run/0` also calls `kind(:c)`, so claim 1's control is not reported | `Claim 1: COULD NOT MEASURE (positive control failed: AnchorSpike.Private not reported)`; claim 2 `REFUTED` (true for this mutated fixture: the clause is now reachable, and the Widened control proves the run reports); claim 4 `COULD NOT MEASURE`; exit 1 |
| M4 | the sweep starts past the limit (`@widened_generated Enum.to_list(14..19)`), so claim 3's control is not reported | `Claim 3: COULD NOT MEASURE (positive control N=14 not reported)`; claim 4 `COULD NOT MEASURE`; exit 1 |
| M5 | `never_match?/2` looks for `"can NEVER match"` (Dialyzer's wording changing under the runner), so no control is seen | all four claims `COULD NOT MEASURE`, among them `Claim 2: COULD NOT MEASURE (neither AnchorSpike.Private nor the Widened control reported)`; exit 1 |

Not sabotaged (each refusal is a `with` step before any verdict, and prints
`COULD NOT MEASURE: <reason>` with exit 1 by the same `fail/1` path M1 took):
a missing fixture file, `widened.ex` drifting from the template, a
module/beam count mismatch, a compiled module with no source span, the 60 s
PLT cap. Also not sabotaged: an unattributed Dialyzer warning, which makes
every claim line COULD NOT MEASURE and exits 1 by M3-M5's path.

M1 verbatim output (the mutated copy's own compile warnings omitted):

```
tmp dir: /tmp/anchor-dialyzer-spike-ab690d63a6c9
tmp dir removed: true
COULD NOT MEASURE: 0 beams compiled
EXIT=1
```

M3 verbatim (claim lines and exit; per-module lines for unchanged modules
omitted):

```
AnchorSpike.Private: no warnings
Claim 1: COULD NOT MEASURE (positive control failed: AnchorSpike.Private not reported)
Claim 2: REFUTED (AnchorSpike.Private kind(:c) not reported; Widened control reported)
Claim 3: CONFIRMED. Limit observed: 14. N=3 reported, ..., N=13 reported, N=14 not reported, ..., N=20 not reported
Claim 4: COULD NOT MEASURE (positive controls failed: the run reported no unreachable clause)
tmp dir removed: true
COULD NOT MEASURE: 2 of 4 claims could not be measured
EXIT=1
```

M4 verbatim:

```
Claim 1: CONFIRMED (no 'can never match' for AnchorSpike.Exported; control reported)
Claim 2: CONFIRMED (AnchorSpike.Private kind(:c) reported)
Claim 3: COULD NOT MEASURE (positive control N=14 not reported). N=14 not reported, N=15 not reported, N=16 not reported, N=17 not reported, N=18 not reported, N=19 not reported, N=20 not reported
Claim 4: COULD NOT MEASURE (positive controls failed: the run reported no unreachable clause)
tmp dir removed: true
COULD NOT MEASURE: 2 of 4 claims could not be measured
EXIT=1
```

M5 verbatim (claim 3's per-N list shortened):

```
Claim 1: COULD NOT MEASURE (positive control failed: AnchorSpike.Private not reported)
Claim 2: COULD NOT MEASURE (neither AnchorSpike.Private nor the Widened control reported)
Claim 3: COULD NOT MEASURE (positive control N=3 not reported). N=3 not reported, ..., N=20 not reported
Claim 4: COULD NOT MEASURE (positive controls failed: the run reported no unreachable clause)
tmp dir removed: true
COULD NOT MEASURE: 4 of 4 claims could not be measured
EXIT=1
```

Unsabotaged run on the same runner: all four claims CONFIRMED, limit 14,
`EXIT=0`.
