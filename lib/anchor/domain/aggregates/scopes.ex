defmodule Anchor.Domain.Aggregates.Scopes do
  @moduledoc """
  Transaction scopes and their write sets (DND-5459) — a **Domain** module
  (ADR 001). Pure.

  `closures/1` summarises each function of the project once: the writes read in
  it and those of each project function it calls (remote, local or
  captured), transitively, with the gaps on the way (a dynamic call, an
  unresolved write). It is computed per strongly connected component of the
  call graph (`Anchor.Domain.GraphAlgorithms.sccs/1`, callees first), so
  recursion terminates and each component is summarised once. Calls into
  modules outside the project are not followed: a dependency is assumed not
  to write the project's tables through the project's repo (a library that
  does is listed under `aggregates.write_functions`).

  `build/3` makes one `Anchor.Domain.Aggregates.Scope` per transaction found
  by `Anchor.Domain.Aggregates.WriteSites`: the writes tagged with its
  ordinal in its own function, plus the closure of each call and capture in
  its body. A nested scope keeps its own set, and the outer one holds it too.
  A scope with no gap has `no_gap_noticed?`; one with a gap is incomplete.
  """

  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSite
  alias Anchor.Domain.Aggregates.WriteSource
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.GraphAlgorithms

  @type summary :: %{sites: MapSet.t(WriteSite.t()), gaps: MapSet.t(Scope.gap())}

  @typedoc """
  Which calls, writes and dynamic calls a summary keeps: all it read, those
  outside the transaction bodies read, or those inside body `ordinal` of a function.
  """
  @type selection :: :all | :outside | {:body, non_neg_integer()}

  @doc """
  The closure summary of every function of `functions` (the resolved facts:
  `%{mfa => %{sites, calls, dynamic, ...}}`), over every call; see the
  moduledoc.
  """
  @spec closures(map()) :: %{mfa() => summary()}
  def closures(functions), do: summarise(functions, :all)

  @doc """
  The same summary over the calls `selection` keeps (by their tags), with only
  the writes and dynamic calls it keeps: `Anchor.Domain.Aggregates.NonTransactional`
  asks for `:outside`. A `Repo` or `write_functions` write is outside when no
  transaction body holds it and it is no `Multi.run` callback's.
  """
  @spec summarise(map(), :all | :outside) :: %{mfa() => summary()}
  def summarise(functions, selection) do
    edges =
      for {from, function} <- functions,
          %{to: to, tags: tags} <- function.calls,
          keep_tags?(selection, tags),
          Map.has_key?(functions, to),
          uniq: true,
          do: {from, to}

    graph = Digraph.new(Map.keys(functions), edges)
    out = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    graph
    |> GraphAlgorithms.sccs()
    |> Enum.reduce(%{}, fn scc, done ->
      members = MapSet.new(scc)

      local =
        Enum.reduce(scc, empty(), fn mfa, acc ->
          merge(acc, local(mfa, functions[mfa], selection))
        end)

      summary =
        scc
        |> Enum.flat_map(&Map.get(out, &1, []))
        |> Enum.reject(&MapSet.member?(members, &1))
        |> Enum.uniq()
        |> Enum.reduce(local, &merge(&2, Map.fetch!(done, &1)))

      Enum.reduce(scc, done, &Map.put(&2, &1, summary))
    end)
  end

  @doc "The scopes of `functions`, given their `closures/1`, keyed through `tables` (`WriteSource.tables/1`)."
  @spec build(map(), %{mfa() => summary()}, %{String.t() => [module()]}) :: [Scope.t()]
  def build(functions, closures, tables) do
    functions
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.flat_map(fn {mfa, function} ->
      Enum.map(function.txs, &scope(mfa, function, &1, closures, tables))
    end)
  end

  @doc "The write keys of the resolved writes among `sites`, through `tables`."
  @spec keys(Enumerable.t(), %{String.t() => [module()]}) :: MapSet.t(Scope.key())
  def keys(sites, tables) do
    for %WriteSite{unresolved: nil, sources: sources} <- sites,
        source <- sources,
        into: MapSet.new(),
        do: WriteSource.key(source, tables)
  end

  @doc "Sorts writes into a stable order."
  @spec sort_sites(Enumerable.t()) :: [WriteSite.t()]
  def sort_sites(sites), do: Enum.sort_by(sites, &{&1.mfa, &1.line, &1.op, &1.via, &1.sources})

  @doc "Sorts gaps into a stable order."
  @spec sort_gaps(Enumerable.t()) :: [Scope.gap()]
  def sort_gaps(gaps), do: Enum.sort_by(gaps, &gap_order/1)

  defp scope(mfa, function, tx, closures, tables) do
    selection = {:body, tx.ordinal}
    body = local(mfa, function, selection)

    callees =
      (for(%{to: to, tags: tags} <- function.calls, keep_tags?(selection, tags), do: to) ++
         tx.captures)
      |> Enum.uniq()

    tx_gaps = for _gap <- tx.gaps, into: MapSet.new(), do: {:dynamic_call, mfa, tx.line}

    summary =
      callees
      |> Enum.reduce(body, fn callee, acc -> merge(acc, Map.get(closures, callee, empty())) end)
      |> Map.update!(:gaps, &MapSet.union(&1, tx_gaps))

    gaps = sort_gaps(summary.gaps)

    %Scope{
      mfa: mfa,
      ordinal: tx.ordinal,
      line: tx.line,
      kind: tx.kind,
      writes: sort_sites(summary.sites),
      keys: keys(summary.sites, tables),
      no_gap_noticed?: gaps == [],
      gaps: gaps
    }
  end

  # A function's own writes and dynamic calls that `selection` keeps; an
  # unresolved write is also a gap.
  defp local(mfa, function, selection) do
    sites = for site <- function.sites, keep_site?(selection, site), into: MapSet.new(), do: site

    dynamic =
      for %{tags: tags, line: line} <- function.dynamic,
          keep_tags?(selection, tags),
          into: MapSet.new(),
          do: {:dynamic_call, mfa, line}

    unresolved =
      for %WriteSite{unresolved: seen} = site <- sites,
          seen != nil,
          into: MapSet.new(),
          do: {:unresolved_write, site}

    %{sites: sites, gaps: MapSet.union(dynamic, unresolved)}
  end

  defp keep_tags?(:all, _tags), do: true
  defp keep_tags?(:outside, tags), do: tags == []
  defp keep_tags?({:body, ordinal}, tags), do: ordinal in tags

  defp keep_site?(:all, %WriteSite{}), do: true

  defp keep_site?(:outside, %WriteSite{scopes: [], run_callback?: false, via: via}),
    do: via in [:repo, :write_function]

  defp keep_site?(:outside, %WriteSite{}), do: false
  defp keep_site?({:body, ordinal}, %WriteSite{scopes: scopes}), do: ordinal in scopes

  defp empty, do: %{sites: MapSet.new(), gaps: MapSet.new()}

  defp merge(a, b),
    do: %{sites: MapSet.union(a.sites, b.sites), gaps: MapSet.union(a.gaps, b.gaps)}

  defp gap_order({:dynamic_call, mfa, line}), do: {0, mfa, line || 0, nil}

  defp gap_order({:unresolved_write, %WriteSite{} = site}),
    do: {1, site.mfa, site.line || 0, {site.op, site.unresolved}}
end
