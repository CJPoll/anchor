defmodule Anchor.Managers.GraphWritesTest do
  # DND-5459: the graph runner runs the write analysis once, only when a rule
  # that runs declares `needs: [:aggregate_analysis]`, under the same guard as
  # the flow analysis and the effect inference. Every adapter is doubled (ADR
  # 002); the analysis is injected to crash it or to see that it does not run.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.AggregateWriteSources
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
  defmodule AnchorFixtures.GraphWritesTest.Reader do
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
        graph_rules: [AggregateWriteSources | Rules.all()]
      ] ++ opts
    )
  end

  for {kind, crash, text} <- [
        {"raises", quote(do: raise("writes blew up")), "RuntimeError: writes blew up"},
        {"returns no %Analysis{}", quote(do: :oops),
         "ArgumentError: the analysis returned :oops, not an %Analysis{}"}
      ] do
    test "a write analysis that #{kind}: the rule that needs it is one issue, the others run", %{
      beams: beams
    } do
      rules = [rule(:aggregate_write_sources, "writes", 1), rule(:stub_cfa_probe, "probe", 2)]

      report = run(rules, beams, aggregate_analysis: fn _model -> unquote(crash) end)

      assert [issue, probe] = report.findings

      assert issue.message =~
               "the write analysis it needs (Anchor.Domain.Aggregates.Analysis) crashed"

      assert issue.message =~ unquote(text)
      assert issue.message =~ "Fix:"
      assert probe.message =~ "probe saw cfa:"
      assert report.exit_code == 1
    end
  end

  test "no rule that runs needs it: it is not run, and a crash in it cannot stop the run", %{
    beams: beams
  } do
    report =
      run([rule(:stub_cfa_probe, "probe", 1)], beams,
        aggregate_analysis: fn _model ->
          send(self(), :write_analysis_ran)
          raise "never run"
        end
      )

    refute_received :write_analysis_ran

    assert [probe] = report.findings
    assert probe.message =~ "probe saw cfa:"
    refute Map.has_key?(report.counts, :writes)
  end
end
