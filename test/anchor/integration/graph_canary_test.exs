defmodule Anchor.Integration.GraphCanaryTest do
  # DND-5440: the canary tree `test/fixtures/graph_canary/` through the graph
  # runner with real Domain, the real config file adapter and the real
  # SourceReader. Its beams are compiled in the test
  # (`Anchor.Test.BeamFixtures`: `mix test` turns debug_info off) and fed to
  # the Manager through the BeamSource port; the artifact store is doubled so
  # nothing is written into the repo. Every graph rule ticket adds a compliant
  # and a violating module per rule here (epic QA plan).
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # (layering rows: ../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md)
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

  @root Path.expand("../../fixtures/graph_canary", __DIR__)
  @ebin "_build/test/lib/canary/ebin"
  @stray_file "lib/canary/unclassified.ex"
  @layering_violating "lib/canary/framework/layering/violating.ex"
  @violating [@stray_file, @layering_violating]

  setup_all do
    files =
      Path.wildcard(Path.join(@root, "lib/**/*.ex"))
      |> Enum.sort()
      |> Enum.map(&Path.relative_to(&1, @root))

    beams =
      files
      |> Enum.map(&{File.read!(Path.join(@root, &1)), &1})
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :canary, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams, root \\ @root, opts \\ %{}) do
    expect(ConfigLoaderMock, :load, fn ->
      ConfigFile.load_from_path(Path.join(root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:canary, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:canary, @ebin}],
        root: root,
        env: :test,
        opts: Map.merge(%{format: :text, only: []}, opts)
      },
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceReader,
      graph_store: GraphStoreMock
    )
  end

  test "the compliant canary modules give no findings, and the summary counts the tree", %{
    beams: beams
  } do
    report = run(without(beams, @violating))

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

    assert GraphReport.summary(report) ==
             "anchor.graph: 5 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
  end

  test "positive control: the deliberately unclassified module gives exactly one issue", %{
    beams: beams
  } do
    report = run(without(beams, [@layering_violating]))

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.file == @stray_file
    assert finding.line == 3
    assert finding.message =~ "AnchorFixtures.GraphCanary.Stray is in no architecture bucket."
    assert report.counts.modules == 6
  end

  test "layering (DND-5442): the violating module gives exactly one finding, with the route", %{
    beams: beams
  } do
    report = run(without(beams, [@stray_file]))

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.file == @layering_violating
    assert finding.line == 7
    assert finding.rule_id == "layering"

    assert finding.message =~
             "AnchorFixtures.GraphCanary.Web.Violating.show/1 (framework, " <>
               "AnchorFixtures.GraphCanary) calls AnchorFixtures.GraphCanary.Orders.Store.fetch/1"

    assert finding.message =~ "Fix: route it through managers: framework -> managers -> adapters"
  end

  # DND-5441's ratchet end to end, on the real BaselineFile adapter over a copy
  # of the canary tree: write the baseline, hold it, then STALE once the
  # violation is gone.
  @tag :tmp_dir
  test "layering baseline: written, then held, then STALE once the violation is fixed", %{
    beams: beams,
    tmp_dir: tmp_dir
  } do
    File.cp_r!(Path.join(@root, "lib"), Path.join(tmp_dir, "lib"))

    config =
      @root
      |> Path.join(".anchor.yml")
      |> File.read!()
      |> String.replace(
        "    id: layering\n",
        "    id: layering\n    baseline: .anchor/baselines/layering.txt\n"
      )

    File.write!(Path.join(tmp_dir, ".anchor.yml"), config)
    measured = without(beams, [@stray_file])
    baseline = Path.join(tmp_dir, ".anchor/baselines/layering.txt")

    written = run(measured, tmp_dir, %{write_baseline: "layering"})
    assert written.exit_code == 0

    assert File.read!(baseline) =~
             "layering|AnchorFixtures.GraphCanary.Web.Violating.show/1|-> " <>
               "AnchorFixtures.GraphCanary.Orders.Store.fetch/1\n"

    held = run(measured, tmp_dir)
    assert %GraphReport{exit_code: 0, findings: []} = held
    assert [_one] = held.held

    stale = run(without(measured, [@layering_violating]), tmp_dir)
    assert stale.exit_code == 1
    assert [finding] = stale.findings
    assert finding.file == ".anchor/baselines/layering.txt"
    assert finding.message =~ "matches no finding (it was fixed)"
  end

  defp without(beams, files), do: Enum.reject(beams, &(&1.elixir.relative_file in files))
end
