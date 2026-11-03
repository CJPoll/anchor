defmodule Anchor.Domain.Aggregates.WriteSites do
  @moduledoc """
  Finds every database write, every transaction and every call of the
  project in compiled code (DND-5459) — a **Domain** module (ADR 001). Pure:
  it reads each function's Core from the graph, and never loads or calls a
  project module.

  ## Repos

  `repos/2`: the project modules whose beam declares `@behaviour Ecto.Repo`,
  plus `aggregates.repos`. None at all is `{:error, :no_repo}` from `find/2`:
  a run with no repo would find no write and must not read as clean.

  ## Writes

    * a call on a repo module of a `Repo` write (`insert`, `insert!`, `update`,
      `update!`, `delete`, `delete!`, `insert_or_update`, `insert_or_update!`,
      `insert_all`, `update_all`, `delete_all`) is `via: :repo`, its source
      argument 1. In Core an alias, a pipe and an `@repo` attribute are all
      already the literal module;
    * a call of an `Ecto.Multi` write (the same names without bangs) is
      `via: :multi`, its source argument 3;
    * a call matching an `aggregates.write_functions` entry is
      `via: :write_function`, its source argument 1;
    * inside a `Multi.run/3,5` callback (an inline `fn`, or a function named
      by a capture), a `Repo` write called on the callback's first parameter
      is `via: :run_callback_repo`.

  Any other call on a module held in a variable is a dynamic call, not a
  write: a gap of every scope that reaches it.

  ## Transactions

  `Repo.transaction/1,2` on a repo (and `Repo.transact/1,2` when the repo's
  beam exports it), and every `aggregates.transaction_functions` call. The
  body of each is found here, by following the argument through Core's
  bindings: an inline or let-bound `fn` (kind `:fun`), a capture (`:fun`), or
  an `Ecto.Multi` value (`:multi`): every Multi step, `Multi.run` callback and
  project function on the value's trace (a helper that builds the Multi). An
  argument that is none of these is a gap at the transaction's line. Every
  node of a body is tagged with its scope's ordinal (Core order, from 1), and
  every write, call and dynamic call found under it carries the tag.

  ## Facts

  `facts/3` returns, per function with a Core body, the raw writes (the
  source argument's Core node with its bindings, for
  `Anchor.Domain.Aggregates.WriteSource`), the transactions, the calls into
  project functions, and the dynamic calls; plus every call site of each
  project function (`callers`, for trace rule 7b) and the functions used as
  values (`captured`).
  """

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.FunctionWalk
  alias Anchor.Domain.Aggregates.WriteSite
  alias Anchor.Domain.Aggregates.WriteSource
  alias Anchor.Domain.Core
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  @repo_writes %{
    insert: 1..2,
    insert!: 1..2,
    update: 1..2,
    update!: 1..2,
    delete: 1..2,
    delete!: 1..2,
    insert_or_update: 1..2,
    insert_or_update!: 1..2,
    insert_all: 2..3,
    update_all: 2..3,
    delete_all: 1..2
  }

  @multi_writes %{
    insert: 3..4,
    update: 3..4,
    delete: 3..4,
    insert_or_update: 3..4,
    insert_all: 4..5,
    update_all: 4..5,
    delete_all: 3..4
  }

  @multi Ecto.Multi

  @type raw_site :: %{
          op: atom(),
          via: WriteSite.via(),
          line: non_neg_integer() | nil,
          arg: :cerl.cerl() | nil,
          env: FunctionWalk.env(),
          tags: [term()]
        }

  @type raw_call :: %{
          to: mfa(),
          kind: :remote | :local | :capture,
          args: [:cerl.cerl()],
          env: FunctionWalk.env(),
          tags: [term()],
          line: non_neg_integer() | nil
        }

  @type raw_tx :: %{
          ordinal: pos_integer(),
          line: non_neg_integer() | nil,
          kind: :fun | :multi | :transaction_function,
          captures: [mfa()],
          gaps: [String.t()]
        }

  @type function_facts :: %{
          sites: [raw_site()],
          txs: [raw_tx()],
          calls: [raw_call()],
          dynamic: [%{line: non_neg_integer() | nil, what: String.t(), tags: [term()]}],
          def_line: non_neg_integer() | nil,
          public?: boolean()
        }

  @type t :: %{
          functions: %{mfa() => function_facts()},
          callers: %{mfa() => [{mfa(), [:cerl.cerl()], FunctionWalk.env()}]},
          captured: MapSet.t(mfa()),
          run_callbacks: MapSet.t(mfa()),
          repos: MapSet.t(module())
        }

  @doc "The `Repo` write names and the arities each takes."
  @spec repo_writes() :: %{atom() => Range.t()}
  def repo_writes, do: @repo_writes

  @doc """
  The repo modules: every graph module whose beam declares
  `@behaviour Ecto.Repo`, and every `aggregates.repos` entry.
  """
  @spec repos(Graph.t(), Config.t()) :: MapSet.t(module())
  def repos(%Graph{modules: modules}, %Config{repos: listed}) do
    declared = for {module, %ModuleNode{behaviours: b}} <- modules, Ecto.Repo in b, do: module
    MapSet.new(declared ++ listed)
  end

  @doc """
  Every write of the project, its sources resolved
  (`Anchor.Domain.Aggregates.WriteSource`), in function then Core order;
  `{:error, :no_repo}` when the project has no repo.
  """
  @spec find(Graph.t(), Config.t()) :: {:ok, [WriteSite.t()]} | {:error, :no_repo}
  def find(%Graph{} = graph, %Config{} = config) do
    repos = repos(graph, config)

    if MapSet.size(repos) == 0 do
      {:error, :no_repo}
    else
      facts = facts(graph, config, repos)
      {:ok, sites(facts, graph)}
    end
  end

  @doc "Every raw write of `facts`, resolved into `WriteSite`s, in function then Core order."
  @spec sites(t(), Graph.t()) :: [WriteSite.t()]
  def sites(facts, graph) do
    ctx = WriteSource.context(graph, facts)

    facts.functions
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.flat_map(fn {mfa, function} ->
      Enum.map(function.sites, &site(&1, mfa, ctx))
    end)
  end

  @doc "One raw write of `mfa`, resolved."
  @spec site(raw_site(), mfa(), WriteSource.context()) :: WriteSite.t()
  def site(raw, mfa, ctx) do
    {sources, unresolved} =
      case WriteSource.resolve(raw.arg, raw.env, %{ctx | mfa: mfa}) do
        {:ok, sources} -> {sources, nil}
        {:unresolved, seen} -> {[], seen}
      end

    %WriteSite{
      mfa: mfa,
      line: raw.line,
      op: raw.op,
      via: raw.via,
      sources: sources,
      unresolved: unresolved,
      scopes: Enum.filter(raw.tags, &is_integer/1),
      run_callback?: :run_callback in raw.tags
    }
  end

  @doc "The facts of every function of `graph`; see the moduledoc."
  @spec facts(Graph.t(), Config.t(), MapSet.t(module())) :: t()
  def facts(%Graph{} = graph, %Config{} = config, repos) do
    ctx = %{
      graph: graph,
      repos: repos,
      transact: transact_repos(graph, repos),
      write_functions: config.write_functions,
      transaction_functions: config.transaction_functions
    }

    functions =
      for {module, %ModuleNode{functions: fns}} <- graph.modules,
          {{name, arity}, %FunctionNode{core: core} = node} <- fns,
          core != nil,
          node.kind in [:def, :defp],
          do: {{module, name, arity}, FunctionWalk.label(core), node}

    prescans = Map.new(functions, fn {mfa, core, _node} -> {mfa, prescan(core, mfa, ctx)} end)
    run_callbacks = prescans |> Map.values() |> Enum.flat_map(& &1.run_captures) |> MapSet.new()

    facts =
      Map.new(functions, fn {mfa, core, node} ->
        facts = collect(core, mfa, node.line, prescans[mfa], run_callbacks, ctx)
        {mfa, Map.put(facts, :public?, node.kind == :def)}
      end)

    %{
      functions: facts,
      callers: callers(facts),
      captured: captured(facts, run_callbacks),
      run_callbacks: run_callbacks,
      repos: repos
    }
  end

  # --- pass 1: transactions and Multi.run callbacks ----------------------------

  defp prescan(core, mfa, ctx) do
    events = FunctionWalk.events(core)

    run =
      Enum.reduce(events, %{lambdas: [], captures: []}, fn
        {:call, node, env, _tags}, acc -> run_callback(node, env, mfa, acc)
        _event, acc -> acc
      end)

    txs =
      events
      |> Enum.flat_map(fn
        {:call, node, env, _tags} -> transaction(node, env, mfa, ctx)
        _event -> []
      end)
      |> Enum.with_index(1)
      |> Enum.map(fn {tx, ordinal} -> Map.put(tx, :ordinal, ordinal) end)

    tags =
      Enum.reduce(txs, %{}, fn tx, tags ->
        Enum.reduce(tx.ids, tags, fn id, tags ->
          Map.update(tags, id, [tx.ordinal], &(&1 ++ [tx.ordinal]))
        end)
      end)

    %{
      txs: Enum.map(txs, &Map.drop(&1, [:ids])),
      tags: tags,
      run_lambdas: MapSet.new(run.lambdas),
      run_captures: run.captures
    }
  end

  defp run_callback(node, env, mfa, acc) do
    case {call(node, env), :cerl.call_args(node)} do
      {{:ok, {@multi, :run, 3}}, [_m, _name, fun]} ->
        case callback(fun, env, mfa) do
          {:lambda, id} -> %{acc | lambdas: [id | acc.lambdas]}
          {:capture, callee} -> %{acc | captures: [callee | acc.captures]}
          :error -> acc
        end

      {{:ok, {@multi, :run, 5}}, [_m, _name, mod, fun, args]} ->
        case {FunctionWalk.atom(mod, env), FunctionWalk.atom(fun, env), list_length(args, env)} do
          {{:ok, m}, {:ok, f}, {:ok, n}} -> %{acc | captures: [{m, f, n + 2} | acc.captures]}
          _other -> acc
        end

      _other ->
        acc
    end
  end

  # A fun value: an inline or let-bound `fn` (its id), or a capture (its mfa).
  defp callback(node, env, {module, _name, _arity}) do
    if fname?(node) do
      {f, a} = :cerl.var_name(node)
      {:capture, {module, f, a}}
    else
      case FunctionWalk.deref(node, env) do
        {:node, value, value_env} -> fun_value(value, value_env, module)
        {:binding, _binding} -> :error
      end
    end
  end

  # A local capture bound to a variable first (`f = &step/2`, or the let Core
  # makes of `&step/2` itself) is the module's own function.
  defp fun_value(node, env, module) do
    cond do
      fname?(node) ->
        {f, a} = :cerl.var_name(node)
        {:capture, {module, f, a}}

      :cerl.type(node) == :fun ->
        {:lambda, FunctionWalk.id(node)}

      :cerl.is_literal(node) and is_function(:cerl.concrete(node)) ->
        external(:cerl.concrete(node))

      :cerl.type(node) == :call ->
        make_fun(node, env)

      true ->
        :error
    end
  end

  defp external(fun) do
    case Function.info(fun, :type) do
      {:type, :external} ->
        {:module, m} = Function.info(fun, :module)
        {:name, f} = Function.info(fun, :name)
        {:arity, a} = Function.info(fun, :arity)
        {:capture, {m, f, a}}

      _local ->
        :error
    end
  end

  defp make_fun(node, env) do
    with {:ok, {:erlang, :make_fun, 3}} <- call(node, env),
         [m, f, a] <- :cerl.call_args(node),
         {:ok, m} <- FunctionWalk.atom(m, env),
         {:ok, f} <- FunctionWalk.atom(f, env),
         true <- :cerl.is_literal(a) and is_integer(:cerl.concrete(a)) do
      {:capture, {m, f, :cerl.concrete(a)}}
    else
      _other -> :error
    end
  end

  defp transaction(node, env, mfa, ctx) do
    case call(node, env) do
      {:ok, {module, name, arity} = callee} ->
        args = :cerl.call_args(node)

        cond do
          repo_transaction?(ctx, module, name, arity) ->
            [tx_body(hd(args), node, env, mfa, ctx)]

          Enum.any?(ctx.transaction_functions, &FunctionRef.matches?(&1, module, name, arity)) ->
            [transaction_function(args, node, env, mfa, ctx, callee)]

          true ->
            []
        end

      _other ->
        []
    end
  end

  defp repo_transaction?(ctx, module, name, arity) do
    MapSet.member?(ctx.repos, module) and arity in [1, 2] and
      (name == :transaction or (name == :transact and MapSet.member?(ctx.transact, module)))
  end

  defp tx_body(arg, node, env, mfa, ctx) do
    base = %{line: Core.line(node), ids: [], captures: [], gaps: []}

    case body(arg, env, mfa, ctx) do
      {:ok, kind, ids, captures, gaps} ->
        %{base | ids: base.ids ++ ids, captures: captures, gaps: gaps} |> Map.put(:kind, kind)

      :error ->
        base
        |> Map.put(:kind, :fun)
        |> Map.put(:gaps, [
          "the transaction is given a value Anchor cannot trace to a function or an Ecto.Multi"
        ])
    end
  end

  defp transaction_function(args, node, env, mfa, ctx, callee) do
    bodies =
      for arg <- args,
          {:ok, _kind, _ids, _captures, _gaps} = found <- [body(arg, env, mfa, ctx)],
          do: found

    base = %{line: Core.line(node), ids: [], kind: :transaction_function}

    case bodies do
      [] ->
        Map.merge(base, %{
          captures: [],
          gaps: ["#{format(callee)} is given no function or Ecto.Multi Anchor can trace"]
        })

      found ->
        Map.merge(base, %{
          ids: base.ids ++ Enum.flat_map(found, &elem(&1, 2)),
          captures: Enum.flat_map(found, &elem(&1, 3)),
          gaps: Enum.flat_map(found, &elem(&1, 4))
        })
    end
  end

  defp body(arg, env, mfa, ctx) do
    case callback(arg, env, mfa) do
      {:lambda, id} -> {:ok, :fun, [id], [], []}
      {:capture, callee} -> {:ok, :fun, [], [callee], []}
      :error -> multi(arg, env, mfa, ctx)
    end
  end

  # The trace of an Ecto.Multi value: every step, callback and helper on it.
  defp multi(node, env, mfa, ctx), do: multi(node, env, mfa, ctx, 0)

  defp multi(_node, _env, _mfa, _ctx, depth) when depth > 256, do: :error

  defp multi(node, env, mfa, ctx, depth) do
    case FunctionWalk.deref(node, env) do
      {:node, value, value_env} -> multi_value(value, value_env, mfa, ctx, depth)
      {:binding, _binding} -> :error
    end
  end

  defp multi_value(node, env, mfa, ctx, depth) do
    cond do
      :cerl.is_literal(node) and match?(%{__struct__: @multi}, :cerl.concrete(node)) ->
        {:ok, :multi, [], [], []}

      :cerl.type(node) == :call ->
        multi_call(node, env, call(node, env), mfa, ctx, depth)

      true ->
        :error
    end
  end

  defp multi_call(node, _env, {:ok, {@multi, :new, 0}}, _mfa, _ctx, _depth),
    do: {:ok, :multi, [FunctionWalk.id(node)], [], []}

  defp multi_call(node, env, {:ok, {@multi, :run, 3}}, mfa, ctx, depth) do
    [m, _name, fun] = :cerl.call_args(node)

    {ids, captures} =
      case callback(fun, env, mfa) do
        {:lambda, id} -> {[id], []}
        {:capture, callee} -> {[], [callee]}
        :error -> {[], []}
      end

    node
    |> step(m, env, mfa, ctx, depth)
    |> add(ids, captures, if(ids == [] and captures == [], do: [run_gap()], else: []))
  end

  defp multi_call(node, env, {:ok, {@multi, :run, 5}}, mfa, ctx, depth) do
    [m, _name, mod, fun, args] = :cerl.call_args(node)

    case {FunctionWalk.atom(mod, env), FunctionWalk.atom(fun, env), list_length(args, env)} do
      {{:ok, mo}, {:ok, f}, {:ok, n}} ->
        step(node, m, env, mfa, ctx, depth) |> add([], [{mo, f, n + 2}], [])

      _other ->
        step(node, m, env, mfa, ctx, depth) |> add([], [], [run_gap()])
    end
  end

  defp multi_call(node, env, {:ok, {@multi, name, _arity}}, mfa, ctx, depth)
       when name in [:append, :prepend] do
    [left, right] = :cerl.call_args(node)

    with {:ok, _kind, ids, captures, gaps} <- multi(left, env, mfa, ctx, depth + 1),
         {:ok, _kind, ids2, captures2, gaps2} <- multi(right, env, mfa, ctx, depth + 1) do
      {:ok, :multi, [FunctionWalk.id(node) | ids ++ ids2], captures ++ captures2, gaps ++ gaps2}
    end
  end

  defp multi_call(node, env, {:ok, {@multi, :merge, _arity}}, mfa, ctx, depth) do
    node
    |> step(hd(:cerl.call_args(node)), env, mfa, ctx, depth)
    |> add([], [], ["Multi.merge builds its steps at run time"])
  end

  defp multi_call(node, env, {:ok, {@multi, _name, arity}}, mfa, ctx, depth) when arity > 0,
    do: step(node, hd(:cerl.call_args(node)), env, mfa, ctx, depth)

  # A project function on the trace builds (part of) the Multi: the call is
  # in the body, so its closure is; its arguments are traced when they can be.
  defp multi_call(node, env, {:ok, {module, name, arity}}, mfa, ctx, depth) do
    if project_function?(ctx.graph, {module, name, arity}) do
      node
      |> :cerl.call_args()
      |> Enum.reduce({:ok, :multi, [FunctionWalk.id(node)], [], []}, fn arg, acc ->
        case multi(arg, env, mfa, ctx, depth + 1) do
          {:ok, _kind, ids, captures, gaps} -> add(acc, ids, captures, gaps)
          :error -> acc
        end
      end)
    else
      :error
    end
  end

  defp multi_call(_node, _env, _call, _mfa, _ctx, _depth), do: :error

  defp step(node, previous, env, mfa, ctx, depth) do
    case multi(previous, env, mfa, ctx, depth + 1) do
      {:ok, _kind, ids, captures, gaps} ->
        {:ok, :multi, [FunctionWalk.id(node) | ids], captures, gaps}

      :error ->
        :error
    end
  end

  defp add(:error, _ids, _captures, _gaps), do: :error

  defp add({:ok, kind, ids, captures, gaps}, more_ids, more_captures, more_gaps),
    do: {:ok, kind, ids ++ more_ids, captures ++ more_captures, gaps ++ more_gaps}

  defp run_gap, do: "a Multi.run callback Anchor cannot resolve"

  # --- pass 2: writes, calls, dynamic calls -----------------------------------

  defp collect(core, mfa, def_line, prescan, run_callbacks, ctx) do
    events =
      FunctionWalk.events(core,
        tags: prescan.tags,
        run_lambdas: prescan.run_lambdas,
        repo_param?: MapSet.member?(run_callbacks, mfa)
      )

    acc = %{sites: [], calls: [], dynamic: []}

    acc =
      Enum.reduce(events, acc, fn event, acc -> classify(event, mfa, def_line, ctx, acc) end)

    %{
      sites: Enum.reverse(acc.sites),
      calls: Enum.reverse(acc.calls),
      dynamic: Enum.reverse(acc.dynamic),
      txs: prescan.txs,
      def_line: def_line
    }
  end

  defp classify({:call, node, env, tags}, _mfa, def_line, ctx, acc) do
    line = Core.line(node) || def_line
    args = :cerl.call_args(node)

    case {FunctionWalk.atom(:cerl.call_module(node), env), literal_name(node)} do
      {_module, nil} ->
        dynamic(acc, line, "a call with a computed function name", tags)

      {{:ok, :erlang}, :make_fun} ->
        case make_fun(node, env) do
          {:capture, callee} -> project_call(acc, ctx, callee, :capture, [], env, tags, line)
          :error -> acc
        end

      {{:ok, :erlang}, :apply} ->
        erlang_apply(acc, args, env, tags, line, ctx)

      {{:ok, module}, name} ->
        literal_call(acc, {module, name, length(args)}, args, env, tags, line, ctx)

      {:repo, name} ->
        if repo_write?(name, length(args)),
          do: add_site(acc, name, :run_callback_repo, Enum.at(args, 0), env, tags, line),
          else: acc

      {:error, name} ->
        dynamic(
          acc,
          line,
          "a call of #{name}/#{length(args)} on a module held in a variable",
          tags
        )
    end
  end

  defp classify({:apply, node, env, tags}, {module, _name, _arity}, def_line, ctx, acc) do
    op = :cerl.apply_op(node)
    line = Core.line(node) || def_line

    cond do
      fname?(op) and Map.get(env, :cerl.var_name(op)) == :letrec ->
        acc

      fname?(op) ->
        {f, a} = :cerl.var_name(op)
        project_call(acc, ctx, {module, f, a}, :local, :cerl.apply_args(node), env, tags, line)

      true ->
        applied(acc, op, env, tags, line, {ctx, module})
    end
  end

  defp classify({:fname, node, tags}, {module, _name, _arity}, def_line, ctx, acc) do
    {f, a} = :cerl.var_name(node)
    project_call(acc, ctx, {module, f, a}, :capture, [], %{}, tags, Core.line(node) || def_line)
  end

  defp classify({:literal_fun, node, tags}, _mfa, def_line, ctx, acc) do
    case external(:cerl.concrete(node)) do
      {:capture, callee} ->
        project_call(acc, ctx, callee, :capture, [], %{}, tags, Core.line(node) || def_line)

      :error ->
        acc
    end
  end

  # `fun.(x)`: a fun this function defines is walked where it is defined; a
  # capture is a call; anything else is a call Anchor cannot resolve.
  defp applied(acc, op, env, tags, line, {ctx, module}) do
    case FunctionWalk.deref(op, env) do
      {:node, value, value_env} ->
        case fun_value(value, value_env, module) do
          {:lambda, _id} -> acc
          {:capture, callee} -> project_call(acc, ctx, callee, :capture, [], %{}, tags, line)
          :error -> dynamic(acc, line, "a call of a fun value Anchor cannot resolve", tags)
        end

      {:binding, _binding} ->
        dynamic(acc, line, "a call of a fun value Anchor cannot resolve", tags)
    end
  end

  defp erlang_apply(acc, [m, f, args], env, tags, line, ctx) do
    with {:ok, m} <- FunctionWalk.atom(m, env),
         {:ok, f} <- FunctionWalk.atom(f, env),
         {:ok, n} <- list_length(args, env) do
      literal_call(acc, {m, f, n}, [], env, tags, line, ctx)
    else
      _other -> dynamic(acc, line, "an apply/3 Anchor cannot resolve", tags)
    end
  end

  defp erlang_apply(acc, _args, _env, tags, line, _ctx),
    do: dynamic(acc, line, "an apply/2 Anchor cannot resolve", tags)

  defp literal_call(acc, {module, name, arity} = callee, args, env, tags, line, ctx) do
    cond do
      MapSet.member?(ctx.repos, module) and repo_write?(name, arity) ->
        add_site(acc, name, :repo, Enum.at(args, 0), env, tags, line)

      module == @multi and multi_write?(name, arity) ->
        add_site(acc, name, :multi, Enum.at(args, 2), env, tags, line)

      arity > 0 and Enum.any?(ctx.write_functions, &FunctionRef.matches?(&1, module, name, arity)) ->
        add_site(acc, name, :write_function, Enum.at(args, 0), env, tags, line)

      MapSet.member?(ctx.repos, module) ->
        acc

      true ->
        project_call(acc, ctx, callee, :remote, args, env, tags, line)
    end
  end

  defp add_site(acc, op, via, arg, env, tags, line) do
    site = %{op: op, via: via, line: line, arg: arg, env: env, tags: tags}
    %{acc | sites: [site | acc.sites]}
  end

  defp project_call(acc, ctx, callee, kind, args, env, tags, line) do
    if project_function?(ctx.graph, callee) do
      call = %{to: callee, kind: kind, args: args, env: env, tags: tags, line: line}
      %{acc | calls: [call | acc.calls]}
    else
      acc
    end
  end

  defp dynamic(acc, line, what, tags),
    do: %{acc | dynamic: [%{line: line, what: what, tags: tags} | acc.dynamic]}

  # --- helpers ----------------------------------------------------------------

  defp callers(facts) do
    for {from, %{calls: calls}} <- facts,
        %{kind: kind, to: to, args: args, env: env} <- calls,
        kind in [:remote, :local],
        reduce: %{} do
      acc -> Map.update(acc, to, [{from, args, env}], &(&1 ++ [{from, args, env}]))
    end
  end

  defp captured(facts, run_callbacks) do
    for {_from, %{calls: calls}} <- facts,
        %{kind: :capture, to: to} <- calls,
        into: run_callbacks,
        do: to
  end

  defp transact_repos(graph, repos) do
    for repo <- repos,
        Enum.any?(
          [1, 2],
          &match?(%FunctionNode{kind: :def}, Graph.function(graph, {repo, :transact, &1}))
        ),
        into: MapSet.new(),
        do: repo
  end

  @doc "Whether `{module, name, arity}` is a function of the project with a Core body."
  @spec project_function?(Graph.t(), mfa()) :: boolean()
  def project_function?(graph, mfa),
    do: match?(%FunctionNode{core: core} when core != nil, Graph.function(graph, mfa))

  defp call(node, env) do
    with {:ok, module} <- FunctionWalk.atom(:cerl.call_module(node), env),
         name when is_atom(name) and name != nil <- literal_name(node) do
      {:ok, {module, name, length(:cerl.call_args(node))}}
    else
      _other -> :error
    end
  end

  defp literal_name(node) do
    name = :cerl.call_name(node)

    if :cerl.is_literal(name) and is_atom(:cerl.concrete(name)),
      do: :cerl.concrete(name),
      else: nil
  end

  defp fname?(node), do: :cerl.is_c_var(node) and match?({_name, _arity}, :cerl.var_name(node))

  defp list_length(node, env) do
    case FunctionWalk.deref(node, env) do
      {:node, value, _env} -> cons_length(value, 0)
      {:binding, _binding} -> :error
    end
  end

  defp cons_length(node, n) do
    cond do
      :cerl.is_literal(node) and is_list(:cerl.concrete(node)) ->
        {:ok, n + length(:cerl.concrete(node))}

      :cerl.type(node) == :cons ->
        cons_length(:cerl.cons_tl(node), n + 1)

      true ->
        :error
    end
  end

  defp repo_write?(name, arity), do: arity in Map.get(@repo_writes, name, [])
  defp multi_write?(name, arity), do: arity in Map.get(@multi_writes, name, [])

  defp format({module, name, arity}), do: FunctionRef.format(module, name, arity)
end
