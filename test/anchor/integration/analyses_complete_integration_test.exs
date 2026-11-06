defmodule Anchor.Integration.AnalysesCompleteIntegrationTest do
  # Integration (ADR 002), the one happy path of the whole-program analyses
  # with no double in the read path (DND-5715, replacing demand_self_test.exs
  # and cfa_self_test.exs): the analyses_complete canary,
  # test/fixtures/graph_canary/analyses_complete/, compiled to beams on disk,
  # read by the real BeamReader, its sources by the real SourceReader, its
  # config by the real ConfigFile (through the port, as the canary does), its
  # artifact written by the real GraphArtifact, then the 0-CFA and the demand
  # analysis through the runner. The whole of Anchor's own lib/ is the same path
  # at scale, and that run is CI's `mix anchor.graph`, which declares
  # analyses_complete in .anchor.yml. What each self-test assertion became is in
  # the record below.
  #
  # The canary is compliant only: no small module can hit a default bound, so a
  # violating run injects a bounded analysis, or raises a floor.
  #
  # Sabotage record: ../../sabotage_records/analyses_complete-20261106-dnd_5715_bucket_split.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.ConfigFile
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.GraphReport
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias AnchorFixtures.AnalysesComplete.Flow
  alias AnchorFixtures.AnalysesComplete.Helper

  setup :verify_on_exit!

  @moduletag :tmp_dir

  @root Path.expand("../../fixtures/graph_canary/analyses_complete", __DIR__)

  setup %{tmp_dir: tmp} do
    ebin = Path.join(tmp, "_build/test/lib/fixture/ebin")
    File.mkdir_p!(ebin)

    sources =
      Path.join(@root, "lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&{File.read!(&1), Path.relative_to(&1, @root)})

    for {module, binary} <- compile_all_unloaded(sources) do
      File.write!(Path.join(ebin, "#{module}.beam"), binary)
    end

    %{tmp: tmp, ebin: ebin}
  end

  defp run(%{tmp: tmp, ebin: ebin}, deps, rule_changes \\ %{}) do
    expect(ConfigLoaderMock, :load, fn ->
      {:ok, config} = ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
      {:ok, %{config | rules: Enum.map(config.rules, &Map.merge(&1, rule_changes))}}
    end)

    Graph.run(
      %Request{
        apps: [{:fixture, ebin}],
        root: @root,
        build_path: Path.join(tmp, "_build/test"),
        env: :test,
        opts: %{format: :text, only: []}
      },
      [config_loader: ConfigLoaderMock] ++ deps
    )
  end

  test "real beams through the real read path: clean, with the known results", context do
    test = self()

    observed = fn graph, cfa, effects ->
      demand = Demand.analyze(graph, cfa, effects)
      send(test, {:ran, cfa, demand})
      demand
    end

    report = run(context, demand: observed)

    assert report.findings == []
    assert report.exit_code == 0
    assert report.counts.modules == 2
    assert %{total: 1, resolved: 1, any: 0, bound_hit?: false} = report.counts.apply_sites
    assert GraphReport.summary(report) =~ "2 modules in 1 apps"

    assert_received {:ran, %Cfa{bound_hit?: false}, %Demand{bound_hit: []} = demand}

    # Across two modules read from disk: the parameter Helper drops is absent
    # in its caller too, and the one it returns is used.
    assert Demand.param(demand, {Helper, :keep, 2}, 0) == :all
    assert Demand.param(demand, {Helper, :keep, 2}, 1) == :absent
    assert Demand.param(demand, {Flow, :run, 2}, 0) == :all
    assert Demand.param(demand, {Flow, :run, 2}, 1) == :absent

    assert File.ls!(Path.join(context.tmp, "_build/test/anchor")) != []
  end

  test "violating: a flow analysis that hit its bound fails the run", context do
    bounded = fn graph -> Cfa.analyze(graph, Cfa.default_seed(graph), max_steps: 1) end

    report = run(context, cfa: bounded)

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.message =~ ~s|rule 1 (id: "analyses_complete", analyses_complete)|
    assert finding.message =~ "hit its step bound after 1 steps"
  end

  test "violating: a demand analysis that hit its bound fails the run", context do
    bounded = fn graph, cfa, effects -> Demand.analyze(graph, cfa, effects, max_rounds: 1) end

    report = run(context, demand: bounded)

    assert report.exit_code == 1
    # A component that did not settle reads as used, so nothing is absent: the
    # floor says so too.
    assert [bound, floor] = report.findings
    assert bound.message =~ "hit its round bound on 2 function(s)"
    assert floor.message =~ "judged 0, below min_absent_parameters 1"
  end

  test "violating: a floor above what the project holds fails the run", context do
    report = run(context, [], %{min_functions: 99})

    assert report.exit_code == 1
    assert [finding] = report.findings
    assert finding.message =~ "below min_functions 99"
  end

  test "a beam on disk that cannot be read fails the run, naming it", context do
    File.write!(Path.join(context.ebin, "Elixir.Corrupt.beam"), "not a beam")

    report = run(context, [])

    assert report.exit_code == 1
    assert Enum.any?(report.findings, &(&1.message =~ "Elixir.Corrupt.beam"))
  end
end
