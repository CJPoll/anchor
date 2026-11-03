defmodule Anchor.Domain.ContextGraph do
  @moduledoc """
  The module call graph collapsed to contexts (DND-5445) — a **Domain**
  module (ADR 001). Pure, over the run's `Anchor.Domain.Model`.

  Every call from one classified project module to another whose contexts are
  both known and differ is a context edge `A -> B`, keeping each call as a
  witness `{caller_mfa, callee_mfa, file, line}` (the file is the caller's
  source file). A dynamic call resolved through behaviours
  (`Anchor.Domain.DynamicCalls`) gives an edge to each candidate's context. Not
  edges:

    * a call within one context (a self-loop is not a cycle);
    * a call to a module outside the project, or to an unclassified one;
    * a call where either context is nil (the classification reports those);
    * a dynamic call no behaviour resolves, a computed function name, and a
      closure application: their target is unknown here, and `layering`
      reports every one but the closure.

  `build/2` takes the callers to read, the modules a rule selects; `build/1`
  reads every classified module. Witnesses are sorted, so the first is the
  earliest by file and line.
  """

  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Model

  @type witness :: {mfa(), mfa(), String.t() | nil, pos_integer() | nil}
  @type t :: %{nodes: [String.t()], edges: %{{String.t(), String.t()} => [witness()]}}

  @doc "The context graph of every classified caller of `model`."
  @spec build(Model.t()) :: t()
  def build(%Model{classification: classification} = model),
    do: build(model, Map.keys(classification))

  @doc "The context graph of the calls from `callers` (modules) in `model`."
  @spec build(Model.t(), [module()]) :: t()
  def build(%Model{} = model, callers) do
    callers = MapSet.new(callers)

    edges =
      model.graph.calls
      |> Enum.filter(&MapSet.member?(callers, elem(&1.from, 0)))
      |> Enum.flat_map(&edges(&1, model))
      |> Enum.group_by(fn {edge, _witness} -> edge end, fn {_edge, witness} -> witness end)
      |> Map.new(fn {edge, witnesses} ->
        {edge, witnesses |> Enum.uniq() |> Enum.sort_by(&order/1)}
      end)

    nodes =
      edges
      |> Map.keys()
      |> Enum.flat_map(fn {from, to} -> [from, to] end)
      |> Enum.uniq()
      |> Enum.sort()

    %{nodes: nodes, edges: edges}
  end

  defp edges(%Call{to: {:dynamic, nil, _arity, _receiver}}, _model), do: []

  defp edges(%Call{from: from, to: {:dynamic, name, arity, _receiver}} = call, model) do
    case DynamicCalls.candidates(model.graph, {name, arity}) do
      :unresolved -> []
      {:ok, candidates} -> Enum.flat_map(candidates, &edge(from, {&1, name, arity}, call, model))
    end
  end

  defp edges(%Call{from: from, to: {_module, _name, _arity} = to} = call, model),
    do: edge(from, to, call, model)

  defp edge({caller, _f, _a} = from, {callee, _g, _b} = to, call, model) do
    with %{context: a, source_file: file} when is_binary(a) <-
           Map.get(model.classification, caller),
         %{context: b} when is_binary(b) and a != b <- Map.get(model.classification, callee) do
      [{{a, b}, {from, to, file, call.line}}]
    else
      _not_an_edge -> []
    end
  end

  defp order({from, to, file, line}), do: {file || "", line || 0, from, to}
end
