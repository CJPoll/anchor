defmodule AnchorFixtures.Parity.Orders.Ui.Card do
  # Compliant: ui may call domain.
  def render(order), do: AnchorFixtures.Parity.Orders.Domain.Order.total(order)
end
