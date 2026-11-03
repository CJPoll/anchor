# context_acyclic (DND-5445), compliant on its own: context
# AnchorFixtures.CycleA calls AnchorFixtures.CycleB, one way.
defmodule AnchorFixtures.CycleA do
  @moduledoc false
  def a(x), do: AnchorFixtures.CycleB.b(x)
end
