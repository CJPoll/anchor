# DND-5499 claim 2: the same unreachable clause as exported.ex, in a PRIVATE
# function. Dialyzer refines a module-local function from its call sites, so it
# is expected to report that `kind(:c)` can never match `:a | :b`. This is also
# the positive control for claim 1. F8 does not re-report this case.
# Not compiled by `mix`: run.exs compiles it to a tmp dir.
defmodule AnchorSpike.Private do
  def run, do: kind(:a) + kind(:b)

  defp kind(:a), do: 1
  defp kind(:b), do: 2
  defp kind(:c), do: 3
end
