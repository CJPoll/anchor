defmodule Anchor.Adapters.BehaviourReader do
  @moduledoc """
  Reads behaviours' callbacks through the code server — the **Side Effect**
  adapter behind `Anchor.Adapters.BehaviourSource` (DND-5447).

  Each behaviour is loaded with `Code.ensure_loaded?/1` and asked for its
  `behaviour_info(:callbacks)`. One that cannot be loaded, or is not a
  behaviour, gives `[]`.
  """

  @behaviour Anchor.Adapters.BehaviourSource

  @impl Anchor.Adapters.BehaviourSource
  def callbacks(behaviours), do: Map.new(behaviours, &{&1, callbacks_of(&1)})

  defp callbacks_of(behaviour) do
    if Code.ensure_loaded?(behaviour) and function_exported?(behaviour, :behaviour_info, 1),
      do: behaviour.behaviour_info(:callbacks),
      else: []
  end
end
