defmodule Anchor.Integration.PlacementInvariantTest do
  # DND-5448: the placement canary (test/fixtures/graph_canary/placement/) through the
  # graph runner with real Domain, the real config adapter and the real SourceReader and
  # BehaviourReader. Beams are compiled in the test and fed through the BeamSource port;
  # the artifact store is doubled, so nothing is written.
  #
  # The invariant: every placement violation's Fix is the render of the proposal with
  # its key, and the checks are exactly EXPECTED. `mix anchor.propose` (DND-5449) will
  # list `Placement.proposals/3`, read here directly.
  #
  # Sabotage record: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.SourceReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.Placement
  alias Anchor.Domain.RuleShapes
  alias Anchor.GraphStoreMock
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/graph_canary/placement", __DIR__)
  @ebin "_build/test/lib/placement/ebin"
  @expected @root |> Path.join("EXPECTED") |> File.read!() |> String.split("\n", trim: true)
  @external_resource Path.join(@root, "EXPECTED")

  @violating ~w(
    lib/placement/web/violating_entry.ex
    lib/placement/domain/format.ex
    lib/placement/domain/lease.ex
    lib/placement/domain/statement.ex
    lib/placement/domain/rounding.ex
    lib/placement/domain/dead.ex
    lib/placement/domain/leaky.ex
    lib/placement/domain/totals.ex
    lib/placement/managers/calc.ex
  )

  defp compile(prefix \\ "") do
    Path.wildcard(Path.join(@root, "lib/**/*.ex"))
    |> Enum.sort_by(
      &{not String.ends_with?(&1, "invoice/line.ex"), not String.ends_with?(&1, "invoice.ex"), &1}
    )
    |> Enum.map(fn path -> {prefix <> File.read!(path), Path.relative_to(path, @root)} end)
    |> compile_all_unloaded()
    |> Enum.map(fn {module, binary} ->
      BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")
    end)
  end

  setup_all do
    %{beams: compile()}
  end

  defp run(beams, opts \\ []) do
    {transform, opts} = Keyword.pop(opts, :config, & &1)

    expect(ConfigLoaderMock, :load, fn ->
      {:ok, config} = ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))
      {:ok, transform.(config)}
    end)

    Mox.expect(BeamSourceMock, :read_ebins, fn [{:placement, @ebin}] -> beams end)
    expect(GraphStoreMock, :write, fn _dir, _key, _graph -> :ok end)
    test = self()

    report =
      Graph.run(
        %Request{
          apps: [{:placement, @ebin}],
          root: @root,
          build_path: Path.join(@root, "_build/test"),
          env: :test,
          opts: %{format: :text, only: []}
        },
        [
          config_loader: ConfigLoaderMock,
          beam_source: BeamSourceMock,
          source_source: SourceReader,
          graph_store: GraphStoreMock,
          placement: fn model ->
            placement = Placement.build(model)
            send(test, {:placed, placement, model})
            placement
          end
        ] ++ opts
      )

    assert_received {:placed, placement, model}
    {report, placement, model}
  end

  defp without_violating(beams),
    do: Enum.reject(beams, &(&1.elixir.relative_file in @violating))

  test "the canary yields exactly its listed findings", %{beams: beams} do
    {report, _placement, _model} = run(beams)

    assert report.could_not_check == []
    assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
    assert report.exit_code == 1
  end

  test "every placement violation's Fix equals the render of the proposal with its key", %{
    beams: beams
  } do
    {report, placement, model} = run(beams)
    proposals = placement |> Placement.proposals(model, :function) |> Map.new(&{&1.key, &1})

    assert map_size(proposals) == length(@expected)

    for finding <- report.findings do
      proposal = Map.fetch!(proposals, finding.key)
      [_before, fix] = String.split(finding.message, "Fix: ")
      assert fix == Placement.render(proposal)
      assert RuleShapes.fix_count(finding.message) == 1, finding.message
    end
  end

  test "each finding carries the acceptance criteria's reason and target", %{beams: beams} do
    {_report, placement, model} = run(beams)

    reasons =
      placement
      |> Placement.proposals(model, :function)
      |> Map.new(
        &{&1.subject |> elem(0) |> Module.split() |> List.last(), {&1.reason, &1.proposed}}
      )

    invoice = AnchorFixtures.PlacementTest.Billing.Domain.Invoice

    assert reasons["Calc"] == {:input_type_owner, invoice}
    assert reasons["Format"] == {:output_type_owner, invoice |> Module.concat(Line)}
    assert reasons["Lease"] == {:input_type_owner, invoice}

    assert reasons["Rounding"] ==
             {:dominated_by, AnchorFixtures.PlacementTest.Billing.Domain.Statement}

    assert reasons["Dead"] == {:unreachable, :delete}

    assert reasons["Totals"] ==
             {:inert_hop,
              {:inline, {AnchorFixtures.PlacementTest.Billing.Domain.Statement, :total, 1}}}

    assert {:bucket_from_effects, {:bucket, :adapters, _context, nil}} = reasons["Leaky"]
  end

  test "the same function captured by a reachable one is reachable", %{beams: beams} do
    {_report, placement, _model} = run(beams)
    dead = AnchorFixtures.PlacementTest.Billing.Domain.Dead

    assert Placement.facts(placement, {dead, :captured, 1}).reachable?
    refute Placement.facts(placement, {dead, :unused, 0}).reachable?
  end

  test "a function a literal {M, :f, args} names is reachable, and stays public", %{beams: beams} do
    source = """
    defmodule AnchorFixtures.PlacementTest.Billing.Web.Starter do
      alias AnchorFixtures.PlacementTest.Billing.Domain.Spawned

      def start, do: spawn(Spawned, :loop, [1])
    end

    defmodule AnchorFixtures.PlacementTest.Billing.Domain.Spawned do
      @spec loop(integer()) :: integer()
      def loop(value), do: value + 1
    end
    """

    extra =
      [{source, "lib/placement/web/starter.ex"}]
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")
      end)

    {_report, placement, _model} = run(extra ++ beams)

    facts =
      Placement.facts(placement, {AnchorFixtures.PlacementTest.Billing.Domain.Spawned, :loop, 1})

    assert facts.reachable?
    assert facts.named?
  end

  test "spawn with a computed name loses reachability, naming its line", %{beams: beams} do
    source = """
    defmodule AnchorFixtures.PlacementTest.Billing.Web.ComputedSpawn do
      def run(mod, name, args), do: spawn(mod, name, args)
    end
    """

    [{module, binary}] = compile_all_unloaded([{source, "lib/placement/web/computed_spawn.ex"}])
    extra = BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")
    {report, placement, _model} = run([extra | beams])

    assert placement.precision.reachability == :lost
    assert [issue] = Enum.filter(report.findings, &(&1.message =~ "reachability is imprecise"))
    assert issue.message =~ "lib/placement/web/computed_spawn.ex:2"
  end

  test "a known name with arguments of unknown length reaches every arity, and stays public", %{
    beams: beams
  } do
    source = """
    defmodule AnchorFixtures.PlacementTest.Billing.Web.PartialStart do
      alias AnchorFixtures.PlacementTest.Billing.Domain.Partial

      def run(args), do: Task.start(Partial, :loop, args)
      def any(mod, args), do: spawn(mod, :other_loop, args)
    end

    defmodule AnchorFixtures.PlacementTest.Billing.Domain.Partial do
      def loop(a), do: a
      def loop(a, b), do: {a, b}
      def other_loop(a), do: a
    end
    """

    extra =
      [{source, "lib/placement/web/partial_start.ex"}]
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")
      end)

    {_report, placement, _model} = run(extra ++ beams)
    partial = AnchorFixtures.PlacementTest.Billing.Domain.Partial

    for mfa <- [{partial, :loop, 1}, {partial, :loop, 2}, {partial, :other_loop, 1}] do
      assert Placement.facts(placement, mfa).reachable?, inspect(mfa)
      assert Placement.facts(placement, mfa).named?, inspect(mfa)
    end
  end

  test "a supervised process outside a framework bucket is reached through its child spec", %{
    beams: beams
  } do
    tree = """
    defmodule AnchorFixtures.PlacementTest.Billing.Web.Tree do
      alias AnchorFixtures.PlacementTest.Billing.Managers.Bare
      alias AnchorFixtures.PlacementTest.Billing.Managers.Tupled

      def start, do: Supervisor.start_link([Bare, {Tupled, :arg}], strategy: :one_for_one)
    end
    """

    source = """
    defmodule AnchorFixtures.PlacementTest.Billing.Managers.Bare do
      use GenServer
      def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
      @impl true
      def init(arg), do: {:ok, arg}
    end

    defmodule AnchorFixtures.PlacementTest.Billing.Managers.Tupled do
      use GenServer
      def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
      @impl true
      def init(arg), do: {:ok, arg}
    end

    defmodule AnchorFixtures.PlacementTest.Billing.Managers.Unsupervised do
      use GenServer
      def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
      @impl true
      def init(arg), do: {:ok, arg}
    end
    """

    extra =
      [{tree, "lib/placement/web/tree.ex"}, {source, "lib/placement/managers/supervised.ex"}]
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")
      end)

    # These files are not on disk, so their modules read as possibly generated and get no
    # finding: the call graph's reachability is what this test reads.
    {_report, placement, _model} = run(extra ++ beams)
    managers = AnchorFixtures.PlacementTest.Billing.Managers

    for module <- [Module.concat(managers, Bare), Module.concat(managers, Tupled)] do
      assert Placement.facts(placement, {module, :start_link, 1}).reachable?, inspect(module)
    end

    # The control: a process nothing names is still unreachable.
    unsupervised = Module.concat(managers, Unsupervised)
    refute Placement.facts(placement, {unsupervised, :start_link, 1}).reachable?
  end

  test "every reason the canary emits renders one non-empty line, and each is there", %{
    beams: beams
  } do
    {_report, placement, model} = run(beams)
    proposals = Placement.proposals(placement, model, :function)

    assert proposals |> Enum.map(& &1.reason) |> Enum.uniq() |> Enum.sort() == [
             :bucket_from_effects,
             :dominated_by,
             :inert_hop,
             :input_type_owner,
             :output_type_owner,
             :unreachable
           ]

    for proposal <- proposals do
      line = Placement.render(proposal)
      assert line != ""
      refute line =~ "\n"
    end
  end

  # In this file, not a test file of its own: two test modules compiling the canary's
  # module names at once would race on the code server.
  test "no key carries a line number: every module shifted five lines gives the same keys" do
    {report, _placement, _model} = run(compile("\n\n\n\n\n"))

    assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
    assert Enum.all?(report.findings, &(&1.line > 5))
  end

  test "positive control: the compliant half alone gives no finding", %{beams: beams} do
    {report, _placement, _model} = beams |> without_violating() |> run()

    assert report.findings == []
    assert report.exit_code == 0
  end

  test "report mode never fails, and still prints each finding", %{beams: beams} do
    {report, _placement, _model} =
      run(beams,
        config: fn %Config{} = config ->
          rules = Enum.map(config.rules, &Map.put(&1, :enforcement, :report))
          %{config | rules: rules}
        end
      )

    assert report.exit_code == 0
    assert report.findings |> Enum.map(& &1.key) |> Enum.sort() == @expected
    assert GraphReport.render(report, :text) =~ "[report]"
  end

  test "the precision is printed, and a computed name turns reachability into one issue", %{
    beams: beams
  } do
    source = """
    defmodule AnchorFixtures.PlacementTest.Billing.Web.Computed do
      def run(name), do: apply(__MODULE__, name, [])
    end
    """

    [{module, binary}] = compile_all_unloaded([{source, "lib/placement/web/computed.ex"}])
    computed = BeamReader.decode(binary, app: :placement, path: "#{@ebin}/#{module}.beam")

    {report, _placement, _model} = run([computed | beams])
    summary = GraphReport.summary(report)

    assert summary =~ "; placement: "
    assert summary =~ "1 calls of a computed name, reachability lost at 1 call sites"

    assert [issue] = Enum.filter(report.findings, &(&1.message =~ "reachability is imprecise"))
    assert issue.message =~ "lib/placement/web/computed.ex:2 calls an unknown function"

    # No per-function finding of that rule stands beside it.
    refute Enum.any?(
             report.findings,
             &(&1.key && String.starts_with?(&1.key, "reachable_from_root"))
           )
  end
end
