defmodule AnchorFixtures.Agg.Threads.Thread do
  @moduledoc false
  # A hand-rolled Ecto schema shape: `__schema__(:source)` returns the table.
  def __schema__(:source), do: "threads"
  def __schema__(_other), do: nil
end
