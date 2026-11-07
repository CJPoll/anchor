# Violating (dominated_by): only Statement calls it. And (dominator_subtree, DND-5462):
# Statement dominates it, so it belongs in lib/placement/domain/statement/.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Rounding do
  @spec round_cents(integer()) :: integer()
  def round_cents(cents), do: div(cents, 5) * 5
end
