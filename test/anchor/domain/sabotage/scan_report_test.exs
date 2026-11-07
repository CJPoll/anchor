defmodule Anchor.Domain.Sabotage.ScanReportTest do
  # DND-5490: the nightly scan's report, pure Domain.
  # Sabotage record: ../../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.ScanReport
  alias Anchor.Domain.Sabotage.Survivors.Entry

  defp mutant(id, module, function) do
    %Mutant{
      id: id,
      file: "lib/#{module |> inspect() |> String.downcase()}.ex",
      module: module,
      function: function,
      operator: :delete_statement,
      variant: nil,
      target: "",
      range: {{1, 1}, {1, 2}},
      original: "",
      replacement: "",
      patch: ""
    }
  end

  defp outcome(id, status, module \\ Calc, function \\ {:add, 2}),
    do: %{
      mutant: mutant(id, module, function),
      status: status,
      killers: [],
      selection: {:mirror, []},
      reason: nil
    }

  defp run do
    %Run{
      outcomes: [
        outcome("aaaaaaaaaaaa", :killed),
        outcome("bbbbbbbbbbbb", :survived),
        outcome("cccccccccccc", :survived, Store, {:put, 1}),
        outcome("dddddddddddd", :no_tests, Store, {:get, 1})
      ]
    }
  end

  defp listed(id),
    do: %Entry{
      id: id,
      file: "lib/calc.ex",
      mfa: "Calc.add/2",
      operator: "delete_statement",
      reason: "equivalent",
      line_no: 1
    }

  @golden """
  # Sabotage scan: tests selected by the coverage map cov/anchor-coverage.etf

  - Shard: 3/7
  - Mutants: 4; findings: 1; listed survivors: 1

  ## Totals

  | killed | survived | timeout | invalid | crashed | no_tests |
  |---|---|---|---|---|---|
  | 1 | 2 | 0 | 0 | 0 | 1 |

  ## By module

  | module | killed | survived | timeout | invalid | crashed | no_tests |
  |---|---|---|---|---|---|---|
  | Calc | 1 | 1 | 0 | 0 | 0 | 0 |
  | Store | 0 | 1 | 0 | 0 | 0 | 1 |

  ## Findings: survivors not on the survivors list

  - `cccccccccccc` lib/store.ex Store.put/1 delete_statement

  ## Functions whose mutants had no test

  - Store.get/1 (lib/store.ex)
  """

  describe "render/3" do
    test "1: findings are only the unlisted survivors; no_tests, totals and the markdown" do
      {markdown, term} =
        ScanReport.render(run(), [listed("bbbbbbbbbbbb")], %{
          shard: {3, 7},
          coverage: "cov/anchor-coverage.etf"
        })

      assert markdown == @golden
      assert [%{id: "cccccccccccc", mfa: "Store.put/1"}] = term.findings
      assert term.listed_survivors == 1
      assert term.no_tests == [{"lib/store.ex", "Store.get/1"}]
      assert %{killed: 1, survived: 2, no_tests: 1, timeout: 0} = term.totals
      assert term.shard == {3, 7}
    end

    test "2: with no coverage map, the first line says selection fell back to kill maps and mirror" do
      {markdown, term} = ScanReport.render(%Run{}, [], %{shard: nil, coverage: nil})

      assert hd(String.split(markdown, "\n")) ==
               "# Sabotage scan: no coverage map, so tests were selected from the kill maps " <>
                 "and the test mirror"

      assert markdown =~ "- Shard: all\n"
      assert markdown =~ "## Findings: survivors not on the survivors list\n\nNone.\n"
      assert term.coverage == nil
    end
  end
end
