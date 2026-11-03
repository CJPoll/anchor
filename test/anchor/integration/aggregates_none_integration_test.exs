defmodule Anchor.Integration.AggregatesNoneIntegrationTest do
  # DND-5659 Z6: the `aggregates: declare: none` canary
  # (`test/fixtures/graph_canary/aggregates_none/`) through the graph runner
  # with real Domain, the real config file adapter and the real SourceReader.
  # Its beams are compiled in the test (the schema against Ecto, a test-only
  # dependency) and fed through the BeamSource port; the artifact store is
  # doubled so nothing is written into the repo.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
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

  @root Path.expand("../../fixtures/graph_canary/aggregates_none", __DIR__)
  @ebin "_build/test/lib/agg_none/ebin"
  @thread "lib/agg_none/thread.ex"

  setup_all do
    beams =
      ~w(lib/agg_none/plain.ex lib/agg_none/thread.ex)
      |> Enum.map(&{File.read!(Path.join(@root, &1)), &1})
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :agg_none, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams) do
    expect(ConfigLoaderMock, :load, fn ->
      ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:agg_none, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:agg_none, @ebin}],
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

  test "Z6: none over a project that persists nothing is clean, not checks-nothing", %{
    beams: beams
  } do
    report = run(Enum.reject(beams, &(&1.elixir.relative_file == @thread)))

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
  end

  test "Z6: none over a project with an Ecto schema fails, naming the schema module", %{
    beams: beams
  } do
    report = run(beams)

    assert report.exit_code == 1
    assert [finding] = report.findings

    assert finding.rule_id == "aggregate_declarations"
    assert finding.file == @thread
    assert finding.line == 1

    assert finding.key ==
             "aggregate_declarations|AggNone.Thread|persists_under_none - AggNone.Thread"

    assert finding.message =~
             "AggNone.Thread persists (it exports __schema__/1 (an Ecto schema)), but " <>
               ".anchor.yml says aggregates: declare: none (the canary persists nothing). " <>
               "Fix: declare the aggregate and remove declare: none"
  end
end
