# Sabotage record — the sabotage runner and drop_effect_call (DND-5564, DND-5473)

- **Domain:** sabotage
- **Branch:** dnd-5473-sabotage-run
- **Date:** 2026-11-03
- **Code under test (DND-5564):** `Anchor.Domain.Sabotage.Operators.drop_effect_call/1`
  (`kept_arguments/2`, `call_arguments/1`, `argument_range/1`)
- **Suite run:** `mix test test/anchor/domain/sabotage/operators_test.exs
  test/anchor/domain/sabotage/mutator_test.exs
  test/anchor/domain/sabotage/mutator_compile_test.exs --timeout 2000 --max-cases 2`
  through `test-slot --weight 2` (44 tests, green before and after every row)

Each mutation was applied alone by a scratch driver outside the repo (it
replaces one exact text, runs the three files, and restores the file).
Every failure string is copied from its output.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D1 | the unfixed code: `operators.ex` as on main (452de16), the call's line deleted whole | 3: operators "2: drop_effect_call replaces the Logger call with `_ = {y}`", operators "2: every argument is kept"; mutator 1 | `code:  assert edit.range == {{6, 5}, {6, 19}}` `left:  {{6, 1}, {7, 1}}` `right: {{6, 5}, {6, 19}}`; mutator 1: `{AnchorFixtures.Sabotage.Canary, :effects, 2}` `code: for {mfa, {mutants, skipped}} <- @pinned do` |
| D2 | a piped value is not kept (`call_arguments({:|>, ...})` returns the call's own arguments only) | 1 (+1 bound, below): operators "2: every argument is kept" | `left: [... {"x |> Logger.info(meta: 1)", "_ = {meta: 1}"}, ...]` |
| D3 | the last argument is dropped (`Enum.drop(args, -1)`) | 3: operators "2: ... `_ = {y}`", operators "2: every argument is kept"; mutator 1 | `code:  assert edit.replacement == "_ = {y}"` `left:  "_ = {}"` |

The positive control (operators "2: positive control: a drop that orphans
something else is still refused") passes on D1, D2 and D3 and on the fix, as
it must: a `pat = effect(...)` statement whose binding a later line reads, and
a call through an alias used nowhere else, are refused either way.

## The compile canary

The canary (`test/fixtures/sabotage/canary.ex`) gained `logged/1` (the
`y = ...; Logger.info(y)` case, now a compiling mutant) and `remembered/1`
(`previous = Process.put(...)` with `previous` read later, still refused).
`mutator_compile_test.exs` 1 compiles every emitted mutant with zero
diagnostics on the fix, the new `_ = {y}`, `_ = {pid, {:value, x}}` and
`_ = {self(), :twice}` mutants included; test 2 still proves each refused
edit does not compile cleanly.

## Bound, not a kill

On D2, compile canary 1 also reported `** (ExUnit.TimeoutError) test timed out
after 2000ms`: the canary compiles about 40 modules, and 2000 ms is the
sabotage load rule's short bound, not a verdict on D2. It passed on the fix and
on D1 and D3 under the same bound.

## DND-5473 — `mix anchor.sabotage run` and `restore`

- **Code under test:** `Anchor.Managers.Sabotage.Runner` (via
  `Anchor.Managers.Sabotage.run/2`, `restore/2`), `Anchor.Domain.Sabotage.`
  `Config`, `TestMirror`, `TestSelection`, `Plan`, `TestRun`, `Outcome`,
  `Journal`, `Report`; the adapters `SourcePatcher`, `GitStatus`,
  `TestRunner`; `Anchor.Sabotage.ExUnitFormatter`
- **Suite run:** per row, `mix test <the test files the row names>
  --timeout 2000 --max-cases 2` through `test-slot --weight 2` (the
  sabotage load rule); for example R1:
  `mix test test/anchor/managers/sabotage_run_test.exs --timeout 2000 --max-cases 2`.
  Every file was green before and after every row.

Each mutation was applied alone by a scratch driver outside the repo (one
exact text replaced, the files run, the file restored). The first form of
R3, R4, R9, R12, R13 and R14 tripped warnings-as-errors (a dead clause, an
unused variable or function), so no test ran; each was rewritten with a
condition the compiler cannot see through (`Process.get(:anchor_never)`),
and the rows below are the rewritten runs.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| R1 | the restore moved out of the `after` block (it runs only when the test run returns) | 1: Manager row 8 | `match (=) failed` `code:  assert [` `{:write_journal, _},` `{:write_file, :mutated},` `:touch_ahead,` `{:write_file, :original},` ... `] = Enum.drop(calls(), 4)` `right: [` `{:write_journal, "05ccd80be8e0"},` `{:write_file, :mutated},` `:touch_ahead,` `{:write_journal, "d91ac044da9d"},` `{:write_file, :mutated},` |
| R2 | `Outcome.classify/1` reads `:compile_error` as `:killed` | 1: Outcome row 4 | `code:  assert Outcome.classify(run(:compile_error, exit_code: 1, output_head: output)) == {:invalid, []}` `left:  {:killed, []}` |
| R3 | the dirty-target check off (every `dirty_paths` answer read as clean) | 1: Manager row 5 | `** (Mox.UnexpectedCallError) expected Anchor.ChangeSourceMock.read/2 to be called once but it has been called 2 times` (the run went on to read the file and make mutants) |
| R4 | the baseline skipped (read as passed, no test run) | 6: Manager rows 6, 7, 8, 9, the cap row, the `timeout` row | row 9: `** (Mox.VerificationError) ... expected Anchor.TestExecutionMock.run/3 to be invoked 2 times but it was invoked once` |
| R5 | a leftover journal deleted before its file is restored | 1: Manager row 1 | `code:  assert calls() == [` `left:  [:read_journal, :sha256_file, :delete_journal, :write_file,` `right: [:read_journal, :sha256_file, :write_file, :touch_ahead,` |
| R6 | the restore's sha256 not compared (the journal deleted whatever the file holds) | 1: Manager row 9 | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` (the run went on to the next mutant) |
| R7 | `touch_ahead/1` from now only, not past the current mtime | 1: SourcePatcher row 3 | `code: assert mtime(path) > first` `left: 1793694079` |
| R8 | exit 124 not read as a timeout | 2: Outcome "exit 124 or 137 is a timeout"; TestRunner row 5 | `code:  assert %TestRun{status: :timeout} = TestRun.from_frames(code, [], "x")` `left:  %Anchor.Domain.Sabotage.TestRun{status: :timeout}` `right: %Anchor.Domain.Sabotage.TestRun{` `status: :crashed,` `total: 0,` `failures: [],` `exit_code: 124,` (TestRunner row 5 hit the 2000 ms bound; see below) |
| R9 | the cap ignored | 3: Plan row 1, Plan "--only filters before the cap"; Manager cap row | `code:  assert length(planned) == 30` `left:  40` `right: 30` |
| R10 | the formatter counts an excluded test as run | 1: formatter row 1 | `code:  assert frames(path) == [` `left:  [` `{:suite_started},` `{:test_failed, "test/calc_test.exs", 4, "test adds",` `"** (RuntimeError) boom"},` `{:suite_finished, 3, 1, 0}` `]` `right: [` ... `{:suite_finished, 2, 1, 1}` |
| R11 | a mirror test file that does not exist still selected | 2: TestSelection row 3; Manager row 10 | `code:  assert TestSelection.select(mutant("lib/x.ex"), inputs(["test/y_test.exs"])) == {:none, []}` `left:  {:mirror, ["test/x_test.exs"]}` |
| R12 | the journal-ignored check off | 1: Manager row 4 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.merge_base/2 ... with args ["/repo", "origin/main"]` (the run went on to the scope) |
| R13 | `Sabotage.Config` refuses no unknown key | 1: Config row 2 | `** (MatchError) no match of right hand side value:` `{:ok,` `%Anchor.Domain.Sabotage.Config{` (the unknown-key row loaded) |
| R14 | the real run with its restore removed (no doubles) | 1: integration row 1 | `code:  assert File.read!(Path.join(root, "lib/calc.ex")) == @calc` `left:  "...  def validate(x) do\n    x\n  end..."` (the last mutant left in the file) |

The QA plan's five required breaks are R1 (Manager row 8), R2 (Outcome row
4), R3 (Manager row 5), R4 (Manager row 6, among others) and R5 (Manager row
1's order); each red names the row the plan said it would.

### Bound, not a kill

On R8, TestRunner row 5 (`hang` with `timeout_seconds: 1`) reported
`** (ExUnit.TimeoutError) test timed out after 2000ms`: a real `elixir`
start plus the one-second bound does not fit the sabotage load rule's 2000 ms
ExUnit timeout. The row's own verdict on R8 is the Outcome row; TestRunner
row 5 passes under the suite's default timeout.

### Deviations from the QA plan, and why

- **The integration project does not depend on Anchor.** Its
  `test/test_helper.exs` puts Anchor's compiled ebin on the code path, so
  `--formatter Anchor.Sabotage.ExUnitFormatter` loads without fetching or
  compiling Anchor's dependencies in the tmp project. The formatter calls no
  other Anchor module, which is what makes this work.
- **`--only` filters, then the cap applies.** The plan named both, not their
  order; capping an `--only` list keeps the run bounded.
- **Manager row 8:** the raised error is reported as the mutant's `invalid`
  status (`the test run raised: ...`), and the run goes on to the next mutant,
  since the restore ran and was verified.

### Third pass: the tests the first two left unreddened, and the review floor's

The review floor (code and ADR reviewers) found tests with no red row and
four untested refusal paths. Each row below ran its named test files with
`--timeout 2000 --max-cases 2` through `test-slot --weight 2`. C03's first
form tripped a dead-clause warning and was rewritten with
`Process.get(:anchor_never)`; C32 first survived (the test's `error:` line
was chosen before the mtime warning was ever reached), so the test was
strengthened to a warnings-only output and C32 re-run red.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| C01 | `GitStatus.ignored?/2` reads exit 1 as ignored | 1: GitStatus row 2 | `left = Anchor.Adapters.GitStatus.ignored?(root, journal)` (`left == right` failed: `{:ok, true}` vs `{:ok, false}`) |
| C02 | `dirty_paths/2` keeps the first entry only | 1: GitStatus row 1 | `left:  {:ok, ["lib/dirty.ex"]}` |
| C03 | `Journal.recovery/2` restores when the file is already the original | 3: Journal recovery row; Manager leftover row 2; the discard-delete-fails row | `code:  assert Journal.recovery(entry, Journal.sha256(@original)) == :discard` `left:  :restore` |
| C04 | `Journal.decode/1` does not check the original's sha256 | 1: Journal "bytes it did not write are corrupt" | `code: for bytes <- ["", "{", "[]", ~s({"version":2}), tampered],` |
| C05 | `Journal.decode/1` accepts a file outside the root | 1: Journal "outside the project root" | `code: for file <- ["/etc/passwd", "../outside.ex", "lib/../../outside.ex", ""] do` |
| C06 | `Report.exit_code/1` ignores `no_tests` | 2: Report row 3; Manager row 10 | `code:  assert Report.exit_code(run) == 1` `left:  0` |
| C07 | the survivor's `Fix:` dropped | 1: Report row 2 | `code:  assert Report.render(run) =~` `left:  "aaa\tCalc.add/2\treturn_input\tkilled\t...\nbbb\tCalc.add/2\treturn_input\tsurvived\t\tselected by mirror: test/calc_test.exs` |
| C08 | the cap line miscounts | 1: Report row 4 | `left:  "...\nnot run (cap): 9 mutants; rerun with --max all (CI)\n..."` |
| C09 | `restore` also prints a run summary | 2: Manager restore row 2; the task's restore row | `code:  assert Report.render(run) == "nothing to restore"` `left:  "nothing to restore\nanchor.sabotage run: 0 mutants run: ..."` |
| C10 | errors not listed in a run's report | 1: Report row 5 | `left:  "anchor.sabotage run: 0 mutants run: 0 killed, ...; 1 errors"` |
| C11 | `--max 0` accepted | 1: task row 1 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.read_journal/1` (the run started) |
| C12 | a refused run exits 0 | 1: task "a refused run ... exits with its code" | `code: capture_io(fn ->` (no `{:shutdown, 2}` exit) |
| C13 | the runner never reads the frames | 5: TestRunner rows 1, 2, 3, 5, the argv row | `code:  assert {:ok, %TestRun{status: :failed, exit_code: 2, failures: [failure]}} = run("fail", dir)` |
| C14 | a results file that cannot be removed is ignored | 1 (+1 bound): TestRunner "a stale results file that cannot be removed" | listed `2) test a stale results file that cannot be removed is an error, never read` |
| C15 | the formatter flags not appended | 1 (+1 bound): TestRunner argv row | listed `2) test the test files and both formatters follow the command; ...` |
| C16 | the journal opened without `:exclusive` | 1: SourcePatcher "a second write_journal" | `code:  assert SourcePatcher.write_journal(root, second) == {:error, :eexist}` `left:  :ok` |
| C17 | `write_file/2` never renames the temp file | 4: SourcePatcher rows 1, 2, the eexist row, `save_run` | `code:  assert SourcePatcher.read_journal(root) == {:ok, entry}` `left:  {:error, :corrupt_journal}` |
| C18 | `read_journal/1` reads any journal as none | 3: SourcePatcher rows 1, 4, the eexist row | `left = Anchor.Adapters.SourcePatcher.read_journal(root)` |
| C19 | the formatter drops a `setup_all` failure's text | 1: formatter `setup_all` row | `code:  assert [` `left:  [` |
| C20 | `Anchor.Config` ignores the `sabotage:` section | 3: Config wiring rows 1, 2; `ConfigFile.load_in/1` | `code:  assert {:error, {:invalid_config, "sabotage.max_mutants" <> _rest}} =` |
| C21 | a config with no `sabotage:` section not refused | 3: Manager "missing sabotage: section", leftover rows 1, 2 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.ignored?/2 ... with args ["/repo", ".anchor/sabotage/in-flight.json"]` |
| C22 | a failed recovery restore reads as recovered | 2: Manager "recovery restore whose write fails", "does not reproduce the original" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load_in/1 ... with args ["/repo"]` (the run went on) |
| C23 | a discard whose delete fails reads as done | 1: Manager "a discard whose journal cannot be deleted" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load_in/1` |
| C24 | an existing journal worded as a write error | 1: Manager "a journal already there (another run)" | `code:  assert message =~ "another sabotage run is applying a mutant"` `left:  "could not write .anchor/sabotage/in-flight.json (:eexist); no mutant was written. ..."` |
| C25 | a mutant that cannot be written read as a passed run | 1: Manager "a mutant that cannot be written" | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |
| C26 | a journal that cannot be deleted after a restore reads as done | 1: Manager "a restore whose journal cannot be deleted" | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |
| C27 | `results_not_removed` refused with exit 2, not 3 | 1: Manager "a stale results file ... exit 3" | `code:  assert %{refusal: {3, message}} = Sabotage.run(@facts, @opts)` |
| C28 | an unknown `--only` id read as an empty plan | 1: Manager `--only` row | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.existing/1 ... with args [[]]` |
| C29 | `--dry-run` ignored | 1: Manager row 11 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.TestExecutionMock.run/3 ...` |
| C30 | a leftover journal whose file cannot be read is ignored | 1: Manager "a leftover journal whose file cannot be read" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load_in/1` |
| C31 | a call with a `do` block keeps its arguments | 1: operators "a call with a do block keeps nothing" | `code:  assert edit.replacement == ""` `left:  "_ = {do\n      x}"` (the text that does not parse, which the review predicted) |
| C32 | Mix's mtime warning not filtered | 1: Outcome "Mix's mtime-reset warning is never quoted" | `left:  "did not compile: warning: mtime (modified time) for \"lib/x.ex\" was set to the future, resetting to now"` |
| C33 | `ConfigFile.load_in/1` searches the working directory | 1: ConfigFile `load_in/1` row | `code:  assert {:ok, %Anchor.Config{sabotage: %{max_mutants: 7}, path: path}} = ConfigFile.load_in(root)` |
| C34 | a live owner's journal read as a leftover (critic round 1) | 1: Manager "a journal whose owner is a live run" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.sha256_file/1 in process #PID<0.283.0> with args ["/repo/lib/calc.ex"]` (recovery went on to the file) |
| C35 | `owner_alive?/1` ignores the start time (a reused pid read as live) | 1: SourcePatcher "the journal names this run as its owner" | `Expected false or nil, got true` `code: refute SourcePatcher.owner_alive?(%{owner \| started: started <> "0"})` |
| C36 | the journal never writes its owner | 2: Journal "the owner round-trips"; SourcePatcher owner row | `code:  assert Journal.decode(Journal.encode(entry)) == {:ok, entry}` `left:  {:ok, %Anchor.Domain.Sabotage.Journal{... owner: nil}}` |

On C14 and C15, TestRunner row 5 (`hang`) also hit the 2000 ms bound, as on
R8: a bound, not a verdict.
