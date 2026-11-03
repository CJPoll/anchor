defmodule Anchor.Managers.ExplainTest do
  # DND-5446: the Manager behind mix anchor.explain, its adapters doubled with
  # Hammox (ADR 002). Fixture beams are compiled in the test and decoded by
  # the real BeamReader; the key an explain reads under is the one a graph
  # run of the same build writes under (captured from Managers.Graph.run/2).
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Explain
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Explain, as: ExplainManager
  alias Anchor.Managers.Graph, as: GraphManager
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock

  setup :verify_on_exit!

  @root "/proj"
  @ebin "_build/test/lib/my_app/ebin"
  @build_path "/proj/_build/test"
  @manager_file "lib/my_app/managers/orders.ex"
  @domain_file "lib/my_app/domain/order.ex"

  @manager_source """
  defmodule AnchorFixtures.ExplainManagerTest.Orders do
    @moduledoc false
    def get(id), do: AnchorFixtures.ExplainManagerTest.Order.new(id)
  end
  """

  @domain_source """
  defmodule AnchorFixtures.ExplainManagerTest.Order do
    @moduledoc false
    def new(id), do: id
  end
  """

  @sources %{@manager_file => @manager_source, @domain_file => @domain_source}

  setup_all do
    beams =
      [{@manager_source, @manager_file}, {@domain_source, @domain_file}]
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/#{module}.beam")
      end)

    %{beams: beams}
  end

  defp config do
    Config.parse_config(%{
      "rules" => [%{"type" => "layering", "id" => "layering", "paths" => ["lib/**/*.ex"]}],
      "architecture" => %{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "managers",
            "role" => "managers",
            "select" => [%{"paths" => ["lib/**/managers/**/*.ex"]}]
          },
          %{
            "name" => "domain",
            "role" => "domain",
            "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
          }
        ],
        "calls" => %{"managers" => ["managers", "domain"], "domain" => ["domain"]},
        "interfaces" => %{"buckets" => ["managers"]}
      }
    })
  end

  defp graph_request,
    do: %Request{apps: [{:my_app, @ebin}], root: @root, build_path: @build_path, env: :test}

  defp deps,
    do: [
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock
    ]

  defp stub_sources do
    stub(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, fn file ->
        case Map.fetch(@sources, file) do
          {:ok, text} -> {file, SourceFacts.from_source(file, text)}
          :error -> {file, {:error, :enoent}}
        end
      end)
    end)
  end

  # The key and graph a graph run of this build writes.
  defp written_artifact(beams) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> beams end)

    expect(GraphStoreMock, :write, fn dir, key, graph ->
      send(self(), {:written, dir, key, graph})
      :ok
    end)

    GraphManager.run(graph_request(), deps())
    assert_received {:written, dir, key, %Graph{} = graph}
    {dir, key, graph}
  end

  defp explain(argument, beams, read, compiled? \\ true) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
    if compiled?, do: Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> beams end)
    expect(GraphStoreMock, :read, if(compiled?, do: 1, else: 0), read)
    # Explain writes nothing.
    expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

    ExplainManager.explain(
      %{argument: argument, graph: graph_request(), compiled?: compiled?},
      deps()
    )
  end

  describe "explain/2" do
    test "the artifact under this build's key is used: model and findings present", %{
      beams: beams
    } do
      stub_sources()
      {dir, key, graph} = written_artifact(beams)

      assert {:ok, %Explain{} = explain} =
               explain(@manager_file, beams, fn ^dir, ^key -> {:ok, graph} end)

      assert explain.module == AnchorFixtures.ExplainManagerTest.Orders
      assert explain.exists == true
      assert explain.classification["status"] == "classified"
      assert explain.classification["app"] == "my_app"
      assert explain.findings == []
      assert [%{"modules" => %{"same_context" => _}} | _rest] = explain.may_call
    end

    test "a module subject is placed at its source file by the graph", %{beams: beams} do
      stub_sources()
      {dir, key, graph} = written_artifact(beams)

      assert {:ok, explain} =
               explain(
                 "AnchorFixtures.ExplainManagerTest.Order",
                 beams,
                 fn ^dir, ^key -> {:ok, graph} end
               )

      assert explain.path == @domain_file
      assert explain.classification["bucket"] == "domain"
    end

    test "a stale artifact (another key) is never used: findings not computed", %{beams: beams} do
      stub_sources()

      assert {:ok, explain} =
               explain(@manager_file, beams, fn _dir, _key -> {:error, :key_mismatch} end)

      assert explain.findings == nil
      assert explain.classification["status"] == "classified by path"
      assert explain.unknown != []
    end

    test "a project that did not compile reads no beam and still answers from paths", %{
      beams: beams
    } do
      stub_sources()

      assert {:ok, explain} =
               explain(@manager_file, beams, fn _dir, _key -> flunk("read") end, false)

      assert explain.notes == ["compile failed; beam facts unknown"]
      assert explain.classification["bucket"] == "managers"
    end

    test "a path that does not exist yet", %{beams: beams} do
      stub_sources()

      assert {:ok, explain} =
               explain("lib/my_app/domain/new_thing.ex", beams, fn _d, _k -> {:error, :enoent} end)

      assert explain.exists == false
      assert explain.module == MyApp.Domain.NewThing
      assert explain.classification["bucket"] == "domain"
    end

    test "a missing config is could-not-check (exit 3 in the task)" do
      expect(ConfigLoaderMock, :load, fn ->
        {:error, {:config_not_found, ["/proj/.anchor.yml"]}}
      end)

      assert {:error, {:could_not_check, violation}} =
               ExplainManager.explain(
                 %{argument: @manager_file, graph: graph_request(), compiled?: true},
                 deps()
               )

      assert violation.message =~ "Anchor found no .anchor.yml"
    end

    test "a subject outside the root is a usage error" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)

      assert {:error, {:usage, :outside_root}} =
               ExplainManager.explain(
                 %{argument: "../x.ex", graph: graph_request(), compiled?: true},
                 deps()
               )
    end
  end
end
