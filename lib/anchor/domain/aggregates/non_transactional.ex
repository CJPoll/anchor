defmodule Anchor.Domain.Aggregates.NonTransactional do
  @moduledoc """
  The writes made outside every transaction (DND-5459) — a **Domain** module
  (ADR 001). Pure. DND-5477's atomicity rule reads them.

  `build/3`: for each function `f`, `nontx[f]` is `f`'s `Repo` and
  `write_functions` writes outside every transaction body in `f`, plus
  `nontx[g]` for every project function `g` that `f` calls outside a body;
  per strongly connected component, so recursion terminates
  (`Anchor.Domain.Aggregates.Scopes.summarise/2`). An `Ecto.Multi` step and a
  `Multi.run` callback's write are never non-transactional: a Multi only runs
  inside a transaction. That holds when the Multi is built in a helper too:
  a write inside an inline `Multi.run` callback (`WriteSite.run_callback?`)
  and a capture passed as one (`run_callbacks`, from
  `Anchor.Domain.Aggregates.WriteSites.facts/3`) are inside, never outside.
  A function captured as a run callback is so everywhere it is captured.
  Each entry is complete when no dynamic call and no unresolved write is
  reached.

  `always_in_transaction/3`: the functions that are not roots and whose every
  project call site is inside a transaction body or is a `Multi.run` callback
  (inline, or a capture in `run_callbacks`), or inside a function that is
  itself always in a transaction (the greatest fixpoint, so mutual recursion
  reached only inside a transaction stays in, and a cycle no transaction reaches
  does not). A root is a function given in
  `roots` (the public functions of the framework bucket, when the run has an
  `architecture:` section); with `roots` `nil`, every public function with no
  project caller is one. A function used as a value outside a transaction
  body is called by code Anchor cannot see, so it is never in the set.
  """

  alias Anchor.Domain.Aggregates.Scopes
  alias Anchor.Domain.Aggregates.WriteSite

  @type entry :: %{
          keys: MapSet.t(),
          sites: [WriteSite.t()],
          complete?: boolean(),
          gaps: list()
        }

  @doc """
  `nontx` of every function of `functions` (the resolved facts), keyed
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
         complete?: gaps == [],
         gaps: gaps
       }}
    end)
  end

  @doc "The functions always called inside a transaction; see the moduledoc."
  @spec always_in_transaction(map(), MapSet.t(mfa()) | nil, MapSet.t(mfa())) :: MapSet.t(mfa())
  def always_in_transaction(functions, roots, run_callbacks \\ MapSet.new()) do
    sites =
      for {from, function} <- functions,
          %{to: to, tags: tags} = call <- function.calls,
          Map.has_key?(functions, to),
          do:
            {to, from,
             run_capture?(call, run_callbacks) or
               Enum.any?(tags, &(is_integer(&1) or &1 == :run_callback))}

    by_callee =
      sites
      |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
      |> with_run_callbacks(run_callbacks, functions)

    candidates =
      for {mfa, function} <- functions,
          Map.has_key?(by_callee, mfa),
          not root?(mfa, function, roots, by_callee),
          into: MapSet.new(),
          do: mfa

    candidates |> fixpoint(by_callee) |> reached_inside(by_callee)
  end

  # A `Multi.run/5` callback has no call edge: Ecto calls it, in the transaction.
  defp with_run_callbacks(by_callee, run_callbacks, functions) do
    for mfa <- run_callbacks, Map.has_key?(functions, mfa), reduce: by_callee do
      acc -> Map.update(acc, mfa, [{nil, true}], &[{nil, true} | &1])
    end
  end

  # The fixpoint is the greatest one, so a cycle no transaction reaches stays in
  # it: keep what an inside call site reaches, through the set's own calls.
  defp reached_inside(set, by_callee) do
    set
    |> Enum.filter(fn mfa ->
      by_callee |> Map.fetch!(mfa) |> Enum.any?(fn {_caller, inside?} -> inside? end)
    end)
    |> grow(set, by_callee, MapSet.new())
  end

  defp grow([], _set, _by_callee, reached), do: reached

  defp grow(frontier, set, by_callee, reached) do
    reached = Enum.into(frontier, reached)

    next =
      for mfa <- set,
          not MapSet.member?(reached, mfa),
          Enum.any?(Map.fetch!(by_callee, mfa), fn {caller, _inside?} ->
            MapSet.member?(reached, caller)
          end),
          do: mfa

    grow(next, set, by_callee, reached)
  end

  defp fixpoint(set, by_callee) do
    kept =
      for mfa <- set,
          Enum.all?(Map.fetch!(by_callee, mfa), fn {caller, inside?} ->
            inside? or MapSet.member?(set, caller)
          end),
          into: MapSet.new(),
          do: mfa

    if MapSet.equal?(kept, set), do: set, else: fixpoint(kept, by_callee)
  end

  defp root?(mfa, _function, %MapSet{} = roots, _by_callee), do: MapSet.member?(roots, mfa)

  defp root?(mfa, function, nil, by_callee),
    do: function.public? and not Map.has_key?(by_callee, mfa)

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
