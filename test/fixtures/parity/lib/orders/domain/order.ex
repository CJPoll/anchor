defmodule AnchorFixtures.Parity.Orders.Domain.Order do
  # Compliant itself (domain may call domain), but it reaches Checkout
  # through Calc: a transitive finding.
  def total(order), do: AnchorFixtures.Parity.Orders.Domain.Calc.sum(order)
end
