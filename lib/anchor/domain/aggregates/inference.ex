defmodule Anchor.Domain.Aggregates.Inference do
  @moduledoc """
  Aggregates inferred from co-writes (DND-5459) — a **Domain** module
  (ADR 001). Pure.

  Every key written anywhere (in a scope, or outside every transaction) is a
  vertex. Each scope's resolved keys are one hyperedge, joined as a star from
  its smallest key; an incomplete scope's resolved keys count too, since they
  are certainly written together (its unresolved writes add nothing). The
  connected components (`Anchor.Domain.GraphAlgorithms.components/1`) are the
  inferred aggregates.

  `proposed_declarations/1` names each: its root is the key in the most
  complete scopes (ties: alphabetical), and its name the root schema's module
  name, or a table root camelized (`"audit_log"` is `AuditLog`). Two
  components whose names collide get the second's name suffixed `2`, `3`, ....
  `render_yaml/1` prints an analysis's proposals in the exact `aggregates:`
  shape of `.anchor.yml`, sorted by name, which
  `Anchor.Domain.Aggregates.Config.parse/1` reads back, with a leading comment
  when some writes are unresolved. With no write at all it prints
  `declare: none` with a reason (DND-5659), and only when there is no write
  site, no transaction and no unattributed call outside one; with no repo,
  or such evidence but nothing resolved, it is an error, never `none`.
  """

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSource
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.GraphAlgorithms

  @type key :: Scope.key()
  @type proposal :: %{
          name: String.t(),
          schemas: [module()],
          tables: [String.t()],
          root: key(),
          evidence: %{scopes: [{mfa(), pos_integer()}], writes: non_neg_integer()}
        }

  @doc "The inferred aggregates: each a set of keys, sorted by smallest key."
  @spec components(Analysis.t()) :: [MapSet.t(key())]
  def components(%Analysis{} = analysis) do
    edges =
      for %Scope{keys: keys} <- analysis.scopes,
          [first | rest] <- [Enum.sort(keys)],
          other <- rest,
          do: {first, other}

    analysis
    |> vertices()
    |> Digraph.new(edges)
    |> GraphAlgorithms.components()
    |> Enum.map(&MapSet.new/1)
    |> Enum.sort_by(&Enum.min/1)
  end

  @doc "One proposed declaration per component; see the moduledoc."
  @spec proposed_declarations(Analysis.t()) :: [proposal()]
  def proposed_declarations(%Analysis{} = analysis) do
    analysis
    |> components()
    |> Enum.map(&proposal(&1, analysis))
    |> Enum.sort_by(&{&1.name, &1.root})
    |> unique_names()
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  The analysis's proposals as `.anchor.yml`'s `aggregates:` section; see the
  moduledoc. `{:error, why}` when the analysis cannot support a proposal: no
  repo, or writes found but none traced to a schema or table. "Nothing
  resolved" is never rendered as `declare: none`.
  """
  @spec render_yaml(Analysis.t()) :: {:ok, String.t()} | {:error, String.t()}
  def render_yaml(%Analysis{no_repo?: true}) do
    {:error,
     "no Ecto repo found, so there is nothing to propose. Fix: list the repo under " <>
       "aggregates.repos, or declare: none if the project persists nothing"}
  end

  def render_yaml(%Analysis{counts: counts} = analysis) do
    case {proposed_declarations(analysis), evidence(analysis)} do
      {[], []} ->
        {:ok,
         "aggregates:\n  declare: none\n" <>
           "  reason: \"anchor found no transaction and no write in this project\"\n"}

      {[], evidence} ->
        {:error,
         "#{Enum.join(evidence, ", ")}, and nothing traced to a schema or table, so there " <>
           "is nothing to propose. Fix: resolve the writes and calls " <>
           "(aggregate_write_sources lists them) and propose again"}

      {proposals, _evidence} ->
        {:ok, unresolved_note(counts) <> declarations_yaml(proposals)}
    end
  end

  # What says the project persists even when nothing resolved: a write site,
  # a transaction, or a call Anchor cannot attribute outside one (raw SQL, a
  # write on a module held in a variable make no write site, only a gap).
  # `declare: none` is rendered only when all three are absent.
  defp evidence(%Analysis{counts: counts, scopes: scopes, nontx: nontx}) do
    outside = nontx |> Map.values() |> Enum.flat_map(& &1.gaps) |> Enum.uniq() |> length()

    [
      counts.writes > 0 && "#{counts.writes} write(s) found, #{counts.unresolved} unresolved",
      scopes != [] && "#{length(scopes)} transaction(s)",
      outside > 0 && "#{outside} call(s) Anchor cannot attribute outside a transaction"
    ]
    |> Enum.filter(&is_binary/1)
  end

  defp unresolved_note(%{unresolved: 0}), do: ""

  defp unresolved_note(%{unresolved: unresolved, writes: writes}),
    do: "# #{unresolved} of #{writes} write(s) unresolved: this proposal may miss tables\n"

  defp declarations_yaml(proposals) do
    entries =
      proposals
      |> Enum.sort_by(& &1.name)
      |> Enum.map_join(fn proposal ->
        "    - name: #{proposal.name}\n" <>
          "      schemas: [#{Enum.map_join(proposal.schemas, ", ", &module_name/1)}]\n" <>
          "      tables: [#{Enum.map_join(proposal.tables, ", ", &inspect/1)}]\n" <>
          "      # owners: proposed by aggregate_owner_writes\n"
      end)

    "aggregates:\n  declare:\n" <> entries
  end

  defp vertices(analysis) do
    scoped = Enum.flat_map(analysis.scopes, &MapSet.to_list(&1.keys))
    outside = analysis.nontx |> Map.values() |> Enum.flat_map(&MapSet.to_list(&1.keys))
    Enum.uniq(scoped ++ outside)
  end

  defp proposal(component, analysis) do
    scopes = Enum.filter(analysis.scopes, &(not MapSet.disjoint?(&1.keys, component)))
    root = root(component, scopes)

    %{
      name: name(root),
      schemas: for({:schema, schema} <- component, do: schema) |> Enum.sort(),
      tables: for({:table, table} <- component, do: table) |> Enum.sort(),
      root: root,
      evidence: %{
        scopes: scopes |> Enum.map(&Scope.id/1) |> Enum.sort(),
        writes: Enum.count(analysis.sites, &written?(&1, component, analysis.tables))
      }
    }
  end

  defp root(component, scopes) do
    complete = Enum.filter(scopes, & &1.complete?)

    Enum.min_by(component, fn key ->
      {-Enum.count(complete, &MapSet.member?(&1.keys, key)), key_name(key)}
    end)
  end

  defp written?(site, component, tables),
    do: Enum.any?(site.sources, &MapSet.member?(component, WriteSource.key(&1, tables)))

  defp unique_names(proposals) do
    {named, _seen} =
      Enum.map_reduce(proposals, %{}, fn proposal, seen ->
        case Map.get(seen, proposal.name, 0) do
          0 ->
            {proposal, Map.put(seen, proposal.name, 1)}

          n ->
            {%{proposal | name: "#{proposal.name}#{n + 1}"}, Map.put(seen, proposal.name, n + 1)}
        end
      end)

    named
  end

  defp name({:schema, schema}), do: module_name(schema)
  defp name({:table, table}), do: Macro.camelize(table)

  defp key_name({:schema, schema}), do: module_name(schema)
  defp key_name({:table, table}), do: table

  defp module_name(module), do: module |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
end
