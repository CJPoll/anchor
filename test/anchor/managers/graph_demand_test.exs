defmodule Anchor.Managers.GraphDemandTest do
  # DND-5470: the graph runner runs the demand analysis (`Anchor.Domain.Demand`)
  # once, after the flow analysis, only when a rule that runs declares
  # `needs: [:demand]`, stores it and the behaviours' callbacks on the model, and
  # prints the precision counts. Every adapter is doubled (ADR 002); the analyses
  # are the real ones unless a test injects one to crash it.
  #
  # Sabotage record: ../../sabotage_records/parameter_reaches_sink-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.BehaviourSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphRules.EffectsMatchBucket
  alias Anchor.Domain.GraphRules.ParameterReachesSink
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @file_path "lib/my_app/domain/reader.ex"
  @dropper "AnchorFixtures.GraphDemandTest.Reader.drop/1"
  @source """
  defmodule AnchorFixtures.GraphDemandTest.Reader do
    def drop(_x), do: :ok
    def pure(x), do: x + 1
  end
  """

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@source, @file_path}])
    %{beams: [BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/reader.beam")]}
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
        "effects" => ["Req"]
      })

    %Config{rules: rules, architecture: arch, path: ".anchor.yml"}
  end

  defp rule(type, id, index), do: %{type: type, id: id, bucket: "domain", index: index}
  defp sinks, do: rule(:parameter_reaches_sink, "sinks", 1)
  defp probe(index), do: rule(:stub_cfa_probe, "probe", index)

  defp run(rules, beams, opts \\ []) do
    {source, opts} = Keyword.pop(opts, :source, @source)
    expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:my_app, @ebin}] -> beams end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:my_app, @ebin}],
        root: @root,
        build_path: "/proj/_build/test",
        env: :test,
        opts: %{format: :text, only: []}
      },
      [
        config_loader: ConfigLoaderMock,
        beam_source: BeamSourceMock,
        source_source: SourceSourceMock,
        graph_store: GraphStoreMock,
        behaviour_source: BehaviourSourceMock,
        graph_rules: [ParameterReachesSink, EffectsMatchBucket | Rules.all()]
      ] ++ opts
    )
  end

  test "no rule that runs needs it: not run, no counts, null in the JSON", %{beams: beams} do
    test = self()

    stub(BehaviourSourceMock, :callbacks, fn [] ->
      send(test, :read_behaviours)
      %{}
    end)

    # The rule needs the flow analysis, so all the demand analysis would lack is a rule.
    report =
      run([rule(:stub_needs_cfa, "needs_cfa", 1)], beams,
        demand: fn _graph, _cfa, _effects ->
          send(test, :analysed)
          raise "not run"
        end
      )

    refute_received :read_behaviours
    refute_received :analysed
    assert Map.get(report.counts, :parameter_sinks) == nil
    refute GraphReport.summary(report) =~ "parameter_reaches_sink"
    assert %{"parameter_sinks" => nil} = JSON.decode!(GraphReport.render(report, :json))
  end

  test "a needing rule over code with no apply sites: a measured zero, never null", %{
    beams: beams
  } do
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
    report = run([sinks()], beams)

    assert [finding] = report.findings
    assert finding.key == "sinks|#{@dropper}|param 1"

    assert report.counts.parameter_sinks == %{
             precise: 0,
             any: 0,
             imprecise: 0,
             computed_names: 0,
             judged: 2,
             exempt: 0,
             not_analysed: 0
           }

    summary = GraphReport.summary(report)
    assert summary =~ "; apply sites: 0 resolved, 0 any"

    assert summary =~
             "; parameter_reaches_sink: 0 apply sites precise, 0 fell to any, " <>
               "0 imprecise parameters, 0 calls of a computed name, 2 functions judged, 0 exempt, " <>
               "0 not analysed"

    assert %{
             "apply_sites" => %{"total" => 0, "resolved" => 0, "any" => 0},
             "parameter_sinks" => %{"precise" => 0, "any" => 0, "judged" => 2}
           } = JSON.decode!(GraphReport.render(report, :json))
  end

  test "the analysis runs once for two rules, with the config's effect tokens", %{beams: beams} do
    test = self()
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    analyse = fn graph, cfa, effects ->
      send(test, {:analysed, effects})
      Demand.analyze(graph, cfa, effects)
    end

    report = run([sinks(), rule(:parameter_reaches_sink, "sinks2", 2)], beams, demand: analyse)

    assert_received {:analysed, ["Req"]}
    refute_received {:analysed, _effects}
    assert length(report.findings) == 2

    # Two rules' counts add; the apply sites are the run's.
    assert %{judged: 4, precise: 0} = report.counts.parameter_sinks
  end

  test "the rule reads the callbacks the behaviour port read", %{beams: beams} do
    source = """
    defmodule AnchorFixtures.GraphDemandTest.Impl do
      @behaviour SomeLib
      def drop(_x), do: :ok
      def keep(x), do: x
    end
    """

    [{_module, binary}] = compile_all_unloaded([{source, @file_path}])
    impl = BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/impl.beam")

    expect(BehaviourSourceMock, :callbacks, fn [SomeLib] -> %{SomeLib => [drop: 1]} end)

    report = run([sinks()], beams ++ [impl], source: @source <> source)

    assert [finding] = report.findings
    assert finding.key == "sinks|#{@dropper}|param 1"
    assert %{exempt: 1} = report.counts.parameter_sinks
  end

  for {kind, opts, text} <- [
        {"raises", quote(do: [demand: fn _g, _c, _e -> raise "demand blew up" end]),
         "RuntimeError: demand blew up"},
        {"returns no %Demand{}", quote(do: [demand: fn _g, _c, _e -> :oops end]),
         "ArgumentError: the analysis returned :oops, not %Demand{}"}
      ] do
    test "an analysis that #{kind}: the rule that needs it is one issue and is not run; the " <>
           "others run",
         %{beams: beams} do
      expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
      report = run([sinks(), probe(2)], beams, unquote(opts))

      assert [issue, probe] = report.findings
      assert issue.message =~ "the demand analysis it needs (Anchor.Domain.Demand) crashed"
      assert issue.message =~ unquote(text)
      assert issue.message =~ "Fix:"
      assert probe.message =~ "probe saw cfa:"
      assert report.exit_code == 1
      assert Map.get(report.counts, :parameter_sinks) == nil
    end
  end

  test "a behaviour read that raises is the same one issue", %{beams: beams} do
    expect(BehaviourSourceMock, :callbacks, fn [] -> raise "no code server" end)
    report = run([sinks()], beams)

    assert [issue] = report.findings
    assert issue.message =~ "the demand analysis it needs"
    assert issue.message =~ "RuntimeError: no code server"
  end

  test "a crashed flow analysis: the rule reports it and the demand analysis is not run", %{
    beams: beams
  } do
    report =
      run([sinks()], beams,
        cfa: fn _graph -> raise "cfa blew up" end,
        demand: fn _g, _c, _e -> raise "must not run" end
      )

    assert [issue] = report.findings
    assert issue.message =~ "the higher-order flow analysis it needs"
    refute issue.message =~ "must not run"
  end

  test "a crashed effect inference does not stop a rule that needs only demand", %{beams: beams} do
    stub(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    report =
      run([rule(:effects_match_bucket, "effects", 1), sinks()], beams,
        effects: fn _model, _opts -> raise "effects blew up" end
      )

    assert [effects, sink] = report.findings
    assert effects.message =~ "the effect inference it needs"
    assert sink.key == "sinks|#{@dropper}|param 1"
  end

  test "both crashed: the rule that needs demand reports demand", %{beams: beams} do
    stub(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    report =
      run([rule(:effects_match_bucket, "effects", 1), sinks()], beams,
        effects: fn _model, _opts -> raise "effects blew up" end,
        demand: fn _g, _c, _e -> raise "demand blew up" end
      )

    assert [effects, demand] = report.findings
    assert effects.message =~ "the effect inference it needs"
    assert demand.message =~ "the demand analysis it needs"
  end

  test "a crashed demand analysis does not stop a rule that needs only effects", %{beams: beams} do
    source = """
    defmodule AnchorFixtures.GraphDemandTest.Touches do
      def read(path), do: File.read(path)
    end
    """

    [{_module, binary}] = compile_all_unloaded([{source, @file_path}])
    touches = BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/touches.beam")
    stub(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    report =
      run([sinks(), rule(:effects_match_bucket, "effects", 2)], beams ++ [touches],
        source: @source <> source,
        demand: fn _g, _c, _e -> raise "demand blew up" end
      )

    assert [demand, effects] = report.findings
    assert demand.message =~ "the demand analysis it needs"
    assert effects.key == "effects|AnchorFixtures.GraphDemandTest.Touches.read/1|adapters"
  end
end
