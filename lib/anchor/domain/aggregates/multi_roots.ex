defmodule Anchor.Domain.Aggregates.MultiRoots do
  @moduledoc """
  Which of a function's parameters its returned `Ecto.Multi` is built on
  (DND-5884) — **Domain**, pure.

  A transaction given `helper(a, b)` reads the helper's own body, and needs to
  know which argument the Multi coming back was built from: that one is part of
  the transaction, and a value Anchor cannot trace there is a gap. `of/2` answers
  with the parameter positions, from 1, or `:unknown` when a returned value is one
  it cannot follow. A helper that makes its own Multi has no root, whatever else
  it calls; the question is what it returns.

  The walk is one pass over the function's Core, computing each binding once, so a
  chain of branches costs its length. What does not return (`raise`, a failed
  match) adds nothing. A recursive helper is `:unknown`: the positions depend on
  how it calls itself, and a claim of no root would hide one.
  """

  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph

  @multi Ecto.Multi
  @no_return [{:erlang, :error}, {:erlang, :exit}, {:erlang, :raise}, {:erlang, :throw}]

  @type roots :: MapSet.t(pos_integer()) | :unknown

  @spec of(Graph.t(), mfa()) :: roots()
  def of(graph, mfa), do: function(mfa, %{graph: graph, path: MapSet.new(), module: nil})

  defp function({module, _name, _arity} = mfa, ctx) do
    with false <- MapSet.member?(ctx.path, mfa),
         %FunctionNode{core: core} when core != nil <- Graph.function(ctx.graph, mfa) do
      env =
        core
        |> :cerl.fun_vars()
        |> Enum.with_index(1)
        |> Map.new(fn {var, i} -> {:cerl.var_name(var), MapSet.new([i])} end)

      core
      |> :cerl.fun_body()
      |> value(env, %{ctx | path: MapSet.put(ctx.path, mfa), module: module})
    else
      _other -> :unknown
    end
  end

  defp value(node, env, ctx), do: value(:cerl.type(node), node, env, ctx)

  defp value(:var, node, env, _ctx), do: Map.get(env, :cerl.var_name(node), :unknown)
  defp value(:literal, _node, _env, _ctx), do: MapSet.new()
  defp value(:primop, _node, _env, _ctx), do: MapSet.new()
  defp value(:seq, node, env, ctx), do: value(:cerl.seq_body(node), env, ctx)
  defp value(:letrec, node, env, ctx), do: value(:cerl.letrec_body(node), env, ctx)

  defp value(:let, node, env, ctx) do
    env = bind(:cerl.let_vars(node), arguments(:cerl.let_arg(node), env, ctx), env)
    value(:cerl.let_body(node), env, ctx)
  end

  defp value(:case, node, env, ctx) do
    arguments = arguments(:cerl.case_arg(node), env, ctx)

    node
    |> :cerl.case_clauses()
    |> Enum.map(fn clause ->
      value(:cerl.clause_body(clause), bind(:cerl.clause_pats(clause), arguments, env), ctx)
    end)
    |> union()
  end

  defp value(:try, node, env, ctx) do
    body_env = bind(:cerl.try_vars(node), arguments(:cerl.try_arg(node), env, ctx), env)

    union([
      value(:cerl.try_body(node), body_env, ctx),
      value(:cerl.try_handler(node), env, ctx)
    ])
  end

  defp value(:call, node, env, ctx) do
    module = :cerl.call_module(node)
    name = :cerl.call_name(node)

    if :cerl.is_literal(module) and :cerl.is_literal(name),
      do: call(:cerl.concrete(module), :cerl.concrete(name), :cerl.call_args(node), env, ctx),
      else: :unknown
  end

  defp value(:apply, node, env, ctx) do
    op = :cerl.apply_op(node)

    case :cerl.is_c_var(op) and :cerl.var_name(op) do
      {name, arity} ->
        through({ctx.module, name, arity}, :cerl.apply_args(node), env, ctx)

      _other ->
        :unknown
    end
  end

  defp value(_type, _node, _env, _ctx), do: :unknown

  defp call(@multi, :new, [], _env, _ctx), do: MapSet.new()

  defp call(@multi, name, [left, right], env, ctx) when name in [:append, :prepend],
    do: union([value(left, env, ctx), value(right, env, ctx)])

  defp call(@multi, _name, [multi | _rest], env, ctx), do: value(multi, env, ctx)

  defp call(module, name, args, env, ctx) do
    if {module, name} in @no_return,
      do: MapSet.new(),
      else: through({module, name, length(args)}, args, env, ctx)
  end

  # A callee's roots are positions in its own head: here they are this call's
  # arguments at those positions.
  defp through(callee, args, env, ctx) do
    case function(callee, ctx) do
      :unknown ->
        :unknown

      roots ->
        roots
        |> Enum.map(&value(Enum.at(args, &1 - 1), env, ctx))
        |> union()
    end
  end

  defp arguments(node, env, ctx) do
    nodes = if :cerl.type(node) == :values, do: :cerl.values_es(node), else: [node]
    Enum.map(nodes, &value(&1, env, ctx))
  end

  # A pattern that is no plain variable binds nothing this walk reads: a variable
  # it binds is not in `env`, so it reads as `:unknown`.
  defp bind(patterns, arguments, env) when length(patterns) == length(arguments) do
    patterns
    |> Enum.zip(arguments)
    |> Enum.reduce(env, fn {pattern, roots}, env -> bind_pattern(pattern, roots, env) end)
  end

  defp bind(_patterns, _arguments, env), do: env

  defp bind_pattern(pattern, roots, env) do
    cond do
      :cerl.is_c_var(pattern) -> Map.put(env, :cerl.var_name(pattern), roots)
      :cerl.is_c_alias(pattern) -> Map.put(env, alias_name(pattern), roots)
      true -> env
    end
  end

  defp alias_name(pattern), do: pattern |> :cerl.alias_var() |> :cerl.var_name()

  defp union(all) do
    Enum.reduce(all, MapSet.new(), fn
      :unknown, _acc -> :unknown
      _roots, :unknown -> :unknown
      roots, acc -> MapSet.union(acc, roots)
    end)
  end
end
