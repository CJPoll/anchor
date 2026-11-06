defmodule Anchor.Domain.Aggregates.Analysis do
  @moduledoc """
  The write analysis of one graph run (DND-5459) — a **Domain** module
  (ADR 001). Pure: it reads beams' Core from the graph only, and never loads
  or calls a project module (no `__schema__/1` call, no repo call).

  `build/2` runs, in order: `Anchor.Domain.Aggregates.WriteSites` (the repos,
  then the writes, transactions and calls it reads), `Anchor.Domain.Aggregates.WriteSource`
  (what each write read writes), `Anchor.Domain.Aggregates.Scopes` (each
  transaction's write set over its call closure) and
  `Anchor.Domain.Aggregates.NonTransactional`. `Anchor.Domain.Aggregates.Inference`
  reads the result.

    * `sites` — the writes read, in function then Core order;
    * `scopes` — the transaction scopes read;
    * `nontx` — per function, the writes read with no transaction read around
      them;
    * `tables` — each schema's derived table (`%{table => [schema]}`), for
      write keys;
    * `repos` — the repo modules; `no_repo?` is `true` when there is none:
      then nothing else is computed, and the `aggregate_write_sources` rule
      reports it;
    * `counts` — `%{writes: W, resolved: R, unresolved: U, scopes: S,
      no_gap_noticed: N, incomplete: I, outside_gaps: G, cleared: D,
      unread_by_callee: %{what => count}}`, the run summary's numbers (`G`: the
      gaps with no transaction read around them; `D`: the dependency calls the
      no-write list cleared). `unread_by_callee` goes to the JSON, so a run shows
      what the list would have to hold;
    * `unattributed` — raw SQL, or a write on a computed module, with no
      transaction read around it in its function: the rule reports it.

  A call `Anchor.Domain.Aggregates.WriteSites` does not read is a gap of what
  reaches it. What is not read by construction: a module on the no-write list
  (`Anchor.Domain.Aggregates.NoWrite`, `aggregates.no_write_modules`), and a
  dependency's own internals. An absent write there is not evidence of no write.
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
            tables: %{},
            repos: [],
            no_repo?: false,
            counts: %{
              writes: 0,
              resolved: 0,
              unresolved: 0,
              scopes: 0,
              no_gap_noticed: 0,
              incomplete: 0,
              outside_gaps: 0,
              cleared: 0,
              unread_by_callee: %{}
            },
            unattributed: []

  @type counts :: %{
          writes: non_neg_integer(),
          resolved: non_neg_integer(),
          unresolved: non_neg_integer(),
          scopes: non_neg_integer(),
          no_gap_noticed: non_neg_integer(),
          incomplete: non_neg_integer(),
          outside_gaps: non_neg_integer(),
          cleared: non_neg_integer(),
          unread_by_callee: %{String.t() => pos_integer()}
        }

  @type t :: %__MODULE__{
          sites: [WriteSite.t()],
          scopes: [Scope.t()],
          nontx: %{mfa() => NonTransactional.entry()},
          tables: %{String.t() => [module()]},
          repos: [module()],
          no_repo?: boolean(),
          counts: counts(),
          unattributed: [%{mfa: mfa(), line: pos_integer(), what: String.t()}]
        }

  @doc """
  The analysis of `graph` under the `aggregates:` section `config`.
  """
  @spec build(Graph.t(), Config.t()) :: t()
  def build(%Graph{} = graph, %Config{} = config) do
    repos = WriteSites.repos(graph, config)

    if MapSet.size(repos) == 0 do
      %__MODULE__{no_repo?: true}
    else
      analyse(graph, config, repos)
    end
  end

  defp analyse(graph, config, repos) do
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

    nontx = NonTransactional.build(functions, tables, facts.run_callbacks)

    %__MODULE__{
      sites: sites,
      scopes: scopes,
      unattributed: unattributed(functions, facts.run_callbacks),
      nontx: nontx,
      tables: tables,
      repos: repos |> MapSet.to_list() |> Enum.sort(),
      counts: counts(sites, scopes, nontx, functions)
    }
  end

  # Raw SQL, or a write on a computed module, with no transaction read around it
  # in its own function. A caller's transaction may hold it: this says what was read.
  # A captured Multi.run callback runs in the Multi's transaction, as its own nontx
  # entry says.
  defp unattributed(functions, run_callbacks) do
    rows =
      for {mfa, function} <- functions,
          not MapSet.member?(run_callbacks, mfa),
          %{write?: true, tags: [], line: line, what: what} <- function.dynamic,
          do: %{mfa: mfa, line: line, what: what}

    rows |> Enum.uniq_by(&{&1.mfa, &1.what}) |> Enum.sort_by(&{&1.mfa, &1.line})
  end

  defp counts(sites, scopes, nontx, functions) do
    unresolved = Enum.count(sites, &(not WriteSite.resolved?(&1)))
    incomplete = Enum.count(scopes, &(not &1.no_gap_noticed?))

    %{
      writes: length(sites),
      resolved: length(sites) - unresolved,
      unresolved: unresolved,
      scopes: length(scopes),
      no_gap_noticed: length(scopes) - incomplete,
      incomplete: incomplete,
      outside_gaps:
        nontx
        |> Enum.flat_map(fn {_mfa, entry} -> entry.gaps end)
        |> Enum.uniq()
        |> length(),
      cleared: functions |> Map.values() |> Enum.map(& &1.cleared) |> Enum.sum(),
      unread_by_callee:
        Enum.frequencies(
          for {_mfa, function} <- functions,
              %{unread: true, what: what} <- function.dynamic,
              do: what
        )
    }
  end
end
