defmodule Anchor.Adapters.BehaviourSource do
  @moduledoc """
  Behaviour for reading the callbacks of behaviours defined outside the
  project — the **Side Effect** port (ADR 001) the graph runner asks before
  the effect inference (DND-5447), so `Anchor.Domain.Roots` stays pure.

  `callbacks/1` takes behaviour modules (a stdlib or dependency module such
  as `GenServer`, never a project one) and returns each one's callbacks,
  `[{name, arity}]`. A behaviour that cannot be loaded, or declares none, is
  `[]`: its implementations are then judged rather than skipped, so a miss
  reads as a finding, never as a pass. Every behaviour asked for is a key.
  The real adapter is `Anchor.Adapters.BehaviourReader`.
  """

  @callback callbacks(behaviours :: [module()]) :: %{optional(module()) => [{atom(), arity()}]}
end
