defmodule Anchor.Domain.Sabotage.ReportTest do
  # DND-5473: the run's text and exit code.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ChangedFunction
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.Skipped

  defp mutant(id, operator \\ :return_input) do
    %Mutant{
      id: id,
      file: "lib/calc.ex",
      module: Calc,
      function: {:add, 2},
      operator: operator,
      variant: 0,
      target: "add(a, b)",
      range: {{2, 3}, {4, 5}},
      original: "a + b",
      replacement: "a",
      patch: ""
    }
  end

  defp outcome(id, status, killers \\ [], reason \\ nil, selection \\ nil) do
    %{
      mutant: mutant(id),
      status: status,
      killers: killers,
      selection: selection || {:mirror, ["test/calc_test.exs"]},
      reason: reason
    }
  end

  @killer {"test/calc_test.exs", 4, "test adds"}

  test "1: all killed: exit 0, one line per mutant with id, M.f/a, operator, status, killers, source" do
    run = %Run{
      outcomes: [outcome("aaa", :killed, [@killer]), outcome("bbb", :timeout, ["(timeout)"])]
    }

    assert Report.exit_code(run) == 0
    text = Report.render(run)

    assert text =~
             "aaa\tCalc.add/2\treturn_input\tkilled\ttest/calc_test.exs:4 test adds\t" <>
               "selected by mirror: test/calc_test.exs\n"

    assert text =~ "bbb\tCalc.add/2\treturn_input\ttimeout\t(timeout)\t"

    assert text =~
             "anchor.sabotage run: 2 mutants run: 1 killed, 0 survived, 1 timeout, 0 invalid, " <>
               "0 no_tests; 0 skipped; 0 not run (cap); 0 errors"
  end

  test "DND-5474: a line counts the mutants by the source that chose their tests" do
    run = %Run{
      outcomes: [
        outcome("aaa", :killed, [@killer], nil, {:coverage, ["test/other_test.exs:9"]}),
        outcome("bbb", :killed, [@killer], nil, {:coverage, ["test/other_test.exs:9"]}),
        outcome("ccc", :killed, [@killer])
      ]
    }

    text = Report.render(run)

    assert text =~ "selected by coverage: test/other_test.exs:9"
    assert text =~ "\ntests selected by: 2 coverage, 1 mirror\nanchor.sabotage run: 3 mutants"
  end

  test "2: one survivor: exit 1, its line ends with a Fix:" do
    run = %Run{outcomes: [outcome("aaa", :killed, [@killer]), outcome("bbb", :survived)]}

    assert Report.exit_code(run) == 1

    assert Report.render(run) =~
             ~r/^bbb\tCalc\.add\/2\treturn_input\tsurvived\t\t.*\tFix: add a test that fails under this mutant$/m
  end

  test "3: a no_tests mutant: exit 1, it names the mirror path it looked for" do
    run = %Run{outcomes: [outcome("ccc", :no_tests, [], "test/calc_test.exs", {:none, []})]}

    assert Report.exit_code(run) == 1

    assert Report.render(run) =~
             "ccc\tCalc.add/2\treturn_input\tno_tests\t\tselected by: none\t" <>
               "Fix: add test/calc_test.exs, or a test_mirror rule that finds this file's tests"
  end

  test "4: mutants past the cap are listed, counted, never dropped" do
    run = %Run{
      outcomes: [outcome("aaa", :killed, [@killer])],
      not_run: Enum.map(1..10, &mutant("n#{&1}"))
    }

    text = Report.render(run)
    assert text =~ "\nnot run (cap): 10 mutants; rerun with --max all (CI)\n"
    assert text =~ "; 10 not run (cap);"
    assert Report.exit_code(run) == 0
  end

  test "5: an error is listed, not counted as killed" do
    function = %ChangedFunction{
      file: "lib/gen.ex",
      module: Gen,
      name: :init,
      arity: 1,
      kind: :def,
      changed_lines: [3]
    }

    run = %Run{errors: [{function, :not_in_source}]}
    text = Report.render(run)

    assert text =~ "error\tlib/gen.ex\tGen.init/1\tno literal def/defp clause in the source"
    assert text =~ "0 mutants run: 0 killed,"
    assert text =~ "; 1 errors"
  end

  test "an invalid mutant says why, is counted in the summary, and does not fail the run" do
    run = %Run{
      outcomes: [outcome("ddd", :invalid, [], "did not compile: error: undefined variable \"y\"")]
    }

    text = Report.render(run)
    assert text =~ "ddd\tCalc.add/2\treturn_input\tinvalid\t\t"
    assert text =~ "\tdid not compile: error: undefined variable \"y\""
    assert text =~ "0 timeout, 1 invalid, 0 no_tests"
    assert Report.exit_code(run) == 0
  end

  test "a skipped mutant is listed with its reason" do
    skipped = %Skipped{
      file: "lib/calc.ex",
      module: Calc,
      function: {:add, 2},
      operator: :narrow_clause,
      variant: nil,
      target: "add(a, b)",
      reason: "the function has one clause"
    }

    assert Report.render(%Run{skipped: [skipped]}) =~
             "skipped\tCalc.add/2\tnarrow_clause\t\"add(a, b)\"\tthe function has one clause"
  end

  test "a refusal prints its notes and message and exits with its code" do
    run = %Run{
      notes: ["restored leftover mutant aaa in lib/calc.ex"],
      refusal: {2, "no. Fix: yes"}
    }

    assert Report.render(run) == "restored leftover mutant aaa in lib/calc.ex\nno. Fix: yes"
    assert Report.exit_code(run) == 2
  end

  test "a dry run prints the plan and exits 0" do
    run = %Run{dry_run: true, planned: [{mutant("aaa"), {:mirror, ["test/calc_test.exs"]}}]}

    assert Report.render(run) =~
             "aaa\tCalc.add/2\treturn_input\tplanned\t\tselected by mirror: test/calc_test.exs\n" <>
               "anchor.sabotage run --dry-run: 1 mutants planned; nothing applied"

    assert Report.exit_code(run) == 0
  end
end
