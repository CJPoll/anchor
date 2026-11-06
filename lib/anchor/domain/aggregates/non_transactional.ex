defmodule Anchor.Domain.Aggregates.NonTransactional do
  @moduledoc """
  The writes read with no transaction read around them (DND-5459) — a **Domain** module
  (ADR 001). Pure. DND-5477's atomicity rule reads them.

  `build/3`: for each function `f`, `nontx[f]` is `f`'s `Repo` and
  `write_functions` writes read outside the transaction bodies read in `f`, plus
  `nontx[g]` for each project function `g` that `f` calls outside a body;
  per strongly connected component, so recursion terminates
  (`Anchor.Domain.Aggregates.Scopes.summarise/2`). An `Ecto.Multi` step and a
  `Multi.run` callback's write are never non-transactional: a Multi only runs
  inside a transaction. That holds when the Multi is built in a helper too:
  a write inside an inline `Multi.run` callback (`WriteSite.run_callback?`)
  and a capture passed as one (`run_callbacks`, from
  `Anchor.Domain.Aggregates.WriteSites.facts/3`) are inside, never outside.
  A function captured as a run callback is so wherever it is captured.
  An entry has `no_gap_noticed?` when no dynamic call and no unresolved write
  is reached. It says what was read: a caller's transaction may still hold a
  function's writes, and a form not read is not in the entry.
  """

  alias Anchor.Domain.Aggregates.Scopes
  alias Anchor.Domain.Aggregates.WriteSite

  @type entry :: %{
          keys: MapSet.t(),
          sites: [WriteSite.t()],
          no_gap_noticed?: boolean(),
          gaps: list()
        }

  @doc """
  `nontx` of each function of `functions` (the resolved facts), keyed
  through `tables`; `run_callbacks` are the functions captured as a
  `Multi.run` callback.
  """
  @spec build(map(), %{String.t() => [module()]}, MapSet.t(mfa())) :: %{mfa() => entry()}
  def build(functions, tables, run_callbacks \\ MapSet.new()) do
    functions
    |> without_run_captures(run_callbacks)
    |> Scopes.summarise(:outside)
    |> Map.new(fn {mfa, summary} ->
      # A run callback's own writes are inside the Multi's transaction; a direct
      # caller's entry still holds them, through its call.
      summary =
        if MapSet.member?(run_callbacks, mfa),
          do: %{sites: MapSet.new(), gaps: MapSet.new()},
          else: summary

      gaps = Scopes.sort_gaps(summary.gaps)

      {mfa,
       %{
         keys: Scopes.keys(summary.sites, tables),
         sites: Scopes.sort_sites(summary.sites),
         no_gap_noticed?: gaps == [],
         gaps: gaps
       }}
    end)
  end

  # A capture passed as a `Multi.run` callback is inside the Multi's
  # transaction, never a call outside one.
  defp without_run_captures(functions, run_callbacks) do
    Map.new(functions, fn {mfa, function} ->
      {mfa, %{function | calls: Enum.reject(function.calls, &run_capture?(&1, run_callbacks))}}
    end)
  end

  defp run_capture?(%{kind: :capture, to: to}, run_callbacks),
    do: MapSet.member?(run_callbacks, to)

  defp run_capture?(_call, _run_callbacks), do: false
end
