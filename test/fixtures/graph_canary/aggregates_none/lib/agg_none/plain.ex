defmodule AggNone.Plain do
  @moduledoc "Persists nothing: it maps a map."
  def label(map), do: Map.put(map, :label, "plain")
end
