defmodule AnchorFixtures.GraphCanary.Orders.Store do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Order

  def fetch(id), do: Order.new(id)
end
