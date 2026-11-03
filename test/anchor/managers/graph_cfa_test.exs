defmodule Anchor.Managers.GraphCfaTest do
  # DND-5574: the graph runner runs the higher-order flow analysis
  # (`Anchor.Domain.Cfa`) once, only when a rule that runs declares
  # `needs: [:cfa]`, stores it on `Model.cfa`, and reports the apply-site
  # counts (R6). Every adapter is doubled (ADR 002); the analysis is the real
  # one unless a test injects `:cfa` to observe or crash it. QA plan:
  # test/anchor/managers/graph_cfa_test.exs.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5574_cfa_wiring.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @flow_file "lib/my_app/domain/flow.ex"
  # Three apply sites: `f.(f.(x))` is two, both `any` (an exported function's
  # parameter under the open-world seed); the invocation inside `Enum.map/2`
  # is one, resolved to the literal `fn`.
  @flow_source """
  defmodule AnchorFixtures.GraphCfaTest.Flow do
    def twice(f, x), do: f.(f.(x))
    def doubled(list), do: Enum.map(list, fn x -> x * 2 end)
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
        "calls" => %{"domain" => []}
      })

    %Config{rules: rules, architecture: arch, path: ".anchor.yml"}
  end

  defp rule(type, id, index), do: %{type: type, id: id, bucket: "domain", index: index}

  defp request(only \\ []),
    do: %Request{
      apps: [{:my_app, @ebin}],
      root: @root,
      build_path: "/proj/_build/test",
      env: :test,
      opts: %{format: :text, only: only}
    }

  # The real analysis, with a message to the test each time it runs.
  defp observed_cfa do
    test = self()

    fn graph ->
      send(test, :cfa_ran)
      Cfa.analyze(graph, Cfa.default_seed(graph))
    end
  end

  defp run(rules, beams, opts \\ []) do
    expect(ConfigLoaderMock, :load_in, fn _root -> {:ok, config(rules)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:my_app, @ebin}] -> beams end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @flow_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      Keyword.get(opts, :request, request()),
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock,
      graph_rules: Rules.all(),
      cfa: Keyword.get(opts, :cfa, observed_cfa())
    )
  end

  defp messages(report), do: Enum.map(report.findings, & &1.message)

  describe "no rule that runs needs the analysis" do
    test "it is not run: Model.cfa is nil, no counts, the summary says nothing of apply sites",
         %{beams: beams} do
      report = run([rule(:stub_cfa_probe, "probe", 1)], beams)

      refute_received :cfa_ran
      assert messages(report) == ["probe saw cfa: nil. Fix: none, a probe."]
      assert report.counts.apply_sites == nil
      refute GraphReport.summary(report) =~ "apply sites"
    end

    test "--only narrowing away the rule that needs it: not run", %{beams: beams} do
      rules = [rule(:stub_cfa_probe, "probe", 1), rule(:stub_needs_cfa, "needs", 2)]

      report = run(rules, beams, request: request(["probe"]))

      refute_received :cfa_ran
      assert messages(report) == ["probe saw cfa: nil. Fix: none, a probe."]
      assert report.counts.apply_sites == nil
    end
  end

  describe "a rule that runs needs the analysis" do
    test "it runs once for every rule, on Model.cfa, and the counts are exact", %{beams: beams} do
      rules = [
        rule(:stub_needs_cfa, "a", 1),
        rule(:stub_needs_cfa, "b", 2),
        rule(:stub_cfa_probe, "probe", 3)
      ]

      report = run(rules, beams)

      assert_received :cfa_ran
      refute_received :cfa_ran

      # Every rule reads the one analysis, the probe that did not ask included.
      assert messages(report) == [
               "a saw cfa: 3 sites. Fix: none, a probe.",
               "b saw cfa: 3 sites. Fix: none, a probe.",
               "probe saw cfa: 3 sites. Fix: none, a probe."
             ]

      flow = AnchorFixtures.GraphCfaTest.Flow

      assert report.counts.apply_sites == %{
               total: 3,
               resolved: 1,
               any: 2,
               bound_hit?: false,
               by_function: %{
                 {flow, :twice, 2} => %{total: 2, resolved: 0, any: 2},
                 {flow, :doubled, 1} => %{total: 1, resolved: 1, any: 0}
               }
             }

      assert GraphReport.summary(report) =~ "; apply sites: 1 resolved, 2 any"
      refute GraphReport.summary(report) =~ "bound"

      assert %{"apply_sites" => %{"total" => 3, "resolved" => 1, "any" => 2}} =
               JSON.decode!(GraphReport.render(report, :json))
    end

    test "an analysis that hits its bound is printed as one, every site any", %{beams: beams} do
      bounded = fn graph -> Cfa.analyze(graph, Cfa.default_seed(graph), max_steps: 1) end

      report = run([rule(:stub_needs_cfa, "a", 1)], beams, cfa: bounded)

      assert %{total: 3, resolved: 0, any: 3, bound_hit?: true} = report.counts.apply_sites

      assert GraphReport.summary(report) =~
               "; apply sites: 0 resolved, 3 any (step bound hit: every site reads any)"
    end
  end

  describe "fail closed" do
    for {kind, crash, text} <- [
          {"raises", quote(do: raise("cfa blew up")), "RuntimeError: cfa blew up"},
          {"throws", quote(do: throw(:nope)), "throw: :nope"},
          {"exits", quote(do: exit(:gone)), "exit: :gone"},
          {"returns no %Cfa{}", quote(do: :oops),
           "ArgumentError: the analysis returned :oops, not a %Cfa{}"}
        ] do
      test "an analysis that #{kind}: each rule that needs it is one issue and is not run; " <>
             "the others run",
           %{beams: beams} do
        rules = [
          rule(:stub_needs_cfa, "needs", 1),
          rule(:stub_cfa_probe, "probe", 2)
        ]

        report = run(rules, beams, cfa: fn _graph -> unquote(crash) end)

        assert report.exit_code == 1
        assert [crashed, probe] = report.findings

        assert crashed.message =~
                 ~s|rule 1 (id: "needs", stub_needs_cfa) could not run: the higher-order flow | <>
                   "analysis it needs (Anchor.Domain.Cfa) crashed: #{unquote(text)}"

        assert crashed.message =~ "Fix: this is an Anchor bug"
        assert probe.message == "probe saw cfa: nil. Fix: none, a probe."
        assert report.counts.apply_sites == nil
      end
    end

    test "a rule whose needs/0 names what the runner does not compute is one issue and is " <>
           "not run; the analysis is not run for it",
         %{beams: beams} do
      rules = [
        rule(:stub_needs_unknown, "unknown", 1),
        rule(:stub_needs_non_list, "nonlist", 2),
        rule(:stub_cfa_probe, "probe", 3)
      ]

      report = run(rules, beams)

      refute_received :cfa_ran
      assert report.exit_code == 1
      assert [unknown, nonlist, probe] = report.findings

      assert unknown.message =~
               ~s|rule 1 (id: "unknown", stub_needs_unknown) could not run: ArgumentError: | <>
                 "Anchor.Test.GraphRuleStubs.NeedsUnknown.needs/0 names [:nope]"

      assert nonlist.message =~
               ~s|rule 2 (id: "nonlist", stub_needs_non_list) could not run: ArgumentError: | <>
                 "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list"

      assert probe.message == "probe saw cfa: nil. Fix: none, a probe."

      # One Fix: per message, so the JSON's fix is the rule_crashed one.
      for finding <- [unknown, nonlist] do
        assert length(String.split(finding.message, "Fix: ")) == 2
        assert finding.message =~ "Fix: this is an Anchor bug"
      end
    end
  end
end
