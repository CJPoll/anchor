defmodule Anchor.Managers.GraphRuleFailClosedTest do
  # DND-5476: a graph rule's fail-closed violation (a rule that checks
  # nothing, `aggregate_declarations` with no aggregate declared) is an issue
  # of the run: enforced even for an `enforcement: report` rule, and never
  # held or written by its baseline. Every adapter is doubled by Hammox.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
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
  alias Anchor.Domain.Violation
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.SourceSourceMock

  defmodule ChecksNothing do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_checks_nothing

    # One rule finding (keyed) and one fail-closed issue carrying a key the
    # baseline lists: the key must not hold it.
    def check(_model, rule) do
      [
        %Violation{filename: "lib/x.ex", line: 1, key: "c|found", message: "found. Fix: no."},
        %Violation{
          kind: :fail_closed,
          filename: ".anchor.yml",
          key: "c|nothing",
          message: "#{rule.id} checks nothing. Fix: declare one."
        }
      ]
    end
  end

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  @path ".anchor/baselines/c.txt"
  @user_file "lib/my_app/domain/user.ex"
  @user_source """
  defmodule AnchorFixtures.GraphRuleFailClosedTest.User do
    def name(user), do: user
  end
  """

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@user_source, @user_file}])
    %{beam: BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/user.beam")}
  end

  defp config(rule) do
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

    %Config{rules: [rule], architecture: arch, path: ".anchor.yml"}
  end

  defp run(rule, beam, opts \\ %{}) do
    expect(ConfigLoaderMock, :load_in, fn _root -> {:ok, config(rule)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> [beam] end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @user_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    Graph.run(
      %Request{
        apps: [{:my_app, @ebin}],
        root: @root,
        build_path: Path.join(@root, "_build/test"),
        env: :test,
        opts: Map.merge(%{format: :text, only: []}, opts)
      },
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock,
      baseline_store: BaselineStoreMock,
      graph_rules: [ChecksNothing]
    )
  end

  @rule %{
    type: :stub_checks_nothing,
    id: "c",
    bucket: "domain",
    index: 1,
    baseline: @path,
    enforcement: :report
  }

  test "a report rule's fail-closed issue is enforced, and its baseline holds only the rule finding",
       %{beam: beam} do
    expect(BaselineStoreMock, :read, fn @root, @path ->
      Baseline.parse("c|found\nc|nothing\n")
    end)

    report = run(@rule, beam)

    assert report.exit_code == 1
    assert [held] = report.held
    assert held.key == "c|found"

    assert [nothing] = Enum.filter(report.findings, &(&1.message =~ "checks nothing"))
    assert nothing.enforcement == :enforce
    assert nothing.key == nil
    assert nothing.label == "anchor.graph"
  end

  test "positive control: the same rule's finding without a baseline is report-only",
       %{beam: beam} do
    report = run(Map.delete(@rule, :baseline), beam)

    assert [%{enforcement: :report, key: "c|found"}] =
             Enum.filter(report.findings, &(&1.message =~ "found."))
  end

  test "--write-baseline writes the rule finding only, and the issue still fails the run",
       %{beam: beam} do
    expect(BaselineStoreMock, :create, fn @root, @path, contents ->
      send(self(), {:written, contents})
      :ok
    end)

    report = run(%{@rule | enforcement: :enforce}, beam, %{write_baseline: "c"})

    assert_received {:written, contents}
    assert contents =~ "c|found"
    refute contents =~ "nothing"
    assert report.exit_code == 1
  end
end
