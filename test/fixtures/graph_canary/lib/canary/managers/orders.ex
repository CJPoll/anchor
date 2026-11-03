defmodule AnchorFixtures.GraphCanary.Orders do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Pricing
  alias AnchorFixtures.GraphCanary.Orders.Store

  def priced(id), do: id |> Store.fetch() |> Pricing.with_tax()

  # The canary's higher-order flow (DND-5574): an apply site inside
  # Enum.map/2, resolved to the capture &priced/1.
  def all_priced(ids), do: Enum.map(ids, &priced/1)
end
