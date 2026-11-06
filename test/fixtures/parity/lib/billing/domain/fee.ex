defmodule AnchorFixtures.Parity.Billing.Domain.Fee do
  # A dynamic call: the graph resolves it to every module exporting save/1
  # (Orders.Adapters.Store, which domain may not call); the AST cannot see a
  # receiver. The parity test's one listed divergence.
  def charge(store, fee), do: store.save(fee)
end
