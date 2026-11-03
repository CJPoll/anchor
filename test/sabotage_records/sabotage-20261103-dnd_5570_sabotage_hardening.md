# Sabotage record — sabotage runner hardening (DND-5570, DND-5573, DND-5563, DND-5571, DND-5572)

- **Domain:** sabotage
- **Branch:** dnd-5570-sabotage-hardening
- **Date:** 2026-11-03
- **Method:** each mutation was applied alone by a scratch driver outside the
  repo (one exact text replaced, the named test files run through `test-slot`
  with `--timeout 2000 --max-cases 2`, the file restored and touched). Every
  failure string is copied from its output. A mutation that only tripped
  warnings-as-errors (a dead clause, an unused variable) is not a row: its
  text was changed until it compiled.

## DND-5570 — exit-code policy

- **Code under test:** `Anchor.Domain.Sabotage.Report` (`exit_code/1`,
  `verdict/1`, `zero_scope/1`, `conclusion/2`), `Outcome.classify/1`,
  `Anchor.Managers.Sabotage.Runner` (`changed_functions`, a raised test run)
- **Suite run:** `mix test test/anchor/domain/sabotage/report_test.exs
  test/anchor/domain/sabotage/outcome_test.exs
  test/anchor/managers/sabotage_run_test.exs --timeout 2000 --max-cases 2`
  (71 tests, green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U1 | the unfixed code (the new tests against the old `Report`, `Outcome` and Runner; only the `Run.changed_functions` field added so the file compiles) | 14 | report "an unmeasured mutant (crashed, or no test) in a measured run fails like a survivor"; report "mutants run and none measured is exit 3 ..."; manager "10: a mutant with no test selected is no_tests ..."; manager "a crashed test run is crashed ..."; outcome "5: a crashed run is crashed (unmeasured), not invalid" `code:  assert Outcome.classify(run(:no_tests, total: 0)) == {:no_tests, []}` |
| S1 | `verdict_code(:unmeasured)` is 0 (a run that measured nothing passes) | 3 | report "mutants run and none measured is exit 3, COULD NOT MEASURE with a Fix:" `[:invalid]` `code: for statuses <- [` |
| S2 | `@failing` is only `:survived` (a crashed or no-test mutant beside a measured one does not fail) | 2 | report "3: a no_tests mutant in a measured run: exit 1 ..." `code:  assert Report.exit_code(run) == 1` `left:  0` |
| S3 | `:invalid` counts as measured (an all-invalid run reads as measured) | 1 | report "mutants run and none measured is exit 3 ..." `[:invalid]` |
| S4 | zero outcomes is `:unmeasured` (a good empty scope exits 3) | 4 | report "zero changed functions from a good diff read: exit 0, said loudly with the range" `code:  assert Report.exit_code(run) == 0` `left:  3` |
| S5 | the zero-scope line is replaced (`sabotage: scope <base>`) | 3 | report "zero changed functions ..." `code:  assert Report.render(run) =~ "sabotage: 0 changed functions in origin/main..HEAD\n"` |
| S6 | a crashed run classifies `:invalid` | 2 | outcome "5: a crashed run is crashed (unmeasured), not invalid" `left:  {:invalid, []}` `right: {:crashed, []}` |
| S7 | a raised test run is `:invalid` in the Runner | 1 | manager "8: a test run that raises still restores the file ..." (the `status: :crashed` match) |
| S8 | the Runner never sets `changed_functions` | 1 | manager "zero changed functions from a good diff read: exit 0, loud, no baseline, no write" `code:  assert run.changed_functions == 0` `left:  nil` |

Positive controls: report "positive control: one measured mutant makes invalid
mutants not change the exit" and "positive control: changed functions that
made no mutant do not print the zero line" pass on S1 to S8 (and the manager
test "a diff that could not be read stays exit 3, never the empty scope" passed
on U1 already: that rule was not broken, and the test pins it).

## DND-5573 — bounded output, exit 137 is a crash

- **Code under test:** `Anchor.Domain.Sabotage.BoundedOutput` (new),
  `TestRun.from_frames/4` (`status/5`, `bound_reached?/1`), `Outcome.reason/1`
  (`crash_text/1`, `dropped_note/1`), `Anchor.Adapters.TestRunner` (`execute/4`)
- **Suite run:** `mix test test/anchor/domain/sabotage/bounded_output_test.exs
  test/anchor/domain/sabotage/outcome_test.exs
  test/anchor/adapters/test_runner_test.exs --timeout 2000 --max-cases 2`
  (37 tests, green after the fix and after every row)
- **Design call:** an exit 137 is not always an out-of-memory kill: `timeout
  --kill-after` exits 137 when it had to KILL a run that ignored its stop
  signal. So 137 is `:timeout` only when the run's measured time reached its
  bound, else `:crashed`, killed by signal 9; with no clock reading it is
  `:crashed`. The adapter test "7: positive control" runs that case for real
  (a fake command ignoring SIGTERM, 1 s bound, 1 s grace).

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U2 | the unfixed code (old `TestRunner`, `TestRun`, `Outcome`; only the `dropped_bytes` field added so the files compile) | 7 | outcome "killed by signal 9 well inside the bound is crashed, never a timeout"; adapter "6: a run killed by signal 9 inside the bound is crashed ..." `code:  assert {:ok, %TestRun{status: :crashed, exit_code: 137} = run} = run("killed", dir)`; adapter "8: the output is bounded ..." `code:  assert dropped > 150_000` `left:  0` `right: 150000` |
| M1 | 137 inside the bound is `:timeout` again | 4 | outcome "positive control: 137 after the bound was reached ..." `code:  assert %TestRun{status: :crashed} = TestRun.from_frames(137, [], "", elapsed_ms: 299_999, timeout_seconds: 300)` |
| M2 | the bound is reached at `>` instead of `>=` | 1 | outcome "positive control: 137 after the bound was reached ..." `code:  assert %TestRun{status: :timeout} = run` |
| M3 | the clock reading is wrong (elapsed minus twice the start) | 1 | adapter "6: a run killed by signal 9 inside the bound is crashed ..." |
| M3a | the clock reading is always 0 | 1 | adapter "7: positive control: a run that ignores the stop signal and needs the KILL is a timeout" |
| M4 | the collector's limits are 1000 times larger | 1 | adapter "8: the output is bounded ..." `code:  assert dropped > 150_000` `left:  0` |
| M5 | dropped tail bytes are not counted | 4 | bounded_output "what is held never exceeds the limits, whatever is collected" `code:  assert BoundedOutput.dropped(out) == 2000 * 1024 - 250` `left:  0` |
| M6 | the head never keeps a byte | 5 | bounded_output "output within both limits is kept whole and nothing is dropped" |
| M7 | the tail keeps the oldest bytes instead of the newest | 1 | bounded_output "output past the limits keeps the first head bytes and the last tail bytes ..." `code:  assert out.tail == "EFGHIJ"` `left:  "456789"` |
| M8 | a crash does not say how many bytes were dropped | 1 | outcome "a crash says how many bytes of its output were dropped" `left:  "test run crashed (exit 1)"` |
| M9 | `kill_after_seconds` is not passed on (the grace period stays 10 s) | 1 | adapter "7: positive control ..." `** (ExUnit.TimeoutError) test timed out after 8000ms` (a bound, not a sleep: the real run is about 2.5 s) |
| M10 | the adapter does not pass the dropped count on | 1 | adapter "8: the output is bounded ..." `left:  0` |
| M11 | the exit-137 crash reason loses "killed by signal 9" | 2 | outcome "killed by signal 9 well inside the bound ..." `left:  "test run crashed (exit 137)"` |

Positive controls (they pass on every row where the rule is not the one
broken): adapter "9: output within the bound drops nothing", outcome
"positive control: 124 is a timeout whatever the clock says".

Bound, not a kill: the adapter hang rows ("5" and "7") carry their own
`@tag timeout`, because the `timeout` binary's 1 s plus the VM's start-up is
longer than the load rule's 2000 ms.

## DND-5563 — OrphanCheck tracks imports per imported name

- **Code under test:** `Anchor.Domain.Sabotage.OrphanCheck` (`module_refs/5`,
  `tracked/1`, `tracked_key/2`, `call_key/4`, `listed?/3`, `open?/3`)
- **Suite run:** `mix test test/anchor/domain/sabotage/orphan_check_imports_test.exs
  --timeout 2000 --max-cases 2` (7 tests, green after the fix and after
  every row; the whole `test/anchor/domain/sabotage` directory, 179 tests,
  green after the fix)
- **What the compiler says** (Elixir 1.19.4, checked): `import M, only:
  [a: 1, b: 1]` with `b` unused warns `unused import M.b/1` (per listed name);
  `import M` warns `unused import M` only when no call reaches it. The test
  compiles every mutant it expects (zero diagnostics) and every edit it
  refuses (an `unused import` warning).

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U3 | the unfixed code (tests against the old `OrphanCheck`, which tracked every non-builtin undefined call as its own key) | 4 | "3: another function's call keeps the import used ..." `code:  assert targets(result.mutants) == ["upcase(x)"]` `left:  []`; "1: removing the last call of one name ..." `left:  []`; "6: ..." and "2: positive control ..." on the reason text |
| O1 | the comparison is with `later.uses` again (the group key is never seen as still used) | 3 | "3: another function's call keeps the import used: the mutant is not refused" `code:  assert targets(result.mutants) == ["upcase(x)"]` |
| O2 | calls that may reach an open import are untracked | 2 | "6: the listed name is its own import; the unlisted calls share the other" `Assertion with == failed` |
| O3 | a name in an `only:` list is untracked | 2 | "4: removing the last call of a listed name is refused ..." `code:  assert result.mutants == []` |
| O5 | a `Kernel` function or operator counts as a call that reaches an import | 2 | "2: positive control: removing the only call that reaches the import is refused, and it would warn" `code:  assert result.mutants == []` |
| O8 | a call counts as reaching an import when the module has none | 1 | "7: no import at all: a call to a name a `use` brought in ..." `code:  assert targets(result.mutants) == ["brought_in(x)"]` `left:  []` |

O0 (the same text replaced by itself) was green, as the driver's check.
