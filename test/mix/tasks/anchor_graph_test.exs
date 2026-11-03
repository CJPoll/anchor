defmodule Mix.Tasks.Anchor.GraphTest do
  # DND-5440: `mix anchor.graph`, the Framework entry: argument parsing,
  # rendering and exit codes. The Manager's adapters are doubled by Hammox and
  # passed through the task's options (the `mix anchor.sabotage` precedent);
  # the compile step is injected, so no test spawns mix or compiles a project.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5630_graph_hardening.md
  # DND-5441 (--base, --write-baseline, --verbose):
  #   ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5658 (--project): ../../sabotage_records/graph_runner-20261103-dnd_5658_ci_base_ratchet.md
  use ExUnit.Case, async: false

  import Anchor.Test.BeamFixtures
  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph.SourceFacts
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
    expect(ConfigLoaderMock, :load_in, fn _root -> {:ok, config(rules)} end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, ebin}] ->
      # The task gathers the project's own ebin from Mix.
      assert String.ends_with?(ebin, "lib/anchor/ebin")
      [beam]
    end)

    expect(SourceSourceMock, :read, fn _root, [@file_path] ->
      %{@file_path => SourceFacts.from_source(@file_path, @source)}
    end)

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

  # DND-5585: a project built somewhere other than <root>/_build/<env>
  # (MIX_BUILD_PATH, as some docker setups set it) gets its artifact under its
  # own build path. sync: MIX_BUILD_PATH is the VM's OS environment.
  test "the artifact goes under Mix's build path, as MIX_BUILD_PATH sets it", %{beam: beam} do
    build = Path.join(System.tmp_dir!(), "anchor-build-#{System.unique_integer([:positive])}")
    previous = System.get_env("MIX_BUILD_PATH")

    on_exit(fn ->
      if previous,
        do: System.put_env("MIX_BUILD_PATH", previous),
        else: System.delete_env("MIX_BUILD_PATH")
    end)

    System.put_env("MIX_BUILD_PATH", build)

    expect(ConfigLoaderMock, :load_in, fn _root -> {:ok, config([rule(:stub_ok, "ok", 1)])} end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, ebin}] ->
      assert ebin == Path.join(build, "lib/anchor/ebin")
      [beam]
    end)

    expect(SourceSourceMock, :read, fn _root, [@file_path] ->
      %{@file_path => SourceFacts.from_source(@file_path, @source)}
    end)

    expect(GraphStoreMock, :write, fn dir, _key, _graph ->
      send(self(), {:artifact_dir, dir})
      :ok
    end)

    capture_io(fn -> assert Graph.run([], opts()) == :ok end)

    assert_received {:artifact_dir, dir}
    assert dir == Path.join(build, "anchor")
  end

  # DND-5630: a module compiled from a source outside the root
  # (`elixirc_paths: ["../shared"]`) has an absolute relative_file. It is
  # project code: enforced, and printed on its root-relative ../ path.
  test "a module compiled from outside the root is enforced on its ../ path" do
    shared_path = Path.expand("../anchor-graph-task-shared/lib/shared.ex", File.cwd!())
    shared_file = "../anchor-graph-task-shared/lib/shared.ex"

    shared_source = """
    defmodule AnchorFixtures.AnchorGraphTaskTest.Shared do
      def y, do: :y
    end
    """

    [{_module, binary}] = compile_unloaded(shared_source, shared_path)
    beam = BeamReader.decode(binary, app: :anchor, path: "ebin/shared.beam")
    assert beam.elixir.relative_file == shared_path

    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "shared",
            "role" => "domain",
            "select" => [%{"paths" => ["../anchor-graph-task-shared/**/*.ex"]}]
          }
        ],
        "calls" => %{"shared" => []}
      })

    rules = [%{type: :stub_finds, id: "a", bucket: "shared", index: 1}]

    expect(ConfigLoaderMock, :load_in, fn _root ->
      {:ok, %Config{rules: rules, architecture: arch, path: ".anchor.yml"}}
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, _ebin}] -> [beam] end)

    expect(SourceSourceMock, :read, fn _root, [^shared_file] ->
      %{shared_file => SourceFacts.from_source(shared_file, shared_source)}
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 1} end)

    assert output =~
             ~s|#{shared_file}:2: [enforce] rule 1 (id: "a", stub_finds) AnchorFixtures.AnchorGraphTaskTest.Shared was found.|

    assert output =~ "anchor.graph: 1 modules (1 outside the root) in 1 apps"
  end

  # DND-5637: in an umbrella the task gathers each app's ebin under the build
  # path and each app's directory from Mix.Project.apps_paths/0 (injected
  # here: this test runs inside Anchor, which is no umbrella), and the
  # app-relative relative_file Mix writes is keyed umbrella-root-relative.
  test "an umbrella's app-relative source paths are keyed from the umbrella root" do
    alpha_source = """
    defmodule AnchorFixtures.AnchorGraphTaskTest.Alpha do
      def z, do: :z
    end
    """

    [{_module, binary}] = compile_unloaded(alpha_source, "lib/alpha.ex")
    beam = BeamReader.decode(binary, app: :alpha, path: "ebin/alpha.beam")

    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{"name" => "alpha", "role" => "domain", "select" => [%{"paths" => ["apps/alpha/**"]}]}
        ],
        "calls" => %{"alpha" => []}
      })

    rules = [%{type: :stub_finds, id: "a", bucket: "alpha", index: 1}]

    expect(ConfigLoaderMock, :load_in, fn _root ->
      {:ok, %Config{rules: rules, architecture: arch, path: ".anchor.yml"}}
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:alpha, ebin}] ->
      assert String.ends_with?(ebin, "_build/test/lib/alpha/ebin")
      [beam]
    end)

    expect(SourceSourceMock, :read, fn _root, ["apps/alpha/lib/alpha.ex"] ->
      %{"apps/alpha/lib/alpha.ex" => SourceFacts.from_source("x.ex", alpha_source)}
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)

    opts = Keyword.put(opts(), :apps_paths, %{alpha: "apps/alpha"})
    output = capture_io(fn -> assert catch_exit(Graph.run([], opts)) == {:shutdown, 1} end)

    assert output =~ ~s|apps/alpha/lib/alpha.ex:2: [enforce] rule 1 (id: "a", stub_finds)|
  end

  test "a violation exits {:shutdown, 1} after printing it", %{beam: beam} do
    expect_run([rule(:stub_finds, "a", 1)], beam)

    output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 1} end)

    assert output =~
             ~s|#{@file_path}:2: [enforce] rule 1 (id: "a", stub_finds) AnchorFixtures.AnchorGraphTaskTest.Thing was found. Fix: do not be found.|
  end

  test "could not measure exits {:shutdown, 3}" do
    expect(ConfigLoaderMock, :load_in, fn _root ->
      {:error, {:config_not_found, ["/p/.anchor.yml"]}}
    end)

    output = capture_io(fn -> assert catch_exit(Graph.run([], opts())) == {:shutdown, 3} end)
    assert output =~ "Anchor found no .anchor.yml"
  end

  test "an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:" do
    for argv <- [
          ~w(--bogus),
          ~w(--format xml),
          ~w(extra),
          ["--base", "main; rm -rf /"],
          ["--base", "--output=/tmp/x"]
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

  # DND-5441: the baseline flags reach the Manager as request options.
  describe "baseline flags" do
    defp baselined(index),
      do: Map.merge(rule(:stub_finds, "a", index), %{baseline: ".anchor/baselines/a.txt"})

    @key "a|AnchorFixtures.AnchorGraphTaskTest.Thing|found"

    test "--base REF reads the baseline at REF; a growth fails with GREW", %{beam: beam} do
      expect_run([baselined(1)], beam)

      expect(Anchor.BaselineStoreMock, :read, fn _root, ".anchor/baselines/a.txt" ->
        {:ok, ["#{@key}", "a|Extra|x"]}
      end)

      # DND-5629: the base copy is found by the rule's id in the base config.
      expect(Anchor.GitBaseMock, :rules, fn _root, "origin/main", ".anchor.yml" ->
        {:ok, [baselined(1)]}
      end)

      expect(Anchor.GitBaseMock, :show, fn _root, "origin/main", ".anchor/baselines/a.txt" ->
        {:ok, ["#{@key}"]}
      end)

      output =
        capture_io(fn ->
          assert catch_exit(Graph.run(~w(--base origin/main), baseline_opts())) == {:shutdown, 1}
        end)

      assert output =~ "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
    end

    test "--write-baseline RULE_ID creates the file; held findings print with --verbose", %{
      beam: beam
    } do
      expect_run([baselined(1)], beam)

      expect(Anchor.BaselineStoreMock, :create, fn _root, ".anchor/baselines/a.txt", contents ->
        assert contents == "# anchor baseline for a; shrink only\n#{@key}\n"
        :ok
      end)

      output =
        capture_io(fn ->
          assert Graph.run(~w(--write-baseline a --verbose), baseline_opts()) == :ok
        end)

      assert output =~ "wrote 1 entries to .anchor/baselines/a.txt"
      assert output =~ "[held] rule 1 (id: \"a\", stub_finds)"
      assert output =~ "(1 report-only, 1 baselined)"
    end

    test "--write-baseline over an existing file exits 2", %{beam: beam} do
      expect_run([baselined(1)], beam)

      expect(Anchor.BaselineStoreMock, :create, fn _root, _path, _contents ->
        {:error, :exists}
      end)

      output =
        capture_io(fn ->
          assert catch_exit(Graph.run(~w(--write-baseline a), baseline_opts())) == {:shutdown, 2}
        end)

      assert output =~ ".anchor/baselines/a.txt exists; --write-baseline only creates"
    end

    defp baseline_opts,
      do: opts() ++ [baseline_store: Anchor.BaselineStoreMock, git_base: Anchor.GitBaseMock]
  end

  # DND-5658: `--project DIR` judges another checkout with this checkout's
  # Anchor, so CI can judge a pull request with the code landed on its base.
  describe "--project DIR" do
    setup do
      dir = Path.join(System.tmp_dir!(), "anchor-project-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "reads DIR's config, beams, sources, baselines and git; the artifact stays the judge's",
         %{beam: beam, dir: dir} do
      rule = Map.merge(rule(:stub_finds, "a", 1), %{baseline: ".anchor/baselines/a.txt"})
      key = "a|AnchorFixtures.AnchorGraphTaskTest.Thing|found"
      expect(ConfigLoaderMock, :load_judged, fn ^dir -> {:ok, config([rule])} end)

      Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, ebin}] ->
        assert ebin == Path.join(dir, "_build/test/lib/anchor/ebin")
        [beam]
      end)

      expect(SourceSourceMock, :read, fn ^dir, [@file_path] ->
        %{@file_path => SourceFacts.from_source(@file_path, @source)}
      end)

      expect(GraphStoreMock, :write, fn artifact_dir, _key, _graph ->
        assert artifact_dir == Path.join(Mix.Project.build_path(), "anchor")
        :ok
      end)

      expect(Anchor.BaselineStoreMock, :read, fn ^dir, ".anchor/baselines/a.txt" ->
        {:ok, [key, "a|Extra|x"]}
      end)

      expect(Anchor.GitBaseMock, :rules, fn ^dir, "origin/main", ".anchor.yml" ->
        {:ok, [rule]}
      end)

      expect(Anchor.GitBaseMock, :show, fn ^dir, "origin/main", ".anchor/baselines/a.txt" ->
        {:ok, [key]}
      end)

      opts = opts() ++ [baseline_store: Anchor.BaselineStoreMock, git_base: Anchor.GitBaseMock]

      output =
        capture_io(fn ->
          assert catch_exit(Graph.run(["--project", dir, "--base", "origin/main"], opts)) ==
                   {:shutdown, 1}
        end)

      assert_received :compiled
      assert output =~ "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
    end

    test "a DIR that is not a directory, --write-baseline and an umbrella judge exit 2 with Fix:",
         %{dir: dir} do
      for {argv, extra, reason} <- [
            {["--project", Path.join(dir, "missing")], [],
             "is not a directory. Fix: pass --project the root of a compiled checkout."},
            {["--project", dir, "--write-baseline", "a"], [],
             "writes the judged tree. Fix: run mix anchor.graph --write-baseline in #{dir}"},
            {["--project", dir], [apps_paths: %{web: "apps/web"}],
             "from an umbrella is not supported. Fix: run the judge from a single-project"}
          ] do
        stderr =
          capture_io(:stderr, fn ->
            assert catch_exit(Graph.run(argv, opts() ++ extra)) == {:shutdown, 2}
          end)

        assert stderr =~ "--project refused: "
        assert stderr =~ reason
        refute_received :compiled
      end
    end

    # sync: MIX_BUILD_PATH is the VM's OS environment.
    test "a build path outside this checkout exits 2: DIR's ebin could not be found", %{dir: dir} do
      previous = System.get_env("MIX_BUILD_PATH")

      on_exit(fn ->
        if previous,
          do: System.put_env("MIX_BUILD_PATH", previous),
          else: System.delete_env("MIX_BUILD_PATH")
      end)

      System.put_env("MIX_BUILD_PATH", Path.join(System.tmp_dir!(), "anchor-elsewhere"))

      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Graph.run(["--project", dir], opts())) == {:shutdown, 2}
        end)

      assert stderr =~ "is outside this checkout. Fix: unset MIX_BUILD_PATH"
      refute_received :compiled
    end
  end
end
