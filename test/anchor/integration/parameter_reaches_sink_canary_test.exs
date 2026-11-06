defmodule Anchor.Integration.ParameterReachesSinkCanaryTest do
  # DND-5470: the parameter_reaches_sink canary tree
  # (test/fixtures/graph_canary/parameter_reaches_sink/) through the graph
  # runner with real Domain (the flow analysis and the demand analysis
  # included), the real config adapter and the real SourceReader and
  # BehaviourReader. Beams are compiled in the test and fed through the
  # BeamSource port; the artifact store is doubled, so nothing is written.
  #
  # Sabotage record: ../../sabotage_records/parameter_reaches_sink-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.SourceReader
  alias Anchor.BeamSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.RuleShapes
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/graph_canary/parameter_reaches_sink", __DIR__)
  @ebin "_build/test/lib/sinks/ebin"
  @drops "AnchorFixtures.ParameterSinks.Drops"

  setup_all do
    beams =
      Path.wildcard(Path.join(@root, "lib/**/*.ex"))
      |> Enum.sort()
      |> Enum.map(fn path -> {File.read!(path), Path.relative_to(path, @root)} end)
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :sinks, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp run(beams) do
    expect(ConfigLoaderMock, :load, fn ->
      ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:sinks, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:sinks, @ebin}],
        root: @root,
        build_path: Path.join(@root, "_build/test"),
        env: :test,
        opts: %{format: :text, only: []}
      },
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceReader,
      graph_store: GraphStoreMock
    )
  end

  defp finding(report, key), do: Enum.find(report.findings, &(&1.key == "sinks|#{@drops}.#{key}"))

  test "exactly the dropped parameters are findings; every compliant and exempt one is not", %{
    beams: beams
  } do
    report = run(beams)

    assert report.could_not_check == []
    assert report.exit_code == 1

    assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == [
             "sinks|#{@drops}.count/2|param 1",
             "sinks|#{@drops}.drop_first/2|param 1",
             "sinks|#{@drops}.f/2|param 2",
             "sinks|#{@drops}.g/1|param 1",
             "sinks|#{@drops}.index/1|param 1",
             "sinks|#{@drops}.ping/2|param 1",
             "sinks|#{@drops}.price/2|param 2",
             "sinks|#{@drops}.via_lambda/1|param 1",
             "sinks|#{@drops}.via_var/1|param 1"
           ]

    for finding <- report.findings do
      assert RuleShapes.fix_count(finding.message) == 1, finding.message
    end
  end

  test "the message names the parameter, its chain and its call sites", %{beams: beams} do
    report = run(beams)

    # The default's generated head, drop_first/1, is not a second issue.
    refute finding(report, "drop_first/1|param 1")

    price = finding(report, "price/2|param 2")
    assert price.file == "lib/sinks/domain/drops.ex"
    assert price.line == 3
    assert price.message =~ "price/2 parameter 2 (_opts) reaches no return value and no effect"
    assert price.message =~ "Fix: drop parameter 2 (_opts) of #{@drops}.price/2"
    assert price.message =~ "chain: #{@drops}.price/2 param 2 (dropped)"

    f = finding(report, "f/2|param 2")
    assert f.message =~ "chain: #{@drops}.f/2 param 2 -> #{@drops}.g/1 param 1 (dropped)"

    # g/1's one call site is f/2.
    assert finding(report, "g/1|param 1").message =~ "call sites: 1"
    assert finding(report, "g/1|param 1").message =~ "(_x)"

    # Recursion ends the chain.
    assert finding(report, "count/2|param 1").message =~
             "chain: #{@drops}.count/2 param 1 -> #{@drops}.count/2 param 1 (dropped)"

    # A lambda is the end of a chain, named by its ordinal.
    assert finding(report, "via_lambda/1|param 1").message =~
             "#{@drops}.via_lambda/1 param 1 -> fn 0 in #{@drops}.via_lambda/1 param 1 (dropped)"
  end

  test "the summary prints the precision counts, and the apply site that fell to any", %{
    beams: beams
  } do
    report = run(beams)

    %{
      precise: precise,
      any: any,
      imprecise: imprecise,
      judged: judged,
      exempt: exempt,
      not_analysed: not_analysed
    } = report.counts.parameter_sinks

    assert any > 0, "Uses.invoked/2 applies a closure from outside"
    assert imprecise > 0, "Uses.applied/3 passes p to an apply/3 Core does not name"

    assert report.counts.parameter_sinks.computed_names == 4,
           "Uses.applied/3, Computed.dispatch/2, Computed.anywhere/3, Started.run/3"

    assert judged > 0
    assert exempt > 0
    assert not_analysed == 0

    assert GraphReport.summary(report) =~
             "; parameter_reaches_sink: #{precise} apply sites precise, #{any} fell to any, "

    assert GraphReport.summary(report) =~ ", 4 calls of a computed name"

    assert %{"parameter_sinks" => %{"any" => ^any, "judged" => ^judged}} =
             JSON.decode!(GraphReport.render(report, :json))
  end
end
