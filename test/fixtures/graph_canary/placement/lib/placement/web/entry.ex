# Compliant: the root of the compliant half.
defmodule AnchorFixtures.PlacementTest.Billing.Web.Entry do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice
  alias AnchorFixtures.PlacementTest.Billing.Managers.Invoices

  def show(path) do
    line = Invoice.Line.new(1)
    invoice = Invoice.add(%Invoice{lines: []}, line)
    {Invoices.fetch(path), Invoice.total(invoice), Invoice.summary(invoice), line.cents}
  end
end
