# Compliant: a struct's own constructor, called from two modules.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line do
  defstruct [:cents]

  @type t :: %__MODULE__{cents: integer()}

  @spec new(integer()) :: t()
  def new(cents), do: %__MODULE__{cents: cents}
end
