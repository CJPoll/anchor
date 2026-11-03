# interface (DND-5443), violating: context AnchorFixtures.IfaceLeft calls a
# domain module of AnchorFixtures.IfaceRight, past its interface.
defmodule AnchorFixtures.IfaceLeft.Violating do
  @moduledoc false
  alias AnchorFixtures.IfaceRight.Rules

  def run(x), do: Rules.allowed?(x)
end
