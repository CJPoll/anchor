defmodule Anchor.Domain.BehaviourReceiver do
  @moduledoc """
  The behaviour a dynamic call's receiver is declared to implement (DND-5633)
  — a **Domain** module (ADR 001), pure over the graph.

  A dynamic call `recv.f(args)` reaches whatever module `recv` holds at run
  time, so `Anchor.Domain.DynamicCalls` judges it against every project module
  exporting `f/arity`. The 0-CFA (`Anchor.Domain.Cfa`) follows closures, not
  module atoms, so it leaves a module receiver `any`; a receiver that is a port
  read from options (`Keyword.get(opts, :port, Default)`) is `any` in any case,
  since the options come from outside. This module is the second way to narrow
  such a call, and it narrows only on declared evidence, never on the function
  name alone:

    * `recv` is a parameter of the calling function, used as nothing but that
      parameter: no other binding in the function (a nested `fn`, a `let`, a
      clause pattern) has its name, and every call of `f/arity` in the
      function on a variable receiver is on such a parameter;
    * the function has exactly one `@spec`, and it types each of those
      parameters as `B.t()` for one module `B` of the project;
    * `B` declares `@type t :: module()` and `f/arity` among its
      `@callback`s.

  Then the call's targets are the project modules that declare `@behaviour B`
  and export `f/arity` (`implementers/3`). Anything short of that is `:none`,
  and the call keeps the full over-approximation. A `@spec` is a declaration,
  not a proof: a caller can still pass any module, and Dialyzer, not Anchor,
  checks the spec against its callers.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  @doc """
  `{:ok, behaviour}` when `call` (a dynamic call on a variable, with a known
  name and arity) is on a parameter the caller's `@spec` types as
  `behaviour.t()`, a project behaviour with that callback; `:none` otherwise.
  """
  @spec behaviour(Graph.t(), Call.t()) :: {:ok, module()} | :none
  def behaviour(%Graph{} = graph, %Call{from: from, to: {:dynamic, name, arity, :variable}})
      when is_atom(name) and name != nil and is_integer(arity) do
    with {:ok, node, function} <- caller(graph, from),
         {:ok, indexes} <- receiver_params(function.core, name, arity),
         {:ok, behaviour} <- spec_behaviour(node, from, indexes),
         true <- contract?(Map.get(graph.modules, behaviour), name, arity) do
      {:ok, behaviour}
    else
      _no_evidence -> :none
    end
  end

  def behaviour(%Graph{}, %Call{}), do: :none

  @doc "The project modules declaring `@behaviour behaviour` that export `name/arity`, sorted."
  @spec implementers(Graph.t(), module(), {atom(), arity()}) :: [module()]
  def implementers(%Graph{modules: modules}, behaviour, {name, arity}) do
    modules
    |> Enum.filter(fn {_module, %ModuleNode{behaviours: behaviours, functions: functions}} ->
      behaviour in behaviours and
        match?(%FunctionNode{kind: :def}, Map.get(functions, {name, arity}))
    end)
    |> Enum.map(fn {module, _node} -> module end)
    |> Enum.sort()
  end

  defp caller(graph, {module, name, arity}) do
    with %ModuleNode{functions: functions} = node <- Map.get(graph.modules, module),
         %FunctionNode{core: core} = function when core != nil <-
           Map.get(functions, {name, arity}) do
      {:ok, node, function}
    else
      _missing -> :none
    end
  end

  # The parameter positions of the function's every `call V:'name'(args)` on
  # a variable `V` with `arity` arguments; `:none` when one is on a variable
  # that is not a parameter, or a parameter's name is bound again inside.
  defp receiver_params(core, name, arity) do
    {aliases, nested, inner} = parameters(core)
    rebound = inner |> Enum.map(&rebound/1) |> Enum.reduce(nested, &MapSet.union/2)

    receivers =
      Enum.flat_map(inner, fn tree ->
        :cerl_trees.fold(
          fn node, acc ->
            if call_on_var?(node, name, arity), do: [var(node) | acc], else: acc
          end,
          [],
          tree
        )
      end)

    indexes = Enum.map(receivers, &Map.get(aliases, &1))

    cond do
      receivers == [] -> :none
      nil in indexes -> :none
      Enum.any?(receivers, &MapSet.member?(rebound, &1)) -> :none
      true -> {:ok, Enum.uniq(indexes)}
    end
  end

  # The names that hold parameter `i`, `%{name => i}`: the Core parameters
  # themselves and, since Elixir compiles a function's clauses into one
  # `case <_0, _1> of <Suite, Args> -> ...`, a clause pattern that is a bare
  # variable at position `i`. Also the variables nested deeper in those
  # patterns (bound, so never a parameter's alias) and the trees left to walk
  # (each clause's guard and body, or the whole body).
  defp parameters(core) do
    params = core |> :cerl.fun_vars() |> Enum.map(&:cerl.var_name/1)
    direct = params |> Enum.with_index() |> Map.new()
    body = :cerl.fun_body(core)

    if dispatch?(body, params) do
      clauses = :cerl.case_clauses(body)

      aliases =
        for clause <- clauses,
            {pattern, index} <- Enum.with_index(:cerl.clause_pats(clause)),
            :cerl.is_c_var(pattern),
            into: direct,
            do: {:cerl.var_name(pattern), index}

      nested =
        for clause <- clauses,
            pattern <- :cerl.clause_pats(clause),
            not :cerl.is_c_var(pattern),
            name <- :cerl_trees.variables(pattern),
            into: MapSet.new(),
            do: name

      inner = Enum.flat_map(clauses, &[:cerl.clause_guard(&1), :cerl.clause_body(&1)])
      {aliases, nested, inner}
    else
      {direct, MapSet.new(), [body]}
    end
  end

  # `case <_0, ..., _n> of ...` over exactly the parameters, in order.
  defp dispatch?(body, params) do
    :cerl.is_c_case(body) and
      body |> :cerl.case_arg() |> argument_names() == params
  end

  defp argument_names(arg) do
    vars = if :cerl.is_c_values(arg), do: :cerl.values_es(arg), else: [arg]
    if Enum.all?(vars, &:cerl.is_c_var/1), do: Enum.map(vars, &:cerl.var_name/1), else: nil
  end

  defp call_on_var?(node, name, arity) do
    :cerl.is_c_call(node) and :cerl.is_c_var(:cerl.call_module(node)) and
      :cerl.is_literal(:cerl.call_name(node)) and
      :cerl.concrete(:cerl.call_name(node)) == name and :cerl.call_arity(node) == arity
  end

  defp var(node), do: node |> :cerl.call_module() |> :cerl.var_name()

  # Every variable name bound inside the body: a nested fun's parameters, a
  # let's variables, a clause's pattern variables, a try's and a receive's.
  defp rebound(body) do
    :cerl_trees.fold(
      fn node, acc -> Enum.reduce(bound_by(node), acc, &MapSet.put(&2, &1)) end,
      MapSet.new(),
      body
    )
  end

  defp bound_by(node) do
    case :cerl.type(node) do
      :fun -> names(:cerl.fun_vars(node))
      :let -> names(:cerl.let_vars(node))
      :clause -> node |> :cerl.clause_pats() |> Enum.flat_map(&:cerl_trees.variables/1)
      :try -> names(:cerl.try_vars(node) ++ :cerl.try_evars(node))
      :catch -> []
      _other -> []
    end
  end

  defp names(vars), do: Enum.map(vars, &:cerl.var_name/1)

  # The one module `B` the function's one spec types every receiver position
  # as `B.t()`.
  defp spec_behaviour(%ModuleNode{specs: specs}, {_module, name, arity}, indexes) do
    with [{:"::", _meta, [{^name, _call_meta, args}, _return]}] when length(args) == arity <-
           Map.get(specs, {name, arity}),
         [behaviour] <- indexes |> Enum.map(&remote_t(Enum.at(args, &1))) |> Enum.uniq(),
         true <- is_atom(behaviour) and behaviour != nil do
      {:ok, behaviour}
    else
      _other -> :none
    end
  end

  defp remote_t({{:., _dot_meta, [module, :t]}, _meta, []}) when is_atom(module), do: module
  defp remote_t(_type), do: nil

  # A project module declaring `@type t :: module()` and the callback.
  defp contract?(%ModuleNode{types: types, callbacks: callbacks}, name, arity) do
    {name, arity} in callbacks and module_type?(Map.get(types, {:t, 0}))
  end

  defp contract?(nil, _name, _arity), do: false

  defp module_type?({:type, {:"::", _meta, [{:t, _t_meta, []}, {:module, _m_meta, []}]}}),
    do: true

  defp module_type?(_other), do: false
end
