defmodule Anchor.Managers.GraphDemandTest do
  # DND-5715: the graph runner runs the demand analysis (`Anchor.Domain.Demand`)
  # once, only when a rule that runs declares `needs: [:demand]`, stores it on
  # `Model.demand`, and `analyses_complete` fails the run closed on a hit bound
  # or an unsummarised function. Every adapter is doubled (ADR 002); the
  # analyses are the real ones unless a test injects one to observe, bound or
  # crash it.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261106-dnd_5715_bucket_split.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.AnalysesComplete
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules
  alias AnchorFixtures.GraphDemandTest.Flow

  defmodule NeedsEffects do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_effects
    def needs, do: [:cfa, :effects]
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: []
  end

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @flow_file "lib/my_app/domain/flow.ex"
  @flow_source """
  defmodule AnchorFixtures.GraphDemandTest.Flow do
    def first(a, _b), do: a
    def doubled(list), do: Enum.map(list, fn x -> x * 2 end)
    def ping(0, p), do: p
    def ping(n, p), do: pong(n - 1, p)
    def pong(n, p), do: ping(n, p)
  end
  """

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@flow_source, @flow_file}])
    %{beams: [BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/flow.beam")]}
  end

  defp config(rules) do
    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "domain",
            "role" => "domain",
            "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
          }
        ],
        "calls" => %{"domain" => []},
        "effects" => ["AnchorFixtures.GraphDemandTest.Extra"]
      })

    %Config{rules: rules, architecture: arch, path: ".anchor.yml"}
  end

  defp rule(type, id, index, extra \\ %{}),
    do: Map.merge(%{type: type, id: id, bucket: "domain", index: index}, extra)

  defp complete(extra \\ %{}), do: rule(:analyses_complete, "complete", 1, extra)

  # The real analysis, with a message to the test each time it runs, carrying
  # what it was given and what it found.
  defp observed_demand do
    test = self()

    fn graph, cfa, effects ->
      send(test, :demand_ran)
      demand = Demand.analyze(graph, cfa, effects)
      send(test, {:demand_result, cfa, effects, demand})
      demand
    end
  end

  defp run(rules, beams, opts \\ []) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:my_app, @ebin}] -> beams end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @flow_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:my_app, @ebin}],
        root: @root,
        build_path: "/proj/_build/test",
        env: :test,
        opts: %{format: :text, only: Keyword.get(opts, :only, [])}
      },
      Keyword.merge(
        [
          config_loader: ConfigLoaderMock,
          beam_source: BeamSourceMock,
          source_source: SourceSourceMock,
          graph_store: GraphStoreMock,
          graph_rules: [AnalysesComplete | Rules.all()],
          demand: observed_demand()
        ],
        Keyword.delete(opts, :only)
      )
    )
  end

  describe "no rule that runs needs the analysis" do
    test "it is not run, and the rule that does not need it sees none", %{beams: beams} do
      report = run([rule(:stub_ok, "ok", 1)], beams)

      refute_received :demand_ran
      assert report.exit_code == 0
    end

    test "--only narrowing away the rule that needs it: not run", %{beams: beams} do
      report = run([complete(), rule(:stub_ok, "ok", 2)], beams, only: ["ok"])

      refute_received :demand_ran
      assert report.exit_code == 0
    end
  end

  describe "a rule that runs needs the analysis" do
    test "it runs once, over the flow analysis and the architecture's effect tokens",
         %{beams: beams} do
      report = run([complete(), rule(:stub_needs_cfa, "needs", 2)], beams)

      assert_received :demand_ran
      refute_received :demand_ran

      assert_received {:demand_result, %Cfa{} = cfa, ["AnchorFixtures.GraphDemandTest.Extra"],
                       demand}

      assert cfa.counts.total == 1
      assert Demand.param(demand, {Flow, :first, 2}, 0) == :all
      assert Demand.param(demand, {Flow, :first, 2}, 1) == :absent

      assert report.exit_code == 1
      assert [%{message: "needs saw cfa: 1 sites. Fix: none, a probe."}] = report.findings
    end

    test "the rule alone over a complete analysis: exit 0, no finding", %{beams: beams} do
      report = run([complete()], beams)

      assert_received :demand_ran
      assert report.exit_code == 0
      assert report.findings == []
    end
  end

  describe "analyses_complete fails the run closed" do
    test "on a flow analysis that hit its step bound", %{beams: beams} do
      bounded = fn graph -> Cfa.analyze(graph, Cfa.default_seed(graph), max_steps: 1) end

      report = run([complete()], beams, cfa: bounded)

      assert report.exit_code == 1
      assert [finding] = report.findings
      assert finding.message =~ "hit its step bound after 1 steps"
    end

    test "on a demand analysis that hit its round bound", %{beams: beams} do
      bounded = fn graph, cfa, effects -> Demand.analyze(graph, cfa, effects, max_rounds: 1) end

      report = run([complete()], beams, demand: bounded)

      assert report.exit_code == 1
      assert [finding] = report.findings
      assert finding.message =~ "hit its round bound on 4 function(s)"
      assert finding.message =~ "AnchorFixtures.GraphDemandTest.Flow.first/2"
    end

    test "on a function the analysis left unsummarised", %{beams: beams} do
      dropped = fn graph, cfa, effects ->
        demand = Demand.analyze(graph, cfa, effects)
        %{demand | summaries: Map.delete(demand.summaries, {Flow, :first, 2})}
      end

      report = run([complete()], beams, demand: dropped)

      assert report.exit_code == 1
      assert [finding] = report.findings
      assert finding.message =~ "no demand summary (AnchorFixtures.GraphDemandTest.Flow.first/2)"
    end

    test "under enforcement: report too, since it is fail-closed", %{beams: beams} do
      bounded = fn graph -> Cfa.analyze(graph, Cfa.default_seed(graph), max_steps: 1) end

      report = run([complete(%{enforcement: :report})], beams, cfa: bounded)

      assert report.exit_code == 1
    end
  end

  describe "fail closed" do
    for {kind, crash, text} <- [
          {"raises", quote(do: raise("demand blew up")), "RuntimeError: demand blew up"},
          {"throws", quote(do: throw(:nope)), "throw: :nope"},
          {"exits", quote(do: exit(:gone)), "exit: :gone"},
          {"returns no %Demand{}", quote(do: :oops),
           "ArgumentError: the analysis returned :oops, not a %Demand{}"}
        ] do
      test "an analysis that #{kind}: the rule that needs it is one issue and is not run; " <>
             "the others run",
           %{beams: beams} do
        rules = [complete(), rule(:stub_cfa_probe, "probe", 2)]

        report = run(rules, beams, demand: fn _graph, _cfa, _effects -> unquote(crash) end)

        assert report.exit_code == 1
        assert [crashed, probe] = report.findings

        assert crashed.message =~
                 ~s|rule 1 (id: "complete", analyses_complete) could not run: the demand | <>
                   "analysis it needs (Anchor.Domain.Demand) crashed: #{unquote(text)}"

        assert crashed.message =~ "Fix: this is an Anchor bug"
        assert probe.message == "probe saw cfa: 1 sites. Fix: none, a probe."
      end
    end

    test "the effect inference and the demand analysis both crashed: each rule says its own",
         %{beams: beams} do
      report =
        run([complete(), rule(:stub_needs_effects, "effects", 2)], beams,
          graph_rules: [AnalysesComplete, NeedsEffects],
          effects: fn _model, _opts -> raise "effects blew up" end,
          demand: fn _graph, _cfa, _effects -> raise "demand blew up" end
        )

      assert report.exit_code == 1
      assert [demand, effects] = report.findings
      assert demand.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
      assert effects.message =~ "the effect inference it needs (Anchor.Domain.Effects) crashed"
    end

    test "a flow analysis that crashed: the demand analysis is not run, and the rule says why",
         %{beams: beams} do
      report = run([complete()], beams, cfa: fn _graph -> raise "cfa blew up" end)

      refute_received :demand_ran
      assert report.exit_code == 1
      assert [crashed] = report.findings

      assert crashed.message =~
               "the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed"
    end
  end
end
