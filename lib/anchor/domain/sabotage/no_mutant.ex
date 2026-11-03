defmodule Anchor.Domain.Sabotage.NoMutant do
  @moduledoc """
  Why a changed function yielded no mutant (DND-5617). Pure **Domain**.

  `reason/1` reads one `Anchor.Domain.Sabotage.Mutator.generate/4` result and
  returns `nil` when it holds at least one mutant, else the reason as text:

    * `skipped: <operator>: <why>; ...` when every edit was skipped (each
      distinct operator and reason once, in the generator's order);
    * `macro: ...` when no literal `def`/`defp` clause covers the function;
    * `defimpl target not a literal: ...` when the function is in a `defimpl`
      whose module name the source does not spell: its `for:` is not a module
      name, or it has no `for:` and its enclosing module is unnamed
      (DND-5624);
    * `no mutable site` when no operator found anything to change;
    * `does not parse ...` / `could not be read ...` for a file error.

  `Anchor.Domain.Sabotage.Report` prints one line per such function, plus a
  summary, when a run's changed functions yielded no mutant at all: a run that
  measured nothing must never read like one that found no survivor.
  """

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Skipped

  @type generated ::
          {:ok, %{mutants: [Mutant.t()], skipped: [Skipped.t()]}}
          | {:error,
             :not_in_source
             | :defimpl_target_not_literal
             | {:parse_error, pos_integer(), String.t()}
             | {:unreadable, atom()}}

  @spec reason(generated()) :: String.t() | nil
  def reason({:ok, %{mutants: [_mutant | _rest]}}), do: nil
  def reason({:ok, %{mutants: [], skipped: []}}), do: "no mutable site"
  def reason({:ok, %{mutants: [], skipped: skipped}}), do: "skipped: " <> skipped_text(skipped)

  def reason({:error, :not_in_source}),
    do: "macro: no literal def/defp clause in the source (a macro made it)"

  def reason({:error, :defimpl_target_not_literal}),
    do:
      "defimpl target not a literal: the source does not spell its module name " <>
        "(a for: that is not a module name, or an unnamed enclosing module)"

  def reason({:error, {:parse_error, line, message}}),
    do: "does not parse at line #{line}: #{message}"

  def reason({:error, {:unreadable, posix}}), do: "could not be read (#{inspect(posix)})"

  defp skipped_text(skipped) do
    skipped
    |> Enum.map(&"#{&1.operator}: #{&1.reason}")
    |> Enum.uniq()
    |> Enum.join("; ")
  end
end
