defmodule Anchor.Integration.SabotageRunIntegrationTest do
  # DND-5473: `Anchor.Managers.Sabotage.run/2` with every real adapter (no
  # doubles) on a small Mix project in a tmp directory: git, the journal, the
  # bounded `mix test` with Anchor's formatter, and the restore. Two mutants
  # by --only, so the run stays light: a killed `return_input` of add/2 and a
  # survived `delete_statement` of validate/1 (no test reads it).
  # DND-5484: the same run writes its sabotage record, read back here.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Managers.Sabotage

  @moduletag :tmp_dir
  @moduletag timeout: 300_000

  @calc """
  defmodule Calc do
    def add(a, b) do
      a + b
    end

    def validate(x) do
      check(x)
      x
    end

    def check(x), do: x
  end
  """

  @calc_test """
  defmodule CalcTest do
    use ExUnit.Case, async: true

    test "adds" do
      assert Calc.add(1, 2) == 3
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

  # The formatter is Anchor's; the project does not depend on Anchor, so its
  # test helper puts Anchor's compiled modules on the code path.
  defp project!(root) do
    ebin = Anchor.Sabotage.ExUnitFormatter |> :code.which() |> to_string() |> Path.dirname()

    git!(root, ["init", "-q", "-b", "dnd-77-calc"])
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

  defp id(mfa, operator) do
    {:ok, %{mutants: mutants}} = Mutator.generate(@calc, "lib/calc.ex", mfa)
    [mutant | _rest] = Enum.filter(mutants, &(&1.operator == operator))
    mutant.id
  end

  test "1: a killed and a survived mutant; the file is byte-equal after, and no journal is left",
       %{tmp_dir: root} do
    base = project!(root)
    killed = id({Calc, :add, 2}, :return_input)
    survived = id({Calc, :validate, 1}, :delete_statement)

    run =
      Sabotage.run(%{
        root: root,
        env: :test,
        base: base,
        max: :all,
        only: [killed, survived],
        dry_run: false,
        now: ~U[2026-11-05 14:07:00Z],
        command: "mix anchor.sabotage run",
        version: "0.1.0"
      })

    assert run.refusal == nil, Report.render(run)
    assert run.baseline == :passed

    assert Enum.map(run.outcomes, &{&1.mutant.id, &1.status}) |> Enum.sort() ==
             Enum.sort([{killed, :killed}, {survived, :survived}])

    assert [{"test/calc_test.exs", _line, "test adds"}] =
             Enum.find(run.outcomes, &(&1.status == :killed)).killers

    assert File.read!(Path.join(root, "lib/calc.ex")) == @calc
    refute File.exists?(Path.join(root, ".anchor/sabotage/in-flight.json"))
    assert git!(root, ["status", "--porcelain"]) == "?? test/sabotage_records/"
    assert Report.exit_code(run) == 1

    record_path = "test/sabotage_records/calc-20261105-dnd_77_calc.md"
    assert run.records == [{:create, record_path}]
    record = File.read!(Path.join(root, record_path))
    assert record =~ "- **Domain:** calc\n- **Branch:** dnd-77-calc\n- **Date:** 2026-11-05\n"
    assert record =~ "code:  assert Calc.add(1, 2) == 3\n"
    assert record =~ "## Tests still lacking a red\n\nNone.\n"

    assert {:ok, rows} = Anchor.Domain.Sabotage.KillMap.parse(record)

    assert Enum.sort(Enum.map(rows, &{&1.id, &1.status})) ==
             Enum.sort([{killed, "killed"}, {survived, "survived"}])

    saved = File.read!(Path.join(root, "_build/test/anchor/sabotage/last-run.etf"))
    assert :erlang.binary_to_term(saved) == run
  end
end
