defmodule AnchorFixtures.GraphCanary.Orders.Rebate do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Order

  # struct_owned_by_module_flow (DND-5454), violating: Order.new/1's @spec
  # says it returns an Order, and Rebate changes it with Map.put/3.
  def free(id), do: id |> Order.new() |> Map.put(:total, 0)
end
