defmodule Anchor.Domain.Core do
  @moduledoc """
  Pure helpers over one function's Core Erlang (`:cerl`) — **Domain**
  (DND-5497). They name what the 0-CFA (`Anchor.Domain.Cfa`) tracks — the
  lambdas, the apply sites and the containers' allocation sites — with
  ordinals that are stable for identical Core.

  `label/1` walks the function's body once, in pre-order
  (`:cerl_trees.mapfold/4`), keeping three ordinal sequences, each counted
  from 0 in order of appearance, and annotates

    * every `fun` inside the body with `{:anchor_lambda, ordinal}`. The
      function's own `fun` is not one of them. A `letrec` definition (the loop
      Core makes of a `receive`, or of a comprehension over a binary) is a
      `fun` too, so it is a lambda with its own ordinal;
    * every apply site with `{:anchor_sites, [ordinal]}`. A site is
        * `apply E(...)` where `E` is not a function name (`fun.(x)`, and an
          apply of any computed value): one site;
        * `call 'erlang':'apply'(F, Args)` (`apply/2`): one site;
        * a call to a function `Anchor.Domain.HigherOrder` lists
          (`Enum.map(list, fun)`): one site per invoked argument, in the
          table's order.

      `apply 'f'/a(...)` (a local or `letrec` call) and `apply/3` are calls,
      not apply sites;
    * every node that builds a container with `{:anchor_alloc, ordinal}`: a
      tuple, a cons, a map, a `maps:put/3` or `Map.put/3` call, and a literal
      container that holds a fun (a pattern is labelled too; nothing reads
      its label).

  `lambdas/1`, `apply_sites/2`, `lambda_ordinal/1`, `site_ordinals/1` and
  `alloc_ordinal/1` read those annotations back, so the 0-CFA and its
  consumers share one numbering.
  """

  alias Anchor.Domain.HigherOrder

  @labels [:anchor_lambda, :anchor_sites, :anchor_alloc]
  @map_puts [{:maps, :put, 3}, {Map, :put, 3}]

  @typedoc "An apply site: the enclosing function and the site's ordinal in it."
  @type site_id :: {mfa(), non_neg_integer()}

  @doc "The allocation ordinal of a labelled container node, or `nil`."
  @spec alloc_ordinal(:cerl.cerl()) :: non_neg_integer() | nil
  def alloc_ordinal(node), do: label_value(node, :anchor_alloc, nil)

  @doc """
  The apply sites of `core_fun`, the Core `c_fun` of `mfa`, as
  `[{site_id, node}]` in ordinal order. A call that invokes two arguments
  (`Enum.group_by/3`) is two entries with the same node.
  """
  @spec apply_sites(mfa(), :cerl.cerl()) :: [{site_id(), :cerl.cerl()}]
  def apply_sites(mfa, core_fun) do
    core_fun
    |> label()
    |> collect(fn node -> node |> site_ordinals() |> Enum.map(&{{mfa, &1}, node}) end)
    |> Enum.sort_by(fn {{_mfa, ordinal}, _node} -> ordinal end)
  end

  @doc "The `{module, name, arity}` of a `call` with a literal module and name, else `nil`."
  @spec call_mfa(:cerl.cerl()) :: mfa() | nil
  def call_mfa(node) do
    module = :cerl.call_module(node)
    name = :cerl.call_name(node)

    with true <- :cerl.is_literal(module) and :cerl.is_literal(name),
         m when is_atom(m) <- :cerl.concrete(module),
         f when is_atom(f) <- :cerl.concrete(name) do
      {m, f, length(:cerl.call_args(node))}
    else
      _not_literal -> nil
    end
  end

  @doc """
  Annotates `core_fun` with lambda, apply-site and allocation ordinals (see
  the moduledoc). Labelling labelled Core again gives the same ordinals.
  """
  @spec label(:cerl.cerl()) :: :cerl.cerl()
  def label(core_fun) do
    body = :cerl.fun_body(core_fun)
    {body, _counters} = :cerl_trees.mapfold(&label_node/2, &{&1, &2}, {0, 0, 0}, body)
    :cerl.update_c_fun(core_fun, :cerl.fun_vars(core_fun), body)
  end

  @doc "The lambda ordinal of a labelled `fun` node, or `nil`."
  @spec lambda_ordinal(:cerl.cerl()) :: non_neg_integer() | nil
  def lambda_ordinal(node), do: label_value(node, :anchor_lambda, nil)

  @doc """
  The lambdas inside `core_fun`, as `[{ordinal, c_fun}]` in ordinal order (the
  function's own `fun` is not one).
  """
  @spec lambdas(:cerl.cerl()) :: [{non_neg_integer(), :cerl.cerl()}]
  def lambdas(core_fun) do
    core_fun
    |> label()
    |> collect(fn node ->
      case lambda_ordinal(node) do
        nil -> []
        ordinal -> [{ordinal, node}]
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  The source line of `node`'s Core annotation, else of the first annotated
  node inside it (pre-order), else `nil`. Line 0 (the compiler's mark for
  generated code) is no line.
  """
  @spec line(:cerl.cerl()) :: pos_integer() | nil
  def line(node) do
    case own_line(node) do
      nil -> node |> :cerl.subtrees() |> List.flatten() |> Enum.find_value(&line/1)
      line -> line
    end
  end

  @doc """
  The apply-site ordinals a labelled node carries (`[]` for a node that is no
  apply site).
  """
  @spec site_ordinals(:cerl.cerl()) :: [non_neg_integer()]
  def site_ordinals(node), do: label_value(node, :anchor_sites, [])

  # --- labelling ---------------------------------------------------------------

  defp label_node(node, {lambdas, sites, allocs}) do
    node = strip_labels(node)

    {node, lambdas} =
      if :cerl.type(node) == :fun, do: add(node, :anchor_lambda, lambdas), else: {node, lambdas}

    {node, sites} = label_sites(node, site_count(node), sites)

    {node, allocs} =
      if alloc?(node), do: add(node, :anchor_alloc, allocs), else: {node, allocs}

    {node, {lambdas, sites, allocs}}
  end

  defp add(node, key, ordinal), do: {:cerl.add_ann([{key, ordinal}], node), ordinal + 1}

  defp label_sites(node, 0, sites), do: {node, sites}

  defp label_sites(node, count, sites) do
    ordinals = Enum.to_list(sites..(sites + count - 1)//1)
    {:cerl.add_ann([{:anchor_sites, ordinals}], node), sites + count}
  end

  defp strip_labels(node) do
    annotation =
      Enum.reject(:cerl.get_ann(node), fn
        {key, _value} -> key in @labels
        _other -> false
      end)

    :cerl.set_ann(node, annotation)
  end

  defp site_count(node) do
    case :cerl.type(node) do
      :apply -> if :cerl.is_c_fname(:cerl.apply_op(node)), do: 0, else: 1
      :call -> call_site_count(call_mfa(node))
      _other -> 0
    end
  end

  defp call_site_count({:erlang, :apply, 2}), do: 1
  defp call_site_count(nil), do: 0
  defp call_site_count(mfa), do: length(HigherOrder.invocations(mfa))

  defp alloc?(node) do
    case :cerl.type(node) do
      type when type in [:tuple, :cons, :map] -> true
      :call -> call_mfa(node) in @map_puts
      :literal -> container_holding_fun?(:cerl.concrete(node))
      _other -> false
    end
  end

  defp container_holding_fun?(term),
    do: (is_tuple(term) or is_list(term) or is_map(term)) and holds_fun?(term)

  defp holds_fun?(term) when is_function(term), do: true

  defp holds_fun?(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.any?(&holds_fun?/1)

  defp holds_fun?(term) when is_map(term), do: term |> Map.to_list() |> Enum.any?(&holds_fun?/1)
  defp holds_fun?([head | tail]), do: holds_fun?(head) or holds_fun?(tail)
  defp holds_fun?(_term), do: false

  # --- reading -----------------------------------------------------------------

  defp collect(tree, fun) do
    (&[fun.(&1) | &2])
    |> :cerl_trees.fold([], tree)
    |> Enum.reverse()
    |> List.flatten()
  end

  defp label_value(node, key, default) do
    case List.keyfind(:cerl.get_ann(node), key, 0) do
      {^key, value} -> value
      nil -> default
    end
  end

  defp own_line(node) do
    Enum.find_value(:cerl.get_ann(node), fn
      line when is_integer(line) and line > 0 -> line
      {line, column} when is_integer(line) and line > 0 and is_integer(column) -> line
      _other -> nil
    end)
  end
end
