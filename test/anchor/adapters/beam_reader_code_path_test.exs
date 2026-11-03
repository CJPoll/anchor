defmodule Anchor.Adapters.BeamReaderCodePathTest do
  # Side Effect adapter (ADR 002), QA plan row 7b (DND-5438). Split from
  # beam_reader_test.exs: this test puts a directory on the VM-wide code path,
  # which every concurrently running test shares, so it runs with async: false.
  #
  # Sabotage record: ../../sabotage_records/beam_reader-20261103-dnd_5438.md
  use ExUnit.Case, async: false

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Graph.Beam

  describe "decode/2" do
    # Row 7b (AC5, integrity): lowering to Core must not load the modules a
    # beam names either. The behaviour's beam is on the code path here, so a
    # decoder that loaded it would succeed; the positive control at the end
    # shows the probe sees a load.
    @tag :tmp_dir
    test "never loads a behaviour the decoded module names, even when it is on the code path", %{
      tmp_dir: dir
    } do
      behaviour = AnchorFixtures.BeamReaderTest.Behaviour
      user = AnchorFixtures.BeamReaderTest.BehaviourUser

      modules =
        compile_all_unloaded([
          {"defmodule #{inspect(behaviour)} do\n  @callback x() :: :ok\nend\n",
           "lib/behaviour.ex"},
          {"defmodule #{inspect(user)} do\n  @behaviour #{inspect(behaviour)}\n  def x, do: :ok\nend\n",
           "lib/user.ex"}
        ])

      File.write!(Path.join(dir, "#{behaviour}.beam"), binary!(modules, behaviour))
      true = Code.append_path(dir)

      on_exit(fn ->
        Code.delete_path(dir)
        :code.purge(behaviour)
        :code.delete(behaviour)
      end)

      assert %Beam{module: ^user} =
               BeamReader.decode(binary!(modules, user), app: :demo, path: "x.beam")

      assert :code.is_loaded(behaviour) == false

      assert {:module, ^behaviour} = :code.ensure_loaded(behaviour)
      assert {:file, _path} = :code.is_loaded(behaviour)
    end
  end
end
