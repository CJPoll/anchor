defmodule Anchor.Domain.Interfaces do
  @moduledoc """
  A context's interface over the run's model (DND-5443, shared contract
  section 3.1) — a **Domain** module (ADR 001). Pure.

  A module is its context's interface when its bucket is one of
  `architecture: interfaces.buckets` or it is listed in `interfaces.exports`
  (`Anchor.Domain.Classification`'s `interface?`, set once, when the model is
  built). This module answers the questions the `interface` graph rule and
  `mix anchor.explain` ask about it:

    * `modules_of/2` — the interface modules of one context, sorted;
    * `width/1` — per context, how many public functions its interface
      modules export, for the run summary and a later ratchet (`max_width`).
      A function the compiler generates (`__struct__/0,1`, `__info__/1`,
      `module_info/0,1`, `behaviour_info/1`, any `__name__`) is not counted:
      it is not something an author chose to expose;
    * `route/2` — the one interface module of a target's context that reaches
      the target through calls inside that context, so a finding can say
      "call that instead". Two or more such modules, or none, is `:none`: the
      route would be a guess.
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Model

  @generated ~w(module_info behaviour_info)a

  @doc "The interface modules of `context` among the model's classified modules, sorted."
  @spec modules_of(Model.t(), String.t()) :: [module()]
  def modules_of(%Model{classification: classification}, context) do
    modules =
      for {module, %Classification{context: ^context, interface?: true}} <- classification,
          do: module

    Enum.sort(modules)
  end

  @doc """
  Per context of the model's classified modules, the number of public
  functions its interface modules export (generated ones not counted). A
  context with no interface module is 0; a module with no context is not
  counted anywhere.
  """
  @spec width(Model.t()) :: %{String.t() => non_neg_integer()}
  def width(%Model{classification: classification, graph: graph}) do
    classification
    |> Map.values()
    |> Enum.reject(&is_nil(&1.context))
    |> Enum.reduce(%{}, fn class, acc ->
      Map.update(
        acc,
        class.context,
        public_count(class, graph),
        &(&1 + public_count(class, graph))
      )
    end)
  end

  @doc """
  `{:ok, module}` when exactly one interface module of `target`'s context
  reaches `target` through calls between modules of that context (a
  breadth-first walk backwards from `target`); `:none` when no interface
  module does, two or more do, or `target` has no context.
  """
  @spec route(Model.t(), module()) :: {:ok, module()} | :none
  def route(%Model{classification: classification} = model, target) do
    case Map.get(classification, target) do
      %Classification{context: context} when is_binary(context) ->
        callers = same_context_callers(model, context)

        callers
        |> reaching([target], MapSet.new([target]))
        |> MapSet.delete(target)
        |> Enum.filter(&interface?(classification, &1))
        |> Enum.sort()
        |> one()

      _no_context ->
        :none
    end
  end

  defp one([module]), do: {:ok, module}
  defp one(_none_or_several), do: :none

  defp interface?(classification, module),
    do: match?(%Classification{interface?: true}, Map.get(classification, module))

  # `seen` and every module that reaches one of `frontier` through `callers`
  # (breadth first; each module visited once, so a call cycle ends).
  defp reaching(_callers, [], seen), do: seen

  defp reaching(callers, frontier, seen) do
    next =
      frontier
      |> Enum.flat_map(&Map.get(callers, &1, []))
      |> Enum.reject(&MapSet.member?(seen, &1))
      |> Enum.uniq()

    reaching(callers, next, MapSet.union(seen, MapSet.new(next)))
  end

  # `%{callee => [caller]}` over static calls whose two modules are distinct
  # and both in `context`.
  defp same_context_callers(%Model{graph: graph, classification: classification}, context) do
    in_context = fn module ->
      match?(%Classification{context: ^context}, Map.get(classification, module))
    end

    graph.calls
    |> Enum.flat_map(fn
      %Call{from: {caller, _f, _a}, to: {callee, _g, _b}}
      when is_atom(callee) and caller != callee ->
        if in_context.(caller) and in_context.(callee), do: [{callee, caller}], else: []

      _dynamic_or_self ->
        []
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp public_count(%Classification{interface?: false}, _graph), do: 0

  defp public_count(%Classification{module: module}, graph) do
    case Map.get(graph.modules, module) do
      nil -> 0
      node -> Enum.count(node.functions, &authored_public?/1)
    end
  end

  defp authored_public?({{name, _arity}, %FunctionNode{kind: :def}}),
    do: not generated_name?(name)

  defp authored_public?(_function), do: false

  defp generated_name?(name) when name in @generated, do: true

  defp generated_name?(name) do
    text = Atom.to_string(name)
    String.starts_with?(text, "__") and String.ends_with?(text, "__")
  end
end
