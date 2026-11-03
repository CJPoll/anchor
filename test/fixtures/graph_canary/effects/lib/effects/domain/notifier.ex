defmodule AnchorFixtures.EffectsCanary.Notifier do
  @moduledoc false
  require Logger

  # Violating three times: Logger and send reach Core as calls of effect
  # primitives, and a comprehension into a collectable the caller passes (an
  # IO.stream/0, a File.stream!/1) applies a collector nothing can resolve.
  def log(message), do: Logger.info(message)
  def notify(pid, message), do: send(pid, message)
  def dump(lines, sink), do: for(line <- lines, into: sink, do: line)
end
