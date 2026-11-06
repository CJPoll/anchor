defmodule Anchor.Domain.Roots do
  @moduledoc """
  The entry points of a program (DND-5447) — **Domain**, over the model.

  A root is a function something outside the project calls, so its bucket is
  Framework whatever it causes:

    * every public function (`def`) of a module classified into a bucket whose
      role is `framework`;
    * every public function of a module an `architecture.roots` selector
      matches (the selectors the buckets use, over the module's
      classification facts, `Anchor.Domain.Model.facts`);
    * every function that implements a callback of a behaviour defined
      outside the project (`GenServer`, `Mix.Task`, `Credo.Check`, a protocol
      such as `Inspect`): a framework calls it. A callback of a project
      behaviour is not a root: its caller is in the project.

  A private function is never a root.

  ## External callbacks come in as data

  An external behaviour's callbacks are read by the runner through the
  `Anchor.Adapters.BehaviourSource` port (`behaviour_info(:callbacks)`), for
  exactly the behaviours `external_behaviours/1` names, and handed to
  `roots/2` as a map. This module never loads one. A behaviour missing from
  the map, or mapped to `[]`, gives no callbacks, so its implementations are
  judged rather than skipped: a miss reads as a finding, never as a pass.
  """

  alias Anchor.Domain.Architecture.Selector
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model

  @typedoc "Each external behaviour's callbacks, `%{behaviour => [{name, arity}]}`."
  @type callbacks :: %{module() => [{atom(), arity()}]}

  @doc """
  The roots of `model`, as a set of mfas. `callbacks` holds the external
  behaviours' callbacks (`Anchor.Adapters.BehaviourSource`); a behaviour it
  does not hold has none.
  """
  @spec roots(Model.t(), callbacks()) :: MapSet.t(mfa())
  def roots(%Model{} = model, callbacks) when is_map(callbacks) do
    project = model.graph.modules

    for {module, %ModuleNode{functions: functions} = node} <- project,
        {{name, arity}, %FunctionNode{kind: :def}} <- functions,
        root?(module, {name, arity}, node, model, callbacks),
        into: MapSet.new(),
        do: {module, name, arity}
  end

  @doc "Whether `mfa` is in `roots`."
  @spec root?(MapSet.t(mfa()), mfa()) :: boolean()
  def root?(roots, mfa), do: MapSet.member?(roots, mfa)

  @doc """
  The behaviours the project's modules declare that the graph does not hold
  (defined outside the project), sorted: what to ask the
  `Anchor.Adapters.BehaviourSource` port for.
  """
  @spec external_behaviours(Graph.t()) :: [module()]
  def external_behaviours(%Graph{modules: modules}) do
    modules
    |> Map.values()
    |> Enum.flat_map(& &1.behaviours)
    |> Enum.reject(&Map.has_key?(modules, &1))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp root?(module, name_arity, node, model, callbacks) do
    framework?(module, model) or selected_root?(module, model) or
      external_callback?(name_arity, node, model, callbacks)
  end

  defp framework?(module, model) do
    case Map.get(model.classification, module) do
      %{role: :framework} -> true
      _other -> false
    end
  end

  defp selected_root?(module, %Model{architecture: architecture, facts: facts}) do
    case Map.get(facts, module) do
      nil -> false
      module_facts -> Enum.any?(architecture.roots, &Selector.matches?(&1, module_facts))
    end
  end

  defp external_callback?(name_arity, %ModuleNode{behaviours: behaviours}, model, callbacks) do
    behaviours
    |> Enum.reject(&Map.has_key?(model.graph.modules, &1))
    |> Enum.any?(&(name_arity in Map.get(callbacks, &1, [])))
  end
end
