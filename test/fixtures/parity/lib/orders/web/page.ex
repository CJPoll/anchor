defmodule AnchorFixtures.Parity.Orders.Web.Page do
  # Compliant: framework may call ui, managers and domain.
  alias AnchorFixtures.Parity.Orders.Ui.Card

  def show(order) do
    AnchorFixtures.Parity.Orders.Managers.Checkout.run(order)
    Card.render(order)
  end
end
