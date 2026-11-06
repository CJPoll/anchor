defmodule AnchorFixtures.Parity.Orders.Domain.Calc do
  # Forbidden, through apply/3 with a literal module: domain may not call
  # managers.
  def sum(order), do: apply(AnchorFixtures.Parity.Orders.Managers.Checkout, :run, [order])
end
