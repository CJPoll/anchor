# Violating (input_type_owner): its result is computed from another module's struct.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Lease do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice

  @spec expired?(Invoice.t(), integer()) :: boolean()
  def expired?(%Invoice{} = invoice, now), do: invoice.ends_at < now
end
