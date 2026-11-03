defmodule Anchor.Domain.Sabotage.PlanTest do
  # DND-5473: the run's order, cap and --only filter.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Plan

  defp mutant(i) do
    %Mutant{
      id: String.pad_leading(Integer.to_string(i, 16), 12, "0"),
      file: "lib/f#{rem(i, 3)}.ex",
      module: M,
      function: {:"f#{rem(i, 4)}", 1},
      operator: Enum.at([:delete_statement, :return_input], rem(i, 2)),
      variant: nil,
      target: "t",
      range: {{1, 1}, {1, 2}},
      original: "a",
      replacement: "b",
      patch: ""
    }
  end

  defp forty, do: Enum.map(1..40, &mutant/1)

  defp order(mutants), do: Enum.sort_by(mutants, &{&1.file, &1.function, &1.operator, &1.id})

  describe "build/2" do
    test "1: 40 shuffled mutants, cap 30: the first 30 in order are planned, 10 not run" do
      shuffled = Enum.shuffle(forty())

      assert {:ok, %{planned: planned, not_run: not_run}} = Plan.build(shuffled, cap: 30)

      assert length(planned) == 30
      assert length(not_run) == 10
      assert planned ++ not_run == order(forty())
    end

    test "2: cap :all plans every mutant" do
      assert {:ok, %{planned: planned, not_run: []}} =
               Plan.build(Enum.reverse(forty()), cap: :all)

      assert planned == order(forty())
    end

    test "3: --only keeps exactly the named mutants; an unknown id is an error naming it" do
      [a, b | _rest] = forty()

      assert {:ok, %{planned: [^a], not_run: []}} = Plan.build(forty(), cap: 30, only: [a.id])

      assert Plan.build(forty(), cap: 30, only: [b.id, "ffffffffffff"]) ==
               {:error,
                "--only names a mutant this run does not have: ffffffffffff. " <>
                  "Fix: pass an id `mix anchor.sabotage run --dry-run` lists"}
    end

    test "--only filters before the cap, which still applies" do
      [x, y] = forty() |> order() |> Enum.take(-2)

      assert Plan.build(forty(), cap: 1, only: [y.id, x.id]) ==
               {:ok, %{planned: [x], not_run: [y]}}
    end
  end
end
