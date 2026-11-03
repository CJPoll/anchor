# context_acyclic (DND-5445), violating: AnchorFixtures.CycleB calls back
# into AnchorFixtures.CycleA, closing a two-context cycle.
defmodule AnchorFixtures.CycleB do
  @moduledoc false
  def b(x), do: x
  def back(x), do: AnchorFixtures.CycleA.a(x)
end
