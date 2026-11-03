# Sabotage record — zero-mutant lines, exit 137 without a wall clock (DND-5617, DND-5618)

- **Domain:** sabotage
- **Branch:** dnd-5617-sabotage-cfa-batch
- **Date:** 2026-11-03
- **Code under test:** per ticket, in each section below
- **Method:** each mutation was applied alone by a scratch driver outside the
  repo (one exact text replaced, the named test files run through `test-slot`
  with `mix test --timeout 2000 --max-cases 2`, the file restored and
  touched). Every failure string is copied from its output. A mutation that
  only tripped warnings-as-errors (the type checker on a dead comparison) is
  not a row: its text was changed until it compiled. After the last row the
  same files ran green.

## DND-5617 — changed functions that yield no mutant are said loudly

- **Code under test:** `Anchor.Domain.Sabotage.NoMutant` (new, `reason/1`),
  `Anchor.Domain.Sabotage.Report` (`no_mutants/1`), `Anchor.Domain.Sabotage.Run`
  (`generated`, `no_mutant`), `Anchor.Managers.Sabotage.Runner` (`generate/5`,
  `no_mutant/1`), through `mix anchor.sabotage run`
- **Suite run:** `mix test test/anchor/domain/sabotage/no_mutant_test.exs
  test/anchor/domain/sabotage/report_test.exs
  test/anchor/managers/sabotage_run_test.exs
  test/mix/tasks/anchor_sabotage_run_test.exs --timeout 2000 --max-cases 2`
  (75 tests, green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U1 | the unfixed code: `no_mutants/1` prints nothing and the Runner sets neither `generated` nor `no_mutant` (the new fields and module present so the tests compile) | 7 | report Z1 `code:  assert text =~` `left:  "error\tlib/gen.ex\tGen.init/1\tno literal def/defp clause in the source (a macro made it): no mutant, not killed\nerror\tlib/gen.ex\tGen.stop/1\tno literal def/defp clause in the source (a macro made it): no mutant, not killed\nanchor.sabotage run: 0 mutants run: 0 killed, 0 survived, 0 timeout, 0 invalid, 0 crashed, 0 no_tests; 0 skipped; 0 not run (cap); 2 errors"` (also Z2, Z3, manager M1, M2, M3, and the task test) |
| S1 | `no_mutants/1` returns `[]` (silent again) | 6 | report Z1, same `left:` as U1 (also Z2, Z3, M1, M2, the task test) |
| S2 | the per-function line drops its reason | 6 | report Z2 `left:  "sabotage: no mutant from Gen.init/1 (lib/gen.ex) 0\nsabotage: no mutant from Gen.stop/1 (lib/stop.ex) 0\nsabotage: no mutants generated from 2 changed functions: nothing was measured (exit 0; see the lines above for why)\n..."` |
| S3 | the guard is `n >= 0` (a zero scope also says "no mutants generated") | 1 | report Z5 `code:  refute text =~ "no mutants generated"` `left:  "sabotage: 0 changed functions in origin/main..HEAD\nsabotage: no mutants generated from 0 changed functions: nothing was measured (exit 0; see the lines above for why)\n..."` |
| S4 | the head matches any `generated` (a run with mutants says it too) | 2 | report Z4 `code:  refute text =~ "no mutants generated"` `left:  "sabotage: no mutant from Gen.stop/1 (lib/gen.ex): no mutable site\nsabotage: no mutants generated from 2 changed functions: ..."` (also M3) |
| S5 | the Runner sets `generated: nil` | 4 | manager M1 `code:  assert {run.changed_functions, run.generated, run.outcomes} == {1, 0, []}` `left:  {1, nil, []}` (also M2, M3, the task test) |
| S6 | the Runner keeps no per-function reason (`no_mutant([])`) | 3 | manager M1 `code:  assert text =~` `left:  "sabotage: no mutants generated from 1 changed functions: nothing was measured (exit 0; see the lines above for why)\nerror\tlib/calc.ex\tString.Chars.Calc.to_string/1\tno literal def/defp clause in the source (a macro made it): no mutant, not killed\n..."` (also M2, the task test) |
| S7 | a skipped reason drops its operator | 3 | no_mutant N2 `code:  assert NoMutant.reason(generated(source)) ==` `left:  "skipped: orphans variable `x` bound at line 3 and used at line 4"` (also M2, the task test) |
| S8 | the "has a mutant" clause also needs a skipped edit | 19 | no_mutant N1 `** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.NoMutant.reason/1` (every manager test whose function has mutants) |
| S9 | the macro reason loses its `macro:` label | 2 | no_mutant N3 `code:  assert NoMutant.reason(generated("defmodule Calc do\nend\n")) ==` `left:  "no literal def/defp clause in the source (a macro made it)"` (also M1) |
| S10 | the `no mutable site` clause removed | 1 | no_mutant N4 `code:  assert NoMutant.reason(generated(source)) == "no mutable site"` `left:  "skipped: "` |

Positive controls: report Z4 (one mutant generated: no such line) and manager
M3 (a function with mutants, dry run) pass on S1, S2, S3, S6, S7, S9 and S10,
and both fail under S4. M3 also asserts the counts, so it fails under U1, S5
and S8, where `generated` or `no_mutant` is wrong.
