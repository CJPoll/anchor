# Sabotage record — sabotage follow-up batch (DND-5654, DND-5653, DND-5639, DND-5642, DND-5643)

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

## DND-5653 — a kill that rests on an ExUnit per-test timeout is a timeout kill

- **Code under test:** `Anchor.Domain.Sabotage.Outcome.classify/1` (a
  `:failed` run whose every failure is an `ExUnit.TimeoutError`),
  `Anchor.Domain.Sabotage.Report` (the `kills rest on time alone` line),
  `Anchor.Domain.Sabotage.Record` (`## Kills by timeout`, the mutant
  section's first failure); pinned in `Anchor.Managers.Sabotage.Runner`: a
  baseline that times out is refused, and the test command's argv reaches
  every run unchanged
- **Suite run:** `mix test test/anchor/domain/sabotage/outcome_test.exs
  test/anchor/domain/sabotage/report_test.exs
  test/anchor/domain/sabotage/record_test.exs
  test/anchor/managers/sabotage_run_test.exs
  test/anchor/domain/sabotage/kill_map_test.exs --timeout 2000 --max-cases 2`
  (149 tests; green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U7 | the unfixed code (the tests written first; T4 not yet added) | 6 of 139 | T1, T2, R1, K1, K2, TO2. K2 `code:  assert entry.content =~ "## Kills by timeout\n\nNone.\n"`; TO2 the mutant's status `:killed`, not `:timeout` |
| S1 | no failure is read as a timeout (`test_timeout?/1` always false) | 3 | T2 `code:  assert Outcome.classify(run(:failed, total: 3, failures: [@t1, @f1])) ==` `left:  {:killed,` (also T1 and TO2) |
| S2 | a timeout beside an assertion failure is still a timeout kill | 1 | T2 `left:  {:timeout, ["(test timeout) test/x_test.exs:12 test slow"]}` `right: {:killed, [{"test/x_test.exs", 4, "test adds"}]}` |
| S3 | a failure whose text merely contains the timeout text counts as one (`String.contains?`) | 1 | T3 `left:  {:timeout, ["(test timeout) test/x_test.exs:4 test adds"]}` `right: {:killed, [{"test/x_test.exs", 4, "test adds"}]}` |
| S4 | a failed run with no failure frame becomes a timeout kill | 1 | T4 `code:  assert Outcome.classify(run(:failed, total: 3, failures: [])) == {:killed, []}` `left:  {:timeout, []}` |
| S5 | the report's timeout line never printed | 1 | R1 `code:  assert text =~` `right: "sabotage: 2 kills rest on time alone (no assertion failed; a hang the mutant caused, or a slow host): bbb Calc.add/2 by (test timeout) test/calc_test.exs:9 test slow; ccc Calc.add/2 by (timeout)\n"` |
| S6 | the record's `Kills by timeout` section always `None.` | 1 | K1 `code:  assert entry.content =~` (the `## Kills by timeout\n\n- eee555 ...` line) |
| S7 | a per-test timeout's mutant section shows the bound text, not ExUnit's failure | 1 | K1 `code:  assert entry.content =~` `"** (ExUnit.TimeoutError) test timed out after 2000ms."` |
| S8 | the section heading renamed (`Timeouts`) | 3 | K2 `code:  assert entry.content =~ "## Kills by timeout\n\nNone.\n"` (also K1 and the golden record) |
| S9 | the runner accepts a baseline whose first failure is a timeout | 1 | TO1 `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.write_journal/2` |
| S10 | the runner runs `["mix", "test"]`, not the configured test command | 24 | TO3 `code:  assert runs == List.duplicate({command, ["test/calc_test.exs"]}, 3)` `left:  [{["mix", "test"], ["test/calc_test.exs"]}, ...` |

TO1 and TO3 pin behaviour the runner already had (they passed on the unfixed
code); S9 and S10 are their reds. T4 is the positive control added after U7:
a `:failed` run with no failure frame stays `{:killed, []}`, as before.

## DND-5639 — the targets of one multi-target mutant share one run per test set

- **Code under test:** `Anchor.Domain.Sabotage.SharedRun` (`key/2`: the
  file, range, replacement and sorted unique tests; `nil` with no test;
  `attribute/3`), `Anchor.Managers.Sabotage.Runner` (`mutants/6` reuses a
  measured run by key)
- **Suite run:** `mix test test/anchor/domain/sabotage/shared_run_test.exs
  test/anchor/managers/sabotage_run_test.exs --timeout 2000 --max-cases 2`
  (82 tests; green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U8 | the unfixed runner (T1 and T2 written first; 78 tests) | 1 | T1 `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |
| P1 | the key drops the tests (`Enum.take(tests, 0)`) | 2 | G2 `code: refute SharedRun.key(calc, {:mirror, ["test/a_test.exs"]}) ==` `left: {"lib/calc.ex", {{3, 5}, {3, 29}}, "_ = {\"rendering\"}", []}` (also T2) |
| P2 | the key drops the range | 1 | G3 `code: refute SharedRun.key(calc, tests) == SharedRun.key(moved, tests)` `left: {"lib/calc.ex", nil, "_ = {\"rendering\"}", ["test/a_test.exs"]}` |
| P3 | the key drops the replacement | 16 | G3 `code: refute SharedRun.key(calc, tests) == SharedRun.key(replaced, tests)` `left: {"lib/calc.ex", {{3, 5}, {3, 29}}, nil, ["test/a_test.exs"]}` (and 15 runner tests whose mutants of one site took one verdict, e.g. `code:  assert Report.exit_code(run) == 1`) |
| P4 | the key drops the file | 1 | G4 `left: {nil, {{3, 5}, {3, 29}}, "_ = {\"rendering\"}", ["test/a_test.exs"]}` |
| P5 | a mutant with no test gets a key | 1 | G5 `code:  assert SharedRun.key(calc, {:none, []}) == nil` `left:  {"lib/calc.ex", {{3, 5}, {3, 29}}, "_ = {\"rendering\"}", []}` |
| P6 | the tests not sorted (selection order is part of the key) | 1 | G1 `code:  assert SharedRun.key(other, {:coverage, ["test/b_test.exs", "test/a_test.exs"]}) == key` |
| P7 | `attribute/3` keeps the first target's mutant | 2 | G6 `code:  assert shared == %{` (also T1) |
| P8 | `attribute/3` keeps the first target's selection | 1 | G6 `code:  assert shared == %{` |
| P9 | the runner never records a measured run | 1 | T1 `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |
