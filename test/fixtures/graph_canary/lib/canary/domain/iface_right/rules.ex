# interface (DND-5443): a domain module of context AnchorFixtures.IfaceRight,
# not part of its interface.
defmodule AnchorFixtures.IfaceRight.Rules do
  @moduledoc false
  def allowed?(x), do: x != nil
end
