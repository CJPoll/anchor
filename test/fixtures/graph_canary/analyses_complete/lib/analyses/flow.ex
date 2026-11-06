defmodule AnchorFixtures.AnalysesComplete.Flow do
  alias AnchorFixtures.AnalysesComplete.Helper

  def run(list, unused), do: Helper.keep(Enum.map(list, fn x -> x * 2 end), unused)
end
