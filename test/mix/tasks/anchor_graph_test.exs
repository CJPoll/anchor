defmodule Mix.Tasks.Anchor.GraphTest do
  # DND-5440: `mix anchor.graph`, the Framework entry: argument parsing,
  # rendering and exit codes. The Manager's adapters are doubled by Hammox and
  # passed through the task's options (the `mix anchor.sabotage` precedent);
  # the compile step is injected, so no test spawns mix or compiles a project.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: false

  import Anchor.Test.BeamFixtures
  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.GraphStoreMock
  alias Anchor.Test.GraphRuleStubs, as: Rules
  alias Anchor.SourceSourceMock
  alias Mix.Tasks.Anchor.Graph

  setup :verify_on_exit!

  @file_path "lib/app/domain/thing.ex"
  @source """
  defmodule AnchorFixtures.AnchorGraphTaskTest.Thing do
    def x, do: :x
  end
  """

  setup_all do
    [{_module, binary}] = compile_unloaded(@source, @file_path)
    %{beam: BeamReader.decode(binary, app: :anchor, path: "ebin/thing.beam")}
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

  defp opts do
    [
      compile: fn -> send(self(), :compiled) end,
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock,
      graph_rules: Rules.all()
    ]
  end

  defp expect_run(rules, beam) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules)} end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, ebin}] ->
      # The task gathers the project's own ebin from Mix.
      assert String.ends_with?(ebin, "lib/anchor/ebin")
      [beam]
    end)

    expect(SourceSourceMock, :read, fn _root, [@file_path] -> %{@file_path => {:ok, @source}} end)

    expect(GraphStoreMock, :write, fn dir, _key, _graph ->
      assert String.ends_with?(dir, "_build/test/anchor")
      :ok
    end)
  end

  test "a passing run prints the summary and returns :ok after compiling", %{beam: beam} do
    expect_run([rule(:stub_ok, "ok", 1)], beam)

    output = capture_io(fn -> assert Graph.run([], opts()) == :ok end)

    assert_received :compiled

    assert output ==
             "anchor.graph: 1 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)\n"
  end

  test "--format json --only a --only b runs only rules a and b, and prints JSON", %{beam: beam} do
    expect_run(
      [rule(:stub_finds, "a", 1), rule(:stub_ok, "b", 2), rule(:stub_raises, "c", 3)],
      beam
    )

    output =
      capture_io(fn ->
        assert catch_exit(Graph.run(~w(--format json --only a --only b), opts())) ==
                 {:shutdown, 1}
      end)

    assert %{"rules" => 2, "findings" => [%{"rule_id" => "a", "file" => @file_path}]} =
             JSON.decode!(output)
  end

  test "a violation exits {:shutdown, 1} after printing it", %{beam: beam} do
    expect_run([rule(:stub_finds, "a", 1)], beam)

    output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 1} end)

    assert output =~
             ~s|#{@file_path}:2: [enforce] rule 1 (id: "a", stub_finds) AnchorFixtures.AnchorGraphTaskTest.Thing was found. Fix: do not be found.|
  end

  test "could not measure exits {:shutdown, 3}" do
    expect(ConfigLoaderMock, :load, fn -> {:error, {:config_not_found, ["/p/.anchor.yml"]}} end)

    output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 3} end)
    assert output =~ "Anchor found no .anchor.yml"
  end

  test "an unknown flag, a bad format, an argument, --base or --write-baseline is usage: exit 2 with Fix:" do
    for argv <- [
          ~w(--bogus),
          ~w(--format xml),
          ~w(extra),
          ~w(--base main),
          ~w(--write-baseline r)
        ] do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Graph.run(argv, opts())) == {:shutdown, 2}
        end)

      assert stderr =~ "Usage: mix anchor.graph"
      assert stderr =~ "Fix: "
      refute_received :compiled
    end
  end
end
