defmodule Anchor.Integration.SabotageVerifyIntegrationTest do
  # DND-5516: `Anchor.Managers.Sabotage.verify/2` with every real adapter on a
  # git repository built in the test: a commit A, then a commit B that changes
  # one function and adds its record. Nothing is compiled and no test is run:
  # the record's rows are written from the generator's own ids.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5516_verify.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Verify
  alias Anchor.Managers.Sabotage

  @moduletag :tmp_dir

  @record "test/sabotage_records/calc-20261106-verify.md"

  @calc_a """
  defmodule Calc do
    def add(a, b), do: a
  end
  """

  @calc_b """
  defmodule Calc do
    def add(a, b) do
      if a > b, do: a, else: b
    end
  end
  """

  # The condition is a mutation target, so editing it changes those ids.
  @calc_c """
  defmodule Calc do
    def add(a, b) do
      if a >= b, do: a, else: b
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

  defp commit!(root, message) do
    git!(root, ["add", "-A"])
    git!(root, ["commit", "-q", "-m", message])
  end

  defp record(mutants) do
    outcomes =
      Enum.map(
        mutants,
        &%{mutant: &1, status: :killed, killers: [{"test/calc_test.exs", 4, "test adds"}]}
      )

    "# Sabotage record\n\n" <> KillMap.render_block(outcomes)
  end

  # Commit A, then commit B: add/2 changed, and a record covering every mutant
  # of B's add/2 (or all but `drop` of them).
  defp project!(root, drop \\ 0) do
    git!(root, ["init", "-q", "-b", "main"])
    write!(root, ".anchor.yml", "rules: []\nsabotage: {}\n")
    write!(root, "lib/calc.ex", @calc_a)
    commit!(root, "A")
    base = git!(root, ["rev-parse", "HEAD"])

    {:ok, %{mutants: mutants}} = Mutator.generate(@calc_b, "lib/calc.ex", {Calc, :add, 2})
    assert length(mutants) > max(drop, 1)

    write!(root, "lib/calc.ex", @calc_b)
    write!(root, @record, record(Enum.drop(mutants, drop)))
    commit!(root, "B")
    {base, mutants}
  end

  test "1: a record that covers every mutant of the changed function passes", %{tmp_dir: root} do
    {base, mutants} = project!(root)

    assert {:ok, verdict} = Sabotage.verify(%{root: root, base: base})
    assert Verify.exit_code(verdict) == 0, Verify.render(verdict, :text)

    assert Verify.render(verdict, :text) ==
             "sabotage verify: 1 functions, #{length(mutants)} mutants, all covered " <>
               "(#{length(mutants)} killed, 0 survivors, 0 invalid)"

    assert git!(root, ["status", "--porcelain"]) == ""
  end

  test "2: editing the function after its record makes the record STALE", %{tmp_dir: root} do
    {base, _mutants} = project!(root)
    write!(root, "lib/calc.ex", @calc_c)
    commit!(root, "C")

    assert {:ok, verdict} = Sabotage.verify(%{root: root, base: base})
    assert Verify.exit_code(verdict) == 1
    assert Verify.render(verdict, :text) =~ "STALE RECORD #{@record}: Calc.add/2 changed"
  end

  test "3: a row removed from the record leaves its mutant UNCOVERED", %{tmp_dir: root} do
    {base, [dropped | _rest]} = project!(root, 1)

    assert {:ok, verdict} = Sabotage.verify(%{root: root, base: base})
    assert Verify.exit_code(verdict) == 1

    assert Verify.render(verdict, :text) =~
             "UNCOVERED #{dropped.id} lib/calc.ex Calc.add/2 #{dropped.operator}:"
  end
end
