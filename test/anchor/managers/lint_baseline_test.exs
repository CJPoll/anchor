defmodule Anchor.Managers.LintBaselineTest do
  # DND-5632: an ast rule's baseline, applied by the Lint Manager. The config
  # and the baseline file are Hammox doubles (`expect/3`, so each read
  # self-proves); the analyzer, selection and comparison are real.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5632, AB-R2 to AB-W): ../../sabotage_records/lint-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.Check.NoDependency
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  @root "/proj"
  @path ".anchor/baselines/pure.txt"

  @a """
  defmodule MyApp.A do
    def f, do: File.read("x")
    def g, do: IO.puts("x")
  end
  """

  @b """
  defmodule MyApp.B do
    def f, do: File.read("y")
  end
  """

  defp rule(extra \\ %{}) do
    Map.merge(
      %{
        type: :no_direct_dependency,
        id: "pure",
        pattern: "MyApp.*",
        forbidden_modules: [File, IO],
        baseline: @path
      },
      extra
    )
  end

  defp files(sources \\ [{@a, "lib/a.ex"}, {@b, "lib/b.ex"}]),
    do: Enum.map(sources, fn {source, name} -> SourceFile.parse(source, name) end)

  defp run(rules, source_files, opts \\ []) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: rules, path: ".anchor.yml"}} end)

    {:ok, results} =
      Lint.run(
        NoDependency,
        source_files,
        [],
        [config_loader: ConfigLoaderMock, baseline_store: BaselineStoreMock, root: @root] ++
          opts
      )

    results
  end

  defp expect_entries(entries) do
    expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, entries} end)
  end

  defp findings(results) do
    for {%SourceFile{filename: file}, violations} <- results,
        %Violation{} = v <- violations,
        do: {file, v.trigger, v.key}
  end

  defp config(results) do
    case List.keyfind(results, :config, 0) do
      {:config, violations} -> violations
      nil -> []
    end
  end

  describe "a baselined rule's findings" do
    test "positive control: every finding held, nothing printed" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/b.ex|File))
      results = run([rule()], files())

      assert findings(results) == []
      assert config(results) == []
    end

    test "each finding carries the rule's id and its key" do
      expect_entries([])
      results = run([rule()], files())

      assert Enum.sort(findings(results)) == [
               {"lib/a.ex", "File", "pure|lib/a.ex|File"},
               {"lib/a.ex", "IO", "pure|lib/a.ex|IO"},
               {"lib/b.ex", "File", "pure|lib/b.ex|File"}
             ]

      assert [%Violation{rule_id: "pure"} | _rest] =
               results |> Enum.flat_map(fn {_file, vs} -> vs end)
    end

    test "NEW: a finding no entry covers stands" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/b.ex|File))
      results = run([rule()], files())

      assert findings(results) == [{"lib/a.ex", "IO", "pure|lib/a.ex|IO"}]
      assert config(results) == []
    end

    test "STALE: an entry no finding consumes is a finding on the baseline path" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/b.ex|File pure|lib/b.ex|IO))
      results = run([rule()], files())

      assert findings(results) == []

      assert [%Violation{filename: @path, key: "pure|lib/b.ex|IO", enforcement: :enforce} = stale] =
               config(results)

      assert stale.message =~ "matches no finding (it was fixed)"
    end

    test "STALE takes the rule's enforcement: report" do
      expect_entries(~w(pure|lib/gone.ex|File))
      results = run([rule(%{enforcement: :report})], files([{@b, "lib/b.ex"}]))

      assert [%Violation{key: "pure|lib/gone.ex|File", enforcement: :report}] = config(results)
      assert [{"lib/b.ex", "File", "pure|lib/b.ex|File"}] = findings(results)
    end

    test "an absolute filename is keyed relative to the root" do
      expect_entries(~w(pure|lib/b.ex|File))

      assert run([rule()], files([{@b, "/proj/lib/b.ex"}])) |> findings() == []
    end
  end

  describe "a narrowed run (DND-5632)" do
    test "no false STALE for an entry on a file it did not read, and a note says so" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/b.ex|File))

      results =
        run([rule()], files([{@a, "lib/a.ex"}]), enforce_selection_floors: false)

      assert findings(results) == []

      assert [%Violation{filename: @path, enforcement: :report, message: message}] =
               config(results)

      assert message =~ "NOTE: 1 entry of #{@path} names a file this run did not read"
    end

    test "a narrowed run still fails STALE on a file it read" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/a.ex|IO))

      results = run([rule()], files([{@a, "lib/a.ex"}]), enforce_selection_floors: false)

      assert [%Violation{key: "pure|lib/a.ex|IO", enforcement: :enforce}] = config(results)
    end

    test "the same entry in a whole run is STALE" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/b.ex|File))

      results = run([rule()], files([{@a, "lib/a.ex"}]))

      assert [%Violation{key: "pure|lib/b.ex|File", enforcement: :enforce}] = config(results)
    end

    test "an entry on a file that does not parse is unjudged, never STALE" do
      expect_entries(~w(pure|lib/a.ex|File pure|lib/a.ex|IO pure|lib/bad.ex|File))

      results = run([rule()], files([{@a, "lib/a.ex"}, {"defmodule X do", "lib/bad.ex"}]))

      assert [%Violation{enforcement: :report, message: "NOTE: 1 entry" <> _rest}] =
               config(results)
    end
  end

  # The anchor.graph review (effects_match_bucket): the Manager no longer
  # reads the working directory itself; the caller names the root
  # (Check.Base passes File.cwd!()), and a run that needs it without one
  # says so instead of keying against wherever it happens to run.
  describe "the project root" do
    test "a baselined rule with no :root given raises, naming the option" do
      expect(ConfigLoaderMock, :load, fn ->
        {:ok, %Config{rules: [rule()], path: ".anchor.yml"}}
      end)

      assert_raise ArgumentError, ~r/:root/, fn ->
        Lint.run(NoDependency, files(), [], config_loader: ConfigLoaderMock)
      end
    end

    test "with no baselined rule, no root is needed" do
      expect(ConfigLoaderMock, :load, fn ->
        {:ok, %Config{rules: [Map.delete(rule(), :baseline)], path: ".anchor.yml"}}
      end)

      assert {:ok, _results} =
               Lint.run(NoDependency, files(), [], config_loader: ConfigLoaderMock)
    end
  end

  describe "a baseline the run cannot use" do
    test "unreadable: one fail-closed issue naming the writer, and every finding stands" do
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)
      results = run([rule()], files([{@b, "lib/b.ex"}]))

      assert findings(results) == [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]

      assert [%Violation{kind: :fail_closed, filename: @path, rule_id: "pure", message: message}] =
               config(results)

      assert message =~ "Fix: create it with mix anchor.baseline --write pure"
    end

    test "another rule's entry: one fail-closed issue, and every finding stands" do
      expect_entries(~w(pure|lib/b.ex|File other|lib/b.ex|File))
      results = run([rule()], files([{@b, "lib/b.ex"}]))

      assert findings(results) == [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
      assert [%Violation{kind: :fail_closed, message: message}] = config(results)
      assert message =~ ~s(holds "other|lib/b.ex|File", an entry of another rule)
    end
  end

  describe "beside rules with no baseline" do
    test "a rule with no baseline is not read, and its findings carry no key" do
      results = run([Map.delete(rule(), :baseline)], files([{@b, "lib/b.ex"}]))

      assert findings(results) == [{"lib/b.ex", "File", nil}]
    end

    test "a violation every pass makes once per file is printed once" do
      source = """
      defmodule MyApp.C do
        alias @target, as: T
        def g, do: T.go()
        def f, do: File.read("z")
      end
      """

      expect_entries(~w(pure|lib/c.ex|File))

      plain = %{
        type: :no_direct_dependency,
        id: "plain",
        pattern: "MyApp.*",
        forbidden_modules: [System]
      }

      results = run([plain, rule()], files([{source, "lib/c.ex"}]))
      [{_file, violations}] = Enum.reject(results, &match?({:config, _}, &1))

      unresolved = Enum.filter(violations, &(&1.message =~ "cannot statically resolve"))
      assert length(unresolved) == 1, inspect(violations)
      # The baselined rule's keyed copy is the one kept: it is NEW (its
      # baseline holds only File), and its key is what --write would write.
      assert [%Violation{key: "pure|lib/c.ex|alias"}] = unresolved
    end
  end

  # DND-5632 critic round 1: a finding two rules make is one finding, and the
  # baselined rule's keyed copy is still judged against its own baseline.
  describe "a finding two rules make" do
    @plain %{
      type: :no_direct_dependency,
      id: "plain",
      pattern: "MyApp.*",
      forbidden_modules: [File]
    }

    test "a report rule's copy never downgrades an enforced baselined rule's NEW finding" do
      expect_entries([])

      results =
        run([Map.put(@plain, :enforcement, :report), rule()], files([{@b, "lib/b.ex"}]))

      [{_file, violations}] = Enum.reject(results, &match?({:config, _}, &1))

      assert [%Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}] = violations
    end

    test "held by the baseline: the report rule's copy still prints, report-only; no STALE" do
      expect_entries(~w(pure|lib/b.ex|File))

      results =
        run([Map.put(@plain, :enforcement, :report), rule()], files([{@b, "lib/b.ex"}]))

      assert [{_file, [%Violation{enforcement: :report, key: nil}]}] = results
    end

    test "with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write)" do
      expect(BaselineStoreMock, :read, fn @root, @path -> {:error, :enoent} end)

      results =
        run(
          [Map.put(@plain, :enforcement, :report), rule(%{enforcement: :report})],
          files([{@b, "lib/b.ex"}])
        )

      assert [{"lib/b.ex", "File", "pure|lib/b.ex|File"}] = findings(results)
    end

    test "two baselined rules each judge their own copy: both held, no false STALE" do
      other = %{rule() | id: "other", baseline: ".anchor/baselines/other.txt"}

      expect(BaselineStoreMock, :read, fn @root, @path -> {:ok, ~w(pure|lib/b.ex|File)} end)

      expect(BaselineStoreMock, :read, fn @root, ".anchor/baselines/other.txt" ->
        {:ok, ~w(other|lib/b.ex|File)}
      end)

      assert [{_file, []}] = run([rule(), other], files([{@b, "lib/b.ex"}]))
    end

    test "an enforced plain rule's copy stands when the baselined rule holds its own" do
      expect_entries(~w(pure|lib/b.ex|File))

      assert [{_file, [%Violation{enforcement: :enforce, key: nil}]}] =
               run([@plain, rule()], files([{@b, "lib/b.ex"}]))
    end
  end
end
