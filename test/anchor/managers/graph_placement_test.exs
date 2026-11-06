defmodule Anchor.Managers.GraphPlacementTest do
  # DND-5448: the graph runner builds the placement model once, after the effect
  # inference, only when a rule that runs declares `needs: [:placement]`, stores it on
  # `Model.placement`, and prints its precision. Every adapter is doubled (ADR 002).
  #
  # Sabotage record: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.BehaviourSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphRules.EffectsMatchBucket
  alias Anchor.Domain.GraphRules.FunctionPlacement
  alias Anchor.Domain.Placement
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules

  setup :verify_on_exit!

  defmodule NeedsEffectsOnly do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_effects_only
    def narrows?(_base_key, _key), do: false
    def needs, do: [:cfa, :effects]
    def check(_model, _rule), do: []
  end

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @file_path "lib/my_app/domain/reader.ex"
  @source """
  defmodule AnchorFixtures.GraphPlacementTest.Reader do
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

  defp run(rules, beams, opts) do
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
        graph_rules: [EffectsMatchBucket, FunctionPlacement, NeedsEffectsOnly | Rules.all()]
      ] ++ opts
    )
  end

  test "no rule that runs needs it: not built, no counts, nothing in the summary", %{beams: beams} do
    test = self()

    report =
      run([rule(:stub_cfa_probe, "probe", 1)], beams,
        placement: fn model ->
          send(test, :built)
          Placement.build(model)
        end
      )

    refute_received :built
    assert Map.get(report.counts, :placement) == nil
    refute GraphReport.summary(report) =~ "placement:"
    assert %{"placement" => nil} = JSON.decode!(GraphReport.render(report, :json))
  end

  test "a rule that needs the inference only: no model is built", %{beams: beams} do
    test = self()
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    report =
      run([rule(:stub_needs_effects_only, "effects_only", 1)], beams,
        placement: fn model ->
          send(test, :built)
          Placement.build(model)
        end
      )

    refute_received :built
    assert Map.get(report.counts, :effects) != nil
    assert Map.get(report.counts, :placement) == nil
  end

  test "a rule that needs it: built once, and its precision is in the summary and the JSON", %{
    beams: beams
  } do
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
    test = self()

    rules = [rule(:effects_match_bucket, "effects", 1), rule(:function_placement, "placed", 2)]

    report =
      run(rules, beams,
        placement: fn model ->
          send(test, {:built, model.effects != nil})
          Placement.build(model)
        end
      )

    assert_received {:built, true}
    refute_received {:built, _again}

    assert GraphReport.summary(report) =~
             "; placement: 1 functions placed, 1 with no @spec (ownership unknown), " <>
               "0 ambiguous owner, 0 with no clause to slice, 0 calls of a computed name, " <>
               "reachability no roots"

    assert %{"placement" => %{"functions" => 1, "reachability" => "no_roots"}} =
             JSON.decode!(GraphReport.render(report, :json))
  end

  for {kind, crash, text} <- [
        {"raises", quote(do: raise("placement blew up")), "RuntimeError: placement blew up"},
        {"is no %Placement{}", quote(do: :oops),
         "ArgumentError: the placement model was :oops, not a %Placement{}"}
      ] do
    test "a model that #{kind}: the rule that needs it is one issue and is not run; the others run",
         %{beams: beams} do
      rules = [rule(:function_placement, "placed", 1), rule(:stub_cfa_probe, "probe", 2)]

      expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)
      report = run(rules, beams, placement: fn _model -> unquote(crash) end)

      assert [issue, probe] = report.findings
      assert issue.message =~ "the placement model it needs (Anchor.Domain.Placement) crashed"
      assert issue.message =~ unquote(text)
      assert issue.message =~ "Fix:"
      assert probe.message =~ "probe saw cfa:"
      assert report.exit_code == 1
    end
  end

  test "an inference that crashed: no model is built, and the rule reports the inference", %{
    beams: beams
  } do
    test = self()
    expect(BehaviourSourceMock, :callbacks, fn [] -> %{} end)

    report =
      run([rule(:function_placement, "placed", 1)], beams,
        effects: fn _model, _opts -> raise "effects blew up" end,
        placement: fn model ->
          send(test, :built)
          Placement.build(model)
        end
      )

    refute_received :built
    assert [issue] = report.findings
    assert issue.message =~ "the effect inference it needs"
  end
end
