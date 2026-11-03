defmodule Anchor.Adapters.BehaviourReaderTest do
  # Adapter (ADR 002), on the real code server: the stdlib behaviours it reads
  # are loaded already. DND-5447: the callbacks the roots of the effect
  # inference read.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.BehaviourReader

  test "a stdlib behaviour's callbacks, and [] for one that cannot be loaded or is no behaviour" do
    callbacks =
      BehaviourReader.callbacks([GenServer, AnchorFixtures.BehaviourReaderTest.NoSuch, Enum])

    assert {:handle_call, 3} in callbacks[GenServer]
    assert callbacks[AnchorFixtures.BehaviourReaderTest.NoSuch] == []
    assert callbacks[Enum] == []
    assert map_size(callbacks) == 3
  end
end
