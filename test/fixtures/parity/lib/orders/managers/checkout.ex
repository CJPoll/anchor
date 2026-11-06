defmodule AnchorFixtures.Parity.Orders.Managers.Checkout do
  # Compliant: managers may call adapters and domain.
  def run(order) do
    AnchorFixtures.Parity.Orders.Adapters.Store.save(order)
    AnchorFixtures.Parity.Orders.Domain.Order.total(order)
  end
end
