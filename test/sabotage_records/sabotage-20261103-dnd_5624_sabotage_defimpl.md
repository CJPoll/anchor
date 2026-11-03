# Sabotage record — defs inside defimpl are mutated (DND-5624)

- **Domain:** sabotage
- **Branch:** dnd-5624-sabotage-defimpl
- **Date:** 2026-11-03
- **Code under test:** per ticket, in each section below
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
  (101 tests, green after the fix and after every row)

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U1 | the unfixed code: the six `lib/` files as at 39f55e1 (the tests unchanged; suite without `mutator_test.exs`, 83 tests) | 13 | no_mutant N6 `** (ArgumentError) expected an Elixir module, got: nil` at `lib/anchor/domain/sabotage/source_tree.ex:73: Anchor.Domain.Sabotage.SourceTree.module_node/2` (manager M1 too: a non-literal `for:` crashed the whole run); D1 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` (also D2, D3, D4, D5, D6, D7, D10, the report row, manager M4); D8 `code:  assert {:ok, %{mutants: [], skipped: skipped}} = Mutator.generate(source, @path, {Calc, :name, 1})` `right: {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{id: "03d5c941781c", file: "lib/calc.ex", module: Calc, function: {:name, 1},` |
| S1 | `for: [T1, T2]` read as one target (the list clause of `impl_targets/1` removed) | 2 | D10 `** (MatchError) no match of right hand side value: {:error, :not_in_source}` `code: for source <- sources,` (also D3) |
| S2 | a defimpl with no `for:` ignores the enclosing module (`impl_name(protocol, :enclosing, _parent)` uses `nil`) | 4 | D4 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` (also D2, D5, D10) |
| S3 | the walk no longer recognises `defimpl` (its clause matches `:defimpl_never`) | 11 | no_mutant N6 `left:  "macro: no literal def/defp clause in the source (a macro made it)"` (also D1, D2, D3, D4, D5, D6, D7, D10, manager M1, M4) |
| S4 | a non-literal `for:` is `:not_in_source` again (`missing(true)`) | 3 | no_mutant N6 `left:  "macro: no literal def/defp clause in the source (a macro made it)"` (also D6, manager M1) |
| S5 | `OrphanCheck.refs/2` enters a nested `defimpl` (skips only `defmodule`) | 1 | D8 `code:  assert {:ok, %{mutants: [], skipped: skipped}} = Mutator.generate(source, @path, {Calc, :name, 1})` `right: {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{` |
| S6 | `refs_of/3` reads only the first option list (`List.first` for `Enum.concat`): a defimpl's `do` is not found | 1 | D7 `code:  assert mutants == []` `left:  [%Anchor.Domain.Sabotage.Mutant{id: "aee05ea049d4", file: "lib/calc.ex", module: String.Chars.Calc,` |
| S7 | `module_node(_ast, nil)` removed: `nil` matches an unnamed definition | 3 | no_mutant N6 `left:  nil` `right: "defimpl target not a literal: its for: is not a module name the source spells, so the implementation module cannot be named"` (also D6, manager M1) |
| S8 | the walk enters `quote` | 1 | D9 `code:  assert Mutator.generate(source, @path, {String.Chars.Calc, :to_string, 1}) == {:error, :not_in_source}` `left:  {:ok, %{mutants: [%Anchor.Domain.Sabotage.Mutant{id: "fada1c194460",` |
| S9 | `for: __MODULE__` not read (the `literal_name/2` `__MODULE__` clause removed) | 1 | D4 `code:  assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)` `right: {:error, :not_in_source}` |
| S10 | the report's `defimpl target not a literal` error text removed (falls to `inspect/1`) | 1 | report `code:  assert text =~ "error\tlib/gen.ex\tnil.to_string/1\tdefimpl target not a literal (its for: names " <> "no module): no mutant, not killed"` `left:  "error\tlib/gen.ex\tnil.to_string/1\t:defimpl_target_not_literal\nanchor.sabotage run: 0 mutants run: ...` |

Positive controls: D5 (a plain `defmodule` def beside a same-named impl def:
each resolves to its own lines) and the existing `mutator_test.exs` rows pass
on every row but S2, S3 (D5's impl half) and U1. D9 passed on the unfixed code
too: it guards the new walk, not the old lookup.
