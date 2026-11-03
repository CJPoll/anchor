# DND-5499 claim 1: a clause of an EXPORTED function that no caller in the
# project reaches. Dialyzer analyses exported functions open world (any caller
# outside the analysed set may pass `:c`), so it is expected NOT to report
# `kind(:c)`. This is the case F8 (`clause_reachability`, DND-5501) flags under
# Anchor's closed world. Not compiled by `mix`: run.exs compiles it to a tmp dir.
defmodule AnchorSpike.Exported do
  def kind(:a), do: 1
  def kind(:b), do: 2
  def kind(:c), do: 3
end

defmodule AnchorSpike.Caller do
  def run, do: AnchorSpike.Exported.kind(:a) + AnchorSpike.Exported.kind(:b)
end
