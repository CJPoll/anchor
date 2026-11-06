# Compliant in itself: Rounding below is the violation.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Statement do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Rounding

  @spec total([integer()]) :: integer()
  def total(amounts), do: amounts |> Enum.sum() |> Rounding.round_cents()
end
