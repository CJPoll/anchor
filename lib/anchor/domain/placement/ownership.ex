defmodule Anchor.Domain.Placement.Ownership do
  @moduledoc """
  Which struct owns a function, from its `@spec` and its slices (DND-5448) —
  **Domain**, pure over the graph.

  `output_owner/2` reads the return type: `S` when it is `%S{}`, a named type
  naming `S` (`S.t()`, read through `Anchor.Domain.StructTypes`), or a union whose
  non-error members are `{:ok, S-type}` or `S-type` (an error member is
  `{:error, _}`, `:error` or `nil`).

  `input_owner/3` applies only when the return type is a primitive. It takes the
  parameters the spec types as a project struct and keeps those on the backward
  slice of the return value in **every** clause; exactly one distinct struct left
  is the owner.

  ## The slice reads the beam's clauses

  A clause is the function's expanded `elixir_v1` clause
  (`Anchor.Domain.Graph.FunctionNode.clauses`), the shape `Anchor.Domain.DataFlow`
  reads. A function with no clause to read has no slice: `:unjoined`, counted by
  the caller.

  A guard that reads a parameter decides the result, so it counts as on the slice.
  Matching a head against `%S{}` with no variable binds nothing, so that parameter
  is not on the slice.

  ## The answers

  An owner is `{:ok, S}`. No owner has a reason, counted in the run's precision:
  `:no_spec`, `:ambiguous` (two different structs), `:unjoined`, or `:none` (the
  types name no project struct, or none is on the slice).
  """

  alias Anchor.Domain.DataFlow
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.StructTypes

  @primitives ~w(atom binary boolean float integer neg_integer non_neg_integer number pos_integer)a

  @type answer :: {:ok, module()} | :none | :no_spec | :ambiguous | :unjoined

  @doc "The struct whose module owns `mfa` by its return type; see the moduledoc."
  @spec output_owner(Graph.t(), mfa()) :: answer()
  def output_owner(%Graph{} = graph, {module, name, arity}) do
    case Map.fetch(specs(graph, module), {name, arity}) do
      {:ok, [_ | _] = clauses} ->
        clauses
        |> Enum.flat_map(&return_structs(&1, module, graph))
        |> owner_of()

      _no_spec ->
        :no_spec
    end
  end

  @doc "The struct whose module owns `mfa` by the input its result is computed from."
  @spec input_owner(Graph.t(), mfa(), FunctionNode.t()) :: answer()
  def input_owner(%Graph{} = graph, {module, name, arity}, %FunctionNode{} = function) do
    case Map.fetch(specs(graph, module), {name, arity}) do
      {:ok, [_ | _] = specs} -> typed_input_owner(specs, module, graph, function)
      _no_spec -> :no_spec
    end
  end

  @doc "Whether the spec type `type` is a primitive: what `input_owner/3` judges."
  @spec primitive?(Macro.t()) :: boolean()
  def primitive?(type) do
    type |> alternatives() |> Enum.all?(&primitive_member?/1)
  end

  defp typed_input_owner(specs, module, graph, function) do
    if Enum.all?(specs, &primitive_return?/1),
      do: sliced_owner(struct_params(specs, module, graph), function),
      else: :none
  end

  defp sliced_owner([], _function), do: :none
  defp sliced_owner(_params, %FunctionNode{clauses: []}), do: :unjoined

  defp sliced_owner(params, %FunctionNode{clauses: clauses}) do
    params
    |> Enum.filter(fn {index, _struct} -> Enum.all?(clauses, &on_slice?(&1, index)) end)
    |> Enum.map(&elem(&1, 1))
    |> owner_of()
  end

  defp owner_of(structs) do
    case Enum.uniq(structs) do
      [] -> :none
      [nil] -> :none
      [struct] -> {:ok, struct}
      several -> if nil in several, do: :none, else: :ambiguous
    end
  end

  # The one struct, or none, each non-error member of the return type names. A
  # member naming no struct is `nil`: such a union has no owner.
  defp return_structs(spec, module, graph) do
    spec
    |> spec_parts()
    |> elem(1)
    |> alternatives()
    |> Enum.reject(&error_member?/1)
    |> Enum.map(&StructTypes.struct_of(unwrap_ok(&1), module, graph))
  end

  defp primitive_return?(spec), do: spec |> spec_parts() |> elem(1) |> primitive?()

  # `{index, struct}` for each parameter a spec types as a project struct.
  defp struct_params(specs, module, graph) do
    specs
    |> Enum.flat_map(&spec_params(&1, module, graph))
    |> Enum.uniq()
  end

  defp spec_params(spec, module, graph) do
    {args, _return} = spec_parts(spec)

    for {arg, index} <- Enum.with_index(args),
        struct = StructTypes.struct_of(param_type(arg), module, graph),
        struct != nil,
        do: {index, struct}
  end

  defp param_type({:"::", _meta, [_name, type]}), do: type
  defp param_type(type), do: type

  defp spec_parts({:when, _meta, [spec, _bindings]}), do: spec_parts(spec)

  defp spec_parts({:"::", _meta, [{_name, _call_meta, args}, return]}) when is_list(args),
    do: {args, return}

  defp spec_parts(_other), do: {[], nil}

  defp alternatives({:|, _meta, [left, right]}), do: alternatives(left) ++ alternatives(right)
  defp alternatives(type), do: [type]

  defp error_member?(member) when member in [:error, nil], do: true
  defp error_member?({:error, _reason}), do: true
  defp error_member?({:{}, _meta, [:error | _rest]}), do: true
  defp error_member?(_member), do: false

  defp unwrap_ok({:ok, type}), do: type
  defp unwrap_ok({:{}, _meta, [:ok, type]}), do: type
  defp unwrap_ok(type), do: type

  defp primitive_member?(atom) when is_atom(atom), do: atom != nil
  defp primitive_member?({name, _meta, []}) when name in @primitives, do: true
  defp primitive_member?({{:., _meta, [String, :t]}, _call_meta, []}), do: true
  defp primitive_member?(_type), do: false

  defp on_slice?({_meta, args, guards, body}, index) do
    flow = DataFlow.analyze({args, guards, body})
    live = DataFlow.backward_slice(flow, DataFlow.result_nodes(flow))
    used = live |> Enum.flat_map(&flow.nodes[&1].uses) |> Kernel.++(flow.guard_uses)
    names = args |> Enum.at(index) |> head_variables()

    Enum.any?(flow.params, fn {name, context, _version} = key ->
      {name, context} in names and key in used
    end)
  end

  defp head_variables(arg) do
    {_ast, names} =
      Macro.prewalk(arg, [], fn
        {name, _meta, context} = var, names when is_atom(name) and is_atom(context) ->
          {var, [{name, context} | names]}

        other, names ->
          {other, names}
      end)

    names
  end

  defp specs(%Graph{modules: modules}, module) do
    case Map.get(modules, module) do
      %ModuleNode{specs: specs} -> specs
      nil -> %{}
    end
  end
end
