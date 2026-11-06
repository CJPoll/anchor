# Violating (dominated_by): only Statement calls it.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Rounding do
  @spec round_cents(integer()) :: integer()
  def round_cents(cents), do: div(cents, 5) * 5
end
