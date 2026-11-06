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
  alias Anchor.Domain.GraphReport.Finding
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Explain, as: ExplainManager
  alias Anchor.Managers.Graph, as: GraphManager
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock

  setup :verify_on_exit!

  # Graph rule doubles under the real types the config names (the Domain's
  # Explain reads each rule's type through RuleSchema, so a stub type would
  # not get that far): one finds on every module it selects, one crashes.
  defmodule FindsEveryModule do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :layering
    def narrows?(_base_key, _key), do: false

    def check(model, rule) do
      for module <- Anchor.Domain.GraphRules.select(model, rule) do
        %Anchor.Domain.Violation{
          filename: model.classification[module].source_file,
          line: 2,
          message: "#{inspect(module)} was found. Fix: do not be found.",
          key: "layering|#{inspect(module)}|found"
        }
      end
    end
  end

  defmodule Crashes do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :context_acyclic
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: raise("rule blew up")
  end

  defmodule Throws do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :context_acyclic
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: throw(:thrown)
  end

  # What a real effects_match_bucket reads: a rule run without its analyses
  # would check nothing and read clean, so this one says which it was given.
  defmodule NeedsAnalyses do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :effects_match_bucket
    def narrows?(_base_key, _key), do: false
    def needs, do: [:cfa, :effects]

    def check(model, rule) do
      for module <- Anchor.Domain.GraphRules.select(model, rule) do
        %Anchor.Domain.Violation{
          filename: model.classification[module].source_file,
          message: "cfa given: #{model.cfa != nil}; effects given: #{model.effects != nil}."
        }
      end
    end
  end

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

  defp explain(argument, beams, read, compiled? \\ true, extra_deps \\ []) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
    if compiled?, do: Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> beams end)
    expect(GraphStoreMock, :read, if(compiled?, do: 1, else: 0), read)
    # Explain writes nothing.
    expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

    ExplainManager.explain(
      %{argument: argument, graph: graph_request(), compiled?: compiled?},
      deps() ++ extra_deps
    )
  end

  # The findings of an explain whose config adds `rule`, the graph rules being
  # `modules` and the other adapters `extra_deps`.
  defp findings_with(beams, rule, modules, extra_deps \\ []) do
    stub_sources()
    # The store double answers this graph whatever key it is asked under (the
    # key check is the store's); this is about the rules.
    {dir, _key, graph} = written_artifact(beams)

    expect(ConfigLoaderMock, :load, fn ->
      {:ok, %{config() | rules: config().rules ++ [rule]}}
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> beams end)
    expect(GraphStoreMock, :read, fn ^dir, _key -> {:ok, graph} end)

    {:ok, explain} =
      ExplainManager.explain(
        %{argument: @manager_file, graph: graph_request(), compiled?: true},
        deps() ++ [graph_rules: modules] ++ extra_deps
      )

    explain.findings
  end

  # An explain's findings with a context_acyclic rule run by `crashing`, beside
  # the layering double that finds on every module.
  defp crashed_findings(beams, crashing) do
    acyclic = %{type: :context_acyclic, id: "acyclic", paths: ["lib/**/*.ex"], index: 2}
    findings_with(beams, acyclic, [FindsEveryModule, crashing])
  end

  @effects_rule %{type: :effects_match_bucket, id: "effects", paths: ["lib/**/*.ex"], index: 2}

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

    test "findings are the subject file's only: another file's finding is not shown", %{
      beams: beams
    } do
      stub_sources()
      {dir, key, graph} = written_artifact(beams)

      assert {:ok, explain} =
               explain(
                 @manager_file,
                 beams,
                 fn ^dir, ^key -> {:ok, graph} end,
                 true,
                 graph_rules: [FindsEveryModule]
               )

      # The rule found both fixture modules; only the subject's file is kept.
      assert [%Finding{file: @manager_file, message: message}] = explain.findings
      assert message =~ "AnchorFixtures.ExplainManagerTest.Orders was found"
    end

    test "a rule that raises or throws is named among the findings, never dropped", %{
      beams: beams
    } do
      for {crashing, text} <- [
            {Crashes, "could not run: RuntimeError: rule blew up"},
            {Throws, "could not run: throw: :thrown"}
          ] do
        assert [%Finding{file: @manager_file}, crashed] = crashed_findings(beams, crashing)
        assert crashed.label == Finding.fail_closed_label()
        assert crashed.message =~ text
      end
    end

    # A rule that needs the analyses was run without them, so it checked nothing
    # and read clean; the graph run computes them, and so does an explain.
    test "a rule that needs the flow analysis and the effects is given them", %{beams: beams} do
      assert [%Finding{file: @manager_file, message: message}] =
               findings_with(beams, @effects_rule, [NeedsAnalyses])

      assert message == "cfa given: true; effects given: true."
    end

    test "a flow analysis that crashes is named among the findings; its rule does not run", %{
      beams: beams
    } do
      assert [finding] =
               findings_with(beams, @effects_rule, [NeedsAnalyses],
                 cfa: fn _graph -> raise "analysis blew up" end
               )

      assert finding.label == Finding.fail_closed_label()
      assert finding.message =~ "analysis blew up"
    end

    test "an inference that crashes is named among the findings; its rule does not run", %{
      beams: beams
    } do
      assert [finding] =
               findings_with(beams, @effects_rule, [NeedsAnalyses],
                 effects: fn _model, _opts -> raise "inference blew up" end
               )

      assert finding.label == Finding.fail_closed_label()
      assert finding.message =~ "inference blew up"
    end

    test "a rule that selects nothing is named among the findings, as in a graph run", %{
      beams: beams
    } do
      rule = %{@effects_rule | paths: ["lib/nothing/**/*.ex"]}

      assert [finding] = findings_with(beams, rule, [NeedsAnalyses])
      assert finding.label == Finding.fail_closed_label()
      assert finding.message =~ "effects"
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

    # DND-5655's normalising, on the path Explain takes: raw, an absolute
    # apps_path raised out of ProjectFile.place/3 with no Fix:, and the key could
    # not have been the one the graph run wrote under.
    test "an absolute apps_path under the root: the graph run's own key, and no crash", %{
      beams: beams
    } do
      stub(SourceSourceMock, :read, fn @root, files ->
        Map.new(files, &{&1, {:error, :enoent}})
      end)

      request = %{graph_request() | source_dirs: %{my_app: "/proj/apps/my_app"}}

      expect(ConfigLoaderMock, :load, 2, fn -> {:ok, config()} end)
      Mox.expect(BeamSourceMock, :read_ebins, 2, fn _apps -> beams end)

      expect(GraphStoreMock, :write, fn dir, key, _graph ->
        send(self(), {:written, dir, key})
        :ok
      end)

      GraphManager.run(request, deps())
      assert_received {:written, dir, key}
      expect(GraphStoreMock, :read, fn ^dir, ^key -> {:error, :enoent} end)

      assert {:ok, %Explain{findings: nil}} =
               ExplainManager.explain(
                 %{argument: @manager_file, graph: request, compiled?: true},
                 deps()
               )
    end

    test "an apps_path outside the root is could-not-check, as in a graph run" do
      request = %{graph_request() | source_dirs: %{my_app: "/elsewhere/my_app"}}

      expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)
      expect(GraphStoreMock, :read, 0, fn _dir, _key -> {:error, :enoent} end)

      assert {:error, {:could_not_check, violation}} =
               ExplainManager.explain(
                 %{argument: @manager_file, graph: request, compiled?: true},
                 deps()
               )

      assert violation.message =~ "the apps_path of :my_app is /elsewhere/my_app"
      assert violation.message =~ "Fix:"
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
