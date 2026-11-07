defmodule Anchor.Domain.Sabotage.ReportTest do
  # DND-5473: the run's text and exit code.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  # Sabotage record (DND-5617): ../../../sabotage_records/sabotage-20261103-dnd_5617_sabotage_cfa_batch.md
  # Sabotage record (DND-5624): ../../../sabotage_records/sabotage-20261103-dnd_5624_sabotage_defimpl.md
  # Sabotage record (DND-5653): ../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  # Sabotage record (DND-5483): ../../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
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
               "0 crashed, 0 no_tests; 0 skipped; 0 not run (cap); 0 errors"
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

  test "3: a no_tests mutant in a measured run: exit 1, it names the mirror path it looked for" do
    run = %Run{
      outcomes: [
        outcome("aaa", :killed, [@killer]),
        outcome("ccc", :no_tests, [], "test/calc_test.exs", {:none, []})
      ]
    }

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

  test "a function in a defimpl whose for: is not a literal is its own error line (DND-5624)" do
    function = %ChangedFunction{
      file: "lib/gen.ex",
      module: nil,
      name: :to_string,
      arity: 1,
      kind: :def,
      changed_lines: [3]
    }

    text = Report.render(%Run{errors: [{function, :defimpl_target_not_literal}]})

    assert text =~
             "error\tlib/gen.ex\tnil.to_string/1\tdefimpl target not a literal (its module " <>
               "cannot be named): no mutant, not killed"

    refute text =~ "a macro made it"
  end

  test "an invalid mutant says why, is counted in the summary, and does not fail the run" do
    run = %Run{
      outcomes: [outcome("ddd", :invalid, [], "did not compile: error: undefined variable \"y\"")]
    }

    text = Report.render(run)
    assert text =~ "ddd\tCalc.add/2\treturn_input\tinvalid\t\t"
    assert text =~ "\tdid not compile: error: undefined variable \"y\""
    assert text =~ "0 timeout, 1 invalid, 0 crashed, 0 no_tests"
  end

  describe "exit-code policy (DND-5570)" do
    defp exit_of(statuses) do
      outcomes =
        statuses
        |> Enum.with_index()
        |> Enum.map(fn {status, i} ->
          killers = if status == :killed, do: [@killer], else: []
          outcome("m#{i}", status, killers, "why")
        end)

      Report.exit_code(%Run{outcomes: outcomes})
    end

    test "zero changed functions from a good diff read: exit 0, said loudly with the range" do
      run = %Run{base: "origin/main", changed_functions: 0}

      assert Report.exit_code(run) == 0
      assert Report.render(run) =~ "sabotage: 0 changed functions in origin/main..HEAD\n"
    end

    test "zero changed functions is also said loudly in a dry run" do
      run = %Run{base: "main", changed_functions: 0, dry_run: true}

      assert Report.exit_code(run) == 0
      assert Report.render(run) =~ "sabotage: 0 changed functions in main..HEAD\n"
    end

    test "positive control: changed functions that made no mutant do not print the zero line" do
      run = %Run{base: "origin/main", changed_functions: 2}

      refute Report.render(run) =~ "0 changed functions"
    end

    test "mutants run and none measured is exit 3, COULD NOT MEASURE with a Fix:" do
      for statuses <- [
            [:invalid],
            [:invalid, :invalid],
            [:crashed],
            [:no_tests, :no_tests],
            [:invalid, :crashed, :no_tests]
          ] do
        assert exit_of(statuses) == 3, inspect(statuses)
      end

      text = Report.render(%Run{outcomes: [outcome("aaa", :invalid, [], "did not compile: x")]})
      assert text =~ "COULD NOT MEASURE: 1 mutants were run and none was measured"
      assert text =~ "Fix: "
    end

    test "positive control: one measured mutant makes invalid mutants not change the exit" do
      assert exit_of([:killed, :invalid]) == 0
      assert exit_of([:invalid, :killed, :invalid]) == 0
      assert exit_of([:timeout, :invalid]) == 0
      assert exit_of([:survived, :invalid]) == 1
    end

    test "an unmeasured mutant (crashed, or no test) in a measured run fails like a survivor" do
      assert exit_of([:killed, :crashed]) == 1
      assert exit_of([:killed, :no_tests]) == 1
      assert exit_of([:timeout, :crashed]) == 1
      assert exit_of([:killed, :survived]) == 1
    end

    test "a crashed mutant's line says why and ends with a Fix:" do
      run = %Run{
        outcomes: [
          outcome("aaa", :killed, [@killer]),
          outcome("bbb", :crashed, [], "test run crashed (exit 1)")
        ]
      }

      assert Report.render(run) =~
               ~r/^bbb\tCalc\.add\/2\treturn_input\tcrashed\t\t.*\ttest run crashed \(exit 1\)\tFix: .+$/m
    end

    test "a no_tests mutant whose tests ran none says why, not a mirror path" do
      run = %Run{
        outcomes: [
          outcome("aaa", :killed, [@killer]),
          outcome("ddd", :no_tests, [], "no test ran")
        ]
      }

      text = Report.render(run)
      assert text =~ "\tno test ran\tFix: "
      refute text =~ "Fix: add no test ran"
    end

    test "a refusal and a dry run keep their own codes" do
      assert Report.exit_code(%Run{refusal: {3, "x"}, outcomes: [outcome("a", :killed)]}) == 3
      assert Report.exit_code(%Run{dry_run: true}) == 0

      # A dry run applies nothing, so whatever outcomes it holds are not read.
      assert Report.exit_code(%Run{dry_run: true, outcomes: [outcome("a", :survived)]}) == 0
    end
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

  describe "changed functions that yield no mutant (DND-5617)" do
    defp changed(name, file \\ "lib/gen.ex"),
      do: %ChangedFunction{
        file: file,
        module: Gen,
        name: name,
        arity: 1,
        kind: :def,
        changed_lines: [3]
      }

    @summary "sabotage: no mutants generated from 2 changed functions: nothing was measured"

    test "Z1: only macros: exit 0, one loud line per function naming it and why, then the count" do
      run = %Run{
        base: "origin/main",
        changed_functions: 2,
        generated: 0,
        errors: [{changed(:init), :not_in_source}, {changed(:stop), :not_in_source}],
        no_mutant: [
          {changed(:init), "macro: no literal def/defp clause in the source (a macro made it)"},
          {changed(:stop), "macro: no literal def/defp clause in the source (a macro made it)"}
        ]
      }

      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "sabotage: no mutant from Gen.init/1 (lib/gen.ex): macro: no literal def/defp " <>
                 "clause in the source (a macro made it)\n"

      assert text =~ "sabotage: no mutant from Gen.stop/1 (lib/gen.ex): macro:"
      assert text =~ @summary
    end

    test "Z2: only skipped functions: exit 0, each line names the skip rule, then the count" do
      run = %Run{
        changed_functions: 2,
        generated: 0,
        no_mutant: [
          {changed(:init), "skipped: delete_statement: orphans variable `x`"},
          {changed(:stop, "lib/stop.ex"), "no mutable site"}
        ]
      }

      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "sabotage: no mutant from Gen.init/1 (lib/gen.ex): skipped: delete_statement: " <>
                 "orphans variable `x`"

      assert text =~ "sabotage: no mutant from Gen.stop/1 (lib/stop.ex): no mutable site"
      assert text =~ @summary
    end

    test "Z3: the dry run says it too" do
      run = %Run{
        dry_run: true,
        changed_functions: 1,
        generated: 0,
        no_mutant: [{changed(:init), "no mutable site"}]
      }

      assert Report.exit_code(run) == 0

      assert Report.render(run) =~
               "sabotage: no mutant from Gen.init/1 (lib/gen.ex): no mutable site"

      assert Report.render(run) =~ "no mutants generated from 1 changed functions"
    end

    test "Z4: positive control: one mutant generated prints no such line" do
      run = %Run{
        changed_functions: 2,
        generated: 1,
        no_mutant: [{changed(:stop), "no mutable site"}],
        outcomes: [outcome("aaa", :killed, [@killer])]
      }

      assert Report.exit_code(run) == 0
      text = Report.render(run)
      refute text =~ "no mutants generated"
      refute text =~ "sabotage: no mutant from"
    end

    test "Z5: zero changed functions keeps its own line and never this one" do
      run = %Run{base: "origin/main", changed_functions: 0, generated: 0}

      text = Report.render(run)
      assert text =~ "sabotage: 0 changed functions in origin/main..HEAD"
      refute text =~ "no mutants generated"
    end
  end

  describe "a record that could not be written (DND-5641)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5641_record_error_exit.md
    @record_error "could not write the sabotage record test/sabotage_records/x.md (:eacces); " <>
                    "nothing was overwritten. Fix: check test/sabotage_records is writable, then rerun"

    defp failed_record(statuses) do
      outcomes =
        statuses
        |> Enum.with_index()
        |> Enum.map(fn {status, i} ->
          killers = if status == :killed, do: [@killer], else: []
          outcome("m#{i}", status, killers, "why")
        end)

      %Run{base: "origin/main", outcomes: outcomes, record_error: @record_error}
    end

    test "a survivor keeps exit 1; the record failure is said loudly" do
      run = failed_record([:killed, :survived])

      assert Report.exit_code(run) == 1
      assert Report.render(run) =~ "sabotage: record not written: #{@record_error}\n"
    end

    test "nothing measured keeps exit 3, COULD NOT MEASURE; the record failure is said loudly" do
      run = failed_record([:invalid, :crashed])

      assert Report.exit_code(run) == 3
      assert Report.render(run) =~ "sabotage: record not written: #{@record_error}\n"
    end

    test "only a passing verdict becomes exit 2" do
      run = failed_record([:killed, :timeout])

      assert Report.exit_code(run) == 2
      assert Report.render(run) =~ "sabotage: record not written: #{@record_error}\n"
    end

    test "a written record is no failure: the pass stays exit 0" do
      assert Report.exit_code(%{failed_record([:killed]) | record_error: nil}) == 0
    end
  end

  describe "a scan (DND-5490)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
    @scan %{report: "scan.md", shard: {0, 7}, coverage: nil}

    test "its survivors and no_tests mutants are findings, never a failure: exit 0" do
      run = %Run{
        scan: @scan,
        outcomes: [outcome("a", :killed, [@killer]), outcome("b", :survived)]
      }

      assert Report.exit_code(run) == 0
      assert Report.exit_code(%{run | scan: nil}) == 1

      assert Report.exit_code(%Run{
               scan: @scan,
               outcomes: [outcome("a", :survived), outcome("b", :no_tests)]
             }) ==
               0
    end

    test "a scan that measured nothing is 3; a report not written is 2, said loudly" do
      assert Report.exit_code(%Run{scan: @scan, outcomes: [outcome("a", :invalid, [], "why")]}) ==
               3

      run = %Run{scan: @scan, outcomes: [outcome("a", :survived)], report_error: "eacces"}
      assert Report.exit_code(run) == 2
      assert Report.render(run) =~ "sabotage: scan report not written: eacces\n"

      written = %{run | report_error: nil, report: ["scan.md", "scan.etf"]}

      assert Report.render(written) =~
               "sabotage scan report written: scan.md\nsabotage scan report written: scan.etf\n"
    end
  end

  describe "kills that rest on time alone (DND-5653)" do
    test "R1: the timeout kills get their own line, naming each mutant and its killers; still exit 0" do
      run = %Run{
        outcomes: [
          outcome("aaa", :killed, [@killer]),
          outcome("bbb", :timeout, ["(test timeout) test/calc_test.exs:9 test slow"]),
          outcome("ccc", :timeout, ["(timeout)"])
        ]
      }

      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "sabotage: 2 kills rest on time alone (no assertion failed; a hang the mutant " <>
                 "caused, or a slow host): bbb Calc.add/2 by (test timeout) " <>
                 "test/calc_test.exs:9 test slow; ccc Calc.add/2 by (timeout)\n"

      assert text =~ "1 killed, 0 survived, 2 timeout,"
    end

    test "R2: positive control: no timeout kill, no such line" do
      run = %Run{outcomes: [outcome("aaa", :killed, [@killer])]}
      refute Report.render(run) =~ "rest on time alone"
    end
  end

  describe "the survivors list (DND-5483)" do
    alias Anchor.Domain.Sabotage.Survivors.Entry
    alias Anchor.Domain.Sabotage.Survivors.Judgement

    @path ".anchor/sabotage/survivors.txt"

    defp entry(id),
      do: %Entry{
        id: id,
        file: "lib/calc.ex",
        mfa: "Calc.add/2",
        operator: "return_input",
        reason: "logging only",
        line_no: 1
      }

    defp judged(outcomes, judgement, grew \\ {:added, []}),
      do: %Run{
        outcomes: outcomes,
        survivors: %{path: @path, base: "origin/main", judgement: judgement, grew: grew}
      }

    test "S1: one NEW survivor: exit 1; the Fix block holds the line to add" do
      survivor = outcome("aaaaaaaaaaaa", :survived)

      run =
        judged([outcome("bbbbbbbbbbbb", :killed, [@killer]), survivor], %Judgement{
          new: [survivor]
        })

      assert Report.exit_code(run) == 1
      text = Report.render(run)
      assert text =~ "NEW survivor aaaaaaaaaaaa lib/calc.ex Calc.add/2 return_input\n"
      assert text =~ "  Fix: add a test that fails under this mutant, or add to #{@path}:\n"

      assert text =~
               "  aaaaaaaaaaaa lib/calc.ex Calc.add/2 return_input  # <why no test can kill it>\n"
    end

    test "S2: one STALE entry: exit 1; Fix: delete its line" do
      run =
        judged([outcome("bbbbbbbbbbbb", :killed, [@killer])], %Judgement{
          stale: [{entry("aaaaaaaaaaaa"), "now killed by test/calc_test.exs:4 test adds"}]
        })

      assert Report.exit_code(run) == 1

      assert Report.render(run) =~
               "STALE survivor aaaaaaaaaaaa Calc.add/2 return_input " <>
                 "(now killed by test/calc_test.exs:4 test adds). Fix: delete its line from #{@path}\n"
    end

    test "S3: only held and GREW: exit 0, the survivor line names its reason, the GREW block printed" do
      survivor = outcome("aaaaaaaaaaaa", :survived)

      run =
        judged(
          [outcome("bbbbbbbbbbbb", :killed, [@killer]), survivor],
          %Judgement{held: [entry("aaaaaaaaaaaa")]},
          {:added, [entry("aaaaaaaaaaaa")]}
        )

      assert Report.exit_code(run) == 0
      text = Report.render(run)

      assert text =~
               "aaaaaaaaaaaa\tCalc.add/2\treturn_input\tsurvived\t\tselected by mirror: test/calc_test.exs\tlisted in #{@path}: logging only\n"

      refute text =~ "Fix: add a test that fails under this mutant\n"
      assert text =~ "Survivors added by this branch: review each reason\n"
      assert text =~ "  aaaaaaaaaaaa lib/calc.ex Calc.add/2 return_input  # logging only\n"
      assert text =~ "survivors: 1 held, 0 new, 0 stale, 0 not judged\n"
    end

    test "S3b: a first landing names every entry for review, and still exits 0" do
      run =
        judged(
          [outcome("bbbbbbbbbbbb", :killed, [@killer])],
          %Judgement{},
          {:first_landing, [entry("aaaaaaaaaaaa")]}
        )

      assert Report.exit_code(run) == 0

      assert Report.render(run) =~
               "Survivors added by this branch: review each reason (#{@path} is not on origin/main: " <>
                 "every entry is new)\n  aaaaaaaaaaaa"
    end

    test "S4: unjudged entries: exit 0, a not judged line each" do
      run =
        judged([outcome("bbbbbbbbbbbb", :killed, [@killer])], %Judgement{
          unjudged: [{entry("aaaaaaaaaaaa"), :not_run}]
        })

      assert Report.exit_code(run) == 0

      assert Report.render(run) =~
               "survivor aaaaaaaaaaaa Calc.add/2 return_input not judged (not run, cap)\n"
    end

    test "S5: a malformed entry: exit 1, naming it" do
      run =
        judged([outcome("bbbbbbbbbbbb", :killed, [@killer])], %Judgement{
          malformed: [{entry("aaaaaaaaaaaa"), "id aaaaaaaaaaaa belongs to X.y/1"}]
        })

      assert Report.exit_code(run) == 1

      assert Report.render(run) =~
               "survivors file #{@path}, entry 1 (aaaaaaaaaaaa lib/calc.ex Calc.add/2 return_input  # logging only): " <>
                 "id aaaaaaaaaaaa belongs to X.y/1. Fix: correct the entry, or delete it\n"
    end

    test "S6: a crashed mutant fails the run even with the list judged" do
      run =
        judged(
          [
            outcome("bbbbbbbbbbbb", :killed, [@killer]),
            outcome("cccccccccccc", :crashed, [], "boom")
          ],
          %Judgement{}
        )

      assert Report.exit_code(run) == 1
    end

    test "S7: STALE with no mutant run at all (the function changed, no mutant left): exit 1" do
      run = judged([], %Judgement{stale: [{entry("aaaaaaaaaaaa"), "no longer generated"}]})
      assert Report.exit_code(run) == 1
    end

    test "S8: an unmeasured run stays exit 3 even when its no_tests mutant is listed" do
      run =
        judged([outcome("aaaaaaaaaaaa", :no_tests, [], "test/calc_test.exs")], %Judgement{
          held: [entry("aaaaaaaaaaaa")]
        })

      assert Report.exit_code(run) == 3
    end

    test "S9: --print-survivor-lines prints a block of lines to paste; nothing else changes" do
      survivor = outcome("aaaaaaaaaaaa", :survived)
      run = %{judged([survivor], %Judgement{new: [survivor]}) | print_survivor_lines: true}

      assert Report.render(run) =~
               "Survivor lines to add to #{@path} (nothing was written; replace each placeholder with the real reason):\n" <>
                 "aaaaaaaaaaaa lib/calc.ex Calc.add/2 return_input  # <why no test can kill it>"

      refute Report.render(%{run | print_survivor_lines: false}) =~ "Survivor lines to add"
    end
  end
end
