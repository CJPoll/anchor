# Sabotage record — sabotage follow-up batch (DND-5654, DND-5652, DND-5653, DND-5639, DND-5642, DND-5643)

- **Domain:** sabotage
- **Branch:** dnd-5639-sabotage-followups
- **Date:** 2026-11-03
- **Code under test:** per ticket, in each section below (each section has
  its own **Code under test** and **Suite run**)
- **Suite run:** per ticket, in each section below
- **Method:** each mutation was applied alone by a scratch driver outside the
  repo (one exact text replaced, the named test files run through `test-slot`
  with `mix test --timeout 2000 --max-cases 2`, the file restored and
  touched). Every failure string is copied from its output. After the last
  row the same files ran green.

## DND-5654 — the results file lives under the build path, as the last run does

- **Code under test:** `Anchor.Managers.Sabotage.Runner` (`build_path/2`:
  the results file every test run writes, and `last-run.etf`)
- **Suite run:** `mix test test/anchor/managers/sabotage_run_test.exs
  --timeout 2000 --max-cases 2` (71 tests; green after the fix and after
  every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U3 | the unfixed code: the results file at `<root>/_build/<env>/anchor/sabotage/results.bin` (the tests already changed) | 22 | `code:  assert opts[:results_path] == "/builds/repo-test/anchor/sabotage/results.bin"` `left:  "/repo/_build/test/anchor/sabotage/results.bin"` `right: "/builds/repo-test/anchor/sabotage/results.bin"` (B1 too: `left:  ["/repo/_build/test/anchor/sabotage/results.bin", ...]`) |
| K2 | the results path built from the root again (the shared `build_path/2` left for last-run) | 22 | the same `code:` / `left:` / `right:` as U3 |
| K3 | `last-run.etf` built from the root (results left on the build path) | 18 | `** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.SabotageRunTest.expect_save/0` `code: assert Sabotage.run(@rec_facts, @opts).records == [{:append, @record_path}]` |

B1 is the new positive test: the baseline, both mutant runs and the save
each see `/builds/repo-test/...` (a build path that is not
`<root>/_build/<env>`, as `MIX_BUILD_PATH` sets it).
