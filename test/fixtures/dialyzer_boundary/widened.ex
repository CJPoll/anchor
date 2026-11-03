# DND-5499 claim 3: an atom union widened to atom(). A private function called
# with N distinct atoms, one clause per atom, plus a `:never` clause no call
# reaches. Above Dialyzer's atom-set limit the call-site type widens to atom()
# and `:never` stops being reported, though no call can reach it: the
# value-level precision F8 (DND-5501) keeps. This is the committed N = 20
# instance; run.exs generates the other N from the same template
# (`AnchorSpike.Runner.widened_source/1`) and refuses to run if this file
# drifts from it. Not compiled by `mix`: run.exs compiles it to a tmp dir.
defmodule AnchorSpike.Widened20 do
  def run,
    do: [
      kind(:a1),
      kind(:a2),
      kind(:a3),
      kind(:a4),
      kind(:a5),
      kind(:a6),
      kind(:a7),
      kind(:a8),
      kind(:a9),
      kind(:a10),
      kind(:a11),
      kind(:a12),
      kind(:a13),
      kind(:a14),
      kind(:a15),
      kind(:a16),
      kind(:a17),
      kind(:a18),
      kind(:a19),
      kind(:a20)
    ]

  defp kind(:a1), do: 1
  defp kind(:a2), do: 2
  defp kind(:a3), do: 3
  defp kind(:a4), do: 4
  defp kind(:a5), do: 5
  defp kind(:a6), do: 6
  defp kind(:a7), do: 7
  defp kind(:a8), do: 8
  defp kind(:a9), do: 9
  defp kind(:a10), do: 10
  defp kind(:a11), do: 11
  defp kind(:a12), do: 12
  defp kind(:a13), do: 13
  defp kind(:a14), do: 14
  defp kind(:a15), do: 15
  defp kind(:a16), do: 16
  defp kind(:a17), do: 17
  defp kind(:a18), do: 18
  defp kind(:a19), do: 19
  defp kind(:a20), do: 20
  defp kind(:never), do: 0
end
