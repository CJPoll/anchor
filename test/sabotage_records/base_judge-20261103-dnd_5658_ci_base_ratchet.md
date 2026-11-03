# Sabotage record: CI's base-branch judge (DND-5658)

- **Domain:** base_judge
- **Branch:** dnd-5658-ci-base-ratchet
- **Date:** 2026-11-03
- **Code under test:** `bin/ci/judge-with-base.sh` (CI's entry, which runs the base's copy of the judge) and `bin/ci/base-judge.sh` (the landed judge: builds the base and runs its `mix anchor.graph --project`)
- **Suite run:** `bin/tests/base-judge-test.sh`, through `test-slot`. The unmutated run passed every case (T1-T7) in 166 s. Each mutation then ran only the cases named, with `BASE_JUDGE_TEST_ONLY`.

Each mutation edited the working-tree copy, which the self-test copies into its throwaway repo as the base. The runner restored the file with `git checkout -- <file>` after each run, and `git status` was clean at the end. The first S7 mutation came out malformed: perl interpolated `$(`, so the script failed with a syntax error and exit 2. That run does not count. S7 was re-run with an exact text replacement made in Python, and that run is the one below.

The T5 premise is itself a recorded sabotage. The pull request in T5 edits `Anchor.Domain.Enforcement.judge/4` so that it drops STALE and GREW findings, adds `layering|SelfTest.Grown|entry` to the layering baseline, and makes its own `bin/ci/base-judge.sh` exit 0. Run with its own `mix anchor.graph --base main`, that pull request passes (exit 0). That is the hole this ticket closes. Run through the entry, the landed judge fails it with `layering|SelfTest.Grown|entry was added to .anchor/baselines/layering.txt since main.` (exit 1).

| # | Mutation | Case run | Failure |
|---|---|---|---|
| S1 | the entry runs the pull request's own `bin/ci/base-judge.sh` (`cat "$script"`), not the copy on REF | T5 | `FAIL T5 the landed judge refuses the grown baseline: exit 0, wanted 1` |
| S2 | the judge runs the pull request's anchor (`cd "$pr" && mix anchor.graph --base`), not the base build with `--project` | T5 | `FAIL T5 the landed judge refuses the grown baseline: exit 0, wanted 1` |
| S3 | a base that does not compile is ignored (`mix compile ... \|\| true \|\|`) | T4 | `FAIL T4 a base that does not compile is COULD NOT MEASURE: exit 1, wanted 3` |
| S4 | a judge exit of 3 is read as a pass (`3) status=0 ;;`) | T7 | `FAIL T7 a config the landed judge cannot load is COULD NOT MEASURE: exit 0, wanted 3` |
| S5 | no mode check on the landed script (`*) ;;`), so a symlink's target text is run | T3 | `FAIL T3 a symlinked landed judge is COULD NOT MEASURE: exit 127, wanted 3` |
| S6 | no bootstrap branch (`if false; then`) | T2 | `FAIL T2 a base with no landed judge is BOOTSTRAP: exit 3, wanted 0` |
| S7 | a ref that does not resolve exits 0 | T1 | `FAIL T1 an unresolvable ref is COULD NOT MEASURE: exit 0, wanted 3` |

T6 (an honest pull request passes) is the positive control for T5. It passed in the unmutated run.
