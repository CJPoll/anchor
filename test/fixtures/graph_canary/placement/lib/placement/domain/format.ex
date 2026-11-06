# Violating (output_type_owner): it returns another module's struct.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Format do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line

  @spec invoice_line(Invoice.t()) :: Line.t()
  def invoice_line(%Invoice{} = invoice), do: %Line{cents: length(invoice.lines)}
end
