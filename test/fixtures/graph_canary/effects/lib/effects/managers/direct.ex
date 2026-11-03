defmodule AnchorFixtures.EffectsCanary.Direct do
  @moduledoc false
  # Violating: a Manager that performs the effect itself.
  def load(path), do: File.read(path)
end
