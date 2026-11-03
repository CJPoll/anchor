defmodule Anchor.Managers.GraphTest do
  # DND-5440: the graph runner's Manager with every adapter doubled by Hammox
  # (ADR 002). Fixture beams are compiled in the test and decoded by the real
  # reader's decode/2 as setup; the Manager under test gets them from the
  # BeamSource double. QA plan: test/anchor/managers/graph_test.exs.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5551_graph_hardening.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5630_graph_hardening.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5637_umbrella_paths.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5638_root_in_key.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request
  alias Anchor.Test.GraphRuleStubs, as: Rules
  alias Anchor.SourceSourceMock

  setup :verify_on_exit!

  @root "/proj"
  @ebin "/proj/_build/test/lib/my_app/ebin"
  # A build path that is not <root>/_build/<env> (MIX_BUILD_PATH): the
  # artifact goes under it, never under the root (DND-5585).
  @build_path "/builds/my_app-test"
  @artifact_dir "/builds/my_app-test/anchor"
  @user_file "lib/my_app/domain/user.ex"
  @user_source """
  defmodule AnchorFixtures.GraphManagerTest.User do
    def name(user), do: user
  end
  """
  @accounts_file "lib/my_app/managers/accounts.ex"
  @accounts_source """
  defmodule AnchorFixtures.GraphManagerTest.Accounts do
    def get(id), do: AnchorFixtures.GraphManagerTest.User.name(id)
  end
  """
  @stray_file "lib/my_app/stray.ex"
  @stray_source """
  defmodule AnchorFixtures.GraphManagerTest.Stray do
    def x, do: :x
  end
  """

  # DND-5588: compiled from absolute paths outside this test's cwd, so each
  # beam's relative_file is absolute: one inside the root, one outside it (as
  # an `elixirc_paths: ["lib", "../shared"]` entry would compile it).
  @inside_path "/proj/lib/my_app/domain/inside.ex"
  @inside_file "lib/my_app/domain/inside.ex"
  @inside_source """
  defmodule AnchorFixtures.GraphManagerTest.Inside do
    def i(x), do: x
  end
  """
  @outside_path "/shared/lib/shared.ex"
  @outside_source """
  defmodule AnchorFixtures.GraphManagerTest.Shared do
    def t(x), do: x
  end
  """

  @user AnchorFixtures.GraphManagerTest.User
  @accounts AnchorFixtures.GraphManagerTest.Accounts
  @stray AnchorFixtures.GraphManagerTest.Stray

  setup_all do
    beams =
      [
        {@user_source, @user_file},
        {@accounts_source, @accounts_file},
        {@stray_source, @stray_file},
        {@inside_source, @inside_path},
        {@outside_source, @outside_path}
      ]
      |> compile_all_unloaded()
      |> Map.new(fn {module, binary} ->
        {module, BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/#{module}.beam")}
      end)

    %{beams: beams}
  end

  defp architecture(extra_buckets \\ []) do
    buckets =
      [
        %{
          "name" => "domain",
          "role" => "domain",
          "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
        },
        %{
          "name" => "managers",
          "role" => "managers",
          "select" => [%{"paths" => ["lib/**/managers/**/*.ex"]}]
        }
      ] ++ extra_buckets

    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => buckets,
        "calls" => Map.new(buckets, &{&1["name"], []})
      })

    arch
  end

  defp config(rules, arch \\ architecture()),
    do: %Config{rules: rules, architecture: arch, path: ".anchor.yml"}

  defp request(opts \\ %{format: :text, only: []}),
    do: %Request{
      apps: [{:my_app, @ebin}],
      root: @root,
      build_path: @build_path,
      env: :test,
      opts: opts
    }

  defp deps,
    do: [
      config_loader: ConfigLoaderMock,
      beam_source: BeamSourceMock,
      source_source: SourceSourceMock,
      graph_store: GraphStoreMock,
      graph_rules: Rules.all()
    ]

  @sources %{
    @user_file => {:ok, @user_source},
    @accounts_file => {:ok, @accounts_source},
    @stray_file => {:ok, @stray_source}
  }

  defp expect_run(config, beams, opts \\ []) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn [{:my_app, @ebin}] -> beams end)

    sources = Keyword.get(opts, :sources, @sources)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, source_facts(&1, Map.get(sources, &1, {:error, :enoent}))})
    end)

    expect(GraphStoreMock, :write, Keyword.get(opts, :writes, 1), fn @artifact_dir,
                                                                     key,
                                                                     %Anchor.Domain.Graph{} ->
      assert key =~ ~r/\A[0-9a-f]{64}\z/
      send(self(), {:artifact_key, key})
      Keyword.get(opts, :write_result, :ok)
    end)

    # P2: the verdict never reads the artifact.
    expect(GraphStoreMock, :read, 0, fn _dir, _key -> {:error, :enoent} end)
  end

  # What the SourceSource port returns: each file's facts, never its text.
  defp source_facts(file, {:ok, text}), do: SourceFacts.from_source(file, text)
  defp source_facts(_file, error), do: error

  defp classified(beams), do: [beams[@user], beams[@accounts]]

  defp rule(type, id, extra \\ %{}),
    do: Map.merge(%{type: type, id: id, bucket: "domain", index: 1}, extra)

  defp messages(report), do: Enum.map(report.findings ++ report.could_not_check, & &1.message)

  describe "run/2 happy path" do
    test "every module classifies and the rule holds: exit 0, counts exact, artifact written once",
         %{beams: beams} do
      expect_run(config([rule(:stub_ok, "ok")]), classified(beams))

      report = Graph.run(request(), deps())

      assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report

      assert report.counts == %{
               modules: 2,
               apps: 1,
               rules: 1,
               opaque: 0,
               no_core: 0,
               outside_root: 0,
               apply_sites: nil
             }
    end

    # DND-5549: a function with no Core body is never silent.
    test "a public function with no Core body is an issue, and the summary counts it", %{
      beams: beams
    } do
      user = beams[@user]

      defs =
        Enum.reject(:cerl.module_defs(user.core), fn {fname, _fun} ->
          :cerl.var_name(fname) == {:name, 1}
        end)

      core =
        :cerl.update_c_module(
          user.core,
          :cerl.module_name(user.core),
          :cerl.module_exports(user.core),
          :cerl.module_attrs(user.core),
          defs
        )

      expect_run(config([rule(:stub_ok, "ok")]), [%{user | core: core}, beams[@accounts]])

      report = Graph.run(request(), deps())

      assert report.counts.no_core == 1
      assert report.exit_code == 1
      assert Enum.any?(messages(report), &(&1 =~ "has no Core Erlang body for name/1"))
    end

    test "a report-only rule's findings print and exit 0", %{beams: beams} do
      expect_run(config([rule(:stub_finds, "f", %{enforcement: :report})]), classified(beams))

      assert %GraphReport{exit_code: 0, findings: [finding]} = Graph.run(request(), deps())
      assert finding.enforcement == :report
      assert finding.file == @user_file
      assert finding.rule_id == "f"
      assert finding.label == ~s|rule 1 (id: "f", stub_finds)|
    end
  end

  describe "run/2 could not measure (exit 3)" do
    test "a missing config is exit 3 with config_violation's message; no beam is read, no artifact written" do
      expect(ConfigLoaderMock, :load, fn ->
        {:error, {:config_not_found, ["/proj/.anchor.yml"]}}
      end)

      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)
      expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

      report = Graph.run(request(), deps())

      assert report.exit_code == 3
      assert [%{file: "/proj/.anchor.yml", message: message}] = report.could_not_check
      assert message =~ "Anchor found no .anchor.yml"
      assert message =~ "Fix: "
    end

    test "a config with no architecture: section is exit 3" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config([rule(:stub_ok, "ok")], nil)} end)
      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)
      expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

      report = Graph.run(request(), deps())
      assert report.exit_code == 3
      assert [%{message: message}] = report.could_not_check
      assert message =~ "COULD NOT MEASURE: .anchor.yml has no architecture: section"
    end

    test "zero modules read is exit 3, COULD NOT MEASURE naming the ebins; no artifact written" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config([])} end)
      Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> [] end)
      expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

      report = Graph.run(request(), deps())
      assert report.exit_code == 3

      assert [%{message: "COULD NOT MEASURE: read 0 modules from " <> @ebin <> _rest}] =
               report.could_not_check
    end

    test "only undecodable beams is zero modules read: exit 3" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config([])} end)

      Mox.expect(BeamSourceMock, :read_ebins, fn _apps ->
        [{:error, %{path: "#{@ebin}/x.beam", module: X, reason: :no_debug_info}}]
      end)

      expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

      assert Graph.run(request(), deps()).exit_code == 3
    end
  end

  describe "run/2 per-module fail-closed issues (exit 1)" do
    test "a beam with no debug_info is an issue on it; the other modules still classify and their findings print",
         %{beams: beams} do
      broken =
        {:error, %{path: "#{@ebin}/Elixir.Broken.beam", module: Broken, reason: :no_debug_info}}

      expect_run(config([rule(:stub_finds, "f")]), [broken | classified(beams)])

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [issue, rule_finding] = report.findings
      assert issue.file == "#{@ebin}/Elixir.Broken.beam"
      assert issue.label == "anchor.graph"
      assert issue.message =~ "Broken was compiled without debug_info"
      # Positive control: the good modules are classified and the rule ran.
      assert rule_finding.message =~ "#{inspect(@user)} was found."
      assert report.counts.modules == 2
    end

    test "a core_v1 refusal is a per-module issue", %{beams: beams} do
      refused = {:error, %{path: "#{@ebin}/r.beam", module: R, reason: {:core_v1_refused, :boom}}}
      expect_run(config([rule(:stub_ok, "ok")]), [refused | classified(beams)])

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{message: message}] = report.findings

      assert message =~ "R the beam's backend could not produce Core Erlang (:boom)"
    end

    test "an unclassified module is one issue on its source file", %{beams: beams} do
      expect_run(config([rule(:stub_ok, "ok")]), [beams[@stray] | classified(beams)])

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{file: @stray_file, line: 1, message: message}] = report.findings
      assert message =~ "#{inspect(@stray)} is in no architecture bucket."
    end

    test "a source file that cannot be read is an issue on it", %{beams: beams} do
      sources = Map.delete(@sources, @accounts_file)
      expect_run(config([rule(:stub_ok, "ok")]), classified(beams), sources: sources)

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{file: @accounts_file, message: message}] = report.findings
      assert message =~ "could not read the source of #{@accounts_file} (:enoent)"
    end

    test "an Erlang module a pattern selector classifies is opaque and counted, not an issue", %{
      beams: beams
    } do
      erl =
        {:error,
         %{
           path: "#{@ebin}/my_erl.beam",
           module: :my_erl,
           reason: {:not_elixir, :erl_abstract_code}
         }}

      opaque = %{"name" => "erlang", "role" => "adapters", "select" => [%{"pattern" => "my_erl"}]}

      expect_run(config([rule(:stub_ok, "ok")], architecture([opaque])), [erl | classified(beams)])

      report = Graph.run(request(), deps())
      assert report.exit_code == 0
      assert report.findings == []
      assert report.counts.opaque == 1
    end

    test "an Erlang module no bucket classifies is an issue", %{beams: beams} do
      erl =
        {:error,
         %{
           path: "#{@ebin}/my_erl.beam",
           module: :my_erl,
           reason: {:not_elixir, :erl_abstract_code}
         }}

      expect_run(config([rule(:stub_ok, "ok")]), [erl | classified(beams)])

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{message: message}] = report.findings
      assert message =~ ":my_erl is Erlang source"
      assert report.counts.opaque == 0
    end

    test "an interfaces.exports entry naming no module is an issue on the config; one naming a module is not",
         %{beams: beams} do
      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 2},
          "buckets" => [
            %{
              "name" => "domain",
              "role" => "domain",
              "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
            },
            %{
              "name" => "managers",
              "role" => "managers",
              "select" => [%{"paths" => ["lib/**/managers/**/*.ex"]}]
            }
          ],
          "calls" => %{"domain" => [], "managers" => []},
          "interfaces" => %{"exports" => [inspect(@user), "MyApp.Gone"]}
        })

      expect_run(config([rule(:stub_ok, "ok")], arch), classified(beams))

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{file: ".anchor.yml", message: message}] = report.findings
      assert message =~ "architecture interfaces.exports names MyApp.Gone, which is no module"
    end

    test "a rule below its min_modules is an issue on the config", %{beams: beams} do
      expect_run(config([rule(:stub_ok, "ok", %{min_modules: 2})]), classified(beams))

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{file: ".anchor.yml", message: message}] = report.findings
      assert message =~ ~s|rule 1 (id: "ok", stub_ok) selects 1 modules, below min_modules 2.|
    end
  end

  describe "run/2 rule crash isolation (AC4)" do
    for {type, kind_text} <- [
          stub_raises: "RuntimeError: rule blew up",
          stub_throws: "throw: :thrown",
          stub_exits: "exit: :gone",
          stub_malformed: "ArgumentError: check/2 returned :oops, not a list"
        ] do
      test "#{type}: one issue naming the rule and reason; a second rule's finding still prints",
           %{beams: beams} do
        rules = [rule(unquote(type), "crash"), rule(:stub_finds, "f", %{index: 2})]
        expect_run(config(rules), classified(beams))

        report = Graph.run(request(), deps())

        assert report.exit_code == 1
        assert [crash, found] = report.findings

        assert crash.message =~
                 ~s|rule 1 (id: "crash", #{unquote(type)}) could not run: #{unquote(kind_text)}|

        assert crash.message =~ "Fix: this is an Anchor bug"
        assert found.rule_id == "f"
        assert found.message =~ "#{inspect(@user)} was found."
      end
    end
  end

  describe "run/2 --only" do
    test "narrows to the named rules; a running rule's floor is still judged", %{beams: beams} do
      rules = [
        rule(:stub_finds, "a"),
        rule(:stub_raises, "b", %{index: 2}),
        rule(:stub_ok, "c", %{index: 3, min_modules: 99})
      ]

      expect_run(config(rules), classified(beams))

      report = Graph.run(request(%{format: :text, only: ["a", "c"]}), deps())

      assert Enum.map(report.findings, & &1.rule_id) == ["a", nil]

      assert report.counts.rules == 2
      # The narrowed-away rule b (it raises) never ran.
      refute Enum.any?(messages(report), &(&1 =~ "could not run"))
      # Rule c runs, so its floor is judged (positive control for the refute).
      assert Enum.any?(
               messages(report),
               &(&1 =~ ~s|(id: "c", stub_ok) selects 1 modules, below min_modules 99|)
             )
    end
  end

  describe "run/2 --only naming no rule" do
    test "is exit 3: a narrowed run that checks nothing must not read clean" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config([rule(:stub_ok, "ok")])} end)
      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)
      expect(GraphStoreMock, :write, 0, fn _dir, _key, _term -> :ok end)

      report = Graph.run(request(%{format: :text, only: ["ok", "typo"]}), deps())

      assert report.exit_code == 3
      assert [%{message: message}] = report.could_not_check
      assert message =~ ~s(--only "typo" names no graph rule)
    end
  end

  describe "run/2 source paths outside the project root (DND-5588, DND-5630)" do
    # Every beam the runner reads came from a project ebin, so a module
    # compiled from a source outside the root (`elixirc_paths: ["../shared"]`)
    # is project code: classified, judged and enforced like any other, keyed
    # by its root-relative path. The summary still counts such modules.
    @inside AnchorFixtures.GraphManagerTest.Inside
    @outside AnchorFixtures.GraphManagerTest.Shared
    @outside_file "../shared/lib/shared.ex"

    defp shared_bucket,
      do: %{
        "name" => "shared",
        "role" => "domain",
        "select" => [%{"paths" => ["../shared/**/*.ex"]}]
      }

    defp only_shared_architecture do
      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 2},
          "buckets" => [shared_bucket()],
          "calls" => %{"shared" => []}
        })

      arch
    end

    defp with_outside_source(sources), do: Map.put(sources, @outside_file, {:ok, @outside_source})

    test "an absolute path inside the root is a project module, read and classified by its relative path",
         %{beams: beams} do
      assert beams[@inside].elixir.relative_file == @inside_path

      expect_run(config([rule(:stub_ok, "ok")]), classified(beams) ++ [beams[@inside]],
        sources: Map.put(@sources, @inside_file, {:ok, @inside_source})
      )

      report = Graph.run(request(), deps())

      assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
      assert %{modules: 3, outside_root: 0} = report.counts
    end

    test "an outside-root module no bucket selects fails the run on its ../ path", %{beams: beams} do
      assert beams[@outside].elixir.relative_file == @outside_path

      expect_run(config([rule(:stub_ok, "ok")]), classified(beams) ++ [beams[@outside]],
        sources: with_outside_source(@sources)
      )

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [%{enforcement: :enforce, file: @outside_file, message: message}] = report.findings
      assert message =~ "AnchorFixtures.GraphManagerTest.Shared is in no architecture bucket"
      assert message =~ "matches #{@outside_file}"
      assert %{modules: 3, outside_root: 1} = report.counts
      assert GraphReport.summary(report) =~ "3 modules (1 outside the root) in 1 apps"
    end

    test "an outside-root module is enforced by a rule like an inside one, keyed by its ../ path",
         %{beams: beams} do
      rules = [rule(:stub_finds, "shared", %{bucket: "shared"})]

      expect_run(
        config(rules, architecture([shared_bucket()])),
        classified(beams) ++ [beams[@outside]],
        sources: with_outside_source(@sources)
      )

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [finding] = report.findings
      assert finding.enforcement == :enforce
      assert finding.file == @outside_file
      assert finding.message =~ "#{inspect(@outside)} was found."
    end

    test "positive control: the same rule over an inside bucket finds the inside module",
         %{beams: beams} do
      rules = [rule(:stub_finds, "domain", %{bucket: "domain"})]

      expect_run(
        config(rules, architecture([shared_bucket()])),
        classified(beams) ++ [beams[@outside]],
        sources: with_outside_source(@sources)
      )

      report = Graph.run(request(), deps())

      assert [%{enforcement: :enforce, file: @user_file}] = report.findings
    end

    test "its source facts are read by its ../ path like any project file", %{beams: beams} do
      # The source double answers @outside_file with an error: had the runner
      # not asked for it, there would be no issue (positive control: the
      # inside files answer and raise none).
      expect_run(
        config([rule(:stub_ok, "ok")], architecture([shared_bucket()])),
        classified(beams) ++ [beams[@outside]],
        sources: Map.put(@sources, @outside_file, {:error, :eacces})
      )

      report = Graph.run(request(), deps())

      assert [%{file: @outside_file, message: message}] = report.findings
      assert message =~ "could not read the source of #{@outside_file} (:eacces)"
    end

    test "a run whose every module is outside the root is measured, never COULD NOT MEASURE",
         %{beams: beams} do
      rules = [rule(:stub_ok, "ok", %{bucket: "shared"})]

      expect_run(config(rules, only_shared_architecture()), [beams[@outside]],
        sources: %{@outside_file => {:ok, @outside_source}}
      )

      report = Graph.run(request(), deps())

      assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
      assert %{modules: 1, outside_root: 1} = report.counts
    end
  end

  # DND-5637: a two-app umbrella. Mix compiles each app from its own
  # directory, so each beam's relative_file is app-relative (recorded on a
  # real two-app umbrella built with mix compile: apps/alpha/lib/alpha.ex has
  # relative_file "lib/alpha.ex", apps/beta/lib/beta/b.ex "lib/beta/b.ex").
  # The task passes each app's directory; every path is keyed relative to the
  # umbrella root, for selectors, source facts and findings.
  describe "run/2 a two-app umbrella (DND-5637)" do
    @alpha_source """
    defmodule AnchorFixtures.GraphManagerTest.Alpha do
      def a(x), do: x
    end
    """
    @beta_source """
    defmodule AnchorFixtures.GraphManagerTest.Beta.B do
      def b(x), do: AnchorFixtures.GraphManagerTest.Alpha.a(x)
    end
    """
    @alpha_ebin "/proj/_build/test/lib/alpha/ebin"
    @beta_ebin "/proj/_build/test/lib/beta/ebin"

    setup do
      [{alpha, alpha_bin}] = compile_unloaded(@alpha_source, "lib/alpha.ex")
      [{beta, beta_bin}] = compile_unloaded(@beta_source, "lib/beta/b.ex")

      %{
        umbrella: [
          BeamReader.decode(alpha_bin, app: :alpha, path: "#{@alpha_ebin}/#{alpha}.beam"),
          BeamReader.decode(beta_bin, app: :beta, path: "#{@beta_ebin}/#{beta}.beam")
        ]
      }
    end

    defp umbrella_request,
      do: %Request{
        apps: [{:alpha, @alpha_ebin}, {:beta, @beta_ebin}],
        source_dirs: %{alpha: "apps/alpha", beta: "apps/beta"},
        root: @root,
        build_path: @build_path,
        env: :test,
        opts: %{format: :text, only: []}
      }

    defp umbrella_architecture do
      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 2},
          "buckets" => [
            %{
              "name" => "alpha",
              "role" => "domain",
              "select" => [%{"paths" => ["apps/alpha/**"]}]
            },
            %{"name" => "beta", "role" => "domain", "select" => [%{"paths" => ["apps/beta/**"]}]}
          ],
          "calls" => %{"alpha" => [], "beta" => []}
        })

      arch
    end

    test "each app's paths are keyed umbrella-root-relative", %{umbrella: umbrella} do
      assert Enum.map(umbrella, & &1.elixir.relative_file) == ["lib/alpha.ex", "lib/beta/b.ex"]

      rules = [
        rule(:stub_finds, "alpha", %{bucket: "alpha"}),
        rule(:stub_finds, "beta", %{bucket: "beta", index: 2})
      ]

      expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules, umbrella_architecture())} end)

      Mox.expect(BeamSourceMock, :read_ebins, fn [{:alpha, @alpha_ebin}, {:beta, @beta_ebin}] ->
        umbrella
      end)

      expect(SourceSourceMock, :read, fn @root,
                                         ["apps/alpha/lib/alpha.ex", "apps/beta/lib/beta/b.ex"] =
                                           files ->
        sources = %{
          "apps/alpha/lib/alpha.ex" => @alpha_source,
          "apps/beta/lib/beta/b.ex" => @beta_source
        }

        Map.new(files, &{&1, SourceFacts.from_source(&1, sources[&1])})
      end)

      expect(GraphStoreMock, :write, fn @artifact_dir, _key, _graph -> :ok end)

      report = Graph.run(umbrella_request(), deps())

      assert Enum.map(report.findings, &{&1.rule_id, &1.file}) == [
               {"alpha", "apps/alpha/lib/alpha.ex"},
               {"beta", "apps/beta/lib/beta/b.ex"}
             ]

      assert %{modules: 2, apps: 2, outside_root: 0} = report.counts
    end
  end

  describe "run/2 graph artifact" do
    # DND-5586: the artifact is built from the beams AND the source facts
    # (`generated?`, the literal uses), so a source change that leaves the
    # beams alone must still change its key; a comment, which changes no
    # fact, need not.
    test "the key changes with the source facts, not with a comment", %{beams: beams} do
      key = fn sources ->
        expect_run(config([rule(:stub_ok, "ok")]), classified(beams), sources: sources)
        Graph.run(request(), deps())
        assert_received {:artifact_key, key}
        key
      end

      base = key.(@sources)

      commented =
        Map.put(@sources, @user_file, {:ok, "# a comment\n" <> @user_source})

      # One more literal module in the file: its facts change, its beam
      # (compiled from @user_source) does not.
      another_module =
        Map.put(@sources, @user_file, {:ok, @user_source <> "defmodule Another do\nend\n"})

      assert key.(commented) == base
      refute key.(another_module) == base
    end

    # DND-5638: the same beams, sources and config under two roots (two
    # checkouts with the same build output) get two keys.
    test "the key changes with the project root", %{beams: beams} do
      key = fn root ->
        expect(ConfigLoaderMock, :load, fn -> {:ok, config([rule(:stub_ok, "ok")])} end)
        Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> classified(beams) end)

        expect(SourceSourceMock, :read, fn ^root, files ->
          Map.new(files, &{&1, source_facts(&1, Map.fetch!(@sources, &1))})
        end)

        expect(GraphStoreMock, :write, fn @artifact_dir, key, _graph ->
          send(self(), {:artifact_key, key})
          :ok
        end)

        Graph.run(%{request() | root: root}, deps())
        assert_received {:artifact_key, key}
        key
      end

      assert key.("/checkout-a") == key.("/checkout-a")
      refute key.("/checkout-a") == key.("/checkout-b")
    end

    test "a failed write is a report-only note; the verdict stands", %{beams: beams} do
      expect_run(config([rule(:stub_ok, "ok")]), classified(beams),
        write_result: {:error, :eacces}
      )

      report = Graph.run(request(), deps())
      assert report.exit_code == 0
      assert [%{enforcement: :report, message: message}] = report.findings
      assert message =~ "could not write the graph artifact under #{@artifact_dir} (:eacces)"
    end
  end
end
