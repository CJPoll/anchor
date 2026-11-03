defmodule AnchorFixtures.EffectsCanary.Pricing do
  @moduledoc false
  # Compliant: pure. A closure applied through Enum, a literal where Enum could
  # take a function, and a comprehension's collector all stay pure.
  def total(lines), do: lines |> Enum.map(fn {q, p} -> q * p end) |> Enum.sum()
  def numbered(lines), do: Enum.with_index(lines, 1)
  def skus(lines), do: for({sku, _qty} <- lines, into: MapSet.new(), do: sku)
end
