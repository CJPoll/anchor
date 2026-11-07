defmodule Anchor.Managers.SabotageVerifyTest do
  # DND-5516: `Anchor.Managers.Sabotage.verify/2` with every port doubled by
  # Hammox `expect/3`, which self-verifies: a call the test does not expect
  # fails it. The test-run and mutation ports are handed in with no
  # expectation, so a verify that ran a test or wrote a mutant would fail
  # (AC6); the runner's tests prove those doubles fail on a call.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5516_verify.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Sabotage.Config, as: SabotageConfig
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Verify
  alias Anchor.GitBaseMock
  alias Anchor.Managers.Sabotage
  alias Anchor.RecordStoreMock

  setup :verify_on_exit!

  @root "/repo"
  @sha "abc123"
  @base "origin/main"
  @record "test/sabotage_records/calc-20261106-x.md"
  @survivors ".anchor/sabotage/survivors.txt"

  @source """
  defmodule Calc do
    def add(a, b) do
      a + b
    end
  end
  """

  @opts [
    config_loader: ConfigLoaderMock,
    change_source: ChangeSourceMock,
    record_store: RecordStoreMock,
    baseline_store: BaselineStoreMock,
    git_base: GitBaseMock,
    test_execution: Anchor.TestExecutionMock,
    source_mutation: Anchor.SourceMutationMock
  ]

  defp mutants do
    {:ok, %{mutants: mutants}} = Mutator.generate(@source, "lib/calc.ex", {Calc, :add, 2})
    mutants
  end

  defp record(mutants) do
    outcomes =
      Enum.map(
        mutants,
        &%{mutant: &1, status: :killed, killers: [{"test/calc_test.exs", 4, "test adds"}]}
      )

    "# record\n\n" <> KillMap.render_block(outcomes)
  end

  defp header(path, status) do
    case status do
      :added ->
        "diff --git a/#{path} b/#{path}\nnew file mode 100644\n--- /dev/null\n+++ b/#{path}\n"

      :modified ->
        "diff --git a/#{path} b/#{path}\nindex 1..2 100644\n--- a/#{path}\n+++ b/#{path}\n"

      :deleted ->
        "diff --git a/#{path} b/#{path}\ndeleted file mode 100644\n--- a/#{path}\n+++ /dev/null\n"
    end
  end

  defp source_diff, do: header("lib/calc.ex", :modified) <> "@@ -3 +3 @@\n-old\n+new\n"
  defp record_diff(status \\ :added, path \\ @record)
  defp record_diff(:added, path), do: header(path, :added) <> "@@ -0,0 +1 @@\n+x\n"
  defp record_diff(:deleted, path), do: header(path, :deleted) <> "@@ -1 +0,0 @@\n-x\n"

  defp expect_config(sabotage \\ %SabotageConfig{}) do
    expect(ConfigLoaderMock, :load_in, fn @root ->
      {:ok, %Anchor.Config{rules: [], sabotage: sabotage}}
    end)
  end

  defp expect_git(diff) do
    expect(ChangeSourceMock, :merge_base, fn @root, @base -> {:ok, @sha} end)
    expect(ChangeSourceMock, :diff, fn @root, @sha -> {:ok, diff} end)
    expect(ChangeSourceMock, :untracked, fn @root -> {:ok, []} end)
  end

  defp expect_source do
    # Once for the scope's spans, once for the mutants; once more at the base.
    expect(ChangeSourceMock, :read, 2, fn @root, "lib/calc.ex" -> {:ok, @source} end)
    expect(ChangeSourceMock, :show, fn @root, @sha, "lib/calc.ex" -> {:ok, @source} end)
  end

  defp expect_survivors(lines \\ [], base \\ []) do
    expect(BaselineStoreMock, :read, fn @root, @survivors -> {:ok, lines} end)
    expect(GitBaseMock, :show, fn @root, @base, @survivors -> {:ok, base} end)
  end

  defp verify, do: Sabotage.verify(%{root: @root, base: @base}, @opts)

  describe "verify/2" do
    test "1 and 2: it composes the ports and the Domain, and runs no test and no mutant" do
      expect_config()
      expect_git(source_diff() <> record_diff())
      expect_source()
      expect(RecordStoreMock, :read, fn @root, @record -> {:ok, record(mutants())} end)
      expect_survivors()

      assert {:ok, verdict} = verify()
      assert verdict.uncovered == []
      assert verdict.mutants == length(mutants()) and verdict.mutants > 0
      assert verdict.functions == 1
      assert Verify.exit_code(verdict) == 0
    end

    test "a record that covers one mutant fewer leaves it uncovered" do
      [dropped | kept] = mutants()
      expect_config()
      expect_git(source_diff() <> record_diff())
      expect_source()
      expect(RecordStoreMock, :read, fn @root, @record -> {:ok, record(kept)} end)
      expect_survivors()

      assert {:ok, verdict} = verify()
      assert Enum.map(verdict.uncovered, & &1.id) == [dropped.id]
    end

    test "DND-6031: a record in records.outside_apps_dir covers the branch's mutants" do
      outside = "tools/sabotage_records/calc-20261106-x.md"

      records = %{
        %SabotageConfig{}.records
        | dir: "apps/{app}/test/sabotage_records",
          outside_apps_dir: "tools/sabotage_records"
      }

      expect_config(%SabotageConfig{records: records})
      expect_git(source_diff() <> record_diff(:added, outside))
      expect_source()
      expect(RecordStoreMock, :read, fn @root, ^outside -> {:ok, record(mutants())} end)
      expect_survivors()

      assert {:ok, verdict} = verify()
      assert verdict.uncovered == []
      assert Verify.exit_code(verdict) == 0
    end

    test "3: no base is {:error, :no_base}, and nothing is read" do
      assert Sabotage.verify(%{root: @root}, @opts) == {:error, :no_base}
      assert Sabotage.verify(%{root: @root, base: ""}, @opts) == {:error, :no_base}
    end

    test "4: a ref with no merge-base is {:error, {:bad_ref, ref}}" do
      expect_config()

      expect(ChangeSourceMock, :merge_base, fn @root, @base ->
        {:error, {:no_merge_base, @base}}
      end)

      assert verify() == {:error, {:bad_ref, @base}}
    end

    test "any other scope failure is COULD NOT MEASURE" do
      expect_config()
      expect(ChangeSourceMock, :merge_base, fn @root, @base -> {:error, :not_a_work_tree} end)

      assert {:ok, verdict} = verify()
      assert verdict.could_not_measure =~ "COULD NOT MEASURE: /repo is not a git work tree"
      assert Verify.exit_code(verdict) == 3
    end

    test "no sabotage: section is COULD NOT MEASURE" do
      expect(ConfigLoaderMock, :load_in, fn @root ->
        {:ok, %Anchor.Config{rules: [], sabotage: nil}}
      end)

      assert {:ok, verdict} = verify()
      assert verdict.could_not_measure =~ "no sabotage: section"
    end

    test "5: a record that cannot be read is COULD NOT MEASURE" do
      expect_config()
      expect_git(source_diff() <> record_diff())
      expect_source()
      expect(RecordStoreMock, :read, fn @root, @record -> {:error, :eacces} end)

      assert {:ok, verdict} = verify()

      assert verdict.could_not_measure =~
               "the sabotage record #{@record} cannot be read (:eacces)"
    end

    test "6: changed source files with nothing found in them is COULD NOT MEASURE" do
      # An untracked file is wholly added with no hunk, so a file with no
      # function counts nothing.
      expect_config()
      expect(ChangeSourceMock, :merge_base, fn @root, @base -> {:ok, @sha} end)
      expect(ChangeSourceMock, :diff, fn @root, @sha -> {:ok, ""} end)
      expect(ChangeSourceMock, :untracked, fn @root -> {:ok, ["lib/empty.ex"]} end)

      expect(ChangeSourceMock, :read, fn @root, "lib/empty.ex" ->
        {:ok, "defmodule Empty do\nend\n"}
      end)

      assert {:ok, verdict} = verify()
      assert verdict.could_not_measure =~ "the diff changes 1 source files, but no function"
    end

    test "6 (control): a diff with no source file is a measured empty scope" do
      expect_config()
      expect_git(header("README.md", :modified) <> "@@ -1 +1 @@\n-a\n+b\n")
      expect_survivors()

      assert {:ok, verdict} = verify()
      assert verdict.could_not_measure == nil
      assert Verify.render(verdict, :text) == "sabotage verify: no changed functions"
    end

    test "7: a record whose kill map does not parse is named and covers nothing" do
      expect_config()
      expect_git(source_diff() <> record_diff())
      expect_source()

      expect(RecordStoreMock, :read, fn @root, @record ->
        {:ok, "```anchor-kills\nonly\ttwo\n```\n"}
      end)

      expect_survivors()

      assert {:ok, verdict} = verify()
      assert verdict.bad_records == [{@record, 2, "a row has 2 fields, not 6"}]
      assert length(verdict.uncovered) == length(mutants())
    end

    test "8: a landed record the branch deleted is RECORD REMOVED; it is not read" do
      expect_config()
      expect_git(record_diff(:deleted, "test/sabotage_records/old.md"))
      expect_survivors()

      assert {:ok, verdict} = verify()
      assert verdict.deleted_records == ["test/sabotage_records/old.md"]
      assert Verify.exit_code(verdict) == 1
    end

    test "a survivors entry covers its mutant, and the entry the branch added is shown" do
      [listed | killed] = mutants()

      line =
        "#{listed.id} lib/calc.ex Calc.add/2 #{listed.operator}  # equivalent: no test can see it"

      expect_config()
      expect_git(source_diff() <> record_diff())
      expect_source()
      expect(RecordStoreMock, :read, fn @root, @record -> {:ok, record(killed)} end)
      expect_survivors([line], [])

      assert {:ok, verdict} = verify()
      assert verdict.uncovered == []
      assert {listed.id, :survivor} in verdict.covered
      assert [%{id: id}] = verdict.survivors_added
      assert id == listed.id
    end

    test "a survivors file the config names that is absent is a bad survivor" do
      expect_config(%SabotageConfig{survivors: "survivors.txt"})
      expect_git("")
      expect(BaselineStoreMock, :read, fn @root, "survivors.txt" -> {:error, :enoent} end)
      expect(GitBaseMock, :show, fn @root, @base, "survivors.txt" -> {:error, :absent} end)

      assert {:ok, verdict} = verify()
      assert [{nil, message}] = verdict.bad_survivors
      assert message =~ "not found"
      assert Verify.exit_code(verdict) == 1
    end

    test "the default survivors file absent is an empty list" do
      expect_config()
      expect_git("")
      expect(BaselineStoreMock, :read, fn @root, @survivors -> {:error, :enoent} end)
      expect(GitBaseMock, :show, fn @root, @base, @survivors -> {:error, :absent} end)

      assert {:ok, verdict} = verify()
      assert verdict.bad_survivors == []
      assert Verify.exit_code(verdict) == 0
    end

    test "a survivors file, or its base copy, that cannot be read is COULD NOT MEASURE" do
      expect_config()
      expect_git("")
      expect(BaselineStoreMock, :read, fn @root, @survivors -> {:error, :eacces} end)

      assert {:ok, %{could_not_measure: message}} = verify()
      assert message =~ "the survivors file #{@survivors} cannot be read"

      expect_config()
      expect_git("")
      expect(BaselineStoreMock, :read, fn @root, @survivors -> {:ok, []} end)
      expect(GitBaseMock, :show, fn @root, @base, @survivors -> {:error, :bad_ref} end)

      assert {:ok, %{could_not_measure: message}} = verify()
      assert message =~ "cannot be read at origin/main"
    end
  end
end
