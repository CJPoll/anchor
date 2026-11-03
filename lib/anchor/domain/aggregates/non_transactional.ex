defmodule Anchor.Domain.Aggregates.NonTransactional do
  @moduledoc """
  The writes made outside every transaction (DND-5459) — a **Domain** module
  (ADR 001). Pure. DND-5477's atomicity rule reads them.

  `build/2`: for each function `f`, `nontx[f]` is `f`'s `Repo` and
  `write_functions` writes outside every transaction body in `f`, plus
  `nontx[g]` for every project function `g` that `f` calls outside a body;
  per strongly connected component, so recursion terminates
  (`Anchor.Domain.Aggregates.Scopes.summarise/3`). An `Ecto.Multi` step and a
  `Multi.run` callback's write are never non-transactional: a Multi only runs
  inside a transaction. Each entry is complete when no dynamic call and no
  unresolved write is reached.

  `always_in_transaction/2`: the functions that are not roots and whose every
  project call site is inside a transaction body, or inside a function that is
  itself always in a transaction (the greatest fixpoint, so mutual recursion
  reached only inside a transaction stays in). A root is a function given in
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

  @doc "`nontx` of every function of `functions` (the resolved facts), keyed through `tables`."
  @spec build(map(), %{String.t() => [module()]}) :: %{mfa() => entry()}
  def build(functions, tables) do
    functions
    |> Scopes.summarise(&outside?/1, &outside_site?/1)
    |> Map.new(fn {mfa, summary} ->
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
  @spec always_in_transaction(map(), MapSet.t(mfa()) | nil) :: MapSet.t(mfa())
  def always_in_transaction(functions, roots) do
    sites =
      for {from, function} <- functions,
          %{to: to, tags: tags} <- function.calls,
          Map.has_key?(functions, to),
          do: {to, from, Enum.any?(tags, &(is_integer(&1) or &1 == :run_callback))}

    by_callee = Enum.group_by(sites, &elem(&1, 0), &Tuple.delete_at(&1, 0))

    candidates =
      for {mfa, function} <- functions,
          Map.has_key?(by_callee, mfa),
          not root?(mfa, function, roots, by_callee),
          into: MapSet.new(),
          do: mfa

    fixpoint(candidates, by_callee)
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

  defp outside?(tags), do: tags == []

  defp outside_site?(%WriteSite{scopes: [], via: via}), do: via in [:repo, :write_function]
  defp outside_site?(%WriteSite{}), do: false
end
