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

## Critic round 1 (two findings)

The critic found (1) that a map's `file:line` refs are as of the map's commit,
so a test file changed since then could run the wrong test or miss the
branch's new ones, with no warning; and (2) that `CoverageFile` and
`ProjectModules` had no test. The fix: `TestSelection` takes `stale_tests`
(the files `GitStatus.changed_since/2` says differ from the map's commit, or
`:all` when git cannot say or the map names no commit): a ref into a stale
file runs the whole file, and a stale mirror file is added whole. Both
adapters got tmp-dir tests. The new tests were seen red on the unfixed code
first (the three `test_selection_test.exs` rows below, "left" = the unfixed
selection), then by sabotage:

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| F1 | the unfixed code (c153321): `stale_tests` ignored | 3 of 14: selection "a selected test file changed since the map was built runs whole ...", "a mirror file changed ... is added whole", "when what changed is unknown (:all) ..." | `code:  assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==` `left:  {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4"]}` `right: {:coverage, ["test/a_test.exs:10", "test/b_test.exs"]}` |
| S15 | `stale?/2` always false | 3 of 57: the first two rows above, and run "a selected test file changed since the map's commit runs whole, the mirror too" (the `:all` rows still pass: `:all` has its own clause) | as F1 |
| S16 | `CoverageFile.read/1` returns `{:ok, :undecodable}` for bytes it cannot decode | 2 of 5: coverage_file "a term naming an atom this VM does not have is refused, never created", "bytes that are not an external term are :undecodable" | `code:  assert CoverageFile.read(path) == {:error, :undecodable}` `left:  {:ok, :undecodable}` `right: {:error, :undecodable}` |

## Critic round 2 (one finding)

The critic found that `SuiteRunner` put `--max-cases 1` first, but a switch
given twice takes its last value (`OptionParser.parse(["--max-cases", "1",
"x", "--max-cases", "4"], strict: [max_cases: :integer])` returns
`{[max_cases: 4], ["x"], []}`), so `coverage -- --max-cases 4` would run tests
at once and every call would land in every open window. The fix: the Manager
refuses test arguments that set `--max-cases` (exit 2), and `SuiteRunner`
puts `--max-cases 1` last.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| F2 | the unfixed code (3e9563a) | 1 of 12: manager "a --max-cases in the test args is refused, exit 2: tests must never overlap" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ProjectModuleSourceMock.list/1 in process #PID<0.265.0> with args [["/repo/_build/test/lib/app/ebin"]]` |
| S17 | the refusal reads no test arguments (`serial([])`) | 1 of 12: the same test | as F2 |

## Critic round 3 (one finding)

The critic found that a map's ref into a test file deleted or renamed since
the map was built was still passed to `mix test` (and, after round 1, as a
whole-file path), so the baseline would fail and the run end in exit 3. The
fix: the Runner looks up every file a coverage selection could pass
(`TestSelection.coverage_files/2`) with the mirror paths, and `select/2` drops
a ref whose file is not there; with none left the mutant falls to the mirror.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| F3 | the unfixed code (5a20390) | 2 of 16: selection "a ref whose file no longer exists is dropped; with none left, the mirror", "coverage_files/2 names the test files ..." | `code:  assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==` `left:  {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4"]}` `right: {:coverage, ["test/a_test.exs:10"]}` |
| S18 | the existence filter keeps every ref | 2 of 60: the selection row above, and run "a selected test file deleted since the map was built is dropped: the mirror runs" | as F3 |

## Critic round 4 (one finding)

The critic found that a map's `commit` was never checked and reached
`git diff` before `--` (a `--output=PATH` commit would make git write a
file), and a non-string commit crashed the run. The fix: `CoverageMap.check/1`
checks every field that reaches a command line, the commit (nil or a
40-character lowercase hex sha) and each test file (relative, inside the
project, not an option); a map that fails is refused, exit 2.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| F4 | the unfixed code (627675a) | 2 of 18: coverage_map "check/1: ... commit is nil or a 40-character lowercase hex sha", "check/1: ... a test file is a relative path inside the project that is not an option" | `code:  assert CoverageMap.check(%{map \| commit: "--output=x"}) == {:error, {:commit, "--output=x"}}` `left:  {:ok,` `right: {:error, {:commit, "--output=x"}}` |
| S19 | `sha?/1` accepts any commit | 2 of 63: coverage_map "check/1: ... commit is nil or a 40-character lowercase hex sha"; run "run/2 with a coverage map (DND-5474) a map whose commit is not a sha is exit 2: it never reaches git" | `code:  assert CoverageMap.check(%{map \| commit: "--output=x"}) == {:error, {:commit, "--output=x"}}` `left:  {:ok, %{version: 1, ...` |
| S20 | a test file starting with `-` is accepted | 1 of 63: coverage_map "check/1: ... a test file is a relative path inside the project that is not an option" | `code: for file <- ["-x", "--include=slow", "/etc/x_test.exs", "test/../../x.exs", ""] do` (the loop's assertion for `"-x"`) |

The `ProjectModules` adapter's tmp-dir test (critic round 1) is broken in the
DND-5484 record, row D12, beside the other rows the review floor asked for.

## Critic round 5 (one finding)

The critic found that `stop/0` returned before trace messages still on
their way reached the collector (trace delivery is asynchronous to the
traced calls), so a call or a `test_finished` arriving after `finish` would
be lost, never counted. The fix: `stop/0` waits for
`:erlang.trace_delivered(:all)`. The new test floods 4,000 calls from 8
processes and reads the sink's queue length at once after `stop/0`.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| S21 | the wait removed (the unfixed code, 00405f3) | **0 of 4, a measured zero** | none: on one node the messages arrive before the queue is read in every run seen. The race cannot be forced from a test (no hook delays delivery), so the test pins the contract but cannot prove it; the fix rests on the OTP documentation of `trace_delivered/1`. |

The whole-MR critic held that a bug fix with only a measured zero has no
fail-before evidence. So `stop/0` now calls `stop/1` with the delivery
request as a function, and a test passes its own: it sees the request made
and `stop` still waiting until the notice is sent. The race itself still
cannot be forced; the wait now can be seen.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| S21b | the wait removed (the unfixed code: no delivery request, no wait) | 1 of 5: call_tracer "stop/0 asks for trace delivery and returns only once it is notified" | `Assertion failed, no matching message after 100ms` (the `assert_receive {:asked, ^stopper}`) |
| S21c | the request made, the wait skipped | 1 of 5: the same test | `code: refute_received :returned`. The stopper sends `:returned` straight after `{:asked, _}`, so this row can pass when `:returned` has not arrived by the check; S21b's red does not depend on timing. |

`Anchor.Adapters.SuiteRunner` (`Mix.Task.run("test", ...)` in this VM) has no
unit test: it cannot run a suite inside a running suite. The bounded real run
below and the CI workflow exercise it.

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
