defmodule Anchor.Integration.AggregateDeclarationsIntegrationTest do
  # DND-5476 N1: the aggregate_declarations canary
  # (`test/fixtures/graph_canary/aggregate_declarations/`) through the graph
  # runner with real Domain, the real config file adapter and the real
  # SourceReader. Its beams are compiled in the test (`use Anchor.Aggregate`
  # included) and fed through the BeamSource port; the artifact store is
  # doubled so nothing is written into the repo.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
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

  @root Path.expand("../../fixtures/graph_canary/aggregate_declarations", __DIR__)
  @ebin "_build/test/lib/agg/ebin"
  @rogue "lib/agg/threads/rogue.ex"

  setup_all do
    beams =
      Path.wildcard(Path.join(@root, "lib/**/*.ex"))
      |> Enum.sort()
      |> Enum.map(&{File.read!(&1), Path.relative_to(&1, @root)})
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :agg, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams) do
    expect(ConfigLoaderMock, :load_in, fn _root ->
      ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:agg, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:agg, @ebin}],
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

  test "N1: the compliant canary (macro form and config) gives no finding", %{beams: beams} do
    report = run(Enum.reject(beams, &(&1.elixir.relative_file == @rogue)))

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

    assert GraphReport.summary(report) ==
             "anchor.graph: 2 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 " <>
               "baselined); aggregates: 2 declared, 0 tables unknown"
  end

  test "N1: the violating module's table claim is claimed twice, at the config and at it", %{
    beams: beams
  } do
    report = run(beams)

    assert report.exit_code == 1
    assert [config_site, rogue_site] = report.findings

    assert config_site.file == Path.join(@root, ".anchor.yml")
    assert rogue_site.file == @rogue
    assert rogue_site.line == 1

    for finding <- [config_site, rogue_site] do
      assert finding.rule_id == "aggregate_declarations"

      assert finding.message =~
               ~s(table "audit_rows" is claimed by Agg.Audit and AnchorFixtures.Agg.Threads.Space.)
    end

    assert rogue_site.key ==
             "aggregate_declarations|AnchorFixtures.Agg.Threads.Rogue|claimed_twice " <>
               ~s(Agg.Audit,AnchorFixtures.Agg.Threads.Space "audit_rows")
  end
end
