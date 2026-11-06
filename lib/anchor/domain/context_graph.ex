defmodule Anchor.Domain.ContextGraph do
  @moduledoc """
  The module call graph collapsed to contexts (DND-5445) — a **Domain**
  module (ADR 001). Pure, over the run's `Anchor.Domain.Model`.

  Every call from one classified project module to another whose contexts are
  both known and differ is a context edge `A -> B`, keeping each call as a
  witness `{caller_mfa, callee_mfa, file, line}` (the file is the caller's
  source file). A dynamic call on a computed module gives an edge to the
  context of every project module exporting that function
  (`Anchor.Domain.DynamicCalls`). Not edges:

    * a call within one context (a self-loop is not a cycle);
    * a call to a module outside the project, or to an unclassified one;
    * a call where either context is nil (the classification reports those);
    * a dynamic call no project module exports: it reaches none of them;
    * a closure application (`fun.(x)`), left to the higher-order analysis.

  A call whose function name is computed (`apply(M, op, args)`,
  `mod.op_var(x)`) could reach any exported function, so its edges are
  unknown: it is listed in `unresolved` as `{caller_mfa, arity, file, line}`,
  sorted, for the rule to report, never dropped.

  `build/2` takes the callers to read, the modules a rule selects; `build/1`
  reads every classified module. Witnesses are sorted, so the first is the
  earliest by file and line.
  """

  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Model

  @type witness :: {mfa(), mfa(), String.t() | nil, pos_integer() | nil}
  @type unresolved :: {mfa(), arity() | nil, String.t() | nil, pos_integer() | nil}
  @type t :: %{
          nodes: [String.t()],
          edges: %{{String.t(), String.t()} => [witness()]},
          unresolved: [unresolved()]
        }

  @doc "The context graph of every classified caller of `model`."
  @spec build(Model.t()) :: t()
  def build(%Model{classification: classification} = model),
    do: build(model, Map.keys(classification))

  @doc "The context graph of the calls from `callers` (modules) in `model`."
  @spec build(Model.t(), [module()]) :: t()
  def build(%Model{} = model, callers) do
    callers = MapSet.new(callers)
    calls = Enum.filter(model.graph.calls, &MapSet.member?(callers, elem(&1.from, 0)))

    edges =
      calls
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

    %{nodes: nodes, edges: edges, unresolved: unresolved(calls, model)}
  end

  defp edges(%Call{to: {:dynamic, nil, _arity, _receiver}}, _model), do: []

  defp edges(%Call{from: from, to: {:dynamic, name, arity, _receiver}} = call, model) do
    model.graph
    |> DynamicCalls.targets(call)
    |> Enum.flat_map(&edge(from, {&1, name, arity}, call, model))
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

  # Every call with a computed function name but a closure application
  # (`fun.(x)`: an `:apply` through a `:variable`).
  defp unresolved(calls, model) do
    calls
    |> Enum.flat_map(fn
      %Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}} ->
        []

      %Call{from: {caller, _f, _a} = from, to: {:dynamic, nil, arity, _receiver}, line: line} ->
        file = model.classification |> Map.get(caller, %{}) |> Map.get(:source_file)
        [{from, arity, file, line}]

      %Call{} ->
        []
    end)
    |> Enum.uniq()
    |> Enum.sort_by(fn {from, arity, file, line} -> {file || "", line || 0, from, arity} end)
  end
end
