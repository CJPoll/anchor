# Compliant: a Manager that reaches its effect through an adapter.
defmodule AnchorFixtures.PlacementTest.Billing.Managers.Invoices do
  alias AnchorFixtures.PlacementTest.Billing.Adapters.Store

  def fetch(path), do: Store.load(path)
end
