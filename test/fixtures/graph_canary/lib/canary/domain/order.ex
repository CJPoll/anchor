defmodule AnchorFixtures.GraphCanary.Orders.Order do
  @moduledoc false
  defstruct [:id, :total]

  @type t :: %__MODULE__{id: term(), total: integer()}

  @spec new(term()) :: t()
  def new(id), do: %__MODULE__{id: id, total: 1}

  def total(%__MODULE__{total: total}), do: total

  # struct_owned_by_module_flow (DND-5454), compliant: the owner changes its
  # own struct.
  @spec put_total(t(), integer()) :: t()
  def put_total(%__MODULE__{} = order, total), do: %{order | total: total}
end
