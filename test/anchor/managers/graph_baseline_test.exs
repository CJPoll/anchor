defmodule Anchor.Managers.GraphBaselineTest do
  # DND-5441: the graph runner's ratchet, with every adapter doubled by Hammox
  # (ADR 002): BaselineStore and GitBase are the new ports. The stub rule
  # `stub_finds` gives one finding per selected module, keyed
  # `<id>|<Module>|found`; `bucket: "domain"` selects one module here, so a
  # rule has exactly one finding, `@key`.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
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
  defmodule AnchorFixtures.GraphBaselineTest.User do
    def name(user), do: user
  end
  """
  @key "f|AnchorFixtures.GraphBaselineTest.User|found"

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@user_source, @user_file}])
    %{beam: BeamReader.decode(binary, app: :my_app, path: "#{@ebin}/user.beam")}
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

  defp rule(extra \\ %{}),
    do:
      Map.merge(
        %{type: :stub_finds, id: "f", bucket: "domain", index: 1, baseline: @path},
        extra
      )

  defp request(opts \\ %{}),
    do: %Request{
      apps: [{:my_app, @ebin}],
      root: @root,
      env: :test,
      opts: Map.merge(%{format: :text, only: []}, opts)
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

  defp expect_run(rules, beam) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, config(rules)} end)
    Mox.expect(BeamSourceMock, :read_ebins, fn _apps -> [beam] end)

    expect(SourceSourceMock, :read, fn @root, files ->
      Map.new(files, &{&1, SourceFacts.from_source(&1, @user_source)})
    end)

    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)
  end

  defp expect_baseline(bytes_or_error) do
    expect(BaselineStoreMock, :read, fn @root, @path ->
      case bytes_or_error do
        {:error, _reason} = error -> error
        bytes -> Baseline.parse(bytes)
      end
    end)
  end

  defp messages(report), do: Enum.map(report.findings ++ report.refused, & &1.message)

  describe "run/2 comparing with a baseline" do
    test "a baseline holding exactly the finding's key: exit 0, held, counted", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("# header\n#{@key}\n")

      report = Graph.run(request(), deps())

      assert %GraphReport{exit_code: 0, findings: [], held: [held]} = report
      assert held.key == @key
      assert GraphReport.summary(report) =~ "(0 report-only, 1 baselined)"
    end

    test "a finding no entry covers is NEW: it stands and fails (exit 1)", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("f|Other|found\n#{@key}x\n")

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert report.held == []
      assert Enum.any?(report.findings, &(&1.key == @key and &1.file == @user_file))
    end

    test "an entry no finding consumes is STALE, on the baseline path (exit 1)", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\nf|Gone|found\n")

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [stale] = report.findings
      assert stale.file == @path
      assert stale.enforcement == :enforce
      assert stale.message =~ "f|Gone|found in #{@path} matches no finding"
      assert stale.message =~ "Fix: delete that line from #{@path}"
      assert [%{key: @key}] = report.held
    end

    test "a report rule's STALE entry is reported, never failing (exit 0)", %{beam: beam} do
      expect_run([rule(%{enforcement: :report})], beam)
      expect_baseline("#{@key}\nf|Gone|found\n")

      report = Graph.run(request(), deps())

      assert report.exit_code == 0
      assert [%{enforcement: :report, message: message}] = report.findings
      assert message =~ "Fix: delete that line"
    end

    test "a missing baseline is an issue on its path; the finding stands (exit 1)", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline({:error, :enoent})

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [finding, issue] = report.findings
      assert finding.key == @key
      assert issue.file == @path
      assert issue.label == "anchor.graph"
      assert issue.message =~ "could not be read (:enoent)"
      assert issue.message =~ "--write-baseline f"
    end

    test "a baseline line that is not UTF-8 is an issue on that line", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\n\xff\n")

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert [%{key: @key}, %{file: @path, line: 2, message: message}] = report.findings
      assert message =~ "line 2 is not UTF-8"
    end

    test "a baseline holding another rule's entry is an issue; nothing is held", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\nother|X|found\n")

      report = Graph.run(request(), deps())

      assert report.exit_code == 1
      assert report.held == []
      assert Enum.any?(messages(report), &(&1 =~ ~s(holds "other|X|found", an entry of another)))
    end

    test "a rule with no baseline never reads one", %{beam: beam} do
      expect_run([rule(%{baseline: nil})], beam)
      expect(BaselineStoreMock, :read, 0, fn _root, _path -> {:ok, []} end)

      assert %{exit_code: 1, held: []} = Graph.run(request(), deps())
    end

    test "a rule that crashed is not compared: its baseline is never read", %{beam: beam} do
      expect_run([rule(%{type: :stub_raises})], beam)
      expect(BaselineStoreMock, :read, 0, fn _root, _path -> {:ok, []} end)

      report = Graph.run(request(), deps())
      assert report.exit_code == 1
      assert [%{message: message}] = report.findings
      assert message =~ "could not run"
    end
  end

  describe "run/2 --base REF (GREW)" do
    test "an entry the branch added since REF fails as GREW (exit 1)", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\nf|Added|found\n")
      expect(GitBaseMock, :show, fn @root, "main", @path -> Baseline.parse("#{@key}\n") end)

      report = Graph.run(request(%{base: "main"}), deps())

      assert report.exit_code == 1
      grew = Enum.filter(report.findings, &(&1.message =~ "was added to"))
      assert [%{file: @path, key: "f|Added|found", enforcement: :enforce}] = grew
      assert hd(grew).message =~ "f|Added|found was added to #{@path} since main."
    end

    test "a baseline that only shrank since REF is not growth", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\n")

      expect(GitBaseMock, :show, fn @root, "main", @path ->
        Baseline.parse("#{@key}\nf|Fixed|found\n")
      end)

      assert %{exit_code: 0, findings: []} = Graph.run(request(%{base: "main"}), deps())
    end

    test "a baseline absent at REF is a first landing: a NOTE, exit 0", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\n")
      expect(GitBaseMock, :show, fn @root, "main", @path -> {:error, :absent} end)

      report = Graph.run(request(%{base: "main"}), deps())

      assert report.exit_code == 0
      assert [%{enforcement: :report, file: @path, message: message}] = report.findings
      assert message =~ "NOTE: first landing of #{@path} (absent at main); review is the gate."
    end

    test "a failed read at REF is an issue naming the ref, never no growth (exit 1)", %{
      beam: beam
    } do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\n")
      expect(GitBaseMock, :show, fn @root, "nosuch", @path -> {:error, {:git, 128, ""}} end)

      report = Graph.run(request(%{base: "nosuch"}), deps())

      assert report.exit_code == 1
      assert Enum.any?(messages(report), &(&1 =~ "could not read #{@path} at nosuch"))
    end

    test "without --base, git is never asked", %{beam: beam} do
      expect_run([rule()], beam)
      expect_baseline("#{@key}\n")
      expect(GitBaseMock, :show, 0, fn _root, _ref, _path -> {:error, :absent} end)

      assert %{exit_code: 0} = Graph.run(request(), deps())
    end
  end

  describe "run/2 --write-baseline RULE_ID" do
    test "creates the rule's baseline from its keys, sorted under the header; held, exit 0", %{
      beam: beam
    } do
      expect_run([rule()], beam)
      expect(BaselineStoreMock, :read, 0, fn _root, _path -> {:ok, []} end)

      expect(BaselineStoreMock, :create, fn @root, @path, contents ->
        assert contents == "# anchor baseline for f; shrink only\n#{@key}\n"
        :ok
      end)

      report = Graph.run(request(%{write_baseline: "f"}), deps())

      assert report.exit_code == 0
      assert [%{key: @key}] = report.held
      assert [%{enforcement: :report, message: "wrote 1 entries to " <> _rest}] = report.findings
    end

    test "an existing file is refused (exit 2), and the findings stand", %{beam: beam} do
      expect_run([rule()], beam)
      expect(BaselineStoreMock, :create, fn @root, @path, _contents -> {:error, :exists} end)

      report = Graph.run(request(%{write_baseline: "f"}), deps())

      assert report.exit_code == 2
      assert [%{message: message}] = report.refused
      assert message =~ "#{@path} exists; --write-baseline only creates"
      assert [%{key: @key}] = report.findings
    end

    test "an id naming no rule with a baseline is refused (exit 2) before any beam is read" do
      expect(ConfigLoaderMock, :load, fn -> {:ok, config([rule(%{baseline: nil})])} end)
      Mox.expect(BeamSourceMock, :read_ebins, 0, fn _apps -> [] end)
      expect(BaselineStoreMock, :create, 0, fn _root, _path, _contents -> :ok end)

      report = Graph.run(request(%{write_baseline: "f"}), deps())

      assert report.exit_code == 2
      assert [%{message: message}] = report.refused
      assert message =~ ~s|--write-baseline "f" names no graph rule|
    end
  end
end
