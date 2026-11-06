defmodule Anchor.Integration.AggregateWriteSourcesIntegrationTest do
  # DND-5459 I1: the aggregate_write_sources canary
  # (`test/fixtures/graph_canary/aggregate_write_sources/`) through the graph
  # runner with real Domain, the real config file adapter and the real
  # SourceReader. Its beams are compiled in the test against Ecto (a test-only
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

  @root Path.expand("../../fixtures/graph_canary/aggregate_write_sources", __DIR__)
  @ebin "_build/test/lib/aws/ebin"
  @violating "lib/aws/violating.ex"

  setup_all do
    # The schema compiles before the modules that build its struct.
    beams =
      ~w(lib/aws/repo.ex lib/aws/thread.ex lib/aws/compliant.ex lib/aws/violating.ex)
      |> Enum.map(&{File.read!(Path.join(@root, &1)), &1})
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :aws, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams) do
    expect(ConfigLoaderMock, :load, fn ->
      ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:aws, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:aws, @ebin}],
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

  test "I1: the compliant canary gives no finding, and the summary counts its writes", %{
    beams: beams
  } do
    report = run(Enum.reject(beams, &(&1.elixir.relative_file == @violating)))

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

    assert GraphReport.summary(report) =~
             "; writes: 1 read, 1 resolved, 0 unresolved; transactions: 1 read, 1 no gap noticed, 0 incomplete"
  end

  test "I1: the violating module gives exactly the unresolved write and the incomplete transactions",
       %{beams: beams} do
    report = run(beams)

    assert %GraphReport{exit_code: 1, could_not_check: []} = report

    assert [save, run, ask] = Enum.sort_by(report.findings, & &1.line)
    assert save.file == @violating
    assert save.line == line_of(File.read!(Path.join(@root, @violating)), "def save(")

    assert save.key ==
             "aggregate_write_sources|Aws.Violating.save/1|unresolved insert parameter 1 of " <>
               "Aws.Violating.save/1 has no @spec and no project caller"

    assert run.file == @violating
    assert run.key == "aggregate_write_sources|Aws.Violating.run/1|incomplete 1"

    # DND-5889: the same transaction with an unlisted dependency call in it.
    assert ask.key == "aggregate_write_sources|Aws.Violating.ask/1|incomplete 1"
    assert ask.message =~ "unread: call of GenServer.call/2 in Aws.Violating.ask/1"

    assert GraphReport.summary(report) =~
             "; writes: 2 read, 1 resolved, 1 unresolved; transactions: 3 read, 1 no gap noticed, 2 incomplete"
  end
end
