defmodule Anchor.Domain.Sabotage.Plan do
  @moduledoc """
  The mutants a run applies, in order, and those the cap leaves out
  (DND-5473), and the shard a scan keeps (DND-5490). Pure **Domain**.

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

  @doc """
  The mutants of shard `i` of `n` (DND-5490): those whose id, read as a
  hexadecimal number, is `i` modulo `n`. The id hashes the mutant's function,
  operator, target and occurrence, never its line, so a mutant stays in its
  shard when code moves around it, and shards `0..n-1` together hold every
  mutant exactly once. `i` outside `0..n-1`, or `n` below 1, is
  `{:error, :bad_shard}`.
  """
  @spec shard([Mutant.t()], integer(), integer()) :: {:ok, [Mutant.t()]} | {:error, :bad_shard}
  def shard(mutants, i, n)
      when is_integer(i) and is_integer(n) and n >= 1 and i >= 0 and i < n,
      do: {:ok, Enum.filter(mutants, &(rem(String.to_integer(&1.id, 16), n) == i))}

  def shard(_mutants, _i, _n), do: {:error, :bad_shard}

  @doc """
  The shard a nightly scan runs on `date` (DND-5490): `{day_of_year mod n, n}`,
  so every mutant is scanned once every `n` nights and no night runs them all.
  """
  @spec shard_of_day(Date.t(), pos_integer()) :: {non_neg_integer(), pos_integer()}
  def shard_of_day(%Date{} = date, n) when is_integer(n) and n >= 1,
    do: {rem(Date.day_of_year(date), n), n}

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
