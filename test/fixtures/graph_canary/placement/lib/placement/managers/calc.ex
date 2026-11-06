# Violating (input_type_owner, through rule 1): a pure function in a Manager.
defmodule AnchorFixtures.PlacementTest.Billing.Managers.Calc do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice

  @spec total(Invoice.t()) :: integer()
  def total(%Invoice{} = invoice), do: length(invoice.lines)
end
