defmodule Mix.Tasks.Anchor.ExplainTest do
  # DND-5446: `mix anchor.explain`, the Framework entry: argument parsing,
  # rendering and exit codes. The Manager's adapters are doubled by Hammox and
  # passed through the task's options; the compile step is injected, so no
  # test spawns mix or compiles a project.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: false

  import Anchor.Test.BeamFixtures
  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.GraphStoreMock
  alias Anchor.SourceSourceMock
  alias Mix.Tasks.Anchor.Explain

  setup :verify_on_exit!

  @subject "lib/app/domain/thing.ex"

  @source """
  defmodule AnchorFixtures.AnchorExplainTaskTest.Thing do
    def x, do: :x
  end
  """

  setup_all do
    [{_module, binary}] = compile_unloaded(@source, @subject)
    %{beam: BeamReader.decode(binary, app: :anchor, path: "ebin/thing.beam")}
  end

  defp config do
    Config.parse_config(%{
      "rules" => [%{"type" => "layering", "id" => "layering", "paths" => ["lib/**/*.ex"]}],
      "architecture" => %{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "domain",
            "role" => "domain",
            "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
          }
        ],
        "calls" => %{"domain" => ["domain"]}
      }
    })
  end

  defp opts(compiled?) do
    [
      compile: fn ->
        send(self(), :compiled)
        compiled?
      end,
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock
    ]
  end

  defp expect_uncompiled_explain do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
    stub_absent_source()
    expect(GraphStoreMock, :read, 0, fn _dir, _key -> {:error, :enoent} end)
    expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)
  end

  # The subject's file does not exist (it is planned).
  defp stub_absent_source do
    stub(SourceSourceMock, :read, fn _root, files ->
      Map.new(files, &{&1, {:error, :enoent}})
    end)
  end

  test "a path answers in text, and a compile failure is noted rather than fatal" do
    expect_uncompiled_explain()

    output = capture_io(fn -> assert Explain.run([@subject], opts(false)) == :ok end)

    assert_received :compiled
    assert output =~ "anchor.explain: lib/app/domain/thing.ex\n"
    assert output =~ "  module: App.Domain.Thing\n"
    assert output =~ "  bucket: domain (role domain)\n"
    assert output =~ "compile failed; beam facts unknown"
    assert output =~ "findings: not computed (run mix anchor.graph)"
  end

  test "--format json prints the JSON answer" do
    expect_uncompiled_explain()

    output =
      capture_io(fn -> assert Explain.run(["--format", "json", @subject], opts(false)) == :ok end)

    assert %{
             "subject" => @subject,
             "findings" => nil,
             "classification" => %{"bucket" => "domain"}
           } =
             JSON.decode!(output)
  end

  test "a compiled project with no current graph artifact reads it under this build's key", %{
    beam: beam
  } do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, _ebin}] -> [beam] end)
    stub_absent_source()

    expect(GraphStoreMock, :read, fn dir, _key ->
      assert String.ends_with?(dir, "_build/test/anchor")
      {:error, :enoent}
    end)

    expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

    output = capture_io(fn -> assert Explain.run([@subject], opts(true)) == :ok end)

    assert output =~ "findings: not computed (run mix anchor.graph)"
    refute output =~ "compile failed"
  end

  test "no subject, two subjects, an unknown flag or a bad format is usage: exit 2 with Fix:" do
    for argv <- [[], [@subject, "lib/other.ex"], ["--bogus", @subject], ~w(--format xml x.ex)] do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Explain.run(argv, opts(true))) == {:shutdown, 2}
        end)

      assert stderr =~ "Usage: mix anchor.explain"
      assert stderr =~ "Fix: "
      refute_received :compiled
    end
  end

  test "a subject that is neither a module nor a path under the root is usage: exit 2" do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config()} end)

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Explain.run(["../outside.ex"], opts(false))) == {:shutdown, 2}
      end)

    assert stderr =~ ~s("../outside.ex" is neither a module name nor an .ex path)
    assert stderr =~ "Fix: "
  end

  test "no config is could-not-check: exit 3" do
    expect(ConfigLoaderMock, :load, fn -> {:error, {:config_not_found, ["/p/.anchor.yml"]}} end)

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Explain.run([@subject], opts(false))) == {:shutdown, 3}
      end)

    assert stderr =~ "Anchor found no .anchor.yml"
  end
end
