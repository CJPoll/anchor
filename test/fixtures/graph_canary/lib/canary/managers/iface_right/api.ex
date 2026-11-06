# interface (DND-5443): context AnchorFixtures.IfaceRight's interface (a
# managers module), the route to its domain module Rules.
defmodule AnchorFixtures.IfaceRight.Api do
  @moduledoc false
  alias AnchorFixtures.IfaceRight.Rules

  def check(x), do: Rules.allowed?(x)
end
