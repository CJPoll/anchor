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
  # (layering rows: ../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md;
  # context_acyclic rows: ../../sabotage_records/context_acyclic-20261103-dnd_5441_graph_rules_a.md)
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.SourceReader
  alias Anchor.BeamSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphRules
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.Test.GraphRuleStubs

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/graph_canary", __DIR__)
  @ebin "_build/test/lib/canary/ebin"
  @stray_file "lib/canary/unclassified.ex"
  @layering_violating "lib/canary/framework/layering/violating.ex"
  @cycle_violating "lib/canary/domain/cycle/cycle_b.ex"
  @violating [@stray_file, @layering_violating, @cycle_violating]

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
  defp run(beams, root \\ @root, opts \\ %{}, extra_rules \\ []) do
    expect(ConfigLoaderMock, :load, fn ->
      {:ok, config} = ConfigFile.load_from_path(Path.join(root, ".anchor.yml"))
      {:ok, %{config | rules: config.rules ++ extra_rules}}
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
      graph_store: GraphStoreMock,
      graph_rules: GraphRules.all() ++ [GraphRuleStubs.NeedsCfa]
    )
  end

  test "the compliant canary modules give no findings, and the summary counts the tree", %{
    beams: beams
  } do
    report = run(without(beams, @violating))

    assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

    assert GraphReport.summary(report) ==
             "anchor.graph: 6 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
  end

  test "positive control: the deliberately unclassified module gives exactly one issue", %{
    beams: beams
  } do
    report = run(without(beams, @violating -- [@stray_file]))

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.file == @stray_file
    assert finding.line == 3
    assert finding.message =~ "AnchorFixtures.GraphCanary.Stray is in no architecture bucket."
    assert report.counts.modules == 7
  end

  test "layering (DND-5442): the violating module gives exactly one finding, with the route", %{
    beams: beams
  } do
    report = run(without(beams, @violating -- [@layering_violating]))

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
    measured = without(beams, @violating -- [@layering_violating])
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

  test "context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding", %{
    beams: beams
  } do
    report = run(without(beams, @violating -- [@cycle_violating]))

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.rule_id == "context_acyclic"
    assert finding.key == "context_acyclic|AnchorFixtures.CycleA,AnchorFixtures.CycleB"

    assert finding.message =~
             "contexts AnchorFixtures.CycleA, AnchorFixtures.CycleB form a cycle: " <>
               "AnchorFixtures.CycleA -> AnchorFixtures.CycleB (AnchorFixtures.CycleA.a/1 calls " <>
               "AnchorFixtures.CycleB.b/1), AnchorFixtures.CycleB -> AnchorFixtures.CycleA"
  end

  test "context_acyclic: CycleB without its call back is none", %{beams: beams} do
    one_way =
      """
      defmodule AnchorFixtures.CycleB do
        @moduledoc false
        def b(x), do: x
      end
      """
      |> compile_unloaded(@cycle_violating)
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :canary, path: "#{@ebin}/#{module}.beam")
      end)

    report = run(without(beams, @violating) ++ one_way)

    assert %GraphReport{exit_code: 0, findings: []} = report
    assert report.counts.modules == 7
  end

  test "R7: a rule that needs the higher-order flow analysis gets it over the canary, with no " <>
         "bound hit, and the summary counts its apply sites",
       %{beams: beams} do
    compliant = without(beams, @violating)
    needs = %{type: :stub_needs_cfa, id: "cfa", bucket: "managers", index: 1}

    report = run(compliant, @root, %{}, [needs])

    # Two sites, both resolved: the Enum.map/2 invocation in Orders.all_priced/1
    # (the capture &priced/1) and the one in Order's generated __struct__/1.
    assert [%{message: "cfa saw cfa: 2 sites. Fix: none, a probe."}] = report.findings
    assert %{total: 2, resolved: 2, any: 0, bound_hit?: false} = report.counts.apply_sites

    assert report.counts.apply_sites.by_function[
             {AnchorFixtures.GraphCanary.Orders, :all_priced, 1}
           ] == %{total: 1, resolved: 1, any: 0}

    assert GraphReport.summary(report) ==
             "anchor.graph: 6 modules in 1 apps, 3 rules, 1 violations " <>
               "(0 report-only, 0 baselined); apply sites: 2 resolved, 0 any"
  end

  defp without(beams, files), do: Enum.reject(beams, &(&1.elixir.relative_file in files))
end
