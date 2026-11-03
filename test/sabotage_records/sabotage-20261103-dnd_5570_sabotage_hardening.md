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
