defmodule Anchor.Managers.SabotageScanTest do
  # DND-5490: `Anchor.Managers.Sabotage.run/2` as the nightly scan
  # (`scope: :all`, `shard`, `report`), every adapter doubled by Hammox
  # `expect/3`, which self-verifies: a call the test does not expect fails it,
  # so "no record written" is proven by not expecting `create`.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.Domain.Sabotage.Journal
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Plan
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.TestRun
  alias Anchor.GitWorktreeMock
  alias Anchor.Managers.Sabotage
  alias Anchor.RecordStoreMock
  alias Anchor.SourceMutationMock
  alias Anchor.SourceSourceMock
  alias Anchor.TestExecutionMock

  setup :verify_on_exit!

  setup do
    stub(SourceMutationMock, :take_lock, fn "/repo" -> :ok end)
    stub(SourceMutationMock, :release_lock, fn "/repo" -> :ok end)
    stub(RecordStoreMock, :list, fn "/repo", "test/sabotage_records" -> [] end)

    stub(Anchor.BaselineStoreMock, :read, fn "/repo", ".anchor/sabotage/survivors.txt" ->
      {:ok, []}
    end)

    stub(Anchor.GitBaseMock, :show, fn "/repo", _base, ".anchor/sabotage/survivors.txt" ->
      {:ok, []}
    end)

    :ok
  end

  @root "/repo"
  @file_path "/repo/lib/calc.ex"
  @source "defmodule Calc do\n  def add(a, b) do\n    a + b\n  end\nend\n"
  @facts %{
    root: @root,
    env: :test,
    build_path: "/builds/repo-test",
    base: "HEAD",
    max: :all,
    only: [],
    dry_run: false,
    no_record: true,
    scope: :all,
    report: "/tmp/scan/scan.md"
  }
  @opts [
    config_loader: ConfigLoaderMock,
    change_source: ChangeSourceMock,
    source_mutation: SourceMutationMock,
    git_worktree: GitWorktreeMock,
    test_execution: TestExecutionMock,
    record_store: RecordStoreMock,
    baseline_store: Anchor.BaselineStoreMock,
    git_base: Anchor.GitBaseMock,
    source_source: SourceSourceMock
  ]

  defp mutants do
    {:ok, %{mutants: mutants}} = Mutator.generate(@source, "lib/calc.ex", {Calc, :add, 2})
    Enum.sort_by(mutants, & &1.id)
  end

  defp test_run(status),
    do: {:ok, %TestRun{status: status, total: 1, failures: [], exit_code: 0, output_head: ""}}

  defp expect_until_selection(files \\ ["lib/calc.ex"]) do
    expect(SourceMutationMock, :read_journal, fn @root -> :none end)

    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %SabotageConfig{}}}
    end)

    expect(GitWorktreeMock, :ignored?, fn @root, ".anchor/sabotage/in-flight.json" ->
      {:ok, true}
    end)

    expect(SourceSourceMock, :list, fn @root -> files end)
  end

  defp expect_source(reads),
    do: expect(ChangeSourceMock, :read, reads, fn @root, "lib/calc.ex" -> {:ok, @source} end)

  defp expect_clean,
    do: expect(GitWorktreeMock, :dirty_paths, fn @root, ["lib/calc.ex"] -> {:ok, []} end)

  defp expect_tests_exist,
    do:
      expect(SourceMutationMock, :existing, fn ["/repo/test/calc_test.exs"] = paths -> paths end)

  defp expect_one_mutant_run(result) do
    expect(SourceMutationMock, :write_journal, fn @root, %Journal{} -> :ok end)
    expect(SourceMutationMock, :write_file, 2, fn @file_path, _bytes -> :ok end)
    expect(SourceMutationMock, :touch_ahead, 2, fn @file_path -> :ok end)
    expect(SourceMutationMock, :sha256_file, fn @file_path -> {:ok, Journal.sha256(@source)} end)
    expect(SourceMutationMock, :delete_journal, fn @root -> :ok end)

    expect(TestExecutionMock, :run, 2, fn _command, ["test/calc_test.exs"], _opts -> result.() end)
  end

  describe "run/2 as a scan" do
    test "1: one unlisted survivor: the report is written, no record, exit 0" do
      [mutant | _rest] = mutants()
      expect_until_selection()
      expect_source(2)
      expect_clean()
      expect_tests_exist()
      # The baseline passes, and so does the run with the mutant: it survived.
      expect_one_mutant_run(fn -> test_run(:passed) end)

      expect(RecordStoreMock, :write_report, fn @root, "/tmp/scan/scan.md", markdown, etf ->
        assert markdown =~ "## Findings: survivors not on the survivors list\n\n- `#{mutant.id}`"
        assert %{findings: [%{id: id}]} = :erlang.binary_to_term(etf)
        assert id == mutant.id
        {:ok, ["/tmp/scan/scan.md", "/tmp/scan/scan.etf"]}
      end)

      expect(SourceMutationMock, :save_run, fn _path, _bytes -> :ok end)

      # no_record false: the report alone keeps the record from being written.
      run = Sabotage.run(%{@facts | only: [mutant.id], no_record: false}, @opts)

      assert [%{status: :survived}] = run.outcomes
      assert run.report == ["/tmp/scan/scan.md", "/tmp/scan/scan.etf"]
      assert run.scan == %{report: "/tmp/scan/scan.md", shard: nil, coverage: nil}
      assert run.records == []
      assert Report.exit_code(run) == 0, Report.render(run)
    end

    test "2: zero functions in scope is COULD NOT MEASURE, exit 3, nothing applied" do
      expect_until_selection(["lib/empty.ex"])

      expect(ChangeSourceMock, :read, fn @root, "lib/empty.ex" ->
        {:ok, "defmodule Empty do\n  use GenServer\nend\n"}
      end)

      run = Sabotage.run(@facts, @opts)

      assert {3, message} = run.refusal
      assert message =~ "COULD NOT MEASURE: --scope all found no function"
      assert Report.exit_code(run) == 3
    end

    test "3: a failing baseline is exit 3, and no mutant is applied" do
      expect_until_selection()
      expect_source(2)
      expect_clean()
      expect_tests_exist()

      expect(TestExecutionMock, :run, fn _command, ["test/calc_test.exs"], _opts ->
        test_run(:failed)
      end)

      run = Sabotage.run(@facts, @opts)

      assert {3, message} = run.refusal
      assert message =~ "the selected tests fail with no mutant applied"
      assert run.outcomes == []
    end

    test "a shard keeps only the mutants of its id class; a dry run writes nothing" do
      {i, n} = {rem(String.to_integer(hd(mutants()).id, 16), 2), 2}
      {:ok, expected} = Plan.shard(mutants(), i, n)
      expect_until_selection()
      expect_source(2)
      expect_clean()
      expect_tests_exist()

      run = Sabotage.run(%{@facts | dry_run: true} |> Map.put(:shard, {i, n}), @opts)

      assert Enum.map(run.planned, fn {m, _selection} -> m.id end) ==
               Enum.map(
                 Enum.sort_by(expected, &{&1.file, &1.function, &1.operator, &1.id}),
                 & &1.id
               )

      assert length(run.planned) < length(mutants())
    end

    test "--shard auto is the day's shard of sabotage.scan_shards" do
      expect_until_selection()
      expect_source(2)
      expect_clean()
      expect_tests_exist()

      # The day whose shard holds the first mutant: days since 1970-01-01 mod 7
      # is its class.
      i = rem(String.to_integer(hd(mutants()).id, 16), 7)
      day = Date.add(~D[1970-01-01], 7 * 2900 + i)

      facts = %{@facts | dry_run: true} |> Map.put(:shard, {:auto, day})
      run = Sabotage.run(facts, @opts)

      {:ok, expected} = Plan.shard(mutants(), i, 7)
      assert expected != []

      assert Enum.sort(Enum.map(run.planned, fn {m, _s} -> m.id end)) ==
               Enum.sort(Enum.map(expected, & &1.id))
    end
  end
end
