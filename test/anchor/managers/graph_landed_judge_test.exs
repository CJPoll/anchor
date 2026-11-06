defmodule Anchor.Managers.GraphLandedJudgeTest do
  # DND-5658: the graph runner as the landed judge (`opts.judge`, set by
  # `mix anchor.graph --project`), with every adapter doubled by Hammox (ADR
  # 002). The judge loads the change's config with unknown rule types set
  # aside (`ConfigLoader.load_judged/1`) and compares its rules with the base
  # config's (`GitBase.rules/3`): a removed or retyped base rule fails, a rule
  # type new in the change is a report-only FIRST LANDING, and an honest
  # baseline shrink passes. The stub rule `stub_finds` gives one finding per
  # selected module, keyed `<id>|<Module>|found`.
  #
  # Sabotage record: ../../sabotage_records/landed_judge-20261103-dnd_5658_ci_base_ratchet.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BaselineStoreMock
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.GitBaseMock
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock
  alias Anchor.Test.GraphRuleStubs, as: Rules

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @path ".anchor/baselines/f.txt"
  @user_file "lib/my_app/domain/user.ex"
  @user_source """
  defmodule AnchorFixtures.GraphLandedJudgeTest.User do
    def name(user), do: user
  end
  """
  @key "f|AnchorFixtures.GraphLandedJudgeTest.User|found"
  @ref "origin/main"

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@user_source, @user_file}])
    %{beam: BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/user.beam")}
  end

  defp config(rules, deferred) do
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

    %Config{rules: rules, architecture: arch, path: ".anchor.yml", deferred: deferred}
  end

  defp rule(extra \\ %{}),
    do: Map.merge(%{type: :stub_ok, id: "ok", bucket: "domain", index: 1}, extra)

  defp baselined, do: rule(%{type: :stub_finds, id: "f", baseline: @path})

  defp request(opts),
    do: %Request{
      apps: [{:my_app, @ebin}],
      root: @root,
      build_path: Path.join(@root, "_build/test"),
      env: :test,
      opts: Map.merge(%{format: :text, only: [], base: @ref, judge: true}, opts)
    }

  defp deps,
    do: [
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock,
      baseline_store: BaselineStoreMock,
      git_base: GitBaseMock,
      graph_rules: Rules.all()
    ]

  defp expect_run(rules, deferred, beam, base_rules) do
    expect(ConfigLoaderMock, :load_judged, fn @root -> {:ok, config(rules, deferred)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> [beam] end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @user_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)
    expect(GitBaseMock, :rules, fn @root, @ref, ".anchor.yml" -> base_rules end)
  end

  defp messages(report), do: Enum.map(report.findings, & &1.message)

  test "the judge loads with unknown types set aside; a new type is a FIRST LANDING, exit 0",
       %{beam: beam} do
    new = %{
      index: 2,
      id: "fresh",
      type: "brand_new_rule",
      baseline: ".anchor/baselines/fresh.txt"
    }

    expect_run([rule()], [new], beam, {:ok, [rule()]})

    report = Graph.run(request(%{}), deps())

    assert %GraphReport{exit_code: 0, findings: [note]} = report
    assert note.enforcement == :report

    assert note.message =~
             ~s|NOTE: FIRST LANDING of rule 2 (id: "fresh", brand_new_rule), baseline .anchor/baselines/fresh.txt: the anchor landed on origin/main has no rule type "brand_new_rule"|
  end

  test "a base rule the change removes fails: exit 1", %{beam: beam} do
    expect_run([rule()], [], beam, {:ok, [rule(), rule(%{id: "gone", type: :stub_finds})]})

    report = Graph.run(request(%{}), deps())

    assert report.exit_code == 1

    assert Enum.any?(
             messages(report),
             &(&1 =~
                 ~s|rule "gone" (stub_finds) is in .anchor.yml at origin/main and not in this change|)
           )
  end

  test "a base rule the change retypes fails: exit 1", %{beam: beam} do
    expect_run([rule(%{type: :stub_finds})], [], beam, {:ok, [rule()]})

    report = Graph.run(request(%{}), deps())

    assert report.exit_code == 1

    assert Enum.any?(
             messages(report),
             &(&1 =~ ~s|rule "ok" is stub_ok in .anchor.yml at origin/main and stub_finds|)
           )
  end

  test "a base config that cannot be read is COULD NOT MEASURE, never nothing removed" do
    expect(ConfigLoaderMock, :load_judged, fn @root -> {:ok, config([rule()], [])} end)

    expect(GitBaseMock, :rules, fn @root, @ref, ".anchor.yml" ->
      {:error, {:git, 128, "fatal"}}
    end)

    report = Graph.run(request(%{}), deps())

    assert report.exit_code == 3

    assert [issue] = report.could_not_check

    assert issue.message =~
             "COULD NOT MEASURE: the landed judge could not read .anchor.yml at origin/main"
  end

  test "positive control: an honest shrink of a base rule's baseline passes", %{beam: beam} do
    expect_run([baselined()], [], beam, {:ok, [baselined()]})

    expect(BaselineStoreMock, :read, fn @root, @path -> Baseline.parse("#{@key}\n") end)

    expect(GitBaseMock, :show, fn @root, @ref, @path ->
      Baseline.parse("#{@key}\nf|AnchorFixtures.GraphLandedJudgeTest.Fixed|found\n")
    end)

    assert %GraphReport{exit_code: 0, findings: [], held: [_held]} =
             Graph.run(request(%{}), deps())
  end

  test "a base rule the change downgrades and shrinks is judged as the base defines it: exit 1",
       %{beam: beam} do
    downgraded = Map.put(baselined(), :enforcement, :report)
    expect_run([downgraded], [], beam, {:ok, [baselined()]})

    expect(BaselineStoreMock, :read, fn @root, @path -> Baseline.parse("") end)
    expect(GitBaseMock, :show, fn @root, @ref, @path -> Baseline.parse("#{@key}\n") end)

    report = Graph.run(request(%{}), deps())

    assert report.exit_code == 1
    assert [%{key: @key, enforcement: :enforce}] = Enum.filter(report.findings, &(&1.key == @key))
  end

  test "outside the judge, the config loads with load and nothing is compared", %{beam: beam} do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config([rule()], [])} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> [beam] end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @user_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)
    expect(GitBaseMock, :rules, 0, fn _root, _ref, _config -> {:ok, []} end)

    assert %GraphReport{exit_code: 0, findings: []} = Graph.run(request(%{judge: false}), deps())
  end
end
