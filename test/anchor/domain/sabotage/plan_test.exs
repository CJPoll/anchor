defmodule Anchor.Domain.Sabotage.PlanTest do
  # DND-5473: the run's order, cap and --only filter. DND-5490: the scan's shard.
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

  describe "shard/3 (DND-5490)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
    defp seventy do
      Enum.map(1..70, fn i ->
        id = :sha256 |> :crypto.hash("m#{i}") |> Base.encode16(case: :lower) |> binary_part(0, 12)
        %{mutant(i) | id: id}
      end)
    end

    test "1: shards 0..6 of 70 mutants are pairwise disjoint and together the input" do
      mutants = seventy()
      shards = for i <- 0..6, do: elem(Plan.shard(mutants, i, 7), 1)

      assert Enum.sort(Enum.concat(shards)) == Enum.sort(mutants)

      for {a, i} <- Enum.with_index(shards), {b, j} <- Enum.with_index(shards), i < j do
        assert MapSet.disjoint?(MapSet.new(a), MapSet.new(b)), "shards #{i} and #{j}"
      end

      # Every shard holds some: no shard is everything, none is empty.
      assert Enum.all?(shards, &(&1 != [] and length(&1) < 70))
    end

    test "a mutant's shard is its id's: the same id is in the same shard wherever it moved" do
      [m | _rest] = seventy()
      moved = %{m | range: {{90, 1}, {91, 2}}, file: "lib/elsewhere.ex"}
      n = rem(String.to_integer(m.id, 16), 7)

      assert Plan.shard([m, moved], n, 7) == {:ok, [m, moved]}
      assert Plan.shard([m, moved], rem(n + 1, 7), 7) == {:ok, []}
    end

    test "2: i = n, a negative i, or n = 0 is {:error, :bad_shard}" do
      assert Plan.shard(seventy(), 7, 7) == {:error, :bad_shard}
      assert Plan.shard(seventy(), -1, 7) == {:error, :bad_shard}
      assert Plan.shard(seventy(), 0, 0) == {:error, :bad_shard}
    end

    test "shard_of_day/2 is the day of the year modulo n" do
      assert Plan.shard_of_day(~D[2026-01-01], 7) == {1, 7}
      assert Plan.shard_of_day(~D[2026-01-07], 7) == {0, 7}
      assert Plan.shard_of_day(~D[2026-11-06], 7) == {rem(310, 7), 7}
    end
  end
end
