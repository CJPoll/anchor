# Compliant: an adapter performs its effect.
defmodule AnchorFixtures.PlacementTest.Billing.Adapters.Store do
  def load(path), do: File.read(path)
end
