# interface (DND-5443), compliant: context AnchorFixtures.IfaceLeft calls
# AnchorFixtures.IfaceRight through its interface.
defmodule AnchorFixtures.IfaceLeft.Compliant do
  @moduledoc false
  alias AnchorFixtures.IfaceRight.Api

  def run(x), do: Api.check(x)
end
