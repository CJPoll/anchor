# Sabotage record: T14, a config section loosening a base rule (DND-5658)

- **Domain:** base_judge
- **Branch:** dnd-5658-ci-base-ratchet
- **Date:** 2026-11-06
- **Code under test:** `bin/ci/base-judge.sh` and the anchor it runs, on `.anchor.yml`'s `architecture:`
- **Suite run:** `BASE_JUDGE_TEST_ONLY="T14" bin/tests/base-judge-test.sh`, through `test-slot`; the fixed tree of 2983851 ran every case.

Earlier runs: `base_judge-20261103-dnd_5658_ci_base_ratchet.md`.

| # | Mutation | Case run | Failure |
|---|---|---|---|
| S14 | no mutation: the unfixed code at 9e308e1, which ran base rules under the pull request's `architecture:` (T14 was first too loose, exit 1 on another rule's line, so its text was pinned to the layering line) | T14 | `FAIL T14 a widened calls matrix is judged by the base's architecture: output lacks: (id: "layering", layering) Anchor.Managers.SelfTestLeak`. Fixed, unmutated, on the tree of 2983851: `ok   T14 a widened calls matrix is judged by the base's architecture`, `base-judge-test: 14 case(s) passed` |
