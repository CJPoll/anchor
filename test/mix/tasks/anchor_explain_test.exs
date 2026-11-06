defmodule Mix.Tasks.Anchor.ExplainTest do
  # DND-5446: `mix anchor.explain`, the Framework entry: argument parsing,
  # rendering and exit codes. The Manager's adapters are doubled by Hammox and
  # passed through the task's options; the compile step is injected, so no
  # test spawns mix or compiles a project.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  # Sabotage record (the umbrella wiring): ../../sabotage_records/explain-20261106-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: false

  import Anchor.Test.BeamFixtures
  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.GraphStoreMock
  alias Anchor.SourceSourceMock
  alias Mix.Tasks.Anchor.Explain
  alias Mix.Tasks.Anchor.Graph, as: GraphTask

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

  # DND-5637's wiring: the task builds the request mix anchor.graph builds, so an
  # umbrella's explain reads the artifact its graph run wrote. Drifted, it would
  # say "not computed (run mix anchor.graph)" right after that run.
  describe "an umbrella (apps_paths injected: this test runs inside Anchor)" do
    @alpha_file "apps/alpha/lib/alpha.ex"
    @alpha_source """
    defmodule AnchorFixtures.AnchorExplainTaskTest.Alpha do
      def z, do: :z
    end
    """

    defp umbrella_config do
      Config.parse_config(%{
        "rules" => [%{"type" => "layering", "id" => "layering", "paths" => ["apps/**/*.ex"]}],
        "architecture" => %{
          "contexts" => %{"depth" => 2},
          "buckets" => [
            %{
              "name" => "domain",
              "role" => "domain",
              "select" => [%{"paths" => ["apps/alpha/**"]}]
            }
          ],
          "calls" => %{"domain" => ["domain"]}
        }
      })
    end

    test "explain reads the artifact the graph run of the same apps wrote" do
      [{_module, binary}] = compile_unloaded(@alpha_source, "lib/alpha.ex")
      beam = BeamReader.decode(binary, app: :alpha, path: "ebin/alpha.beam")
      apps_paths = [apps_paths: %{alpha: "apps/alpha"}]

      expect(ConfigLoaderMock, :load, 2, fn -> {:ok, umbrella_config()} end)

      Mox.expect(BeamSourceMock, :read_ebins, 2, fn [{:alpha, ebin}] ->
        assert String.ends_with?(ebin, "_build/test/lib/alpha/ebin")
        [beam]
      end)

      stub(SourceSourceMock, :read, fn _root, files ->
        Map.new(files, fn
          @alpha_file -> {@alpha_file, SourceFacts.from_source(@alpha_file, @alpha_source)}
          other -> {other, {:error, :enoent}}
        end)
      end)

      expect(GraphStoreMock, :write, fn dir, key, graph ->
        send(self(), {:written, dir, key, graph})
        :ok
      end)

      capture_io(fn -> GraphTask.run([], opts(true) ++ apps_paths) end)
      assert_received {:written, dir, key, graph}

      expect(GraphStoreMock, :read, fn ^dir, ^key -> {:ok, graph} end)

      output =
        capture_io(fn ->
          assert Explain.run([@alpha_file, "--format", "json"], opts(true) ++ apps_paths) == :ok
        end)

      decoded = JSON.decode!(output)
      assert decoded["findings"] == []
      assert decoded["unknown"] == []
      assert decoded["classification"]["status"] == "classified"
      assert decoded["classification"]["app"] == "alpha"
    end

    test "an app directory outside the root exits 3 with the refusal" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, umbrella_config()} end)
      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)

      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(
                   Explain.run(
                     [@alpha_file],
                     opts(true) ++ [apps_paths: %{alpha: "/elsewhere/alpha"}]
                   )
                 ) == {:shutdown, 3}
        end)

      assert stderr =~ "the apps_path of :alpha is /elsewhere/alpha"
      assert stderr =~ "Fix:"
    end
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

  # The default compile step (no :compile injected), with Mix.Task.run/2
  # doubled as Mix 1.19's compile behaves: without --return-errors a compile
  # error exits {:shutdown, 1}; with it, it returns {:error, diagnostics}.
  test "a project with a compile error still gets an answer: compile runs with --return-errors" do
    expect_uncompiled_explain()

    run_task = fn "compile", args ->
      send(self(), {:compile_args, args})
      if "--return-errors" in args, do: {:error, []}, else: exit({:shutdown, 1})
    end

    output =
      capture_io(fn ->
        assert Explain.run(
                 [@subject],
                 Keyword.delete(opts(true), :compile) ++ [run_task: run_task]
               ) ==
                 :ok
      end)

    assert_received {:compile_args, ["--return-errors"]}
    assert output =~ "compile failed; beam facts unknown"
  end

  test "a compiler that exits anyway is a failed compile, not the task's exit" do
    expect_uncompiled_explain()
    run_task = fn "compile", _args -> exit({:shutdown, 1}) end

    output =
      capture_io(fn ->
        assert Explain.run(
                 [@subject],
                 Keyword.delete(opts(true), :compile) ++ [run_task: run_task]
               ) ==
                 :ok
      end)

    assert output =~ "compile failed; beam facts unknown"
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
