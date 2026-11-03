# DND-5499 claim 4: a parameter passed down and finally dropped. Dialyzer does
# no absence (demand) analysis, so it is expected to report nothing here.
# F2 (`parameter_reaches_sink`, DND-5470) flags `y`.
# Not compiled by `mix`: run.exs compiles it to a tmp dir.
defmodule AnchorSpike.Dropped do
  def f(x, y), do: g(x, y)

  defp g(x, _y), do: x
end
