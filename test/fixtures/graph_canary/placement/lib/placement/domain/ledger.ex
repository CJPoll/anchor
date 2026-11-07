# Violating (DND-5463): two causal components in one module. new/1 and balance/1
# use the module's own struct; label/1 and parse_label/1 call each other and never
# touch it. Nothing links the two groups: split it. Both reach the private total/1,
# a shared helper, which does not link them: extract it.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Ledger do
  defstruct entries: []

  @type t :: %__MODULE__{entries: [integer()]}

  @spec new([integer()]) :: t()
  def new(entries), do: %__MODULE__{entries: entries}

  @spec balance(t()) :: integer()
  def balance(%__MODULE__{entries: entries}), do: total(entries)

  @spec label(integer()) :: String.t()
  def label(cents), do: "#{total([parse_label("#{cents}")])} cents"

  @spec parse_label(String.t() | integer()) :: integer()
  def parse_label(text) when is_binary(text), do: String.to_integer(text)
  def parse_label(cents), do: String.length(label(cents))

  defp total(amounts), do: Enum.sum(amounts)
end
