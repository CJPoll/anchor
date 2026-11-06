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

  The walk computes each binding once and reads each function once per `of/2`, so
  a chain of branches or of helpers costs its length. What does not return (`raise`,
  a failed match) adds nothing. A helper recursive in what it returns is `:unknown`:
  the positions depend on how it calls itself, and a claim of no root would hide
  one.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode

  @multi Ecto.Multi
  @no_return [{:erlang, :error}, {:erlang, :exit}, {:erlang, :raise}, {:erlang, :throw}]

  @type roots :: MapSet.t(pos_integer()) | :unknown

  @spec of(Graph.t(), mfa()) :: roots()
  def of(graph, mfa) do
    {roots, _memo} = function(mfa, %{graph: graph, path: MapSet.new(), module: nil}, %{})
    roots
  end

  # Remembered for this `of/2`. A cycle reads as `:unknown` by the path it was
  # reached on, so a remembered result can only err toward a gap, never hide a root.
  defp function(mfa, ctx, memo) do
    case memo do
      %{^mfa => roots} -> {roots, memo}
      _none -> read_function(mfa, ctx, memo)
    end
  end

  defp read_function({module, _name, _arity} = mfa, ctx, memo) do
    with false <- MapSet.member?(ctx.path, mfa),
         %FunctionNode{core: core} when core != nil <- Graph.function(ctx.graph, mfa) do
      env =
        core
        |> :cerl.fun_vars()
        |> Enum.with_index(1)
        |> Map.new(fn {var, i} -> {:cerl.var_name(var), MapSet.new([i])} end)

      ctx = %{ctx | path: MapSet.put(ctx.path, mfa), module: module}
      {roots, memo} = core |> :cerl.fun_body() |> value(env, ctx, memo)
      {roots, Map.put(memo, mfa, roots)}
    else
      _other -> {:unknown, memo}
    end
  end

  defp value(node, env, ctx, memo), do: value(:cerl.type(node), node, env, ctx, memo)

  defp value(:var, node, env, _ctx, memo),
    do: {Map.get(env, :cerl.var_name(node), :unknown), memo}

  defp value(:literal, _node, _env, _ctx, memo), do: {MapSet.new(), memo}
  defp value(:primop, _node, _env, _ctx, memo), do: {MapSet.new(), memo}
  defp value(:seq, node, env, ctx, memo), do: value(:cerl.seq_body(node), env, ctx, memo)
  defp value(:letrec, node, env, ctx, memo), do: value(:cerl.letrec_body(node), env, ctx, memo)

  defp value(:let, node, env, ctx, memo) do
    {arguments, memo} = arguments(:cerl.let_arg(node), env, ctx, memo)
    value(:cerl.let_body(node), bind(:cerl.let_vars(node), arguments, env), ctx, memo)
  end

  defp value(:case, node, env, ctx, memo) do
    {arguments, memo} = arguments(:cerl.case_arg(node), env, ctx, memo)

    node
    |> :cerl.case_clauses()
    |> Enum.map(fn clause ->
      {:cerl.clause_body(clause), bind(:cerl.clause_pats(clause), arguments, env)}
    end)
    |> all(ctx, memo)
  end

  defp value(:try, node, env, ctx, memo) do
    {arguments, memo} = arguments(:cerl.try_arg(node), env, ctx, memo)
    body_env = bind(:cerl.try_vars(node), arguments, env)

    all([{:cerl.try_body(node), body_env}, {:cerl.try_handler(node), env}], ctx, memo)
  end

  defp value(:call, node, env, ctx, memo) do
    module = :cerl.call_module(node)
    name = :cerl.call_name(node)

    if :cerl.is_literal(module) and :cerl.is_literal(name) do
      call(:cerl.concrete(module), :cerl.concrete(name), :cerl.call_args(node), env, ctx, memo)
    else
      {:unknown, memo}
    end
  end

  defp value(:apply, node, env, ctx, memo) do
    op = :cerl.apply_op(node)

    case :cerl.is_c_var(op) and :cerl.var_name(op) do
      {name, arity} ->
        through({ctx.module, name, arity}, :cerl.apply_args(node), env, ctx, memo)

      _other ->
        {:unknown, memo}
    end
  end

  defp value(_type, _node, _env, _ctx, memo), do: {:unknown, memo}

  defp call(@multi, :new, [], _env, _ctx, memo), do: {MapSet.new(), memo}

  defp call(@multi, name, [left, right], env, ctx, memo) when name in [:append, :prepend],
    do: all([{left, env}, {right, env}], ctx, memo)

  defp call(@multi, _name, [multi | _rest], env, ctx, memo), do: value(multi, env, ctx, memo)

  defp call(module, name, args, env, ctx, memo) do
    if {module, name} in @no_return,
      do: {MapSet.new(), memo},
      else: through({module, name, length(args)}, args, env, ctx, memo)
  end

  # A callee's roots are positions in its own head: here they are this call's
  # arguments at those positions.
  defp through(callee, args, env, ctx, memo) do
    case function(callee, ctx, memo) do
      {:unknown, memo} ->
        {:unknown, memo}

      {roots, memo} ->
        roots
        |> Enum.map(&{Enum.at(args, &1 - 1), env})
        |> all(ctx, memo)
    end
  end

  defp arguments(node, env, ctx, memo) do
    nodes = if :cerl.type(node) == :values, do: :cerl.values_es(node), else: [node]
    Enum.map_reduce(nodes, memo, &value(&1, env, ctx, &2))
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

  defp all(nodes, ctx, memo) do
    {values, memo} =
      Enum.map_reduce(nodes, memo, fn {node, env}, memo -> value(node, env, ctx, memo) end)

    {union(values), memo}
  end

  defp union(all) do
    Enum.reduce(all, MapSet.new(), fn
      :unknown, _acc -> :unknown
      _roots, :unknown -> :unknown
      roots, acc -> MapSet.union(acc, roots)
    end)
  end
end
