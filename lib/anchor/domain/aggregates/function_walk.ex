defmodule Anchor.Domain.Aggregates.FunctionWalk do
  @moduledoc """
  One walk over one function's Core Erlang that the write analysis reads
  (DND-5459) — **Domain**, pure. `:cerl` is a pure accessor library.

  `label/1` gives every node of the function an id (an `{:anchor_aw, n}`
  annotation), so a later walk can say "this node is the body of transaction
  2" without comparing subtrees.

  `events/2` walks the labelled function in pre-order and returns what the
  analysis classifies, each with the variable bindings in scope there and the
  tags of the transaction bodies around it:

    * `{:call, node, env, tags}` — every `call` (remote, or on a variable);
    * `{:apply, node, env, tags}` — every `apply` (a local call, or a call of
      a fun value);
    * `{:fname, node, tags}` — a local function name used as a value (`&f/a`);
    * `{:literal_fun, node, tags}` — an external fun literal (`&M.f/a`);
    * `{:fun, id, tags}` — an anonymous function, by its id, where it is defined.

  The bindings (`t:env/0`) are what lets the analysis trace a value through
  Core's single-assignment `let`s, the function head's `case` and a
  `Multi.run` callback's repo argument:

    * `{:param, i}` — the function's own parameter `i` (from 1);
    * `{:lambda_param, i}` — a parameter of an anonymous function inside it;
    * `:repo` — the repo argument of a `Multi.run` callback;
    * `{:node, node, env}` — a value computed by `node` under `env`;
    * `{:pattern, what}` — a value matched out of a pattern;
    * `:letrec` — a name a `letrec` binds (part of this function's body).

  A `case` clause whose pattern at position `i` is a plain variable (or an
  alias) binds it to the case argument at `i`; that is how the head's
  `case <_0,_1> of <x, y>` keeps `x` as parameter 1.

  `tags` holds, outermost first, the tags the caller gave the ids of the
  nodes it is inside (`opts[:tags]`, `%{id => [tag]}`), plus `:run_callback`
  inside a `Multi.run` callback (`opts[:run_lambdas]`, a set of fun ids).
  """

  @type binding ::
          {:param, pos_integer()}
          | {:lambda_param, pos_integer()}
          | :repo
          | {:node, :cerl.cerl(), env()}
          | {:pattern, String.t()}
          | :letrec

  @type env :: %{term() => binding()}
  @type tag :: term()

  @type event ::
          {:call, :cerl.cerl(), env(), [tag()]}
          | {:apply, :cerl.cerl(), env(), [tag()]}
          | {:fname, :cerl.cerl(), [tag()]}
          | {:literal_fun, :cerl.cerl(), [tag()]}
          | {:fun, non_neg_integer() | nil, [tag()]}

  @doc "Labels every node of `core_fun` with a unique id (`id/1`)."
  @spec label(:cerl.cerl()) :: :cerl.cerl()
  def label(core_fun) do
    {labelled, _next} =
      :cerl_trees.mapfold(
        fn node, n -> {:cerl.add_ann([{:anchor_aw, n}], node), n + 1} end,
        0,
        core_fun
      )

    labelled
  end

  @doc "The id `label/1` gave `node`, or `nil`."
  @spec id(:cerl.cerl()) :: non_neg_integer() | nil
  def id(node) do
    case List.keyfind(:cerl.get_ann(node), :anchor_aw, 0) do
      {:anchor_aw, n} -> n
      nil -> nil
    end
  end

  @doc """
  The events of the labelled `core_fun`; see the moduledoc. Options: `:tags`
  (`%{id => [tag]}`), `:run_lambdas` (fun ids whose first parameter is a
  repo) and `:repo_param?` (the function's own first parameter is a repo: a
  `Multi.run` callback named by a capture).
  """
  @spec events(:cerl.cerl(), keyword()) :: [event()]
  def events(core_fun, opts \\ []) do
    ctx = %{
      tags: Keyword.get(opts, :tags, %{}),
      run_lambdas: Keyword.get(opts, :run_lambdas, MapSet.new())
    }

    env = params(core_fun)

    env =
      if Keyword.get(opts, :repo_param?, false) and :cerl.fun_arity(core_fun) > 0,
        do: Map.put(env, core_fun |> :cerl.fun_vars() |> hd() |> :cerl.var_name(), :repo),
        else: env

    core_fun
    |> :cerl.fun_body()
    |> visit(env, tags(core_fun, [], ctx), ctx, [])
    |> Enum.reverse()
  end

  @doc """
  Follows `node` through the variables `env` binds to the value that made it:
  `{:node, node, env}` for a node that is no variable bound to a value (a
  function name no letrec binds is such a node), or
  `{:binding, binding}` for a parameter, a repo, a pattern value or an unbound
  variable (`:unbound`).
  """
  @spec deref(:cerl.cerl(), env()) :: {:node, :cerl.cerl(), env()} | {:binding, term()}
  def deref(node, env), do: deref(node, env, 0)

  defp deref(node, env, depth) when depth < 64 do
    if :cerl.is_c_var(node) do
      name = :cerl.var_name(node)

      case Map.get(env, name, :unbound) do
        {:node, bound, bound_env} -> deref(bound, bound_env, depth + 1)
        # A function name (`'step'/2`) no letrec binds is the module's own
        # function: the value is the name itself.
        :unbound when is_tuple(name) -> {:node, node, env}
        binding -> {:binding, binding}
      end
    else
      {:node, node, env}
    end
  end

  defp deref(_node, _env, _depth), do: {:binding, :unbound}

  @doc """
  The literal atom `node` is, or is a variable bound to (`{:ok, atom}`); `:repo`
  for a `Multi.run` callback's repo argument; else `:error`.
  """
  @spec atom(:cerl.cerl(), env()) :: {:ok, atom()} | :repo | :error
  def atom(node, env) do
    case deref(node, env) do
      {:node, value, _env} ->
        if :cerl.is_literal(value) and is_atom(:cerl.concrete(value)),
          do: {:ok, :cerl.concrete(value)},
          else: :error

      {:binding, :repo} ->
        :repo

      {:binding, _other} ->
        :error
    end
  end

  @doc "The bindings of a function's own parameters: `{:param, i}` each."
  @spec params(:cerl.cerl()) :: env()
  def params(core_fun) do
    core_fun
    |> :cerl.fun_vars()
    |> Enum.with_index(1)
    |> Map.new(fn {var, i} -> {:cerl.var_name(var), {:param, i}} end)
  end

  @doc "`env` with the variables of the `let` node `node` bound to its argument."
  @spec bind_let(:cerl.cerl(), env()) :: env()
  def bind_let(node, env), do: bind_values(:cerl.let_vars(node), :cerl.let_arg(node), env)

  @doc "`env` with the pattern variables of `clause` bound against the `case` argument `arg`."
  @spec bind_clause(:cerl.cerl(), :cerl.cerl(), env()) :: env()
  def bind_clause(clause, arg, env),
    do: bind_patterns(:cerl.clause_pats(clause), values(arg), env)

  @doc "`env` with the `try` node's result variables bound to its argument."
  @spec bind_try(:cerl.cerl(), env()) :: env()
  def bind_try(node, env), do: bind_values(:cerl.try_vars(node), :cerl.try_arg(node), env)

  @doc "`env` with the `try` node's exception variables bound for its handler."
  @spec bind_handler(:cerl.cerl(), env()) :: env()
  def bind_handler(node, env) do
    Enum.reduce(:cerl.try_evars(node), env, fn var, env ->
      Map.put(env, :cerl.var_name(var), {:pattern, "a caught exception"})
    end)
  end

  # --- the walk ----------------------------------------------------------------

  defp tags(node, tags, ctx) do
    case id(node) do
      nil -> tags
      id -> tags ++ Map.get(ctx.tags, id, [])
    end
  end

  defp visit(node, env, tags, ctx, acc) do
    tags = tags(node, tags, ctx)

    case :cerl.type(node) do
      :fun ->
        visit_fun(node, env, tags, ctx, acc)

      :let ->
        visit_let(node, env, tags, ctx, acc)

      :letrec ->
        visit_letrec(node, env, tags, ctx, acc)

      :case ->
        visit_case(node, env, tags, ctx, acc)

      :try ->
        visit_try(node, env, tags, ctx, acc)

      :call ->
        visit_all(:cerl.call_args(node), env, tags, ctx, [{:call, node, env, tags} | acc])

      :apply ->
        visit_all(:cerl.apply_args(node), env, tags, ctx, [{:apply, node, env, tags} | acc])

      :var ->
        visit_var(node, env, tags, acc)

      :literal ->
        visit_literal(node, tags, acc)

      _other ->
        visit_all(node |> :cerl.subtrees() |> List.flatten(), env, tags, ctx, acc)
    end
  end

  defp visit_all(nodes, env, tags, ctx, acc),
    do: Enum.reduce(nodes, acc, &visit(&1, env, tags, ctx, &2))

  defp visit_fun(node, env, tags, ctx, acc) do
    run? = MapSet.member?(ctx.run_lambdas, id(node))
    tags = if run?, do: tags ++ [:run_callback], else: tags

    env =
      node
      |> :cerl.fun_vars()
      |> Enum.with_index(1)
      |> Enum.reduce(env, fn
        {var, 1}, env when run? -> Map.put(env, :cerl.var_name(var), :repo)
        {var, i}, env -> Map.put(env, :cerl.var_name(var), {:lambda_param, i})
      end)

    visit(:cerl.fun_body(node), env, tags, ctx, [{:fun, id(node), tags} | acc])
  end

  defp visit_let(node, env, tags, ctx, acc) do
    arg = :cerl.let_arg(node)
    acc = visit(arg, env, tags, ctx, acc)
    visit(:cerl.let_body(node), bind_let(node, env), tags, ctx, acc)
  end

  defp visit_letrec(node, env, tags, ctx, acc) do
    defs = :cerl.letrec_defs(node)

    env =
      Enum.reduce(defs, env, fn {fname, _fun}, env ->
        Map.put(env, :cerl.var_name(fname), :letrec)
      end)

    acc = Enum.reduce(defs, acc, fn {_fname, fun}, acc -> visit(fun, env, tags, ctx, acc) end)
    visit(:cerl.letrec_body(node), env, tags, ctx, acc)
  end

  defp visit_case(node, env, tags, ctx, acc) do
    arg = :cerl.case_arg(node)
    acc = visit(arg, env, tags, ctx, acc)

    Enum.reduce(:cerl.case_clauses(node), acc, fn clause, acc ->
      clause_tags = tags(clause, tags, ctx)
      visit(:cerl.clause_body(clause), bind_clause(clause, arg, env), clause_tags, ctx, acc)
    end)
  end

  defp visit_try(node, env, tags, ctx, acc) do
    arg = :cerl.try_arg(node)
    acc = visit(arg, env, tags, ctx, acc)
    acc = visit(:cerl.try_body(node), bind_try(node, env), tags, ctx, acc)

    visit(:cerl.try_handler(node), bind_handler(node, env), tags, ctx, acc)
  end

  # A function name used as a value (`&f/a`): an apply's operator is never
  # visited, so every `fname` reached here is a value.
  defp visit_var(node, env, tags, acc) do
    case :cerl.var_name(node) do
      {_name, _arity} = fname ->
        if Map.get(env, fname) == :letrec, do: acc, else: [{:fname, node, tags} | acc]

      _plain ->
        acc
    end
  end

  defp visit_literal(node, tags, acc) do
    if is_function(:cerl.concrete(node)), do: [{:literal_fun, node, tags} | acc], else: acc
  end

  # --- bindings ----------------------------------------------------------------

  defp values(node) do
    if :cerl.type(node) == :values, do: :cerl.values_es(node), else: [node]
  end

  defp bind_values([var], arg, env), do: Map.put(env, :cerl.var_name(var), binding_of(arg, env))

  defp bind_values(vars, arg, env) do
    case values(arg) do
      args when length(args) == length(vars) ->
        vars
        |> Enum.zip(args)
        |> Enum.reduce(env, fn {var, value}, env ->
          Map.put(env, :cerl.var_name(var), binding_of(value, env))
        end)

      _other ->
        Enum.reduce(
          vars,
          env,
          &Map.put(&2, :cerl.var_name(&1), {:pattern, "one of several values"})
        )
    end
  end

  defp bind_patterns(pats, args, env) when length(pats) == length(args) do
    pats
    |> Enum.zip(args)
    |> Enum.reduce(env, fn {pat, arg}, acc -> bind_pattern(pat, arg, env, acc) end)
  end

  defp bind_patterns(pats, _args, env), do: Enum.reduce(pats, env, &bind_pattern_vars/2)

  defp bind_pattern(pat, arg, env, acc) do
    case :cerl.type(pat) do
      :var ->
        Map.put(acc, :cerl.var_name(pat), binding_of(arg, env))

      :alias ->
        acc = Map.put(acc, :cerl.var_name(:cerl.alias_var(pat)), binding_of(arg, env))
        bind_pattern_vars(:cerl.alias_pat(pat), acc)

      _other ->
        bind_pattern_vars(pat, acc)
    end
  end

  defp bind_pattern_vars(pat, acc) do
    pat
    |> :cerl_trees.variables()
    |> Enum.reduce(acc, &Map.put(&2, &1, {:pattern, "a value matched out of a pattern"}))
  end

  # A variable copies the binding it names; any other node is a value.
  # A function name (`let <F> = 'step'/2`, how Core holds `&step/2`) no
  # letrec binds is a value, the module's own function, never "unbound".
  defp binding_of(node, env) do
    cond do
      not :cerl.is_c_var(node) -> {:node, node, env}
      Map.has_key?(env, :cerl.var_name(node)) -> Map.fetch!(env, :cerl.var_name(node))
      is_tuple(:cerl.var_name(node)) -> {:node, node, env}
      true -> {:pattern, "an unbound variable"}
    end
  end
end
