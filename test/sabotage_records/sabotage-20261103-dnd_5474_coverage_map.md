# Sabotage record — the per-test coverage map (DND-5474)

- **Domain:** sabotage
- **Branch:** dnd-5474-coverage-records
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.CoverageMap` (`attribute/2`,
  `finalize/2`, `validate/1`, `tests_for/2`, `index/1`),
  `Anchor.Domain.Sabotage.TestSelection.select/2` (the `:coverage` source),
  `Anchor.Domain.Sabotage.Report` (the `tests selected by:` line),
  `Anchor.Sabotage.CoverageCollector`, `Anchor.Managers.Sabotage.Coverage`,
  `Anchor.Managers.Sabotage.Runner` (`--coverage`, the staleness warning),
  `Anchor.Adapters.CallTracer`, `Anchor.Adapters.GitStatus.ancestor?/2`
- **Suite run:** per row, `mix test <the files the row names> --timeout 2000
  --max-cases 2` through `test-slot` (the sabotage load rule). Every file was
  green before and after every row.

Each mutation was applied alone by a scratch driver outside the repo: it
replaces one exact text, moves the file's mtime forward, runs the files, then
writes the original back with an mtime later still (so Mix never keeps the
mutant's beam; the DND-5473 trap). Failure strings are copied from its output.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| S1 | `release/2` sorts the buffer by arrival order, not by stamp (QA required break) | 2 of 16: coverage_map "2: events out of arrival order are attributed by stamp", "2: a batch boundary does not reorder" | `code:  assert sets(build(shuffled)) == sets(build(row1()))` `left:  %{"test one" => ["A.f/0", "B.g/0"], "test two" => []}` `right: %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}` |
| S2 | a call outside every window goes into the last finished window (QA required break) | 1 of 16: coverage_map "3: a call after every window closed is outside_windows, in no test" | `code:  assert map.outside_windows == 1` `left:  0` `right: 1` |
| S3 | the CI refusal is skipped (`in_ci(%{local: _any})`) (QA required break) | 2 of 14: manager "1: outside CI and without --local: exit 2 ...", task "outside CI and without --local ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ProjectModuleSourceMock.list/1 in process #PID<0.295.0> with args [["/repo/_build/test/lib/app/ebin"]]` |
| S4 | `tracer.stop()` moved out of the `after` block (QA required break) | 1 of 11: manager "3: a suite that raises still stops tracing" | `code:  assert calls() == [:modules, :stop]` `left:  [:modules]` `right: [:modules, :stop]` |
| S5 | a late event is buffered and attributed, never counted | 1 of 16: coverage_map "6: an event later than the slack allows is counted, never attributed" | `code:  assert map.late_events == 1` `left:  0` `right: 1` |
| S6 | the collector keeps a call's argument list in place of its arity | 2 of 2: collector "1: trace messages give the same map ...", "2: a call's arguments are never kept" | `code:  refute inspect(state, limit: :infinity, printable_limit: :infinity) =~ "secret-value"` `left:  "%Anchor.Domain.Sabotage.CoverageMap{... MapSet.new([{A, :f, [\"secret-value-secret-value-...` |
| S7 | the mirror wins over coverage when both exist | 4 of 51: selection "1: a function the map lists selects its tests as file:line, over the mirror"; run "a mutant of a function a test in another file runs selects that test, by coverage", "... not an ancestor of HEAD ...", "the config's coverage_map is read ..." | `code:  assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==` `left:  {:mirror, ["test/x_test.exs"]}` `right: {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4"]}` |
| S8 | the not-an-ancestor warning is dropped | 1 of 40: run "a map from a commit that is not an ancestor of HEAD is used, with a warning" | `code:  assert run.notes == [` `left:  []` `right: ["coverage map built at c0ffee is not an ancestor of HEAD headsha; selections from it may miss new tests"]` |
| S9 | a failed suite is recorded `suite_exit: 0` | 1 of 11: manager "5: a failed suite still writes the map, marked, and exits 1" | `** (FunctionClauseError) no function clause matching in anonymous fn/2 in Anchor.Managers.SabotageCoverageTest."test 5: ..."/1` (the write double matches `%{suite_exit: 1}` only) |
| S10 | the `:arity` trace flag is dropped (`@flags [:call, :strict_monotonic_timestamp]`) | first run: **0 of 2, a measured zero**: the collector discards arguments either way, so the map was the same. Fixed by adding call_tracer "a call's message carries its arity, never its arguments"; re-run: 1 of 3 | `code:  assert calls == [f: 0, g: 1]` `left:  [f: [], g: [1]]` `right: [f: 0, g: 1]` |
| S11 | `stop/0` leaves the local trace patterns | 1 of 2: call_tracer "1: window events and project calls reach the collector in stamp order; stop clears all" | `code:  assert :erlang.trace_info({a, :f, 0}, :traced) == {:traced, false}` `left:  {:traced, :local}` `right: {:traced, false}` |
| S12 | `validate/1` accepts zero traced modules | 1 of 27: coverage_map "2: zero modules traced is refused" | `code:  assert CoverageMap.validate(map) == {:error, :no_modules}` `left:  :ok` `right: {:error, :no_modules}` |
| S13 | `ancestor?/2` reads git's exit 128 (a commit git does not have) as an ancestor | 1 of 3: git_status "head_sha/1 and ancestor?/2 ... a later or unknown one is not" | `code:  assert GitStatus.ancestor?(root, String.duplicate("0", 40)) == {:ok, false}` `left:  {:ok, true}` `right: {:ok, false}` |
| S14 | the `tests selected by:` line is dropped | 2 of 50: report "DND-5474: a line counts the mutants by the source ...", run "... selects that test, by coverage" | `code:  assert text =~ "\ntests selected by: 2 coverage, 1 mirror\nanchor.sabotage run: 3 mutants"` |

## The measured zero (S10)

S10 is the row this record exists for: dropping `:arity` made the collector
receive every traced call's arguments (a copy of each value into its mailbox,
the cost the flag exists to avoid) and no test noticed, because the collector
discards arguments on arrival. The zero stays; the fix beneath it is the
adapter test that reads the raw trace messages through a plain sink process.

## The real tracing run

Beyond the doubled tests, the command ran for real on this branch, bounded to
two test files: `MIX_ENV=test mix anchor.sabotage coverage --local --out <scratch>/cov.etf --
test/anchor/domain/glob_pattern_test.exs test/anchor/domain/sabotage/test_selection_test.exs`
through `test-slot`: `anchor.sabotage coverage: tests: 59, modules_traced: 123,
outside_windows: 60, late_events: 0, suite_exit: 0`, and
`tests_for(map, "Anchor.Domain.GlobPattern.matches_pattern?/2")` listed 14
tests, every one from `test/anchor/domain/glob_pattern_test.exs`. The full
suite is traced only in CI (`coverage-map.yml`).
