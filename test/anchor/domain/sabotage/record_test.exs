defmodule Anchor.Domain.Sabotage.RecordTest do
  # DND-5484: the sabotage record a run writes, against the golden file.
  # The date and time are facts passed in, never read here.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  # Sabotage record (DND-5653): ../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  # Sabotage record (DND-5643): ../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ChangedFunction
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Record
  alias Anchor.Domain.Sabotage.RecordNaming
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.Skipped
  alias Anchor.Domain.Sabotage.TestRun

  @golden_path "test/fixtures/sabotage/record_golden.md"
  @anchor %{
    dir: "test/sabotage_records",
    naming: :domain_date_slot,
    domain_from: :module,
    domain_strip_prefixes: ["Anchor.Domain.", "Anchor."],
    adr: "ADR 003"
  }

  defp mutant(id, opts) do
    %Mutant{
      id: id,
      file: Keyword.get(opts, :file, "lib/anchor/domain/sabotage/calc.ex"),
      module: Keyword.get(opts, :module, Anchor.Domain.Sabotage.Calc),
      function: {:add, 2},
      operator: Keyword.get(opts, :operator, :return_input),
      variant: Keyword.get(opts, :variant, 0),
      target: "a + b",
      range: {{3, 5}, {3, 10}},
      original: "a + b",
      replacement: "a",
      patch:
        "--- a/lib/anchor/domain/sabotage/calc.ex\n+++ b/lib/anchor/domain/sabotage/calc.ex\n" <>
          "@@ -3 +3 @@\n-    a + b\n+    a\n"
    }
  end

  @failure %{
    file: "test/anchor/domain/sabotage/calc_test.exs",
    line: 4,
    name: "test adds",
    text:
      "** (ExUnit.AssertionError) \n\nAssertion with == failed\ncode:  assert Calc.add(1, 2) == 3\nleft:  1\nright: 3"
  }

  defp killed(id, opts \\ []) do
    %{
      mutant: mutant(id, opts),
      status: :killed,
      killers: [{@failure.file, @failure.line, @failure.name}],
      selection: {:mirror, ["test/anchor/domain/sabotage/calc_test.exs"]},
      reason: nil,
      test_run: %TestRun{
        status: :failed,
        total: 3,
        failures: [@failure],
        exit_code: 2,
        output_head: ""
      }
    }
  end

  defp survived(id) do
    %{
      mutant: mutant(id, operator: :delete_statement, variant: nil),
      status: :survived,
      killers: [],
      selection: {:coverage, ["test/anchor/x_test.exs:7"]},
      reason: nil,
      test_run: %TestRun{status: :passed, total: 1, failures: [], exit_code: 0, output_head: ""}
    }
  end

  defp run do
    %Run{
      base: "origin/main",
      outcomes: [killed("aaa111"), survived("bbb222")],
      skipped: [
        %Skipped{
          file: "lib/anchor/domain/sabotage/calc.ex",
          module: Anchor.Domain.Sabotage.Calc,
          function: {:add, 2},
          operator: :drop_effect_call,
          variant: nil,
          target: "Logger.info(x)",
          reason: "orphans `x`"
        }
      ],
      not_run: [mutant("ccc333", operator: :force_condition, variant: true)],
      errors: [
        {%ChangedFunction{
           file: "lib/anchor/domain/sabotage/calc.ex",
           module: Anchor.Domain.Sabotage.Calc,
           name: :made,
           arity: 0,
           kind: :def,
           changed_lines: [9]
         }, :not_in_source}
      ]
    }
  end

  defp ctx(overrides \\ %{}) do
    {:ok, slot} = RecordNaming.slot("dnd-5484-records")

    Map.merge(
      %{
        records: @anchor,
        date: ~D[2026-11-05],
        time: "14:07",
        branch: "dnd-5484-records",
        slot: slot,
        base_sha: "1111111111111111111111111111111111111111",
        head_sha: "2222222222222222222222222222222222222222",
        command: "mix anchor.sabotage run --max all",
        version: "0.1.0",
        test_command: ["mix", "test", "--max-cases", "2"],
        domain: nil,
        changed_tests: [
          %{file: "test/anchor/domain/sabotage/calc_test.exs", line: 4, name: "test adds"},
          %{file: "test/anchor/domain/sabotage/calc_test.exs", line: 12, name: "test subtracts"}
        ],
        existing: %{}
      },
      overrides
    )
  end

  test "1: one :create entry whose content equals the golden record" do
    assert {:ok, [entry]} = Record.render(run(), ctx())

    assert entry.path == "test/sabotage_records/sabotage-20261105-dnd_5484_records.md"
    assert entry.mode == :create
    assert entry.content == File.read!(@golden_path)
  end

  test "the record's kill map parses back to exactly the run's outcomes" do
    {:ok, [entry]} = Record.render(run(), ctx())
    assert KillMap.parse(entry.content) == {:ok, KillMap.rows(run().outcomes)}
  end

  test "2: the same path already there the same day: :append, a `## Run` section, no title" do
    existing = %{"test/sabotage_records" => ["sabotage-20261105-dnd_5484_records.md"]}

    assert {:ok, [entry]} = Record.render(run(), ctx(%{existing: existing}))

    assert entry.mode == :append
    assert entry.content =~ ~r/\A## Run 14:07 UTC\n/
    refute entry.content =~ "# Sabotage record"
    assert entry.content =~ "\n### Mutants\n"

    assert entry.content =~
             "\n#### aaa111 Anchor.Domain.Sabotage.Calc.add/2 return_input [0]: killed\n"

    assert entry.content =~ "\n### Kill map\n"
  end

  test "3: outcomes in two apps: one record in each app's directory" do
    crew = %{@anchor | dir: "apps/{app}/test/sabotage_records", domain_from: :context_dir}

    run = %Run{
      outcomes: [
        killed("a1", file: "apps/core/lib/core/agents/x.ex"),
        killed("b2", file: "apps/web/lib/web/agents/y.ex")
      ]
    }

    assert {:ok, [core, web]} = Record.render(run, ctx(%{records: crew, changed_tests: []}))
    assert core.path == "apps/core/test/sabotage_records/agents-20261105-dnd_5484_records.md"
    assert web.path == "apps/web/test/sabotage_records/agents-20261105-dnd_5484_records.md"
    assert core.content =~ "a1 " and not (core.content =~ "b2 ")
  end

  test "4: outcomes in two domains: two files" do
    run = %Run{
      outcomes: [
        killed("a1"),
        killed("b2", module: Anchor.Config, file: "lib/anchor/domain/config.ex")
      ]
    }

    assert {:ok, entries} = Record.render(run, ctx())

    assert Enum.map(entries, & &1.path) == [
             "test/sabotage_records/config-20261105-dnd_5484_records.md",
             "test/sabotage_records/sabotage-20261105-dnd_5484_records.md"
           ]
  end

  test "5: ticket_nn_what over two apps: one file per app, each numbered in its own dir" do
    gen_saas = %{@anchor | dir: "apps/{app}/test/sabotage_records", naming: :ticket_nn_what}
    {:ok, slot} = RecordNaming.slot("DND-77-foo")
    existing = %{"apps/core/test/sabotage_records" => ["DND-77-01-x.md"]}

    run = %Run{
      outcomes: [
        killed("a1", file: "apps/core/lib/core/x.ex"),
        killed("b2", file: "apps/core/lib/core/other/y.ex"),
        killed("c3", file: "apps/web/lib/web/z.ex")
      ]
    }

    assert {:ok, [core, web]} =
             Record.render(run, ctx(%{records: gen_saas, slot: slot, existing: existing}))

    assert core.path == "apps/core/test/sabotage_records/DND-77-02-anchor-sabotage-run.md"
    assert web.path == "apps/web/test/sabotage_records/DND-77-01-anchor-sabotage-run.md"
    assert core.content =~ "a1 " and core.content =~ "b2 "
  end

  test "a name the naming cannot make is an error naming the file" do
    gen_saas = %{@anchor | naming: :ticket_nn_what}
    {:ok, slot} = RecordNaming.slot("feat/x")

    assert Record.render(run(), ctx(%{records: gen_saas, slot: slot})) ==
             {:error, {:no_ticket, "lib/anchor/domain/sabotage/calc.ex"}}
  end

  test "a crashed mutant (DND-5570) is listed as unmeasured and its kill-map row reads back" do
    crashed = %{
      mutant: mutant("ddd444", operator: :force_condition, variant: false),
      status: :crashed,
      killers: [],
      selection: {:mirror, ["test/anchor/domain/sabotage/calc_test.exs"]},
      reason: "test run crashed: killed by signal 9 (exit 137)",
      test_run: %TestRun{
        status: :crashed,
        total: 0,
        failures: [],
        exit_code: 137,
        output_head: ""
      }
    }

    run = %{run() | outcomes: run().outcomes ++ [crashed]}
    {:ok, [entry]} = Record.render(run, ctx())

    assert entry.content =~
             "- ddd444 Anchor.Domain.Sabotage.Calc.add/2 force_condition [false]: crashed " <>
               "(test run crashed: killed by signal 9 (exit 137))\n"

    assert KillMap.parse(entry.content) == {:ok, KillMap.rows(run.outcomes)}
  end

  test "6: changed tests [T1, T2] with T1 a killer: only T2 lacks a red" do
    {:ok, [entry]} = Record.render(run(), ctx())

    [_, lacking] = String.split(entry.content, "## Tests still lacking a red\n")
    [lacking, _] = String.split(lacking, "## Kill map")

    assert lacking =~ "calc_test.exs:12 \"test subtracts\""
    refute lacking =~ "calc_test.exs:4 "
  end

  describe "kills by timeout (DND-5653)" do
    @timeout_failure %{
      file: "test/anchor/domain/sabotage/calc_test.exs",
      line: 9,
      name: "test slow",
      text: "** (ExUnit.TimeoutError) test timed out after 2000ms. You can change the timeout:"
    }

    defp timed_out(id) do
      %{
        mutant: mutant(id, operator: :delete_statement, variant: nil),
        status: :timeout,
        killers: ["(test timeout) test/anchor/domain/sabotage/calc_test.exs:9 test slow"],
        selection: {:mirror, ["test/anchor/domain/sabotage/calc_test.exs"]},
        reason: nil,
        test_run: %TestRun{
          status: :failed,
          total: 3,
          failures: [@timeout_failure],
          exit_code: 2,
          output_head: ""
        }
      }
    end

    test "K1: a timeout kill has its own section, and its mutant section quotes the timeout" do
      run = %{run() | outcomes: run().outcomes ++ [timed_out("eee555")]}
      {:ok, [entry]} = Record.render(run, ctx())

      assert entry.content =~
               "## Kills by timeout\n\n- eee555 Anchor.Domain.Sabotage.Calc.add/2 delete_statement: " <>
                 "(test timeout) test/anchor/domain/sabotage/calc_test.exs:9 test slow. No assertion " <>
                 "failed: a hang the mutant caused, or a slow host\n"

      assert entry.content =~
               "test/anchor/domain/sabotage/calc_test.exs:9 test slow\n" <>
                 "** (ExUnit.TimeoutError) test timed out after 2000ms."

      assert KillMap.parse(entry.content) == {:ok, KillMap.rows(run.outcomes)}
    end

    test "K2: positive control: a run with no timeout kill says None. there" do
      {:ok, [entry]} = Record.render(run(), ctx())
      assert entry.content =~ "## Kills by timeout\n\nNone.\n"
    end
  end

  describe "the summary table (DND-5643)" do
    defp table_rows(content, heading) do
      [_before, after_heading] = String.split(content, heading <> "\n\n", parts: 2)

      after_heading
      |> String.split("\n")
      |> Enum.take_while(&String.starts_with?(&1, "|"))
      |> Enum.drop(2)
    end

    defp section_statuses(content, prefix) do
      for [_, id, status] <- Regex.scan(~r/^#{prefix} (\S+) .*: (\w+)$/m, content),
          do: {id, status}
    end

    defp row_statuses(rows) do
      for row <- rows do
        [id, _function, _mutation, status, _killers] =
          row |> String.trim("|") |> String.split(" | ") |> Enum.map(&String.trim/1)

        {id, status}
      end
    end

    test "S1: one row per mutant, before the sections, matching their count and statuses" do
      outcomes = [
        killed("aaa111"),
        survived("bbb222"),
        killed("ddd444", operator: :negate, variant: nil)
      ]

      {:ok, [entry]} = Record.render(%{run() | outcomes: outcomes}, ctx())

      [head, _rest] = String.split(entry.content, "## Mutants\n", parts: 2)

      assert head =~
               "## Summary\n\n| id | function | mutation | status | killers |\n|---|---|---|---|---|\n"

      rows = table_rows(entry.content, "## Summary")

      assert rows == [
               "| aaa111 | `Anchor.Domain.Sabotage.Calc.add/2` | return_input [0] | killed | 1 |",
               "| bbb222 | `Anchor.Domain.Sabotage.Calc.add/2` | delete_statement | survived | 0 |",
               "| ddd444 | `Anchor.Domain.Sabotage.Calc.add/2` | negate | killed | 1 |"
             ]

      assert row_statuses(rows) == section_statuses(entry.content, "###")
    end

    test "S2: an appended run's table is one level down and matches its sections" do
      existing = %{"test/sabotage_records" => ["sabotage-20261105-dnd_5484_records.md"]}
      {:ok, [entry]} = Record.render(run(), ctx(%{existing: existing}))

      rows = table_rows(entry.content, "### Summary")
      assert length(rows) == 2
      assert row_statuses(rows) == section_statuses(entry.content, "####")
    end

    test "S3: a pipe in a mutation text is escaped and a newline flattened, so a row keeps five cells" do
      outcome = killed("eee555", operator: :force_condition, variant: "a | b\nc")
      {:ok, [entry]} = Record.render(%{run() | outcomes: [outcome]}, ctx())

      assert table_rows(entry.content, "## Summary") == [
               "| eee555 | `Anchor.Domain.Sabotage.Calc.add/2` | force_condition [a \\| b c] | killed | 1 |"
             ]
    end

    test "S4: positive control: a run with no mutant says None. under the table's heading" do
      {:ok, [entry]} = Record.render(%{run() | outcomes: []}, ctx())
      assert entry.content =~ "## Summary\n\nNone.\n\n## Mutants\n"
    end
  end
end
