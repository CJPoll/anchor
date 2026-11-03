# layering (DND-5442), violating: framework -> adapters, which the calls
# matrix forbids (the route is framework -> managers -> adapters).
defmodule AnchorFixtures.GraphCanary.Web.Violating do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders.Store

  def show(id), do: Store.fetch(id)
end
