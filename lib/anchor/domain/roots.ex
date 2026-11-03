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

  ## The one code-server call

  An external behaviour's callbacks are its `behaviour_info(:callbacks)`,
  read through `Code.ensure_loaded?/1` (the stdlib or a dependency, never a
  project module: a behaviour the graph holds is a project one and is not
  asked). It is the one code-server call here, as in
  `Anchor.Domain.GraphRules.needs/1`. A behaviour that cannot be loaded gives
  no callbacks, so its implementations are judged rather than skipped: a
  miss reads as a finding, never as a pass. `roots/2` takes the lookup as an
  argument for tests.
  """

  alias Anchor.Domain.Architecture.Selector
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model

  @typedoc "The callbacks of a behaviour module, `[{name, arity}]`."
  @type callbacks_fun :: (module() -> [{atom(), arity()}])

  @doc """
  The roots of `model`, as a set of mfas. `callbacks` answers a behaviour's
  callbacks (default: its `behaviour_info(:callbacks)`, `[]` when it cannot be
  loaded).
  """
  @spec roots(Model.t(), callbacks_fun()) :: MapSet.t(mfa())
  def roots(%Model{} = model, callbacks \\ &external_callbacks/1) do
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
  The callbacks of `behaviour` (`[{name, arity}]`), read from the loaded
  module, or `[]` when it cannot be loaded or declares none.
  """
  @spec external_callbacks(module()) :: [{atom(), arity()}]
  def external_callbacks(behaviour) do
    if Code.ensure_loaded?(behaviour) and function_exported?(behaviour, :behaviour_info, 1),
      do: behaviour.behaviour_info(:callbacks),
      else: []
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
    |> Enum.any?(&(name_arity in callbacks.(&1)))
  end
end
