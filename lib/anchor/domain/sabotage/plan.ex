defmodule Anchor.Domain.Sabotage.Plan do
  @moduledoc """
  The mutants a run applies, in order, and those the cap leaves out
  (DND-5473). Pure **Domain**.

  Order: file, function, operator, id. `--only` keeps the named mutants (an
  id the run does not have is an error, never ignored); the cap then keeps the
  first `cap` (`:all` keeps every one). The rest are `not_run`, listed by the
  report, never dropped.
  """

  alias Anchor.Domain.Sabotage.Mutant

  @type t :: %{planned: [Mutant.t()], not_run: [Mutant.t()]}

  @spec build([Mutant.t()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def build(mutants, opts) do
    cap = Keyword.fetch!(opts, :cap)
    only = Keyword.get(opts, :only, [])
    ordered = Enum.sort_by(mutants, &{&1.file, &1.function, &1.operator, &1.id})

    with {:ok, selected} <- only(ordered, only) do
      {planned, not_run} = if cap == :all, do: {selected, []}, else: Enum.split(selected, cap)
      {:ok, %{planned: planned, not_run: not_run}}
    end
  end

  defp only(ordered, []), do: {:ok, ordered}

  defp only(ordered, ids) do
    known = MapSet.new(ordered, & &1.id)

    case Enum.reject(ids, &MapSet.member?(known, &1)) do
      [] ->
        {:ok, Enum.filter(ordered, &(&1.id in ids))}

      unknown ->
        {:error,
         "--only names a mutant this run does not have: #{Enum.join(unknown, ", ")}. " <>
           "Fix: pass an id `mix anchor.sabotage run --dry-run` lists"}
    end
  end
end
