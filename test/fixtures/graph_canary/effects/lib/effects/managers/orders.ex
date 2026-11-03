defmodule AnchorFixtures.EffectsCanary.Orders do
  @moduledoc false
  alias AnchorFixtures.EffectsCanary.Store

  # Compliant: reaches the effect only through the adapter.
  def load(path), do: Store.fetch(path)
end
