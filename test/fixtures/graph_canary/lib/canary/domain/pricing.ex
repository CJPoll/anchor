defmodule AnchorFixtures.GraphCanary.Orders.Pricing do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Order

  def with_tax(order), do: Order.total(order) * 2
end
