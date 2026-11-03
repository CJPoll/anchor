defmodule AnchorFixtures.GraphCanary.Orders do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Pricing
  alias AnchorFixtures.GraphCanary.Orders.Store

  def priced(id), do: id |> Store.fetch() |> Pricing.with_tax()
end
