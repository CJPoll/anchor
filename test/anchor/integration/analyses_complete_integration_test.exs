defmodule Anchor.Integration.AnalysesCompleteIntegrationTest do
  # Integration (ADR 002), the one happy path of the whole-program analyses
  # with no double in the read path (DND-5715, replacing demand_self_test.exs
  # and cfa_self_test.exs): a small project on disk, its beams read by the real
  # BeamReader, its sources by the real SourceReader, its config by the real
  # ConfigFile, its artifact written by the real GraphArtifact, then the 0-CFA
  # and the demand analysis through the runner. The whole of Anchor's own lib/
  # is the same path at scale, and that run is CI's `mix anchor.graph`, which
  # declares `analyses_complete` in .anchor.yml. What each self-test assertion
  # became is in the record below.
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
  alias AnchorFixtures.AnalysesCompleteIntegrationTest.Flow
  alias AnchorFixtures.AnalysesCompleteIntegrationTest.Helper

  setup :verify_on_exit!

  @moduletag :tmp_dir

  @config """
  rules:
    - type: analyses_complete
      id: analyses_complete
      paths: ["lib/**/*.ex"]
      min_modules: 2

  architecture:
    contexts:
      depth: 2
    buckets:
      - name: domain
        role: domain
        select:
          - paths: ["lib/**/*.ex"]
    calls:
      domain: [domain]
  """

  @sources [
    {"lib/fixture/helper.ex",
     """
     defmodule AnchorFixtures.AnalysesCompleteIntegrationTest.Helper do
       def keep(a, _dropped), do: a
     end
     """},
    {"lib/fixture/flow.ex",
     """
     defmodule AnchorFixtures.AnalysesCompleteIntegrationTest.Flow do
       alias AnchorFixtures.AnalysesCompleteIntegrationTest.Helper

       def run(list, unused), do: Helper.keep(Enum.map(list, fn x -> x * 2 end), unused)
     end
     """}
  ]

  setup %{tmp_dir: root} do
    ebin = Path.join(root, "_build/test/lib/fixture/ebin")
    File.mkdir_p!(ebin)

    for {file, source} <- @sources do
      File.mkdir_p!(Path.dirname(Path.join(root, file)))
      File.write!(Path.join(root, file), source)
    end

    for {module, binary} <- compile_all_unloaded(Enum.map(@sources, fn {f, s} -> {s, f} end)) do
      File.write!(Path.join(ebin, "#{module}.beam"), binary)
    end

    File.write!(Path.join(root, ".anchor.yml"), @config)
    %{root: root, ebin: ebin}
  end

  defp run(%{root: root, ebin: ebin}, deps) do
    expect(ConfigLoaderMock, :load, fn ->
      ConfigFile.load_from_path(Path.join(root, ".anchor.yml"))
    end)

    Graph.run(
      %Request{
        apps: [{:fixture, ebin}],
        root: root,
        build_path: Path.join(root, "_build/test"),
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

    assert File.ls!(Path.join(context.root, "_build/test/anchor")) != []
  end

  test "a beam on disk that cannot be read fails the run, naming it", context do
    File.write!(Path.join(context.ebin, "Elixir.Corrupt.beam"), "not a beam")

    report = run(context, [])

    assert report.exit_code == 1
    assert Enum.any?(report.findings, &(&1.message =~ "Elixir.Corrupt.beam"))
  end
end
