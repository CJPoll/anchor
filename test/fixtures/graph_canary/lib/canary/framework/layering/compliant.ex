# layering (DND-5442), compliant: framework -> managers, which the calls
# matrix allows.
defmodule AnchorFixtures.GraphCanary.Web.Compliant do
  @moduledoc false
  alias AnchorFixtures.GraphCanary.Orders

  def show(id), do: Orders.priced(id)
end
