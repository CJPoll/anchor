defmodule AnchorFixtures.EffectsCanary.Notifier do
  @moduledoc false
  require Logger

  # Violating four times: Logger and send reach Core as calls of effect
  # primitives, and a comprehension into a collectable the caller passes (an
  # IO.stream/0, a File.stream!/1) or into a struct literal (an %IO.Stream{})
  # applies a collector nothing can resolve.
  def log(message), do: Logger.info(message)
  def notify(pid, message), do: send(pid, message)
  def dump(lines, sink), do: for(line <- lines, into: sink, do: line)

  def echo(lines),
    do:
      for(
        line <- lines,
        into: %IO.Stream{device: :stdio, raw: false, line_or_bytes: :line},
        do: line
      )
end
