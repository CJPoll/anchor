defmodule Anchor.Managers.GraphEffectsTest do
  # DND-5447: the graph runner runs the effect inference (`Anchor.Domain.Effects`)
  # once, after the flow analysis, only when a rule that runs declares
  # `needs: [:effects]`, stores it on `Model.effects`, and prints its counts in
  # the summary. Every adapter is doubled (ADR 002); the inference is the real
  # one unless a test injects `:effects` to crash it.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.BehaviourSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphRules.EffectsMatchBucket
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @file_path "lib/my_app/domain/reader.ex"
  @source """
  defmodule AnchorFixtures.GraphEffectsTest.Reader do
    def read(path), do: File.read(path)
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
        "calls" => %{"domain" => []}
      })

    %Config{rules: rules, architecture: arch, path: ".anchor.yml"}
  end

  defp rule(type, id, index), do: %{type: type, id: id, bucket: "domain", index: index}

  defp run(rules, beams, opts \\ []) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:my_app, @ebin}] -> beams end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @source)})
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
        graph_rules: [EffectsMatchBucket | Rules.all()]
      ] ++ opts
    )
  end

  test "no rule that runs needs it: not run, no counts, nothing in the summary", %{beams: beams} do
    report = run([rule(:stub_cfa_probe, "probe", 1)], beams)

    assert Map.get(report.counts, :effects) == nil
    refute GraphReport.summary(report) =~ "effects:"
  end

  test "the rule that needs it runs on Model.effects, and the summary counts it", %{
    beams: beams
  } do
    # The fixture declares no behaviour: the port is asked for none.
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
    report = run([rule(:effects_match_bucket, "effects", 1)], beams)

    assert [finding] = report.findings
    assert finding.key == "effects|AnchorFixtures.GraphEffectsTest.Reader.read/1|adapters"

    assert report.counts.effects == %{
             functions: 2,
             by_role: %{domain: 1, managers: 0, adapters: 1, framework: 0},
             unresolved: 0,
             not_analysed: 0
           }

    assert GraphReport.summary(report) =~
             "; effects: 2 functions (domain 1, managers 0, adapters 1, framework 0), " <>
               "0 unresolved dynamic calls"

    assert %{"effects" => %{"functions" => 2, "unresolved" => 0}} =
             JSON.decode!(GraphReport.render(report, :json))
  end

  test "the inference gets the callbacks the behaviour port read, as :callbacks", %{
    beams: beams
  } do
    callbacks = %{GenServer => [init: 1]}
    expect(BehaviourSourceMock, :callbacks, fn [] -> callbacks end)
    test = self()

    infer = fn model, opts ->
      send(test, {:inferred_with, opts})
      Effects.infer(model, opts)
    end

    run([rule(:effects_match_bucket, "effects", 1)], beams, effects: infer)

    assert_received {:inferred_with, [callbacks: ^callbacks]}
  end

  for {kind, crash, text} <- [
        {"raises", quote(do: raise("effects blew up")), "RuntimeError: effects blew up"},
        {"returns no %Effects{}", quote(do: :oops),
         "ArgumentError: the inference returned :oops, not %Effects{}"}
      ] do
    test "an inference that #{kind}: the rule that needs it is one issue and is not run; " <>
           "the others run",
         %{beams: beams} do
      rules = [rule(:effects_match_bucket, "effects", 1), rule(:stub_cfa_probe, "probe", 2)]

      expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
      report = run(rules, beams, effects: fn _model, _opts -> unquote(crash) end)

      assert [issue, probe] = report.findings
      assert issue.message =~ "the effect inference it needs (Anchor.Domain.Effects) crashed"
      assert issue.message =~ unquote(text)
      assert issue.message =~ "Fix:"
      assert probe.message =~ "probe saw cfa:"
      assert report.exit_code == 1
    end
  end
end
