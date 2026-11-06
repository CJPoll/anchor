defmodule Anchor.Domain.Sabotage.SharedRunTest do
  # DND-5639: a `defimpl P, for: [T1, T2]` mutant is generated once per target;
  # targets that select the same tests share one run.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.SharedRun

  @path "lib/calc.ex"
  @listed """
  defimpl String.Chars, for: [Calc, Other] do
    def to_string(c) do
      Logger.info("rendering")
      c.name
    end
  end
  """

  defp generate!(module) do
    {:ok, %{mutants: mutants}} = Mutator.generate(@listed, @path, {module, :to_string, 1})
    Enum.sort_by(mutants, &{&1.operator, &1.range})
  end

  defp pair do
    [calc | _rest] = generate!(String.Chars.Calc)
    [other | _rest] = generate!(String.Chars.Other)
    {calc, other}
  end

  describe "key/2" do
    test "G1: two targets of one edit with the same tests share a key, whatever the order or source" do
      {calc, other} = pair()
      assert calc.id != other.id

      key = SharedRun.key(calc, {:mirror, ["test/a_test.exs", "test/b_test.exs"]})
      assert is_tuple(key)
      assert SharedRun.key(other, {:coverage, ["test/b_test.exs", "test/a_test.exs"]}) == key
    end

    test "G2: positive control: the same edit with different tests has another key" do
      {calc, other} = pair()

      refute SharedRun.key(calc, {:mirror, ["test/a_test.exs"]}) ==
               SharedRun.key(other, {:coverage, ["test/b_test.exs:12"]})
    end

    test "G3: another edit (another range, or another replacement) with the same tests has another key" do
      {calc, _other} = pair()
      tests = {:mirror, ["test/a_test.exs"]}
      {{line, column}, stop} = calc.range
      moved = %{calc | range: {{line, column + 1}, stop}}
      replaced = %{calc | replacement: calc.replacement <> " "}

      refute SharedRun.key(calc, tests) == SharedRun.key(moved, tests)
      refute SharedRun.key(calc, tests) == SharedRun.key(replaced, tests)
    end

    test "G4: the same edit in another file has another key" do
      {calc, other} = pair()

      refute SharedRun.key(calc, {:mirror, ["test/a_test.exs"]}) ==
               SharedRun.key(%{other | file: "lib/other.ex"}, {:mirror, ["test/a_test.exs"]})
    end

    test "G5: a mutant with no test selected has no key: nothing runs, so nothing is shared" do
      {calc, _other} = pair()
      assert SharedRun.key(calc, {:none, []}) == nil
    end
  end

  describe "attribute/3" do
    test "G6: the measured outcome is given to the other target: its own mutant and selection, the same verdict" do
      {calc, other} = pair()
      killer = {"test/a_test.exs", 4, "test renders"}
      test_run = %{status: :failed}

      measured = %{
        mutant: calc,
        status: :killed,
        killers: [killer],
        selection: {:mirror, ["test/a_test.exs"]},
        reason: nil,
        test_run: test_run
      }

      shared = SharedRun.attribute(measured, other, {:coverage, ["test/a_test.exs"]})

      assert shared == %{
               mutant: other,
               status: :killed,
               killers: [killer],
               selection: {:coverage, ["test/a_test.exs"]},
               reason: nil,
               test_run: test_run
             }
    end
  end
end
