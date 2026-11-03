# Deliberately in no bucket: the canary's positive control for the
# unclassified-module issue (DND-5440).
defmodule AnchorFixtures.GraphCanary.Stray do
  @moduledoc false
  def stray, do: :stray
end
