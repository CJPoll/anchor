defmodule Anchor.Managers.AstBaselineTest do
  # DND-5632: `mix anchor.baseline`'s Manager. Every port is a Hammox double
  # (`expect/3`, so each call self-proves); the comparison is the real Domain.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.GitBaseMock
  alias Anchor.LintKeysMock
  alias Anchor.Managers.AstBaseline

  setup :verify_on_exit!

  @root "/proj"
  @path ".anchor/baselines/pure.txt"

  @rule %{
    type: :no_direct_dependency,
    id: "pure",
    index: 1,
    pattern: "MyApp.*",
    forbidden_modules: [File],
    baseline: @path
  }

  @deps [
    config_loader: ConfigLoaderMock,
    baseline_store: BaselineStoreMock,
    git_base: GitBaseMock,
    lint_keys: LintKeysMock
  ]

  defp config(rules),
    do:
      expect(ConfigLoaderMock, :load, fn ->
        {:ok, %Config{rules: rules, path: "/proj/.anchor.yml"}}
      end)

  defp messages(%{violations: violations}),
    do: Enum.map(violations, &{&1.filename, &1.enforcement, &1.message})

  describe "write/2" do
    test "creates the rule's baseline from its keys alone, sorted, and notes it (exit 0)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)

      expect(LintKeysMock, :keys, fn ->
        {:ok,
         %{
           keys: [
             {"pure", "pure|lib/b.ex|File"},
             {"other", "other|lib/a.ex|IO"},
             {"pure", "pure|lib/a.ex|File"},
             {"pure|x", "pure|x|lib/c.ex|File"}
           ],
           rule_ids: ["pure"]
         }}
      end)

      expect(BaselineStoreMock, :create, fn @root, @path, contents ->
        assert contents ==
                 "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"

        :ok
      end)

      report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)

      assert report.exit_code == 0
      assert [{@path, :report, "wrote 2 entries to " <> _rest}] = messages(report)
    end

    test "an existing file is refused before Credo runs (exit 2)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, []} end)

      report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)

      assert report.exit_code == 2
      assert [{@path, :enforce, message}] = messages(report)
      assert message =~ "mix anchor.baseline --write only creates"
    end

    test "a file created between the read and the write is refused (exit 2)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)

      expect(LintKeysMock, :keys, fn ->
        {:ok, %{keys: [], rule_ids: ["pure"]}}
      end)

      expect(BaselineStoreMock, :create, fn @root, @path, _contents -> {:error, :exists} end)

      assert %{exit_code: 2} = AstBaseline.write(%{root: @root, id: "pure"}, @deps)
    end

    test "a write that fails is an issue (exit 1)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)

      expect(LintKeysMock, :keys, fn ->
        {:ok, %{keys: [], rule_ids: ["pure"]}}
      end)

      expect(BaselineStoreMock, :create, fn @root, @path, _contents -> {:error, :eacces} end)

      report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)
      assert report.exit_code == 1
      assert [{@path, :enforce, "Anchor could not create " <> _rest}] = messages(report)
    end

    test "an id naming no ast rule with a baseline is refused (exit 2)" do
      for rules <- [[], [Map.delete(@rule, :baseline)], [%{@rule | type: :layering}]] do
        config(rules)

        report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)

        assert report.exit_code == 2, inspect(rules)
        assert [{_config, :enforce, message}] = messages(report)
        assert message =~ ~s(--write "pure" names no ast rule)
      end
    end

    test "a rule whose check Credo does not run writes nothing (exit 3)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)
      expect(LintKeysMock, :keys, fn -> {:ok, %{keys: [], rule_ids: ["other"]}} end)

      report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)

      assert report.exit_code == 3
      assert [{_config, :enforce, message}] = messages(report)
      assert message =~ "COULD NOT MEASURE"
      assert message =~ "no enabled Credo check reads no_direct_dependency"
    end

    test "Credo halting writes nothing (exit 3)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)
      expect(LintKeysMock, :keys, fn -> {:error, :halted} end)

      report = AstBaseline.write(%{root: @root, id: "pure"}, @deps)

      assert report.exit_code == 3
      assert [{_file, :enforce, "COULD NOT MEASURE" <> _rest}] = messages(report)
    end

    test "a config that does not load is COULD NOT MEASURE (exit 3)" do
      expect(ConfigLoaderMock, :load, fn ->
        {:error, {:config_not_found, ["/proj/.anchor.yml"]}}
      end)

      assert %{exit_code: 3, violations: [%Violation{kind: :fail_closed}]} =
               AstBaseline.write(%{root: @root, id: "pure"}, @deps)
    end
  end

  describe "grew/2" do
    test "positive control: the branch only removed entries (exit 0)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [@rule]} end)

      expect(GitBaseMock, :show, fn @root, "main", @path ->
        {:ok, ~w(pure|lib/a.ex|File pure|lib/b.ex|File)}
      end)

      assert %{exit_code: 0, violations: [], baselines: 1} =
               AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
    end

    test "GREW: an entry the branch added since the ref (exit 1)" do
      config([@rule])

      expect(BaselineStoreMock, :read, fn @root, @path ->
        {:ok, ~w(pure|lib/a.ex|File pure|lib/c.ex|File)}
      end)

      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [@rule]} end)
      expect(GitBaseMock, :show, fn @root, "main", @path -> {:ok, ~w(pure|lib/a.ex|File)} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)

      assert report.exit_code == 1

      assert [%Violation{filename: @path, key: "pure|lib/c.ex|File", enforcement: :enforce}] =
               report.violations
    end

    test "GREW takes the rule's enforcement: report (exit 0)" do
      rule = Map.put(@rule, :enforcement, :report)
      config([rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/c.ex|File)} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [rule]} end)
      expect(GitBaseMock, :show, fn @root, "main", @path -> {:ok, []} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)

      assert report.exit_code == 0
      assert [%Violation{key: "pure|lib/c.ex|File", enforcement: :report}] = report.violations
    end

    test "the base copy is found by the rule's id, at its path there" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)

      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" ->
        {:ok, [%{@rule | baseline: "old/pure.txt"}]}
      end)

      expect(GitBaseMock, :show, fn @root, "main", "old/pure.txt" ->
        {:ok, ~w(pure|lib/a.ex|File)}
      end)

      assert %{exit_code: 0, violations: []} =
               AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
    end

    test "a rule that had no baseline at the ref: every entry is GREW" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)

      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" ->
        {:ok, [Map.delete(@rule, :baseline)]}
      end)

      assert %{exit_code: 1, violations: [%Violation{key: "pure|lib/a.ex|File"}]} =
               AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
    end

    test "a rule id new since the ref, and a file absent there, are report-only notes" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, []} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
      assert report.exit_code == 0

      assert [{@path, :report, "NOTE: first landing of rule \"pure\"" <> _rest}] =
               messages(report)

      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [@rule]} end)
      expect(GitBaseMock, :show, fn @root, "main", @path -> {:error, :absent} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
      assert report.exit_code == 0
      assert [{@path, :report, "NOTE: first landing of " <> _rest}] = messages(report)
    end

    test "a base copy git cannot read is an issue, never no growth (exit 1)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/a.ex|File)} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [@rule]} end)
      expect(GitBaseMock, :show, fn @root, "main", @path -> {:error, {:git, 128, "bad"}} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
      assert report.exit_code == 1
      assert [{@path, :enforce, "Anchor could not read " <> _rest}] = messages(report)
    end

    test "a base config that does not load is one issue naming every rule (exit 1)" do
      other = %{@rule | id: "other", baseline: ".anchor/baselines/other.txt"}
      config([@rule, other])
      expect(BaselineStoreMock, :read, 2, fn @root, _path -> {:ok, []} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:error, {:yaml, "bad"}} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)

      assert report.exit_code == 1
      assert [{".anchor.yml", :enforce, message}] = messages(report)
      assert message =~ ~s(GREW could not be judged for rules "pure", "other")
    end

    test "a working baseline that cannot be read is an issue (exit 1)" do
      config([@rule])
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)
      expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:ok, [@rule]} end)

      report = AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
      assert report.exit_code == 1
      assert [{@path, :enforce, message}] = messages(report)
      assert message =~ "Fix: create it with mix anchor.baseline --write pure"
    end

    test "graph rules' baselines are mix anchor.graph's: not read here; no git when none is ast" do
      config([%{@rule | type: :layering}, Map.delete(@rule, :baseline)])

      assert %{exit_code: 0, violations: [], baselines: 0} =
               AstBaseline.grew(%{root: @root, ref: "main"}, @deps)
    end
  end
end
