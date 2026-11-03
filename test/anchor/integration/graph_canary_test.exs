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
  # (the CFA run, DND-5574 R7: ../../sabotage_records/graph_runner-20261103-dnd_5574_cfa_wiring.md)
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
  alias Anchor.Test.GraphRuleStubs

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/graph_canary", __DIR__)
  @ebin "_build/test/lib/canary/ebin"
  @stray_file "lib/canary/unclassified.ex"

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

  # `extra_rules` are appended to the canary's own config: the stub graph
  # rules (`Anchor.Test.GraphRuleStubs`) have no RuleSchema type, so they can
  # not be written into its .anchor.yml.
  defp run(beams, extra_rules \\ []) do
    expect(ConfigLoaderMock, :load, fn ->
      {:ok, config} = ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
      {:ok, %{config | rules: config.rules ++ extra_rules}}
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:canary, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:canary, @ebin}],
        root: @root,
        env: :test,
        opts: %{format: :text, only: []}
      },
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceReader,
      graph_store: GraphStoreMock,
      graph_rules: GraphRuleStubs.all()
    )
  end

  test "the compliant canary modules give no findings, and the summary counts the tree", %{
    beams: beams
  } do
    compliant = Enum.reject(beams, &(&1.elixir.relative_file == @stray_file))

    report = run(compliant)

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

    assert GraphReport.summary(report) ==
             "anchor.graph: 4 modules in 1 apps, 0 rules, 0 violations (0 report-only, 0 baselined)"
  end

  test "positive control: the deliberately unclassified module gives exactly one issue", %{
    beams: beams
  } do
    report = run(beams)

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.file == @stray_file
    assert finding.line == 3
    assert finding.message =~ "AnchorFixtures.GraphCanary.Stray is in no architecture bucket."
    assert report.counts.modules == 5
  end

  test "R7: a rule that needs the higher-order flow analysis gets it over the canary, with no " <>
         "bound hit, and the summary counts its apply sites",
       %{beams: beams} do
    compliant = Enum.reject(beams, &(&1.elixir.relative_file == @stray_file))
    needs = %{type: :stub_needs_cfa, id: "cfa", bucket: "managers", index: 1}

    report = run(compliant, [needs])

    # Two sites, both resolved: the Enum.map/2 invocation in Orders.all_priced/1
    # (the capture &priced/1) and the one in Order's generated __struct__/1.
    assert [%{message: "cfa saw cfa: 2 sites. Fix: none, a probe."}] = report.findings
    assert %{total: 2, resolved: 2, any: 0, bound_hit?: false} = report.counts.apply_sites

    assert report.counts.apply_sites.by_function[
             {AnchorFixtures.GraphCanary.Orders, :all_priced, 1}
           ] == %{total: 1, resolved: 1, any: 0}

    assert GraphReport.summary(report) ==
             "anchor.graph: 4 modules in 1 apps, 1 rules, 1 violations " <>
               "(0 report-only, 0 baselined); apply sites: 2 resolved, 0 any"
  end
end
