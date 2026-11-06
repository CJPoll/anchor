# Violating (unreachable): unused/0 has no caller. captured/1 is reachable only by a capture.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Dead do
  @spec unused() :: :ok
  def unused, do: :ok

  @spec captured(integer()) :: integer()
  def captured(value), do: value + 1
end
