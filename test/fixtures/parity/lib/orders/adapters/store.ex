defmodule AnchorFixtures.Parity.Orders.Adapters.Store do
  # Forbidden: adapters may call managers of another context only, and this
  # is its own (Orders).
  def save(order), do: order

  def retry(order), do: AnchorFixtures.Parity.Orders.Managers.Checkout.run(order)
end
