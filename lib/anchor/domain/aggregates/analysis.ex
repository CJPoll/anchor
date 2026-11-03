defmodule Anchor.Domain.Aggregates.Analysis do
  @moduledoc """
  The write analysis of one graph run (DND-5459) — a **Domain** module
  (ADR 001). Pure: it reads beams' Core from the graph only, and never loads
  or calls a project module (no `__schema__/1` call, no repo call).

  `build/3` runs, in order: `Anchor.Domain.Aggregates.WriteSites` (the repos,
  then every write, transaction and call), `Anchor.Domain.Aggregates.WriteSource`
  (what each write writes), `Anchor.Domain.Aggregates.Scopes` (each
  transaction's write set over its call closure) and
  `Anchor.Domain.Aggregates.NonTransactional`. `Anchor.Domain.Aggregates.Inference`
  reads the result.

    * `sites` — every write, in function then Core order;
    * `scopes` — every transaction scope;
    * `nontx` — per function, the writes made outside every transaction;
    * `always_in_transaction` — the functions only ever called inside one;
    * `tables` — every schema's derived table (`%{table => [schema]}`), for
      write keys;
    * `repos` — the repo modules; `no_repo?` is `true` when there is none:
      then nothing else is computed, and the `aggregate_write_sources` rule
      reports it;
    * `counts` — `%{writes: W, resolved: R, unresolved: U, scopes: S,
      complete: C, incomplete: I}`, the run summary's numbers.
  """

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.NonTransactional
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.Scopes
  alias Anchor.Domain.Aggregates.WriteSite
  alias Anchor.Domain.Aggregates.WriteSites
  alias Anchor.Domain.Aggregates.WriteSource
  alias Anchor.Domain.Graph

  defstruct sites: [],
            scopes: [],
            nontx: %{},
            always_in_transaction: MapSet.new(),
            tables: %{},
            repos: [],
            no_repo?: false,
            counts: %{
              writes: 0,
              resolved: 0,
              unresolved: 0,
              scopes: 0,
              complete: 0,
              incomplete: 0
            }

  @type counts :: %{
          writes: non_neg_integer(),
          resolved: non_neg_integer(),
          unresolved: non_neg_integer(),
          scopes: non_neg_integer(),
          complete: non_neg_integer(),
          incomplete: non_neg_integer()
        }

  @type t :: %__MODULE__{
          sites: [WriteSite.t()],
          scopes: [Scope.t()],
          nontx: %{mfa() => NonTransactional.entry()},
          always_in_transaction: MapSet.t(mfa()),
          tables: %{String.t() => [module()]},
          repos: [module()],
          no_repo?: boolean(),
          counts: counts()
        }

  @doc """
  The analysis of `graph` under the `aggregates:` section `config`. Option
  `:roots`: the functions that are entry points (a set of mfas), or `nil`
  (every public function with no project caller), for
  `NonTransactional.always_in_transaction/2`.
  """
  @spec build(Graph.t(), Config.t(), keyword()) :: t()
  def build(%Graph{} = graph, %Config{} = config, opts \\ []) do
    repos = WriteSites.repos(graph, config)

    if MapSet.size(repos) == 0 do
      %__MODULE__{no_repo?: true}
    else
      analyse(graph, config, repos, Keyword.get(opts, :roots))
    end
  end

  defp analyse(graph, config, repos, roots) do
    facts = WriteSites.facts(graph, config, repos)
    ctx = WriteSource.context(graph, facts)

    functions =
      Map.new(facts.functions, fn {mfa, function} ->
        {mfa, %{function | sites: Enum.map(function.sites, &WriteSites.site(&1, mfa, ctx))}}
      end)

    tables = WriteSource.tables(graph)
    scopes = Scopes.build(functions, Scopes.closures(functions), tables)

    sites =
      functions
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.flat_map(fn {_mfa, function} -> function.sites end)

    %__MODULE__{
      sites: sites,
      scopes: scopes,
      nontx: NonTransactional.build(functions, tables, facts.run_callbacks),
      always_in_transaction:
        NonTransactional.always_in_transaction(functions, roots, facts.run_callbacks),
      tables: tables,
      repos: repos |> MapSet.to_list() |> Enum.sort(),
      counts: counts(sites, scopes)
    }
  end

  defp counts(sites, scopes) do
    unresolved = Enum.count(sites, &(not WriteSite.resolved?(&1)))
    incomplete = Enum.count(scopes, &(not &1.complete?))

    %{
      writes: length(sites),
      resolved: length(sites) - unresolved,
      unresolved: unresolved,
      scopes: length(scopes),
      complete: length(scopes) - incomplete,
      incomplete: incomplete
    }
  end
end
