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
- **Suite run:** each row ran only the test files it names, with
  `--timeout 2000 --max-cases 2`, through `test-slot --weight 2` (the
  sabotage load rule). Every file was green before and after every row.

Each mutation was applied alone by a scratch driver outside the repo (one
exact text replaced, the files run, the file restored). The first form of
R3, R4, R9, R12, R13 and R14 tripped warnings-as-errors (a dead clause, an
unused variable or function), so no test ran; each was rewritten with a
condition the compiler cannot see through (`Process.get(:anchor_never)`),
and the rows below are the rewritten runs.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| R1 | the restore moved out of the `after` block (it runs only when the test run returns) | 1: Manager row 8 | `8: a test run that raises still restores the file and deletes the journal; the error is reported` `match (=) failed` `code:  assert [` `{:write_journal, _},` (no `{:write_file, :original}` after the raise) |
| R2 | `Outcome.classify/1` reads `:compile_error` as `:killed` | 1: Outcome row 4 | `code:  assert Outcome.classify(run(:compile_error, exit_code: 1, output_head: output)) == {:invalid, []}` `left:  {:killed, []}` |
| R3 | the dirty-target check off (every `dirty_paths` answer read as clean) | 1: Manager row 5 | `** (Mox.UnexpectedCallError) expected Anchor.ChangeSourceMock.read/2 to be called once but it has been called 2 times` (the run went on to read the file and make mutants) |
| R4 | the baseline skipped (read as passed, no test run) | 6: Manager rows 6, 7, 8, 9, the cap row, the `timeout` row | row 9: `** (Mox.VerificationError) ... expected Anchor.TestExecutionMock.run/3 to be invoked 2 times but it was invoked once` |
| R5 | a leftover journal deleted before its file is restored | 1: Manager row 1 | `code:  assert calls() == [` `left:  [:read_journal, :sha256_file, :delete_journal, :write_file,` `right: [:read_journal, :sha256_file, :write_file, :touch_ahead,` |
| R6 | the restore's sha256 not compared (the journal deleted whatever the file holds) | 1: Manager row 9 | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` (the run went on to the next mutant) |
| R7 | `touch_ahead/1` from now only, not past the current mtime | 1: SourcePatcher row 3 | `code: assert mtime(path) > first` `left: 1793694079` |
| R8 | exit 124 not read as a timeout | 2: Outcome "exit 124 or 137 is a timeout"; TestRunner row 5 | `code:  assert %TestRun{status: :timeout} = TestRun.from_frames(code, [], "x")` (TestRunner row 5 hit the 2000 ms bound; see below) |
| R9 | the cap ignored | 3: Plan row 1, Plan "--only filters before the cap"; Manager cap row | `code:  assert length(planned) == 30` `left:  40` `right: 30` |
| R10 | the formatter counts an excluded test as run | 1: formatter row 1 | `code:  assert frames(path) == [` ... `{:suite_finished, 2, 1, 1}` (got `{:suite_finished, 3, 1, 0}`) |
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
