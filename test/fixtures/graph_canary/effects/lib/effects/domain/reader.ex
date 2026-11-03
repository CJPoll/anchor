defmodule AnchorFixtures.EffectsCanary.Reader do
  @moduledoc false
  # Violating: a Domain function that reads a file.
  def read(path), do: File.read(path)
end
