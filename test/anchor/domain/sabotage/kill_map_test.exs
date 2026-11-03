defmodule Anchor.Domain.Sabotage.KillMapTest do
  # DND-5484: the anchor-kills block, rendered and parsed back.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutant

  defp mutant(id, function) do
    %Mutant{
      id: id,
      file: "lib/calc.ex",
      module: Calc,
      function: function,
      operator: :return_input,
      variant: nil,
      target: "",
      range: {{1, 1}, {1, 2}},
      original: "",
      replacement: "",
      patch: ""
    }
  end

  defp outcome(id, status, killers, function \\ {:add, 2}),
    do: %{
      mutant: mutant(id, function),
      status: status,
      killers: killers,
      selection: {:none, []},
      reason: nil
    }

  defp outcomes do
    [
      outcome("aaa", :killed, [
        {"test/calc_test.exs", 4, "test adds"},
        {"test/other_test.exs", 9, "test tab\there and\nnewline \\ slash"}
      ]),
      outcome("bbb", :survived, []),
      outcome("ccc", :timeout, ["(timeout)"]),
      outcome("ddd", :invalid, [], {:sub, 2})
    ]
  end

  @golden """
  ```anchor-kills
  # id\tfile\tmfa\toperator\tstatus\tkillers
  aaa\tlib/calc.ex\tCalc.add/2\treturn_input\tkilled\ttest/calc_test.exs:4 test adds ; test/other_test.exs:9 test tab\\there and\\nnewline \\\\ slash
  bbb\tlib/calc.ex\tCalc.add/2\treturn_input\tsurvived\t
  ccc\tlib/calc.ex\tCalc.add/2\treturn_input\ttimeout\t(timeout)
  ddd\tlib/calc.ex\tCalc.sub/2\treturn_input\tinvalid\t
  ```
  """

  describe "render_block/1 and parse/1" do
    test "1: the block equals the golden text" do
      assert KillMap.render_block(outcomes()) == @golden
    end

    test "2: parse(render) gives the rows back, a tab, a newline and a backslash included" do
      assert KillMap.parse("# Record\n\n" <> KillMap.render_block(outcomes())) ==
               {:ok, KillMap.rows(outcomes())}

      {:ok, [first | _]} = KillMap.parse(KillMap.render_block(outcomes()))

      assert List.last(first.killers) ==
               "test/other_test.exs:9 test tab\there and\nnewline \\ slash"
    end

    test "a test name holding the separator ` ; ` reads back as one killer" do
      outcomes = [outcome("fff", :killed, ["t_test.exs:1 test a ; b", "t_test.exs:2 test c;d"])]

      assert {:ok, [row]} = KillMap.parse(KillMap.render_block(outcomes))
      assert row.killers == ["t_test.exs:1 test a ; b", "t_test.exs:2 test c;d"]

      assert KillMap.render_block(outcomes) =~
               "t_test.exs:1 test a \\; b ; t_test.exs:2 test c\\;d\n"
    end

    test "3: every block of an appended record is read" do
      text =
        KillMap.render_block(outcomes()) <>
          "\n## Run 10:00 UTC\n\n" <>
          KillMap.render_block([outcome("eee", :killed, ["t_test.exs:1 x"])])

      assert {:ok, rows} = KillMap.parse(text)
      assert Enum.map(rows, & &1.id) == ~w(aaa bbb ccc ddd eee)
    end

    test "4: a row with 5 fields is refused, naming its line" do
      text = "x\n```anchor-kills\n# header\naaa\tlib/a.ex\tA.f/0\top\tkilled\n```\n"
      assert KillMap.parse(text) == {:error, {4, "a row has 5 fields, not 6"}}
    end

    test "an unknown status and an unclosed block are refused" do
      assert {:error, {2, "unknown status \"won\""}} =
               KillMap.parse("```anchor-kills\na\tb\tc\td\twon\t\n```\n")

      assert {:error, {1, _}} = KillMap.parse("```anchor-kills\n")
    end

    test "DND-5640: a killed row whose killer file is not a project test file is refused, naming the line" do
      # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5640_test_path.md
      row = fn killer ->
        "x\n```anchor-kills\n# h\nid\tlib/a.ex\tA.f/0\top\tkilled\t#{killer}\n```\n"
      end

      for {killer, why} <- [
            {"--include x_test.exs:1 t", "starts with -"},
            {"../outside_test.exs:3 t", "a .. segment"},
            {"/abs/x_test.exs:3 t", "an absolute path"},
            {"a/../b_test.exs:3 t", "a .. segment"},
            {"lib/a.ex:3 t", "not a _test.exs file"}
          ] do
        assert {:error, {4, message}} = KillMap.parse(row.(killer)), killer
        assert message =~ "killer #{inspect(killer)} refused: #{why}", killer
      end

      # Positive control, and a timeout row's "(timeout)" is no file.
      assert {:ok, [_]} = KillMap.parse(row.("test/a_test.exs:3 t"))

      assert {:ok, [_]} =
               KillMap.parse(
                 "```anchor-kills\nid\tlib/a.ex\tA.f/0\top\ttimeout\t(timeout)\n```\n"
               )
    end

    test "text with no block parses to no rows" do
      assert KillMap.parse("# nothing here\n```elixir\nfoo\n```\n") == {:ok, []}
    end
  end

  describe "killers_by_function/1" do
    test "1: killed rows map their function to the killers; a survived function is absent" do
      rows = [
        %{id: "1", file: "f", mfa: "M.f/1", operator: "o", status: "killed", killers: ["T1"]},
        %{
          id: "2",
          file: "f",
          mfa: "M.f/1",
          operator: "o",
          status: "killed",
          killers: ["T2", "T1"]
        },
        %{id: "3", file: "f", mfa: "M.g/0", operator: "o", status: "survived", killers: []},
        %{
          id: "4",
          file: "f",
          mfa: "M.h/0",
          operator: "o",
          status: "timeout",
          killers: ["(timeout)"]
        }
      ]

      assert KillMap.killers_by_function(rows) == %{"M.f/1" => ["T1", "T2"]}
    end
  end
end
