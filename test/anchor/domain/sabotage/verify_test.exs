defmodule Anchor.Domain.Sabotage.VerifyTest do
  # DND-5516: the verdict of `mix anchor.sabotage verify`, pure Domain.
  # Sabotage record: ../../../sabotage_records/sabotage-20261106-dnd_5516_verify.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Survivors.Entry
  alias Anchor.Domain.Sabotage.Verify
  alias Anchor.Domain.Sabotage.Verify.Verdict

  @mfa "Calc.add/2"

  defp mutant(id, function \\ {:add, 2}, operator \\ :return_input) do
    %Mutant{
      id: id,
      file: "lib/calc.ex",
      module: Calc,
      function: function,
      operator: operator,
      variant: nil,
      target: "",
      range: {{1, 1}, {1, 2}},
      original: "",
      replacement: "",
      patch: ""
    }
  end

  defp row(id, status, opts \\ []) do
    %{
      record: Keyword.get(opts, :record, "test/sabotage_records/a.md"),
      block: Keyword.get(opts, :block, 1),
      id: id,
      file: "lib/calc.ex",
      mfa: Keyword.get(opts, :mfa, @mfa),
      operator: "return_input",
      status: status,
      killers: []
    }
  end

  defp entry(id, reason \\ "equivalent mutant", operator \\ "return_input") do
    %Entry{
      id: id,
      file: "lib/calc.ex",
      mfa: @mfa,
      operator: operator,
      reason: reason,
      line_no: 1
    }
  end

  defp ctx(extra \\ %{}), do: Map.merge(%{changed_mfas: [@mfa], base: "abc123"}, extra)

  describe "judge/4" do
    test "1: every id covered by a killed row" do
      v =
        Verify.judge(
          [mutant("m1"), mutant("m2")],
          [row("m1", "killed"), row("m2", "killed")],
          [],
          ctx()
        )

      assert v.uncovered == []
      assert v.covered == [{"m1", :killed}, {"m2", :killed}]
      assert Verify.exit_code(v) == 0
    end

    test "2: timeout and invalid rows count as covered" do
      v =
        Verify.judge(
          [mutant("m1"), mutant("m2")],
          [row("m1", "timeout"), row("m2", "invalid")],
          [],
          ctx()
        )

      assert v.uncovered == []
      assert v.covered == [{"m1", :timeout}, {"m2", :invalid}]
    end

    test "survived, no_tests and crashed rows cover nothing (positive control: killed does)" do
      for status <- ~w(survived no_tests crashed) do
        v = Verify.judge([mutant("m1")], [row("m1", status)], [], ctx())
        assert [%Mutant{id: "m1"}] = v.uncovered, status
      end

      assert Verify.judge([mutant("m1")], [row("m1", "killed")], [], ctx()).uncovered == []
    end

    test "a mutant's latest row decides: a later survived row undoes an earlier kill" do
      rows = [row("m1", "killed", block: 1), row("m1", "survived", block: 2)]

      assert [%Mutant{id: "m1"}] = Verify.judge([mutant("m1")], rows, [], ctx()).uncovered

      assert Verify.judge([mutant("m1")], rows, [entry("m1")], ctx()).covered == [
               {"m1", :survivor}
             ]

      # Positive control: the kill as the latest row covers it.
      v = Verify.judge([mutant("m1")], Enum.reverse(rows), [], ctx())
      assert v.covered == [{"m1", :killed}]
    end

    test "3: a survivors entry covers an id" do
      v = Verify.judge([mutant("m1")], [], [entry("m1")], ctx())

      assert v.covered == [{"m1", :survivor}]
      assert v.uncovered == []
    end

    test "a survivors entry naming another operator covers nothing and is a bad survivor" do
      v = Verify.judge([mutant("m1")], [], [entry("m1", "equivalent", "delete_statement")], ctx())

      assert [%Mutant{id: "m1"}] = v.uncovered
      assert [{1, message}] = v.bad_survivors
      assert message =~ "id m1 belongs to Calc.add/2 return_input in lib/calc.ex"
      assert Verify.exit_code(v) == 1
    end

    test "4: an id with no row and no entry is uncovered" do
      v = Verify.judge([mutant("m1"), mutant("m2")], [row("m1", "killed")], [], ctx())

      assert [%Mutant{id: "m2"}] = v.uncovered
      assert Verify.exit_code(v) == 1
    end

    test "5: a row of a changed function's last run whose id is no longer generated is stale" do
      v = Verify.judge([mutant("m1")], [row("m1", "killed"), row("x", "killed")], [], ctx())

      assert v.stale_rows == [{"test/sabotage_records/a.md", "x", @mfa}]
      assert Verify.exit_code(v) == 1
    end

    test "a row of an earlier run of the function is history, never stale" do
      rows = [
        row("x", "killed", block: 1),
        row("m1", "killed", block: 2)
      ]

      v = Verify.judge([mutant("m1")], rows, [], ctx())

      assert v.stale_rows == []
      assert Verify.exit_code(v) == 0

      # Positive control: the same old row in the last block is stale.
      v = Verify.judge([mutant("m1")], Enum.reverse(rows), [], ctx())
      assert v.stale_rows == [{"test/sabotage_records/a.md", "x", @mfa}]
    end

    test "a later record's block is the later run" do
      rows = [
        row("x", "killed", record: "test/sabotage_records/a.md"),
        row("m1", "killed", record: "test/sabotage_records/b.md")
      ]

      assert Verify.judge([mutant("m1")], rows, [], ctx()).stale_rows == []
    end

    test "6: a row for a function the diff did not change is not stale" do
      v =
        Verify.judge(
          [mutant("m1")],
          [row("m1", "killed"), row("y", "killed", mfa: "Calc.sub/2")],
          [],
          ctx()
        )

      assert v.stale_rows == []
    end

    test "7 and 8: refused survivors entries are carried as bad survivors" do
      bad = [{1, "the reason is a placeholder (TODO): write the real reason"}]
      v = Verify.judge([], [], [], ctx(%{bad_survivors: bad, changed_mfas: []}))

      assert v.bad_survivors == bad
      assert Verify.exit_code(v) == 1
    end

    test "9: a deleted landed record is carried" do
      v = Verify.judge([], [], [], ctx(%{deleted_records: ["test/sabotage_records/a.md"]}))

      assert v.deleted_records == ["test/sabotage_records/a.md"]
      assert Verify.exit_code(v) == 1
    end

    test "10: a generated function is listed, not uncovered" do
      v = Verify.judge([], [], [], ctx(%{not_in_source: ["Calc.gen/0"]}))

      assert v.not_in_source == ["Calc.gen/0"]
      assert v.uncovered == []
      assert Verify.exit_code(v) == 0
    end

    test "11: an empty scope" do
      v = Verify.judge([], [], [], %{changed_mfas: []})

      assert %Verdict{functions: 0, mutants: 0, covered: [], uncovered: [], stale_rows: []} = v
      assert Verify.exit_code(v) == 0
    end

    test "a mutant id generated twice is COULD NOT MEASURE" do
      v = Verify.judge([mutant("m1"), mutant("m1")], [row("m1", "killed")], [], ctx())

      assert v.could_not_measure =~
               "COULD NOT MEASURE: the generator made one mutant id twice: m1 (Calc.add/2)"

      assert Verify.exit_code(v) == 3
    end
  end

  describe "survivors/1" do
    test "a good list is all entries" do
      line = "abcdef012345 lib/calc.ex Calc.add/2 return_input  # equivalent"
      assert {[%Entry{id: "abcdef012345"}], []} = Verify.survivors([line])
    end

    test "TODO, empty, duplicate and malformed entries are refused; the good ones still count" do
      lines = [
        "abcdef012345 lib/calc.ex Calc.add/2 return_input  # equivalent",
        "bbbbbb012345 lib/calc.ex Calc.add/2 return_input  # TODO",
        "cccccc012345 lib/calc.ex Calc.add/2 return_input  #",
        "abcdef012345 lib/calc.ex Calc.add/2 return_input  # again",
        "not a line"
      ]

      assert {[%Entry{id: "abcdef012345", line_no: 1}], refused} = Verify.survivors(lines)
      assert Enum.map(refused, &elem(&1, 0)) == [2, 3, 4, 5]
      assert {2, todo} = Enum.at(refused, 0)
      assert todo =~ "placeholder"
      assert {3, empty} = Enum.at(refused, 1)
      assert empty =~ "empty"
      assert {4, duplicate} = Enum.at(refused, 2)
      assert duplicate =~ "duplicate id"
    end
  end

  describe "record_path?/2" do
    test "a record under the records dir, an app's dir by {app}; never README or another dir" do
      assert Verify.record_path?("test/sabotage_records/a-20261106-x.md", "test/sabotage_records")

      assert Verify.record_path?(
               "apps/web/test/sabotage_records/a.md",
               "apps/*/test/sabotage_records"
             )

      refute Verify.record_path?("test/sabotage_records/README.md", "test/sabotage_records")
      refute Verify.record_path?("test/sabotage_records/a.txt", "test/sabotage_records")
      refute Verify.record_path?("test/sabotage_records/sub/a.md", "test/sabotage_records")
      refute Verify.record_path?("docs/a.md", "test/sabotage_records")
    end
  end

  describe "unmeasured_scope?/3" do
    test "changed source files with nothing counted measured nothing" do
      zero = %{outside_hunks: 0, macros: 0}

      assert Verify.unmeasured_scope?(1, 0, zero)
      refute Verify.unmeasured_scope?(0, 0, zero)
      refute Verify.unmeasured_scope?(1, 1, zero)
      refute Verify.unmeasured_scope?(1, 0, %{zero | outside_hunks: 1})
      refute Verify.unmeasured_scope?(1, 0, %{zero | macros: 1})
    end
  end

  describe "exit_code/1" do
    test "1: a clean verdict is 0" do
      assert Verify.exit_code(%Verdict{}) == 0
    end

    test "2: each failure kind is 1" do
      for verdict <- [
            %Verdict{uncovered: [mutant("m1")]},
            %Verdict{stale_rows: [{"r.md", "x", @mfa}]},
            %Verdict{bad_survivors: [{1, "bad"}]},
            %Verdict{bad_records: [{"r.md", 3, "bad"}]},
            %Verdict{deleted_records: ["r.md"]}
          ] do
        assert Verify.exit_code(verdict) == 1, inspect(verdict)
      end
    end

    test "3: could_not_measure is 3" do
      assert Verify.exit_code(%Verdict{could_not_measure: "COULD NOT MEASURE: x. Fix: y"}) == 3
    end
  end

  describe "render/2" do
    defp failing do
      %Verdict{
        base: "abc123",
        survivors_path: ".anchor/sabotage/survivors.txt",
        functions: 1,
        mutants: 2,
        uncovered: [mutant("m1")],
        stale_rows: [{"test/sabotage_records/a.md", "x", @mfa}],
        bad_survivors: [{2, "the reason is empty"}, {nil, "not found"}],
        bad_records: [{"test/sabotage_records/b.md", 4, "a row has 5 fields, not 6"}],
        deleted_records: ["test/sabotage_records/c.md"],
        not_in_source: ["Calc.gen/0"]
      }
    end

    test "1: each failure line ends with exactly one Fix:" do
      lines = String.split(Verify.render(failing(), :text), "\n")

      failures =
        Enum.filter(
          lines,
          &String.starts_with?(
            &1,
            ~w(UNCOVERED STALE\ RECORD BAD\ SURVIVOR BAD\ RECORD RECORD\ REMOVED)
          )
        )

      assert length(failures) == 6

      for line <- failures do
        assert length(String.split(line, "Fix: ")) == 2, line
      end

      assert Enum.any?(lines, &(&1 =~ "UNCOVERED m1 lib/calc.ex Calc.add/2 return_input:"))

      assert Enum.any?(
               lines,
               &(&1 =~ "STALE RECORD test/sabotage_records/a.md: Calc.add/2 changed")
             )

      assert Enum.any?(lines, &(&1 =~ "mix anchor.sabotage run --base abc123"))
      assert Enum.any?(lines, &(&1 =~ "BAD SURVIVOR .anchor/sabotage/survivors.txt, entry 2:"))
      assert Enum.any?(lines, &(&1 =~ "RECORD REMOVED test/sabotage_records/c.md"))
      assert Enum.any?(lines, &(&1 =~ "NOT IN SOURCE Calc.gen/0"))

      assert List.last(lines) =~
               "sabotage verify: 1 functions, 2 mutants: 1 uncovered, 1 stale rows, 2 bad survivors"
    end

    test "2: the summary line of a clean verdict" do
      v = %Verdict{
        functions: 3,
        mutants: 9,
        covered:
          [{"a", :killed}, {"b", :timeout}, {"c", :invalid}, {"d", :survivor}] ++
            for(n <- 1..5, do: {"k#{n}", :killed})
      }

      assert Verify.render(v, :text) ==
               "sabotage verify: 3 functions, 9 mutants, all covered (7 killed, 1 survivors, 1 invalid)"
    end

    test "an empty scope says so" do
      assert Verify.render(%Verdict{}, :text) == "sabotage verify: no changed functions"
    end

    test "COULD NOT MEASURE is the whole text" do
      message = "COULD NOT MEASURE: x. Fix: y"
      assert Verify.render(%Verdict{could_not_measure: message}, :text) == message
    end

    test "3: json carries every Verdict field" do
      decoded = JSON.decode!(Verify.render(failing(), :json))

      keys = %Verdict{} |> Map.from_struct() |> Map.keys() |> Enum.map(&Atom.to_string/1)
      assert Enum.sort(keys -- Map.keys(decoded)) == []
      assert decoded["exit_code"] == 1
      assert [%{"id" => "m1", "mfa" => "Calc.add/2"}] = decoded["uncovered"]
    end

    test "4: survivors added are printed for review, exit unaffected" do
      v = %Verdict{
        functions: 1,
        mutants: 1,
        covered: [{"m1", :survivor}],
        survivors_added: [entry("m1")]
      }

      assert Verify.render(v, :text) =~
               "REVIEW survivor added: m1 lib/calc.ex Calc.add/2 return_input  # equivalent mutant"

      assert Verify.exit_code(v) == 0
    end
  end
end
