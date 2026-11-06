# Violating (bucket_from_effects): a Domain function that reads a file.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Leaky do
  def read(path), do: File.read(path)
end
