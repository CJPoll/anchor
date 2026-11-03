defmodule Anchor.Domain.Aggregates.Index do
  @moduledoc """
  The one index of aggregate declarations a graph run builds (DND-5476) — a
  **Domain** module (ADR 001). Pure: it reads the config and the graph only,
  and never loads or calls a project module.

  Three sources feed it, and all mean the same thing:

    * the `aggregates: declare:` section of `.anchor.yml`
      (`Anchor.Domain.Aggregates.Config`);
    * a module that `use`s `Anchor.Aggregate`, which persists an
      `@anchor_aggregate` attribute;
    * any module that persists that attribute itself (the cross-tool
      contract: `[name: atom, schemas: [atom], tables: [binary], owner:
      boolean]`, `schemas`, `tables` and `owner` optional, defaults `[]`,
      `[]`, `false`). `owner: true` makes the declaring module an owner.

  `build/2`:

    1. collects the config's declarations, then every graph module's
       `@anchor_aggregate` (its site is the module, its source file and its
       `defmodule` line); a value of the wrong shape, or two values, is a
       `:malformed_attribute` issue and the module contributes nothing;
    2. merges declarations by name (schemas, tables, owners and sites are
       unioned);
    3. resolves every schema: a module the project does not have is
       `:unknown_schema`, one with no `__schema__/1` is `:not_a_schema`, and a
       schema's table is read from its `__schema__(:source)` clause in Core
       (`table_of/2`); a source that is not a literal leaves the table
       unknown, counted in `tables_unknown`, never an issue on its own;
    4. finds every schema or table (explicit, or a schema's table) two
       aggregates claim: one `:claimed_twice` issue per claiming site. A
       schema's table is not reported again when the schema's own issue says
       all of it (every claim of the table comes through schemas claimed
       twice, by the same aggregates). The
       lexically first aggregate keeps the claim in `by_schema` / `by_table`,
       so the index does not depend on input order;
    5. reports an owner naming no project module (`:unknown_owner`) and an
       aggregate with no schemas and no tables (`:empty_aggregate`).

  A module the graph could not build (`Graph.unreadable`) is reported there;
  a schema or owner naming it is not also "no module of the project".

  Aggregate names are strings throughout; `by_schema` keys are the module
  atoms the config and graph already hold.
  """

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.DeclarationIssue
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  @attribute :anchor_aggregate
  @attribute_keys [:name, :owner, :schemas, :tables]

  defstruct aggregates: %{},
            by_schema: %{},
            by_table: %{},
            owners: %{},
            tables_unknown: 0,
            issues: []

  @type t :: %__MODULE__{
          aggregates: %{String.t() => Declaration.t()},
          by_schema: %{module() => String.t()},
          by_table: %{String.t() => String.t()},
          owners: %{module() => [String.t()]},
          tables_unknown: non_neg_integer(),
          issues: [DeclarationIssue.t()]
        }

  @doc """
  Builds the index of `config` (the parsed `aggregates:` section, or `nil`
  when the document has none) over `graph`; see the moduledoc.
  """
  @spec build(Config.t() | nil, Graph.t()) :: t()
  def build(config, %Graph{} = graph) do
    {attribute_declarations, malformed} = attribute_declarations(graph)
    declarations = config_declarations(config) ++ attribute_declarations
    aggregates = merge(declarations)
    known = known_modules(graph)
    tables = schema_tables(aggregates, graph, known)
    {by_schema, schema_conflicts} = claims(schema_claims(declarations))
    twice = Map.new(schema_conflicts, &{&1.subject, &1.aggregates})
    {by_table, table_conflicts} = table_claims(declarations, tables, twice)

    issues =
      malformed ++
        schema_conflicts ++
        table_conflicts ++
        schema_issues(declarations, graph, known) ++
        owner_issues(declarations, known) ++ empty_issues(aggregates)

    %__MODULE__{
      aggregates: aggregates,
      by_schema: by_schema,
      by_table: by_table,
      owners: owners(aggregates),
      tables_unknown: tables |> Map.values() |> Enum.count(&(&1 == :unknown)),
      issues: issues |> Enum.uniq() |> Enum.sort_by(&issue_order/1)
    }
  end

  @doc """
  The aggregate a schema module or a table belongs to: `{:ok, name}`, or
  `:error` when no aggregate declares it.
  """
  @spec aggregate_of(t(), module() | String.t()) :: {:ok, String.t()} | :error
  def aggregate_of(%__MODULE__{by_table: by_table}, table) when is_binary(table),
    do: Map.fetch(by_table, table)

  def aggregate_of(%__MODULE__{by_schema: by_schema}, schema) when is_atom(schema),
    do: Map.fetch(by_schema, schema)

  @doc "The modules declared as owners of the aggregate `name`, sorted (`[]` when none)."
  @spec owners(t(), String.t()) :: [module()]
  def owners(%__MODULE__{aggregates: aggregates}, name) do
    case Map.fetch(aggregates, name) do
      {:ok, declaration} -> declaration.owners
      :error -> []
    end
  end

  @doc "How many aggregates are declared."
  @spec declared(t()) :: non_neg_integer()
  def declared(%__MODULE__{aggregates: aggregates}), do: map_size(aggregates)

  @doc """
  The table of the Ecto schema `module`, read from its `__schema__(:source)`
  clause in Core without loading it: `{:ok, table}` when that clause returns
  a literal string, `:unknown` when it returns anything else (or the
  function has no Core body), and `:not_a_schema` when the graph has no such
  module or it exports no `__schema__/1`.
  """
  @spec table_of(Graph.t(), module()) :: {:ok, String.t()} | :unknown | :not_a_schema
  def table_of(%Graph{} = graph, module) do
    case Graph.function(graph, {module, :__schema__, 1}) do
      %FunctionNode{kind: :def, core: nil} -> :unknown
      %FunctionNode{kind: :def, core: core} -> source(core)
      _none -> :not_a_schema
    end
  end

  # --- collecting ---------------------------------------------------------

  defp config_declarations(nil), do: []
  defp config_declarations(%Config{declare: declare}), do: declare

  defp attribute_declarations(%Graph{modules: modules}) do
    modules
    |> Map.values()
    |> Enum.sort_by(& &1.module)
    |> Enum.reduce({[], []}, fn node, {declarations, issues} ->
      case attribute(node) do
        :none -> {declarations, issues}
        {:ok, declaration} -> {[declaration | declarations], issues}
        {:error, issue} -> {declarations, [issue | issues]}
      end
    end)
    |> then(fn {declarations, issues} -> {Enum.reverse(declarations), Enum.reverse(issues)} end)
  end

  defp attribute(%ModuleNode{} = node) do
    site = {:attribute, node.module, node.source_file, node.line}

    case Keyword.get_values(node.attributes, @attribute) do
      [] ->
        :none

      [value] ->
        declaration(node.module, value, site)

      _many ->
        malformed(node.module, site, "it is set more than once; a module declares one aggregate")
    end
  end

  defp declaration(module, value, site) do
    with :ok <- keyword(value),
         :ok <- attribute_keys(value),
         {:ok, name} <- attribute_name(value),
         {:ok, schemas} <- attribute_schemas(value),
         {:ok, tables} <- attribute_tables(value),
         {:ok, owner?} <- attribute_owner(value) do
      {:ok,
       %Declaration{
         name: name,
         schemas: schemas,
         tables: tables,
         owners: if(owner?, do: [module], else: []),
         sites: [site]
       }}
    else
      {:error, detail} -> malformed(module, site, detail)
    end
  end

  defp malformed(module, site, detail) do
    {:error,
     %DeclarationIssue{kind: :malformed_attribute, subject: module, site: site, detail: detail}}
  end

  defp keyword(value) do
    if is_list(value) and Keyword.keyword?(value),
      do: :ok,
      else: {:error, "it is not a keyword list, got: #{inspect(value, limit: 5)}"}
  end

  defp attribute_keys(value) do
    keys = Keyword.keys(value)

    cond do
      (unknown = keys |> Enum.reject(&(&1 in @attribute_keys)) |> Enum.uniq()) != [] ->
        {:error, "unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}"}

      length(keys) != length(Enum.uniq(keys)) ->
        {:error, "a key is given twice"}

      true ->
        :ok
    end
  end

  defp attribute_name(value) do
    case Keyword.fetch(value, :name) do
      {:ok, name} when is_atom(name) -> alias_name(name)
      {:ok, name} -> {:error, "name must be a module-name atom, got: #{inspect(name)}"}
      :error -> {:error, "it has no name"}
    end
  end

  defp alias_name(atom) do
    case alias_string(atom) do
      {:ok, name} -> {:ok, name}
      :error -> {:error, "name must be a module-name atom, got: #{inspect(atom)}"}
    end
  end

  defp attribute_schemas(value) do
    schemas = Keyword.get(value, :schemas, [])

    if is_list(schemas) and Enum.all?(schemas, &(alias_string(&1) != :error)),
      do: {:ok, schemas},
      else: {:error, "schemas must be a list of module atoms, got: #{inspect(schemas)}"}
  end

  defp attribute_tables(value) do
    tables = Keyword.get(value, :tables, [])

    if is_list(tables) and Enum.all?(tables, &(is_binary(&1) and &1 != "")),
      do: {:ok, tables},
      else: {:error, "tables must be a list of non-empty strings, got: #{inspect(tables)}"}
  end

  defp attribute_owner(value) do
    case Keyword.get(value, :owner, false) do
      owner when is_boolean(owner) -> {:ok, owner}
      other -> {:error, "owner must be true or false, got: #{inspect(other)}"}
    end
  end

  # An Elixir alias atom (`MyApp.Space`) as its name without `Elixir.`.
  defp alias_string(atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> name -> if FunctionRef.alias_name?(name), do: {:ok, name}, else: :error
      _erlang -> :error
    end
  end

  defp alias_string(_other), do: :error

  # --- merging ------------------------------------------------------------

  defp merge(declarations) do
    declarations
    |> Enum.group_by(& &1.name)
    |> Map.new(fn {name, group} ->
      {name,
       %Declaration{
         name: name,
         schemas: group |> Enum.flat_map(& &1.schemas) |> Enum.uniq() |> Enum.sort(),
         tables: group |> Enum.flat_map(& &1.tables) |> Enum.uniq() |> Enum.sort(),
         owners: group |> Enum.flat_map(& &1.owners) |> Enum.uniq() |> Enum.sort(),
         sites: group |> Enum.flat_map(& &1.sites) |> Enum.uniq() |> Enum.sort_by(&site_order/1)
       }}
    end)
  end

  defp owners(aggregates) do
    aggregates
    |> Map.values()
    |> Enum.flat_map(fn declaration -> Enum.map(declaration.owners, &{&1, declaration.name}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {owner, names} -> {owner, names |> Enum.uniq() |> Enum.sort()} end)
  end

  # --- resolving ----------------------------------------------------------

  # The modules a schema or owner may name: the graph's, and those the graph
  # could not build (reported as unreadable already).
  defp known_modules(%Graph{modules: modules, unreadable: unreadable}) do
    modules
    |> Map.keys()
    |> Enum.concat(for %{module: module} <- unreadable, is_atom(module), do: module)
    |> MapSet.new()
  end

  # `%{schema => {:ok, table} | :unknown}` for every declared schema the graph
  # has and that is a schema.
  defp schema_tables(aggregates, graph, known) do
    for {_name, declaration} <- aggregates,
        schema <- declaration.schemas,
        MapSet.member?(known, schema),
        (table = table_of(graph, schema)) != :not_a_schema,
        into: %{},
        do: {schema, table}
  end

  defp schema_issues(declarations, graph, known) do
    for declaration <- declarations,
        schema <- declaration.schemas,
        site <- declaration.sites,
        kind = schema_kind(graph, known, schema),
        kind != nil do
      %DeclarationIssue{kind: kind, subject: schema, aggregates: [declaration.name], site: site}
    end
  end

  defp schema_kind(graph, known, schema) do
    cond do
      not MapSet.member?(known, schema) -> :unknown_schema
      not Map.has_key?(graph.modules, schema) -> nil
      table_of(graph, schema) == :not_a_schema -> :not_a_schema
      true -> nil
    end
  end

  defp owner_issues(declarations, known) do
    for declaration <- declarations,
        owner <- declaration.owners,
        not MapSet.member?(known, owner),
        site <- declaration.sites do
      %DeclarationIssue{
        kind: :unknown_owner,
        subject: owner,
        aggregates: [declaration.name],
        site: site
      }
    end
  end

  defp empty_issues(aggregates) do
    for {name, %Declaration{schemas: [], tables: []} = declaration} <- aggregates,
        site <- declaration.sites do
      %DeclarationIssue{kind: :empty_aggregate, subject: name, aggregates: [name], site: site}
    end
  end

  # --- claims -------------------------------------------------------------

  # One claim per (subject, aggregate, site).
  defp schema_claims(declarations) do
    for declaration <- declarations,
        schema <- declaration.schemas,
        site <- declaration.sites,
        do: {schema, declaration.name, site}
  end

  # Explicit tables, and each schema's derived table. A table conflict is
  # left to the schema's own issue only when every claim of the table comes
  # through schemas claimed twice and names no aggregate those schemas' claims
  # do not: then it says nothing the schema issue does not. Any other claimant
  # (an explicit table, another schema) keeps the table conflict, at every
  # site.
  defp table_claims(declarations, tables, twice) do
    explicit =
      for declaration <- declarations,
          table <- declaration.tables,
          site <- declaration.sites,
          do: {table, declaration.name, site, nil}

    derived =
      for declaration <- declarations,
          schema <- declaration.schemas,
          {:ok, table} <- [Map.get(tables, schema)],
          site <- declaration.sites,
          do: {table, declaration.name, site, schema}

    all = explicit ++ derived

    {by_table, conflicts} =
      claims(Enum.map(all, fn {table, name, site, _via} -> {table, name, site} end))

    covered = covered_tables(all, twice)
    {by_table, Enum.reject(conflicts, &MapSet.member?(covered, &1.subject))}
  end

  defp covered_tables(claims, twice) do
    for {table, group} <- Enum.group_by(claims, &elem(&1, 0)),
        vias = Enum.map(group, &elem(&1, 3)),
        Enum.all?(vias, &Map.has_key?(twice, &1)),
        MapSet.new(group, &elem(&1, 1)) ==
          MapSet.new(Enum.flat_map(vias, &Map.fetch!(twice, &1))),
        into: MapSet.new(),
        do: table
  end

  defp claims(claims) do
    grouped = Enum.group_by(claims, &elem(&1, 0))

    by_subject =
      Map.new(grouped, fn {subject, group} ->
        {subject, group |> Enum.map(&elem(&1, 1)) |> Enum.min()}
      end)

    conflicts =
      for {subject, group} <- grouped,
          names = group |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort(),
          match?([_, _ | _], names),
          {^subject, _name, site} <- Enum.uniq(group) do
        %DeclarationIssue{kind: :claimed_twice, subject: subject, aggregates: names, site: site}
      end

    {by_subject, conflicts}
  end

  # --- Core ---------------------------------------------------------------

  # The `:source` clause of `__schema__/1`: clauses are read in order; one on
  # another literal atom is passed over, and the first that could match
  # `:source` decides. Only a literal string body gives the table.
  defp source(core) do
    body = :cerl.fun_body(core)

    if :cerl.type(body) == :case,
      do: body |> :cerl.case_clauses() |> source_clause(),
      else: :unknown
  end

  defp source_clause([]), do: :unknown

  defp source_clause([clause | rest]) do
    case :cerl.clause_pats(clause) do
      [pattern] ->
        cond do
          not :cerl.is_literal(pattern) -> :unknown
          :cerl.concrete(pattern) != :source -> source_clause(rest)
          true_guard?(clause) -> literal_string(:cerl.clause_body(clause))
          true -> :unknown
        end

      _other ->
        :unknown
    end
  end

  defp true_guard?(clause) do
    guard = :cerl.clause_guard(clause)
    :cerl.is_literal(guard) and :cerl.concrete(guard) == true
  end

  defp literal_string(node) do
    with {:ok, bytes} <- literal_binary(node),
         true <- bytes != "" and String.valid?(bytes) do
      {:ok, bytes}
    else
      _other -> :unknown
    end
  end

  defp literal_binary(node) do
    cond do
      :cerl.is_literal(node) and is_binary(:cerl.concrete(node)) -> {:ok, :cerl.concrete(node)}
      :cerl.type(node) == :binary -> segments(:cerl.binary_segments(node), <<>>)
      true -> :error
    end
  end

  # A binary built of literal 8-bit unsigned integer segments, the shape
  # Elixir's string literals take in Core.
  defp segments([], acc), do: {:ok, acc}

  defp segments([segment | rest], acc) do
    if byte_segment?(segment),
      do: segments(rest, <<acc::binary, :cerl.concrete(:cerl.bitstr_val(segment))>>),
      else: :error
  end

  defp byte_segment?(segment) do
    value = :cerl.bitstr_val(segment)

    :cerl.is_literal(value) and is_integer(:cerl.concrete(value)) and
      literal?(:cerl.bitstr_size(segment), 8) and literal?(:cerl.bitstr_unit(segment), 1) and
      literal?(:cerl.bitstr_type(segment), :integer)
  end

  defp literal?(node, value), do: :cerl.is_literal(node) and :cerl.concrete(node) == value

  # --- ordering -----------------------------------------------------------

  defp issue_order(%DeclarationIssue{} = issue),
    do: {site_order(issue.site), issue.kind, issue.aggregates, inspect(issue.subject)}

  defp site_order(:config), do: {0, ""}
  defp site_order({:attribute, module, _file, _line}), do: {1, Atom.to_string(module)}
end
