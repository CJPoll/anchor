defmodule Anchor.Domain.Sabotage.ReplayTest do
  # DND-5485: the replay's plan, verdicts and exit code.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Domain.Sabotage.Replay.Result

  @record "test/sabotage_records/sabotage-20261105-dnd_5473.md"
  @id "3f9a01c2b7de"

  defp mutant(id),
    do: %Mutant{
      id: id,
      file: "lib/calc.ex",
      module: Calc,
      function: {:add, 2},
      operator: :return_input,
      variant: 0,
      target: "",
      range: {{1, 1}, {1, 2}},
      original: "",
      replacement: "",
      patch: ""
    }

  defp row(overrides \\ %{}),
    do:
      Map.merge(
        %{
          id: @id,
          file: "lib/calc.ex",
          mfa: "Calc.add/2",
          operator: "return_input",
          status: "killed",
          killers: ["test/calc_test.exs:4 test add/2 sums"]
        },
        overrides
      )

  defp item(overrides \\ %{}), do: %{record: @record, row: row(overrides)}

  defp facts(overrides \\ %{}),
    do:
      Map.merge(
        %{
          sources: %{"lib/calc.ex" => true},
          generated: %{{"lib/calc.ex", "Calc.add/2"} => {:ok, [mutant(@id)]}},
          tests: MapSet.new(["test/calc_test.exs"])
        },
        overrides
      )

  defp plan(items, facts), do: Replay.plan(items, facts)

  describe "items/1" do
    test "keeps killed and timeout rows only" do
      rows = [
        row(),
        row(%{status: "survived"}),
        row(%{status: "timeout"}),
        row(%{status: "invalid"})
      ]

      assert [%{row: %{status: "killed"}}, %{row: %{status: "timeout"}}] =
               Replay.items([{@record, rows}])
    end
  end

  describe "plan/2" do
    test "1: a row for a file not in the sources is drifted, file gone" do
      i = item(%{file: "lib/gone.ex"})
      assert plan([i], facts()) == %{replayable: [], drifted: [{i, :file_gone}]}
    end

    test "2: file present, function absent: drifted, function gone" do
      i = item()
      f = facts(%{generated: %{{"lib/calc.ex", "Calc.add/2"} => {:error, :not_in_source}}})
      assert plan([i], f).drifted == [{i, {:function_gone, :not_in_source}}]
    end

    test "3: the regenerated ids lack the row's id: drifted, no mutant with id" do
      i = item()
      f = facts(%{generated: %{{"lib/calc.ex", "Calc.add/2"} => {:ok, [mutant("000000000000")]}}})
      assert plan([i], f).drifted == [{i, :no_mutant_with_id}]
    end

    test "4: the id is there, the killer file is gone: drifted, killer gone" do
      i = item()

      assert plan([i], facts(%{tests: MapSet.new()})).drifted == [
               {i, {:killer_gone, "test/calc_test.exs"}}
             ]
    end

    test "5: all present: replayable with the regenerated mutant, run by name (positive control)" do
      i = item()

      assert %{replayable: [r], drifted: []} = plan([i], facts())
      assert r.mutant == mutant(@id)
      assert r.test_args == ["test/calc_test.exs", "--only", "test:test add/2 sums"]
      assert r.by_file == false
    end

    test "a row whose file is outside the project is drifted before anything is read" do
      for file <- ["../x.ex", "/etc/x.ex", "lib/../../x.ex"] do
        i = item(%{file: file})
        assert plan([i], facts(%{sources: %{file => true}})).drifted == [{i, :file_outside}]
      end
    end

    test "a row file or killer file with a symlink on its path is drifted, never followed" do
      i = item()

      assert plan([i], facts(%{symlinked: MapSet.new(["lib/calc.ex"])})).drifted == [
               {i, :symlink}
             ]

      assert plan([i], facts(%{symlinked: MapSet.new(["test/calc_test.exs"])})).drifted ==
               [{i, {:killer_symlink, "test/calc_test.exs"}}]
    end

    test "a (timeout) row runs the killer files of the function's other killed rows, whole" do
      timed = item(%{id: "aaaaaaaaaaaa", status: "timeout", killers: ["(timeout)"]})
      killed = item()

      f =
        facts(%{
          generated: %{
            {"lib/calc.ex", "Calc.add/2"} => {:ok, [mutant(@id), mutant("aaaaaaaaaaaa")]}
          }
        })

      assert %{replayable: [t, _k], drifted: []} = plan([timed, killed], f)
      assert t.test_args == ["test/calc_test.exs"]
      assert t.by_file
    end

    test "a (timeout) row with no other killed row of its function: drifted, no killer test" do
      timed = item(%{status: "timeout", killers: ["(timeout)"]})
      assert plan([timed], facts()).drifted == [{timed, :no_killer_test}]
    end

    test "a module name that does not read: drifted, not a Module.fun/arity" do
      i = item(%{mfa: "add/2"})
      assert plan([i], facts()).drifted == [{i, :bad_function}]
    end
  end

  describe "judge/2" do
    test "1: failed (killed) is still killed" do
      assert Replay.judge(item(), %{status: :killed, reason: nil}) == :still_killed
    end

    test "2: timeout is still killed" do
      assert Replay.judge(item(), %{status: :timeout, reason: nil}) == :still_killed
    end

    test "3: passed (survived) is lost power, naming the killers" do
      assert Replay.judge(item(), %{status: :survived, reason: nil}) ==
               {:lost_power, ["test/calc_test.exs:4 test add/2 sums"]}
    end

    test "4: a compile error is drifted, no longer compiles" do
      assert Replay.judge(item(), %{status: :invalid, reason: "did not compile"}) ==
               {:drifted, :no_longer_compiles}
    end

    test "no test ran is drifted (the named test is gone); a crash is a crash" do
      assert Replay.judge(item(), %{status: :no_tests, reason: nil}) ==
               {:drifted, :killer_not_found}

      assert Replay.judge(item(), %{status: :crashed, reason: "boom"}) == {:crashed, "boom"}
    end
  end

  describe "exit_code/1" do
    test "1: one lost power: 1" do
      r = %Result{rows: 2, results: [{item(), :still_killed}, {item(), {:lost_power, []}}]}
      assert Replay.exit_code(r) == 1
    end

    test "2: all still killed: 0" do
      assert Replay.exit_code(%Result{rows: 1, results: [{item(), :still_killed}]}) == 0
    end

    test "3: zero rows: 3" do
      assert Replay.exit_code(%Result{rows: 0}) == 3
    end

    test "4: rows, every one drifted: 3" do
      r = %Result{
        rows: 2,
        drifted: [{item(), :file_gone}],
        results: [{item(), {:drifted, :no_longer_compiles}}]
      }

      assert Replay.exit_code(r) == 3
    end

    test "5: some drifted, the rest still killed: 0" do
      r = %Result{rows: 2, drifted: [{item(), :file_gone}], results: [{item(), :still_killed}]}
      assert Replay.exit_code(r) == 0
    end

    test "a record that could not be read, beside rows still killed: 3; beside lost power: 1" do
      r = %Result{
        rows: 1,
        unreadable: ["kill map in x.md:2 (bad)"],
        results: [{item(), :still_killed}]
      }

      assert Replay.exit_code(r) == 3
      assert Replay.exit_code(%{r | results: [{item(), {:lost_power, []}}]}) == 1
    end

    test "a crashed row: 1; a refusal: its own code" do
      assert Replay.exit_code(%Result{rows: 1, results: [{item(), {:crashed, "x"}}]}) == 1
      assert Replay.exit_code(%Result{rows: 1, refusal: {2, "no"}}) == 2
    end
  end

  describe "render/1" do
    test "lost power names the mutant, the record and each killer, with a Fix" do
      r = %Result{
        rows: 2,
        records: 1,
        drifted: [{item(%{id: "77c0d1e2aa10"}), :no_mutant_with_id}],
        results: [{item(), {:lost_power, ["test/calc_test.exs:4 test add/2 sums"]}}]
      }

      text = Replay.render(r)
      assert text =~ "LOST POWER #{@id} Calc.add/2 return_input (#{@record})\n"
      assert text =~ "  no longer failed by: test/calc_test.exs:4 test add/2 sums\n"
      assert text =~ "  Fix: restore the assertion that caught this break"
      assert text =~ "drifted (no mutant with id) 77c0d1e2aa10 Calc.add/2 return_input"

      assert text =~
               "anchor.sabotage replay: 2 rows in 1 records; 1 replayed, 0 still killed, " <>
                 "1 LOST POWER, 0 crashed, 1 drifted, 0 not replayed (cap)"
    end

    test "a row run by file says so; a row run by name does not" do
      by_file = Map.put(item(%{id: "aaaaaaaaaaaa"}), :by_file, true)
      by_name = Map.put(item(), :by_file, false)

      text =
        Replay.render(%Result{
          rows: 2,
          records: 1,
          results: [{by_file, :still_killed}, {by_name, :still_killed}]
        })

      assert text =~
               "still killed aaaaaaaaaaaa Calc.add/2 return_input " <>
                 "(killer run by file: the record names no test)\n"

      assert text =~ "still killed #{@id} Calc.add/2 return_input\n"
    end

    test "zero rows says COULD NOT MEASURE and names the directories searched" do
      text = Replay.render(%Result{rows: 0, records: 3, searched: ["test/sabotage_records"]})

      assert text =~
               "COULD NOT MEASURE: anchor.sabotage replay found no killed or timeout row in 3 " <>
                 "records under test/sabotage_records."
    end
  end
end
