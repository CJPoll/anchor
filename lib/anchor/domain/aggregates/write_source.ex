defmodule Anchor.Domain.Aggregates.WriteSource do
  @moduledoc """
  What a write writes: the schema or table its source argument traces to in
  Core (DND-5459) — a **Domain** module (ADR 001). Pure: no project module is
  loaded or called; a schema is a graph module that defines `__schema__/1`,
  and its table is read from Core (`Anchor.Domain.Aggregates.Index.table_of/2`).

  `resolve/3` traces a value by these rules; the first that matches wins, and
  each applies again to what it traces to:

    1. a struct literal `%S{}` with `S` a schema: `{:schema, S}`. An
       `%Ecto.Query{}` traces its `from`, an `%Ecto.Query.FromExpr{}` its
       `source`, an `%Ecto.Changeset{}` its `data` (how `from/2` and a built
       changeset look in Core);
    2. a literal schema module: `{:schema, S}`; a literal string `T`:
       `{:table, T}`; a tuple `{T, S}`: what `T` traces to (in a `from/2`
       query on a schema, `T` is `S.__schema__(:source)`, so rule 4 makes it
       `{:schema, S}`);
    3. a variable bound by a `let`: its value. A variable bound by a `case`:
       the union of every clause's result; a clause that raises gives no value,
       and an unresolvable clause makes the whole value unresolved;
    4. a call `S.f(...)` on a schema module: `{:schema, S}`;
    5. a call into `Ecto.Changeset`: its first argument;
    6. a call into `Ecto.Query`, `Ecto.Query.Builder.*` or `Ecto.Queryable`:
       the first argument that traces to a schema or table, a string
       argument (a prefix) never counting as a table;
    7. a parameter of the function: (a) its `@spec` type `S.t()` with `S` a
       schema; else (b) the union, over every project call site of the
       function, of the argument there. A function used as a value (a
       capture) has callers Anchor cannot see; one with no spec and no caller
       is unresolved. A parameter that leads back to itself, or more than
       8 hops away, is `"parameter cycle"`;
    8. a call into another project function: the union of what its body
       returns (a function that returns itself adds nothing);
    9. anything else: unresolved, naming the Core node kind.

  An unresolved value names what was seen and never a line, so a baseline
  key built from it does not move.

  `key/2` turns a source into the key scopes and inference compare: a table
  that exactly one schema's derived table is becomes that schema.
  """

  alias Anchor.Domain.Aggregates.FunctionWalk
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.ViolationKey

  @max_hops 8

  @raising [{:erlang, :error}, {:erlang, :raise}, {:erlang, :throw}, {:erlang, :exit}]

  @type source :: {:schema, module()} | {:table, String.t()}
  @type result :: {:ok, [source()]} | {:unresolved, String.t()}

  @type context :: %{
          graph: Graph.t(),
          schemas: MapSet.t(module()),
          callers: %{mfa() => [{mfa(), [:cerl.cerl()], FunctionWalk.env()}]},
          captured: MapSet.t(mfa()),
          mfa: mfa() | nil,
          stack: [term()],
          hops: non_neg_integer()
        }

  @doc """
  The context `resolve/3` reads: the graph's schemas, and the call sites and
  captures of `facts` (`Anchor.Domain.Aggregates.WriteSites.facts/3`).
  """
  @spec context(Graph.t(), map()) :: context()
  def context(%Graph{} = graph, facts) do
    %{
      graph: graph,
      schemas: schemas(graph),
      callers: Map.get(facts, :callers, %{}),
      captured: Map.get(facts, :captured, MapSet.new()),
      mfa: nil,
      stack: [],
      hops: 0
    }
  end

  @doc "The graph modules that define `__schema__/1`: the schemas."
  @spec schemas(Graph.t()) :: MapSet.t(module())
  def schemas(%Graph{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        match?(%FunctionNode{kind: :def}, Map.get(functions, {:__schema__, 1})),
        into: MapSet.new(),
        do: module
  end

  @doc """
  The sources of `node` (the write's source argument, `nil` when the call has
  none) under `env`, in the function `ctx.mfa`: `{:ok, sources}` sorted, or
  `{:unresolved, seen}`.
  """
  @spec resolve(:cerl.cerl() | nil, FunctionWalk.env(), context()) :: result()
  def resolve(nil, _env, _ctx), do: {:unresolved, "a write with no source argument"}

  def resolve(node, env, ctx) do
    case trace(node, env, ctx) do
      {:ok, sources} -> {:ok, sources |> MapSet.to_list() |> Enum.sort()}
      :none -> {:unresolved, "a value that is never returned (every branch raises)"}
      {:unresolved, _seen} = unresolved -> unresolved
    end
  end

  @doc """
  The write key of `source`: `{:table, t}` becomes `{:schema, s}` when `s` is
  the only schema whose derived table is `t` (`tables`: `%{table => [schema]}`,
  `tables/1`).
  """
  @spec key(source(), %{String.t() => [module()]}) :: source()
  def key({:table, table} = source, tables) do
    case Map.get(tables, table) do
      [schema] -> {:schema, schema}
      _none_or_many -> source
    end
  end

  def key(source, _tables), do: source

  @doc "Every schema's derived table, as `%{table => [schema]}` (`Index.table_of/2`)."
  @spec tables(Graph.t()) :: %{String.t() => [module()]}
  def tables(%Graph{} = graph) do
    graph
    |> schemas()
    |> Enum.flat_map(fn schema ->
      case Index.table_of(graph, schema) do
        {:ok, table} -> [{table, schema}]
        _other -> []
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {table, schemas} -> {table, Enum.sort(schemas)} end)
  end

  # --- tracing -----------------------------------------------------------------

  defp trace(node, env, ctx) do
    case :cerl.type(node) do
      :var -> var(node, env, ctx)
      :literal -> concrete(:cerl.concrete(node), ctx)
      :binary -> binary(node)
      :tuple -> tuple(:cerl.tuple_es(node), env, ctx)
      :map -> map(node, env, ctx)
      :call -> call(node, env, ctx)
      :apply -> apply_node(node, env, ctx)
      :case -> case_node(node, env, ctx)
      :let -> trace(:cerl.let_body(node), FunctionWalk.bind_let(node, env), ctx)
      :letrec -> letrec(node, env, ctx)
      :seq -> trace(:cerl.seq_body(node), env, ctx)
      :try -> trace(:cerl.try_body(node), FunctionWalk.bind_try(node, env), ctx)
      :primop -> primop(node)
      :fun -> {:unresolved, "an anonymous function"}
      kind -> {:unresolved, "a Core #{kind}"}
    end
  end

  defp var(node, env, ctx) do
    case Map.get(env, :cerl.var_name(node)) do
      {:node, value, value_env} -> trace(value, value_env, ctx)
      {:param, i} -> param(ctx.mfa, i, ctx)
      {:lambda_param, i} -> {:unresolved, "parameter #{i} of an anonymous function"}
      :repo -> {:unresolved, "the repo argument of a Multi.run callback"}
      {:pattern, what} -> {:unresolved, what}
      _fname_or_unbound -> {:unresolved, "a function value"}
    end
  end

  defp concrete(term, ctx) do
    cond do
      is_atom(term) and MapSet.member?(ctx.schemas, term) -> ok({:schema, term})
      is_binary(term) and term != "" -> ok({:table, term})
      is_map(term) -> concrete_struct(term, ctx)
      is_tuple(term) and tuple_size(term) == 2 -> concrete_pair(term, ctx)
      is_atom(term) -> {:unresolved, "the atom #{inspect(term)}, not a schema"}
      true -> {:unresolved, "a literal #{literal_kind(term)}"}
    end
  end

  defp concrete_struct(%{__struct__: Ecto.Query, from: from}, ctx), do: concrete(from, ctx)

  defp concrete_struct(%{__struct__: Ecto.Query.FromExpr, source: source}, ctx),
    do: concrete(source, ctx)

  defp concrete_struct(%{__struct__: Ecto.Changeset, data: data}, ctx), do: concrete(data, ctx)

  defp concrete_struct(%{__struct__: struct}, ctx) when is_atom(struct) do
    if MapSet.member?(ctx.schemas, struct),
      do: ok({:schema, struct}),
      else: {:unresolved, "a %#{inspect(struct)}{} struct, not a schema"}
  end

  defp concrete_struct(_map, _ctx), do: {:unresolved, "a map"}

  defp concrete_pair({table, _schema}, ctx), do: concrete(table, ctx)

  defp binary(node) do
    case Index.string_literal(node) do
      {:ok, table} -> ok({:table, table})
      :unknown -> {:unresolved, "a binary built at run time"}
    end
  end

  defp tuple([table, _schema], env, ctx), do: trace(table, env, ctx)

  defp tuple(_elements, _env, _ctx), do: {:unresolved, "a tuple"}

  # A map node: a struct literal (its `__struct__` pair), or an update of
  # another map that sets no `__struct__` (what the updated map is).
  defp map(node, env, ctx) do
    pairs =
      Map.new(:cerl.map_es(node), fn pair ->
        {:cerl.map_pair_key(pair), :cerl.map_pair_val(pair)}
      end)

    literal_pairs =
      for {key, value} <- pairs,
          :cerl.is_literal(key),
          into: %{},
          do: {:cerl.concrete(key), value}

    case Map.fetch(literal_pairs, :__struct__) do
      {:ok, struct} -> struct_node(struct, literal_pairs, env, ctx)
      :error -> map_update(:cerl.map_arg(node), env, ctx)
    end
  end

  defp struct_node(struct, pairs, env, ctx) do
    case FunctionWalk.atom(struct, env) do
      {:ok, Ecto.Query} -> field(pairs, :from, env, ctx)
      {:ok, Ecto.Query.FromExpr} -> field(pairs, :source, env, ctx)
      {:ok, Ecto.Changeset} -> field(pairs, :data, env, ctx)
      {:ok, module} -> concrete_struct(%{__struct__: module}, ctx)
      _not_literal -> {:unresolved, "a struct whose module is computed"}
    end
  end

  defp field(pairs, key, env, ctx) do
    case Map.fetch(pairs, key) do
      {:ok, value} -> trace(value, env, ctx)
      :error -> {:unresolved, "a struct with no #{key}"}
    end
  end

  defp map_update(arg, env, ctx) do
    if :cerl.is_literal(arg) and :cerl.concrete(arg) == %{},
      do: {:unresolved, "a map"},
      else: trace(arg, env, ctx)
  end

  defp call(node, env, ctx) do
    args = :cerl.call_args(node)

    with {:ok, module} <- FunctionWalk.atom(:cerl.call_module(node), env),
         name = :cerl.call_name(node),
         true <- :cerl.is_literal(name) do
      called(module, :cerl.concrete(name), args, env, ctx)
    else
      _dynamic -> {:unresolved, "the result of a call Anchor cannot resolve"}
    end
  end

  defp called(module, name, args, env, ctx) do
    cond do
      {module, name} in @raising ->
        :none

      MapSet.member?(ctx.schemas, module) ->
        ok({:schema, module})

      module == Ecto.Changeset and args != [] ->
        trace(hd(args), env, ctx)

      query_module?(module) ->
        first_resolved(args, env, ctx, "an Ecto query Anchor cannot trace to a schema or table")

      project_function?(ctx.graph, {module, name, length(args)}) ->
        return({module, name, length(args)}, ctx)

      true ->
        {:unresolved, "the result of #{ViolationKey.mfa({module, name, length(args)})}"}
    end
  end

  defp query_module?(module) do
    name = Atom.to_string(module)

    module in [Ecto.Query, Ecto.Queryable] or
      String.starts_with?(name, "Elixir.Ecto.Query.Builder")
  end

  # Rule 6: a string argument of a query call (a prefix, a name) is never the
  # table, so an unresolved query stays unresolved. A schema module (a
  # literal atom) and a literal `%Ecto.Query{}` map are still traced; a table
  # reaches a query through `from/2`, whose `%Ecto.Query{}` rule 2 reads.
  defp first_resolved(args, env, ctx, seen) do
    args
    |> Enum.reject(&string?/1)
    |> Enum.find_value({:unresolved, seen}, fn arg ->
      case trace(arg, env, ctx) do
        {:ok, _sources} = ok -> ok
        _other -> nil
      end
    end)
  end

  defp string?(node),
    do:
      (:cerl.is_literal(node) and is_binary(:cerl.concrete(node))) or :cerl.type(node) == :binary

  defp apply_node(node, env, ctx) do
    op = :cerl.apply_op(node)

    with true <- :cerl.is_c_var(op),
         {f, a} <- :cerl.var_name(op),
         false <- Map.get(env, {f, a}) == :letrec,
         {module, _name, _arity} <- ctx.mfa,
         true <- project_function?(ctx.graph, {module, f, a}) do
      return({module, f, a}, ctx)
    else
      _other -> {:unresolved, "the result of a call of a fun value"}
    end
  end

  defp case_node(node, env, ctx) do
    arg = :cerl.case_arg(node)

    node
    |> :cerl.case_clauses()
    |> Enum.map(&trace(:cerl.clause_body(&1), FunctionWalk.bind_clause(&1, arg, env), ctx))
    |> union()
  end

  defp letrec(node, env, ctx) do
    env =
      Enum.reduce(:cerl.letrec_defs(node), env, fn {fname, _fun}, env ->
        Map.put(env, :cerl.var_name(fname), :letrec)
      end)

    trace(:cerl.letrec_body(node), env, ctx)
  end

  defp primop(node) do
    case :cerl.atom_val(:cerl.primop_name(node)) do
      name when name in [:match_fail, :raise] -> :none
      name -> {:unresolved, "the primop #{name}"}
    end
  end

  # --- rule 7 and rule 8 -------------------------------------------------------

  defp param(nil, i, _ctx), do: {:unresolved, "parameter #{i}"}

  defp param(mfa, i, ctx) do
    key = {:param, mfa, i}

    cond do
      key in ctx.stack or ctx.hops >= @max_hops ->
        {:unresolved, "parameter cycle"}

      (schema = spec_schema(mfa, i, ctx)) != nil ->
        ok({:schema, schema})

      MapSet.member?(ctx.captured, mfa) ->
        {:unresolved,
         "parameter #{i} of #{ViolationKey.mfa(mfa)} is passed as a function value, so its " <>
           "callers are not known"}

      true ->
        callers(mfa, i, Map.get(ctx.callers, mfa, []), %{
          ctx
          | stack: [key | ctx.stack],
            hops: ctx.hops + 1
        })
    end
  end

  defp callers(mfa, i, [], _ctx),
    do:
      {:unresolved,
       "parameter #{i} of #{ViolationKey.mfa(mfa)} has no @spec and no project caller"}

  defp callers(_mfa, i, sites, ctx) do
    sites
    |> Enum.map(fn {caller, args, env} ->
      case Enum.at(args, i - 1) do
        nil -> {:unresolved, "parameter #{i}"}
        arg -> trace(arg, env, %{ctx | mfa: caller})
      end
    end)
    |> union()
  end

  defp spec_schema({module, name, arity}, i, ctx) do
    with %ModuleNode{specs: specs} <- Graph.module(ctx.graph, module),
         [_ | _] = forms <- Map.get(specs, {name, arity}) do
      Enum.find_value(forms, fn form ->
        with {:"::", _meta, [{^name, _call_meta, args}, _return]} when is_list(args) <- form,
             {{:., _dot, [schema, :t]}, _type_meta, []} <- Enum.at(args, i - 1),
             true <- is_atom(schema) and MapSet.member?(ctx.schemas, schema) do
          schema
        else
          _other -> nil
        end
      end)
    else
      _none -> nil
    end
  end

  defp return(mfa, ctx) do
    key = {:return, mfa}

    cond do
      key in ctx.stack ->
        :none

      ctx.hops >= @max_hops ->
        {:unresolved, "parameter cycle"}

      true ->
        %FunctionNode{core: core} = Graph.function(ctx.graph, mfa)
        ctx = %{ctx | mfa: mfa, stack: [key | ctx.stack], hops: ctx.hops + 1}
        trace(:cerl.fun_body(core), FunctionWalk.params(core), ctx)
    end
  end

  # --- helpers -----------------------------------------------------------------

  defp union(results) do
    Enum.reduce_while(results, :none, fn
      {:unresolved, _seen} = unresolved, _acc -> {:halt, unresolved}
      :none, acc -> {:cont, acc}
      {:ok, sources}, :none -> {:cont, {:ok, sources}}
      {:ok, sources}, {:ok, acc} -> {:cont, {:ok, MapSet.union(acc, sources)}}
    end)
  end

  defp ok(source), do: {:ok, MapSet.new([source])}

  defp project_function?(graph, mfa),
    do: match?(%FunctionNode{core: core} when core != nil, Graph.function(graph, mfa))

  defp literal_kind(term) when is_list(term), do: "list"
  defp literal_kind(term) when is_tuple(term), do: "tuple"
  defp literal_kind(term) when is_number(term), do: "number"
  defp literal_kind(term) when is_function(term), do: "function"
  defp literal_kind(_term), do: "value"
end
