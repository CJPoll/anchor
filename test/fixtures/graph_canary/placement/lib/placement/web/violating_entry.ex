# Violating: the root that keeps the violating half reachable.
defmodule AnchorFixtures.PlacementTest.Billing.Web.ViolatingEntry do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Dead
  alias AnchorFixtures.PlacementTest.Billing.Domain.Format
  alias AnchorFixtures.PlacementTest.Billing.Domain.Ledger
  alias AnchorFixtures.PlacementTest.Billing.Domain.Lease
  alias AnchorFixtures.PlacementTest.Billing.Domain.Leaky
  alias AnchorFixtures.PlacementTest.Billing.Domain.Statement
  alias AnchorFixtures.PlacementTest.Billing.Domain.Totals
  alias AnchorFixtures.PlacementTest.Billing.Managers.Calc

  def show(invoice, now, path) do
    # The capture alone keeps Dead.captured/1 reachable.
    capture = &Dead.captured/1

    {Calc.total(invoice), Format.invoice_line(invoice), Lease.expired?(invoice, now),
     Leaky.read(path), Statement.total([1]), capture.(1), Totals.sum([2]),
     Ledger.balance(Ledger.new([1])), Ledger.label(3)}
  end
end
