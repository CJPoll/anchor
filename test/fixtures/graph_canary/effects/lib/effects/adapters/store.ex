defmodule AnchorFixtures.EffectsCanary.Store do
  @moduledoc false
  # Compliant: the public function delegates to its own private helper,
  # which performs the effect.
  def fetch(path), do: do_fetch(path)

  defp do_fetch(path), do: File.read(path)
end
