defmodule Anchor.Integration.CoverageIntegrationTest do
  # DND-5691: the real command, no doubles, over a fixture project written to a tmp
  # dir, in a VM of its own: `mix anchor.sabotage coverage` compiling first and
  # labels together. Not tagged :global_tracing: it traces no process here.
  # Sabotage record: ../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageMap

  @moduletag :tmp_dir

  @mix_exs """
  defmodule Fixture.MixProject do
    use Mix.Project

    def project,
      do: [
        app: :coverage_fixture,
        version: "0.1.0",
        deps: [],
        prune_code_paths: false,
        elixirc_paths: ["lib"]
      ]
  end
  """

  @lib """
  defmodule Fixture.Calc do
    def add(a, b), do: a + b
    def compile_time, do: :ok
    def handled, do: :ok
    def late, do: :ok
  end

  defmodule Fixture.Server do
    use GenServer
    def init(state), do: {:ok, state}

    def handle_call(:work, _from, state) do
      Fixture.Calc.handled()
      {:reply, :ok, state}
    end
  end
  """

  @clean_test """
  defmodule CleanTest do
    use ExUnit.Case

    Fixture.Calc.compile_time()

    test "adds" do
      assert Fixture.Calc.add(1, 2) == 3
    end

    @tag :excluded_here
    test "excluded", do: flunk("never")

    test "a server's work for this test" do
      :ok = GenServer.call(:fixture_server, :work)
    end
  end
  """

  @leaking_test """
  defmodule LeakingTest do
    use ExUnit.Case

    test "a leaves a process" do
      me = self()

      spawn(fn ->
        Process.register(self(), :fixture_left_behind)
        send(me, :registered)

        receive do
          {:go, ack} ->
            Fixture.Calc.late()
            send(ack, :done)
        end
      end)

      receive(do: (:registered -> :ok))
    end

    test "b releases it" do
      send(:fixture_left_behind, {:go, self()})
      receive(do: (:done -> :ok))
    end
  end
  """

  defp coverage(dir, test_file) do
    File.mkdir_p!(Path.join(dir, "lib"))
    File.mkdir_p!(Path.join(dir, "test"))
    File.write!(Path.join(dir, "mix.exs"), @mix_exs)
    File.write!(Path.join(dir, "lib/fixture.ex"), @lib)

    # Started before any test, so no test owns it: only a label can credit its work.
    File.write!(Path.join(dir, "test/test_helper.exs"), """
    {:ok, _server} = GenServer.start(Fixture.Server, %{}, name: :fixture_server)
    ExUnit.start()
    """)

    File.write!(Path.join(dir, "test/fixture_test.exs"), test_file)

    ebin = :code.which(CoverageMap) |> Path.dirname()

    args =
      ~s(["coverage", "--local", "--out", "map.etf", "--", "--exclude", "excluded_here", "--seed", "0"])

    System.cmd(
      "elixir",
      [
        "-pa",
        ebin,
        "-S",
        "mix",
        "run",
        "--no-start",
        "-e",
        "Mix.Tasks.Anchor.Sabotage.run(#{args})"
      ],
      cd: dir,
      env: [{"MIX_ENV", "test"}, {"CI", nil}, {"MIX_BUILD_PATH", nil}, {"MIX_DEPS_PATH", nil}],
      stderr_to_stdout: true
    )
  end

  defp read_map(dir) do
    {:ok, map} =
      Path.join(dir, "map.etf") |> File.read!() |> :erlang.binary_to_term() |> CoverageMap.check()

    map
  end

  test "a clean suite: exit 0, credit by ownership and by label, the compiler ambient", %{
    tmp_dir: dir
  } do
    {output, code} = coverage(dir, @clean_test)
    assert code == 0, output

    map = read_map(dir)
    sets = Map.new(map.tests, &{&1.name, &1.functions})

    assert Map.keys(sets) == ["test a server's work for this test", "test adds"]
    assert "Fixture.Calc.add/2" in sets["test adds"]
    assert "Fixture.Calc.handled/0" in sets["test a server's work for this test"]
    refute "Fixture.Calc.handled/0" in sets["test adds"]
    assert map.leaks == []
    assert "Fixture.Calc.compile_time/0" in map.ambient
    refute Enum.any?(Map.values(sets), &("Fixture.Calc.compile_time/0" in &1))
    assert map.counters.credited_by_label >= 1
    assert output =~ "anchor.sabotage coverage: tests: 2,"
  end

  test "a leak: exit 1, the pair named with a Fix: line, and the map written", %{tmp_dir: dir} do
    {output, code} = coverage(dir, @leaking_test)

    assert code == 1, output
    assert output =~ "test a leaves a process left a process that called Fixture.Calc.late/0"
    assert output =~ "Fix: make the process end inside its test"

    map = read_map(dir)

    assert [%{function: "Fixture.Calc.late/0", from: %{name: "test a leaves a process"}}] =
             map.leaks
  end
end
