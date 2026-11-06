defmodule Anchor.Integration.SabotageReplayIntegrationTest do
  # DND-5485: `Anchor.Managers.Sabotage.replay/2` with every real adapter (no
  # doubles) on a small Mix project in a tmp directory. A run writes a record
  # with one killed mutant (return_input of add/2, killed by "test adds");
  # the replay finds it still killed by that test alone (the file holds two
  # tests, and one ran: `--only test:` selects by name). Then the killer's
  # assertion is removed and committed, and the replay reports LOST POWER
  # naming it. The source is byte-equal to HEAD after each.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Managers.Sabotage

  @moduletag :tmp_dir
  @moduletag timeout: 300_000

  @calc """
  defmodule Calc do
    def add(a, b) do
      a + b
    end

    def sub(a, b), do: a - b
  end
  """

  @calc_test """
  defmodule CalcTest do
    use ExUnit.Case, async: true

    test "adds" do
      assert Calc.add(1, 2) == 3
    end

    test "subtracts" do
      assert Calc.sub(3, 2) == 1
    end
  end
  """

  defp git!(root, args) do
    {out, 0} =
      System.cmd("git", ["-c", "user.name=t", "-c", "user.email=t@example.com" | args],
        cd: root,
        stderr_to_stdout: true
      )

    String.trim(out)
  end

  defp write!(root, path, text) do
    full = Path.join(root, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, text)
  end

  defp project!(root) do
    ebin = Anchor.Sabotage.ExUnitFormatter |> :code.which() |> to_string() |> Path.dirname()

    git!(root, ["init", "-q", "-b", "dnd-78-replay"])
    write!(root, ".gitignore", "/_build/\n/deps/\n/.anchor/sabotage/in-flight.json\n")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "base"])
    base = git!(root, ["rev-parse", "HEAD"])

    write!(root, "mix.exs", """
    defmodule Calc.MixProject do
      use Mix.Project

      def project,
        do: [app: :calc, version: "0.1.0", elixirc_options: [warnings_as_errors: true], deps: []]
    end
    """)

    write!(root, ".anchor.yml", "rules: []\nsabotage:\n  timeout_seconds: 120\n")
    write!(root, "lib/calc.ex", @calc)
    write!(root, "test/calc_test.exs", @calc_test)
    write!(root, "test/test_helper.exs", "Code.prepend_path(#{inspect(ebin)})\nExUnit.start()\n")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "calc"])
    base
  end

  defp killed_id do
    {:ok, %{mutants: mutants}} = Mutator.generate(@calc, "lib/calc.ex", {Calc, :add, 2})
    Enum.find(mutants, &(&1.operator == :return_input)).id
  end

  defp facts(root),
    do: %{root: root, build_path: Path.join(root, "_build/test"), max: :all, records: []}

  test "1-2: a recorded killer still kills (by name alone), then loses its power", %{
    tmp_dir: root
  } do
    base = project!(root)
    id = killed_id()

    run =
      Sabotage.run(%{
        root: root,
        env: :test,
        build_path: Path.join(root, "_build/test"),
        base: base,
        max: :all,
        only: [id],
        dry_run: false,
        now: ~U[2026-11-05 14:07:00Z],
        command: "mix anchor.sabotage run",
        version: "0.1.0"
      })

    assert [%{status: :killed}] = run.outcomes
    git!(root, ["add", "test/sabotage_records"])
    git!(root, ["commit", "-q", "-m", "record"])

    # 2: the killer intact: still killed, and only the killer ran.
    intact = Sabotage.replay(facts(root), [])
    assert Replay.exit_code(intact) == 0, Replay.render(intact)
    assert [{%{tests_run: 1, row: %{id: ^id}}, :still_killed}] = intact.results
    assert Replay.render(intact) =~ "still killed #{id} Calc.add/2 return_input"
    assert File.read!(Path.join(root, "lib/calc.ex")) == @calc

    # 1: the killer's assertion removed and committed: lost power.
    write!(
      root,
      "test/calc_test.exs",
      String.replace(@calc_test, "assert Calc.add(1, 2) == 3", "Calc.add(1, 2)")
    )

    git!(root, ["commit", "-q", "-am", "weaken"])

    weakened = Sabotage.replay(facts(root), [])
    assert Replay.exit_code(weakened) == 1, Replay.render(weakened)
    text = Replay.render(weakened)
    assert text =~ "LOST POWER #{id} Calc.add/2 return_input"
    assert text =~ "no longer failed by: test/calc_test.exs:4 test adds"
    assert File.read!(Path.join(root, "lib/calc.ex")) == @calc
    assert git!(root, ["status", "--porcelain"]) == ""
  end
end
