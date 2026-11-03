defmodule AnchorFixtures.EffectsCanary.Notifier do
  @moduledoc false
  require Logger

  # Violating twice: Logger and send reach Core as calls of effect primitives.
  def log(message), do: Logger.info(message)
  def notify(pid, message), do: send(pid, message)
end
