defmodule AnchorFixtures.GraphCanary.Orders.Order do
  @moduledoc false
  defstruct [:id, :total]

  def new(id), do: %__MODULE__{id: id, total: 1}

  def total(%__MODULE__{total: total}), do: total
end
