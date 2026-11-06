defmodule AnchorFixtures.Parity.Billing.Adapters.Ledger do
  # Compliant: adapters may call managers of another context (Orders).
  def post(entry), do: AnchorFixtures.Parity.Orders.Managers.Checkout.run(entry)
end
