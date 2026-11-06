defmodule Anchor.Domain.Sabotage.SharedRun do
  @moduledoc """
  Which planned mutants share one test run (DND-5639). Pure **Domain**.

  A `defimpl P, for: [T1, T2]` defines `P.T1` and `P.T2` from one block, so
  the generator makes each mutant once per target (`Mutator`, DND-5624): the
  same edit to the same file, under one id per target. Tests are selected per
  target, and often select the same files. Two such mutants write the same
  bytes and run the same tests, so their runs are the same run: the runner
  measures the first and gives its verdict to the rest (`attribute/3`). Each
  target still has its own outcome, with its own id, module and selection.
  Targets whose selections differ each run their own tests.

  `key/2` is what makes two runs the same: the file, the edited range, the
  replacement text and the selected tests as a set (their order and their
  source do not change what runs). A mutant with no test selected runs
  nothing, so it has no key and is never shared.
  """

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Run

  @type key :: {String.t(), Anchor.Domain.Sabotage.Patch.range(), String.t(), [String.t()]}

  @doc "The run `mutant` with `selection` makes, or `nil` when no test is selected."
  @spec key(Mutant.t(), Run.selection()) :: key() | nil
  def key(%Mutant{}, {_source, []}), do: nil

  def key(%Mutant{} = mutant, {_source, tests}),
    do: {mutant.file, mutant.range, mutant.replacement, tests |> Enum.uniq() |> Enum.sort()}

  @doc """
  The outcome of a run measured for another mutant with the same `key/2`,
  as `mutant`'s own: its mutant and selection, the measured verdict.
  """
  @spec attribute(map(), Mutant.t(), Run.selection()) :: map()
  def attribute(%{} = measured, %Mutant{} = mutant, selection),
    do: %{measured | mutant: mutant, selection: selection}
end
