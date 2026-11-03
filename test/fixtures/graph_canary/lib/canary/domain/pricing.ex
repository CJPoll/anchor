defmodule AnchorFixtures.GraphCanary.Orders.Pricing do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Order

  def with_tax(order), do: Order.total(order) * 2

  # struct_owned_by_module_flow (DND-5454), compliant: a spec-known Order is
  # changed through its own module.
  def free(id), do: id |> Order.new() |> Order.put_total(0)
end
