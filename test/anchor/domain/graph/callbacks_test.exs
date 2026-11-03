defmodule Anchor.Domain.Graph.CallbacksTest do
  # DND-5442: a behaviour's callbacks reach its graph node (the layering rule
  # resolves a dynamic call through them). Fixtures compiled in the test.
  #
  # Sabotage record: ../../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder

  @source """
  defmodule AnchorFixtures.CallbacksTest.Port do
    @callback fetch(term()) :: term()
    @callback store(term(), term()) :: :ok
    @macrocallback m(term()) :: Macro.t()
  end

  defmodule AnchorFixtures.CallbacksTest.Impl do
    @behaviour AnchorFixtures.CallbacksTest.Port
    def fetch(x), do: x
    def store(_k, _v), do: :ok
  end
  """

  test "a behaviour's node lists its callbacks, sorted; an implementation's lists none" do
    beams =
      [{@source, "lib/port.ex"}]
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :demo, path: "ebin/#{module}.beam")
      end)

    graph = Builder.build(beams, %{})

    assert Graph.module(graph, AnchorFixtures.CallbacksTest.Port).callbacks ==
             [{:"MACRO-m", 2}, {:fetch, 1}, {:store, 2}]

    assert Graph.module(graph, AnchorFixtures.CallbacksTest.Impl).callbacks == []
  end
end
