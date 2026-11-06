defmodule AnchorFixtures.Parity.Orders.Ui.Badge do
  # Forbidden, through an alias: ui may not call managers. The alias names a
  # namespace no bucket selects, so only alias resolution makes M.Checkout
  # the forbidden module.
  alias AnchorFixtures.Parity.Orders.Managers, as: M

  def label(order), do: M.Checkout.run(order)
end
