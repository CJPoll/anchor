# Violating (inert_hop, DND-5461): it only forwards to Statement, in its own bucket and
# context. Managers.Invoices.fetch/1 is the compliant forwarder: it crosses a bucket.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Totals do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Statement

  defdelegate sum(amounts), to: Statement, as: :total
end
