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

| # | Mutation | Result |
|---|---|---|
| M1 | `compile/2` analyses an empty file list (`files = []` in place of the fixture and generated paths), run from a copy outside the tree | No module line at all and no claim line; prints `COULD NOT MEASURE: 0 beams compiled`, exit 1. It does not report four CONFIRMED claims |
| M2 | (found, not planted) `claim_lines/2` read the positive control at `N = 2` after the sweep was changed to start at 3 | `** (FunctionClauseError) no function clause matching in AnchorSpike.Runner.claim4/2`, exit 1, no claim line: a broken control crashes loud rather than reading as CONFIRMED. Fixed by reading the control at the sweep's first N |

M1 verbatim output (compile warnings of the mutated copy trimmed to their
first line):

```
warning: variable "generated" is unused (if the variable is not meant to be used, prefix it with an underscore)
warning: module attribute @fixture_files was set but never used
tmp dir: /tmp/anchor-dialyzer-spike-5190
tmp dir removed: true
COULD NOT MEASURE: 0 beams compiled
SABOTAGE_EXIT=1
```
