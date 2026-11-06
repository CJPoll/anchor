defmodule AnchorFixtures.Parity.Orders.Domain.Rules do
  # Forbidden, through a capture: domain may not call adapters.
  def saver, do: &AnchorFixtures.Parity.Orders.Adapters.Store.save/1
end
