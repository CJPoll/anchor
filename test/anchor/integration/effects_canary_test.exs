defmodule Anchor.Integration.EffectsCanaryTest do
  # DND-5447: the effects_match_bucket canary tree
  # (test/fixtures/graph_canary/effects/) through the graph runner with real
  # Domain (the flow analysis and the effect inference included), the real
  # config file adapter and the real SourceReader. Beams are compiled in the
  # test (Anchor.Test.BeamFixtures) and fed through the BeamSource port; the
  # artifact store is doubled, so nothing is written into the repo.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.SourceReader
  alias Anchor.BeamSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.GraphReport
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/graph_canary/effects", __DIR__)
  @ebin "_build/test/lib/effects/ebin"
  @violating ~w(lib/effects/domain/reader.ex lib/effects/domain/notifier.ex
                lib/effects/managers/direct.ex)

  setup_all do
    beams =
      Path.wildcard(Path.join(@root, "lib/**/*.ex"))
      |> Enum.sort()
      |> Enum.map(fn path -> {File.read!(path), Path.relative_to(path, @root)} end)
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :effects, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams) do
    expect(ConfigLoaderMock, :load_in, fn _root ->
      ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:effects, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:effects, @ebin}],
        root: @root,
        build_path: Path.join(@root, "_build/test"),
        env: :test,
        opts: %{format: :text, only: []}
      },
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceReader,
      graph_store: GraphStoreMock
    )
  end

  defp without(beams, files),
    do: Enum.reject(beams, &(&1.elixir.relative_file in files))

  test "the violating modules give one finding per bad function, the compliant none", %{
    beams: beams
  } do
    report = run(beams)

    assert report.exit_code == 1
    assert report.could_not_check == []

    assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
             "effects|AnchorFixtures.EffectsCanary.Direct.load/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.dump/2|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.echo/1|managers",
             "effects|AnchorFixtures.EffectsCanary.Notifier.log/1|adapters",
             "effects|AnchorFixtures.EffectsCanary.Notifier.notify/2|adapters",
             "effects|AnchorFixtures.EffectsCanary.Reader.read/1|adapters"
           ]

    reader = Enum.find(report.findings, &(&1.file == "lib/effects/domain/reader.ex"))
    assert reader.line == 4
    assert reader.message =~ "File.read/1"
    assert reader.message =~ "Fix: move the effect into an adapter"
  end

  test "the footer counts the functions per role and the unresolved calls", %{beams: beams} do
    summary = beams |> without(@violating) |> run() |> GraphReport.summary()

    assert summary =~
             "; effects: 6 functions (domain 3, managers 1, adapters 2, framework 0), " <>
               "0 unresolved dynamic calls"
  end

  test "positive control: the compliant modules alone give no finding", %{beams: beams} do
    report = beams |> without(@violating) |> run()

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
  end
end
