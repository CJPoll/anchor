# Sabotage record — defs inside defimpl are mutated (DND-5624); the timeout argv contract without a hang (DND-5625)

- **Domain:** sabotage
- **Branch:** dnd-5624-sabotage-defimpl
- **Date:** 2026-11-03
- **Code under test:** per ticket, in each section below (each section has
  its own **Code under test** and **Suite run**)
- **Suite run:** DND-5624: `mix test
  test/anchor/domain/sabotage/mutator_defimpl_test.exs
  test/anchor/domain/sabotage/no_mutant_test.exs
  test/anchor/domain/sabotage/report_test.exs
  test/anchor/domain/sabotage/mutator_test.exs
  test/anchor/managers/sabotage_run_test.exs --timeout 2000 --max-cases 2`;
  DND-5625: `mix test test/anchor/adapters/test_runner_test.exs --timeout 2000
  --max-cases 2`
- **Method:** each mutation was applied alone by a scratch driver outside the
  repo (one exact text replaced, the named test files run through `test-slot`
  with `mix test --timeout 2000 --max-cases 2`, the file restored and
  touched). Every failure string is copied from its output. After the last row
  the same files ran green.

## DND-5624 — the generator resolves `P.T` to the def inside its defimpl

- **Code under test:** `Anchor.Domain.Sabotage.SourceTree` (`module_node/2`,
  `function_clauses/4`, `definition_body/1`: a walk of every `defmodule`,
  `defprotocol` and `defimpl` named as `FunctionSpans` names them),
  `Anchor.Domain.Sabotage.OrphanCheck` (`refs_of/3` reads any definition's
  body; `refs/2` skips a nested `defimpl`), `Anchor.Domain.Sabotage.NoMutant`
  and `Anchor.Domain.Sabotage.Report` (the `defimpl target not a literal`
  reason), through `Anchor.Managers.Sabotage.run/2`
- **Suite run:** `mix test test/anchor/domain/sabotage/mutator_defimpl_test.exs
  test/anchor/domain/sabotage/no_mutant_test.exs
  test/anchor/domain/sabotage/report_test.exs
  test/anchor/domain/sabotage/mutator_test.exs
  test/anchor/managers/sabotage_run_test.exs --timeout 2000 --max-cases 2`
  (101 tests at S1-S10 as first run; 103 after the review round added D11 and
  D12, run for S4, S7, S10 again (their strings below are from that run) and
  for S11-S13; green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U1 | the unfixed code: the six `lib/` files as at 39f55e1 (the tests unchanged; suite without `mutator_test.exs`, 83 tests) | 13 | no_mutant N6 `** (ArgumentError) expected an Elixir module, got: nil` at `lib/anchor/domain/sabotage/source_tree.ex:73: Anchor.Domain.Sabotage.SourceTree.module_node/2` (manager M1 too: a non-literal `for:` crashed the whole run); D1 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` (also D2, D3, D4, D5, D6, D7, D10, the report row, manager M4); D8 `code:  assert {:ok, %{mutants: [], skipped: skipped}} = Mutator.generate(source, @path, {Calc, :name, 1})` `right: {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{id: "03d5c941781c", file: "lib/calc.ex", module: Calc, function: {:name, 1},` |
| S1 | `for: [T1, T2]` read as one target (the list clause of `impl_targets/1` removed) | 2 | D10 `** (MatchError) no match of right hand side value: {:error, :not_in_source}` `code: for source <- sources,` (also D3) |
| S2 | a defimpl with no `for:` ignores the enclosing module (`impl_name(protocol, :enclosing, _parent)` uses `nil`) | 4 | D4 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` (also D2, D5, D10) |
| S3 | the walk no longer recognises `defimpl` (its clause matches `:defimpl_never`) | 11 | no_mutant N6 `left:  "macro: no literal def/defp clause in the source (a macro made it)"` (also D1, D2, D3, D4, D5, D6, D7, D10, manager M1, M4) |
| S4 | a non-literal `for:` is `:not_in_source` again (`missing(true)`) | 3 | no_mutant N6 `code:  assert NoMutant.reason(Mutator.generate(source, "lib/calc.ex", {nil, :to_string, 1})) ==` `left:  "macro: no literal def/defp clause in the source (a macro made it)"` `right: "defimpl target not a literal: the source does not spell its module name (a for: that is not a module name, or an unnamed enclosing module)"` (also D6, manager M1) |
| S5 | `OrphanCheck.refs/2` enters a nested `defimpl` (skips only `defmodule`) | 1 | D8 `code:  assert {:ok, %{mutants: [], skipped: skipped}} = Mutator.generate(source, @path, {Calc, :name, 1})` `right: {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{` |
| S6 | `refs_of/3` reads only the first option list (`List.first` for `Enum.concat`): a defimpl's `do` is not found | 1 | D7 `code:  assert mutants == []` `left:  [%Anchor.Domain.Sabotage.Mutant{id: "aee05ea049d4", file: "lib/calc.ex", module: String.Chars.Calc,` |
| S7 | `module_node(_ast, nil)` removed: `nil` matches an unnamed definition | 3 | no_mutant N6, same `code:`, `left:  nil` `right: "defimpl target not a literal: the source does not spell its module name (a for: that is not a module name, or an unnamed enclosing module)"` (also D6, manager M1) |
| S8 | the walk enters `quote` | 1 | D9 `code:  assert Mutator.generate(source, @path, {String.Chars.Calc, :to_string, 1}) == {:error, :not_in_source}` `left:  {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{id: "fada1c194460",` |
| S9 | `for: __MODULE__` not read (the `literal_name/2` `__MODULE__` clause removed) | 1 | D4 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` |
| S10 | the report's `defimpl target not a literal` error text removed (falls to `inspect/1`) | 1 | report `code:  assert text =~` `left:  "error\tlib/gen.ex\tnil.to_string/1\t:defimpl_target_not_literal\nanchor.sabotage run: 0 mutants run: 0 killed, 0 survived, 0 timeout, 0 invalid, 0 crashed, 0 no_tests; 0 skipped; 0 not run (cap); 1 errors"` `right: "error\tlib/gen.ex\tnil.to_string/1\tdefimpl target not a literal (its module cannot be named): no mutant, not killed"` |
| S11 | `defprotocol` dropped from the walk (`kind in [:defmodule]`) | 2 | D11 `code:  assert Mutator.generate(@protocol, @path, {Shape, :area, 1}) == {:ok, %{mutants: [], skipped: []}}` `left:  {:error, :not_in_source}` (also D10) |
| S12 | `for: nil` not read as the enclosing module (its `impl_targets/1` clause removed) | 1 | D12 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` |
| S13 | `for: []` not read as the enclosing module (its `impl_targets/1` clause removed) | 1 | D12, same `code:`, `right: {:error, :not_in_source}` |

Positive controls: D5 (a plain `defmodule` def beside a same-named impl def:
each resolves to its own lines) and the existing `mutator_test.exs` rows pass
on every row but S2, S3 (D5's impl half) and U1. D9 passed on the unfixed code
too: it guards the new walk, not the old lookup. U1 predates D11 and D12 (the
review round); they are proven red by S11-S13 instead.

## DND-5625 — the coreutils `timeout` argv contract, with nothing that hangs

- **Code under test:** `Anchor.Adapters.TestRunner` (`execute/4`: the argv
  `--kill-after=<grace> <bound> <command> ...` handed to the real `timeout`
  binary, and the exit code passed through to `TestRun`). Rows 5 and 7 of
  `test/anchor/adapters/test_runner_test.exs` (a fake command that hangs, and
  one that ignores SIGTERM, each waiting about 2.5 s for the real bound, row
  7's verdict read from the measured wall time) are replaced by C1 and C2: the
  real binary around `true` and `false`, which exit at once. Each takes about
  1 ms; no row waits for the bound or reads the clock for its verdict. The
  fixture's `hang` and `stubborn` modes, used only by those rows, are gone.
- **Suite run:** `mix test test/anchor/adapters/test_runner_test.exs --timeout
  2000 --max-cases 2` (17 tests, green after the change and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| T1 | `--kill-after` dropped from the argv (the ticket's row) | 2 | K2 `code: assert_received {:cmd, _timeout, ["--kill-after=10", "30" \| _rest], _cmd_opts}` (also K1). C1 and C2 stay green: `timeout` accepts the argv without the flag, so the grace period is proven by the injected-runner rows, not the contract rows |
| T2 | the bound before `--kill-after` | 11 | C1 `code:  assert {:ok, %TestRun{exit_code: 0, output_head: ""}} = contract("true", dir)` `exit_code: 127,` `output_head: "timeout: failed to run command ‘--kill-after=1’: No such file or directory\n",` (also C2, K1, K2, and rows 1-4, 6, 8, 9) |
| T3 | a bound `timeout` cannot read (`"30x"`) | 11 | C1, same `code:`, `exit_code: 125,` `output_head: "timeout: invalid time interval ‘30x’\nTry '/usr/sbin/timeout --help' for more information.\n",` (also C2, K1, K2, and the fake-command rows) |
| T4 | the flag misspelt (`--kill-afer=`) | 11 | C1, same `code:`, `exit_code: 125,` `output_head: "/usr/sbin/timeout: unrecognized option '--kill-afer=1'\nTry '/usr/sbin/timeout --help' for more information.\n",` (also C2, K1, K2, and the fake-command rows) |
| T5 | the exit code not passed through (`code * 0`) | 7 | C2 `code:  assert {:ok, %TestRun{exit_code: 1, output_head: ""}} = contract("false", dir)` `exit_code: 0,` (also rows 2, 4, 6, K3, K4, K5) |

The fake-command rows 1-4, 6, 8 and 9 also run the real `timeout`, so they
too go red when coreutils refuses the argv (T2-T4); C1 and C2 are the named,
instant check of that contract, and C2 the only one with a bare non-zero
exit.
