defmodule Anchor.Managers.SabotageBehavioursTest do
  # Manager tests for `Anchor.Managers.Sabotage.behaviours/2` (DND-5489): every port
  # doubled by Hammox, so a call the test does not expect fails it.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.CoverageStoreMock
  alias Anchor.Domain.Sabotage.Config
  alias Anchor.GitBaseMock
  alias Anchor.Managers.Sabotage
  alias Anchor.RecordStoreMock
  alias Anchor.SourceSourceMock

  setup :verify_on_exit!

  @opts [
    config_loader: ConfigLoaderMock,
    coverage_store: CoverageStoreMock,
    record_store: RecordStoreMock,
    source_source: SourceSourceMock,
    baseline_store: BaselineStoreMock,
    git_base: GitBaseMock
  ]
  @path ".anchor/baselines/behaviour-locality.txt"
  @key "test/t_test.exs::test t"
  @map %{
    version: 2,
    leaks: [],
    ambient: [],
    commit: nil,
    modules_traced: 2,
    tests: [
      %{
        file: "test/t_test.exs",
        line: 3,
        name: "test t",
        module: "TTest",
        functions: ["A.f/0", "B.g/0"]
      },
      %{file: "test/u_test.exs", line: 3, name: "test u", module: "UTest", functions: ["A.f/0"]}
    ]
  }
  @record """
  # r
  ```anchor-kills
  # id\tfile\tmfa\toperator\tstatus\tkillers
  a\tlib/a/a.ex\tA.f/0\top\tkilled\ttest/t_test.exs:9 test t
  b\tlib/b/b.ex\tB.g/0\top\tkilled\ttest/t_test.exs:9 test t
  ```
  """

  defp facts(overrides \\ %{}) do
    Map.merge(
      %{root: "/repo", coverage: "cov.etf", format: :text, write_baseline: false, base: nil},
      overrides
    )
  end

  defp config(overrides \\ %{}) do
    expect(ConfigLoaderMock, :load_in, fn "/repo" ->
      {:ok, %Anchor.Config{sabotage: struct!(Config, overrides)}}
    end)
  end

  defp coverage_read(result \\ {:ok, @map}) do
    expect(CoverageStoreMock, :read, fn "/repo/cov.etf" -> result end)
  end

  defp records(text \\ @record) do
    expect(RecordStoreMock, :list, fn "/repo", "test/sabotage_records" ->
      ["test/sabotage_records/r.md"]
    end)

    expect(RecordStoreMock, :read, fn "/repo", "test/sabotage_records/r.md" -> {:ok, text} end)
  end

  defp sources do
    expect(SourceSourceMock, :list, fn "/repo" -> ["lib/a/a.ex"] end)

    expect(SourceSourceMock, :read, fn "/repo", ["lib/a/a.ex"] ->
      %{"lib/a/a.ex" => %{defmodules: ["A"], uses: %{}, nonliteral_defmodule?: false}}
    end)
  end

  defp measured(overrides \\ %{}) do
    config(overrides)
    coverage_read()
    records()
    sources()
  end

  defp baseline(result, path \\ @path) do
    expect(BaselineStoreMock, :read, fn "/repo", ^path -> result end)
  end

  defp text(lines), do: Enum.join(lines, "\n")

  describe "what cannot be measured is exit 3, never a clean report" do
    test "no map given and none configured: the download Fix" do
      config()
      assert {3, [line]} = Sabotage.behaviours(facts(%{coverage: nil}), @opts)
      assert line =~ "no coverage map was given"
      assert line =~ "Fix: download a current anchor-coverage artifact (CI) and pass --coverage"
    end

    test "the configured map is used when none is given" do
      config(%{coverage_map: "cov.etf"})
      coverage_read({:error, :enoent})
      assert {3, [line]} = Sabotage.behaviours(facts(%{coverage: nil}), @opts)
      assert line =~ "the coverage map cov.etf cannot be read (:enoent)"
      assert line =~ "Fix: download a current anchor-coverage artifact (CI) and pass --coverage"
    end

    test "--coverage wins over the configured map" do
      config(%{coverage_map: "other.etf"})
      coverage_read({:error, :enoent})
      assert {3, [_line]} = Sabotage.behaviours(facts(), @opts)
    end

    test "a term that is no map" do
      config()
      coverage_read({:ok, :nope})
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "is not a usable coverage map (:not_a_map)"
    end

    test "a map with zero tests" do
      config()
      coverage_read({:ok, %{@map | tests: []}})
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "measured nothing (:no_tests)"
    end

    test "a map whose modules_traced is no count is refused, not a crash" do
      for bad <- [
            Map.delete(@map, :modules_traced),
            %{@map | modules_traced: "2"},
            %{@map | modules_traced: -1}
          ] do
        config()
        coverage_read({:ok, bad})
        assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
        assert line =~ "measured nothing (:no_modules)"
        assert line =~ "Fix: download a current anchor-coverage artifact (CI) and pass --coverage"
      end
    end

    test "a map with a test that has no name is refused, not a crash" do
      [first | rest] = @map.tests
      config()
      coverage_read({:ok, %{@map | tests: [Map.delete(first, :name) | rest]}})
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "names no test"
      assert line =~ "Fix: download a current anchor-coverage artifact (CI) and pass --coverage"
    end

    test "a map of an old version says so, and names no version of its own" do
      config()
      coverage_read({:ok, %{@map | version: 1}})
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "is not a usable coverage map ({:version, 1})"
    end

    test "no sabotage section" do
      expect(ConfigLoaderMock, :load_in, fn "/repo" -> {:ok, %Anchor.Config{sabotage: nil}} end)
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "no sabotage: section"
    end

    test "zero records" do
      config()
      coverage_read()
      expect(RecordStoreMock, :list, fn "/repo", _glob -> [] end)
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "nothing confirms any cause yet"
    end

    test "records with no killed row" do
      config()
      coverage_read()

      records(
        "```anchor-kills\n# id\tfile\tmfa\toperator\tstatus\tkillers\na\tlib/a.ex\tA.f/0\top\tsurvived\t\n```\n"
      )

      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "nothing confirms any cause yet"
    end

    test "a record that cannot be read names it" do
      config()
      coverage_read()
      expect(RecordStoreMock, :list, fn "/repo", _glob -> ["r.md"] end)
      expect(RecordStoreMock, :read, fn "/repo", "r.md" -> {:error, :eacces} end)
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "the record r.md cannot be read (:eacces)"
    end

    test "a record that cannot be parsed names it and the line" do
      config()
      coverage_read()
      records("```anchor-kills\nbad row\n```\n")
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "the record test/sabotage_records/r.md, line 2"
    end

    test "killed rows that confirm no behaviour: exit 3 in both modes, never clean" do
      gone = """
      ```anchor-kills
      # id\tfile\tmfa\toperator\tstatus\tkillers
      a\tlib/a/a.ex\tA.f/0\top\tkilled\ttest/gone_test.exs:1 test gone
      b\tlib/b/b.ex\tB.g/0\top\tkilled\ttest/u_test.exs:3 test u
      ```
      """

      for overrides <- [%{}, %{behaviour_locality_enforcement: :enforce}] do
        config(overrides)
        coverage_read()
        records(gone)
        sources()

        assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
        assert line =~ "COULD NOT MEASURE: nothing confirms any cause yet"
        assert line =~ "1 killers name no test of the map"
        assert line =~ "1 kills are of a function the map says their test never executed"
        assert line =~ "Fix: rebuild the map from the current tree"
      end
    end

    test "--write-baseline writes no empty ratchet when nothing confirms a behaviour" do
      config()
      coverage_read()

      records("""
      ```anchor-kills
      # id\tfile\tmfa\toperator\tstatus\tkillers
      a\tlib/a/a.ex\tA.f/0\top\tkilled\ttest/gone_test.exs:1 test gone
      ```
      """)

      sources()

      assert {3, [_line]} = Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
    end

    test "a baseline that cannot be read for another reason" do
      measured()
      baseline({:error, :outside_root})
      assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "cannot be read (:outside_root)"
    end

    test "a base that cannot be read is no growth it could vouch for" do
      measured()
      baseline({:ok, [@key, @key]})
      expect(GitBaseMock, :show, fn "/repo", "main", @path -> {:error, :bad_ref} end)
      assert {3, [line]} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
      assert line =~ "cannot be read at main (:bad_ref)"
    end
  end

  describe "the ratchet" do
    test "report mode, clean: exit 0 and the behaviours by width (positive control)" do
      measured()
      baseline({:ok, [@key, @key]})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      output = text(lines)
      assert output =~ "2\t#{@key}\tlib/a lib/b"
      assert output =~ "behaviours: 1 confirmed, 1 unconfirmed"
      assert output =~ "behaviour locality: clean against #{@path} (report mode)"
      refute output =~ "NEW"
    end

    test "report mode, one NEW: exit 0, printed" do
      measured()
      baseline({:ok, [@key]})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      output = text(lines)
      assert output =~ "NEW #{@key}: this behaviour reaches one more directory"
      assert output =~ "1 NEW, 0 STALE against #{@path} (report mode, not failing)"
    end

    test "enforce mode, one NEW: exit 1" do
      measured(%{behaviour_locality_enforcement: :enforce})
      baseline({:ok, [@key]})

      assert {1, lines} = Sabotage.behaviours(facts(), @opts)
      assert text(lines) =~ "behaviour locality: FAILED, 1 NEW, 0 STALE"
    end

    test "enforce mode, one STALE: exit 1" do
      measured(%{behaviour_locality_enforcement: :enforce})
      baseline({:ok, [@key, @key, @key]})

      assert {1, lines} = Sabotage.behaviours(facts(), @opts)
      assert text(lines) =~ "STALE #{@key}: this behaviour reaches one fewer directory"
    end

    test "enforce mode, clean: exit 0" do
      measured(%{behaviour_locality_enforcement: :enforce})
      baseline({:ok, [@key, @key]})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      assert text(lines) =~ "clean against #{@path} (enforce mode)"
    end

    test "enforce mode, an entry the branch added: GREW, exit 1" do
      measured(%{behaviour_locality_enforcement: :enforce})
      baseline({:ok, [@key, @key]})
      expect(GitBaseMock, :show, fn "/repo", "main", @path -> {:ok, [@key]} end)

      assert {1, lines} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
      output = text(lines)
      assert output =~ "GREW #{@key}: added to the baseline since main"
      assert output =~ "0 NEW, 0 STALE, 1 GREW"
    end

    test "a first landing has no base copy, so nothing grew" do
      measured(%{behaviour_locality_enforcement: :enforce})
      baseline({:ok, [@key, @key]})
      expect(GitBaseMock, :show, fn "/repo", "main", @path -> {:error, :absent} end)

      assert {0, _lines} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
    end

    test "the default path absent: every key is NEW, said loudly" do
      measured()
      baseline({:error, :enoent})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      output = text(lines)
      assert output =~ "no baseline at #{@path}: every locality key is NEW"
      assert output =~ "2 NEW, 0 STALE"
    end

    test "a named baseline absent: exit 1, in report mode too" do
      measured(%{behaviour_locality_baseline: "named.txt"})
      baseline({:error, :enoent}, "named.txt")

      assert {1, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "baseline named.txt not found. Fix:"
    end

    test "a malformed baseline: exit 1, in report mode too" do
      measured()
      baseline({:ok, ["no key here"]})

      assert {1, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ ~s|baseline #{@path} is malformed: "no key here"|
    end

    test "a baseline that is not UTF-8: exit 1" do
      measured()
      baseline({:error, {:line, 4, :invalid_utf8}})

      assert {1, [line]} = Sabotage.behaviours(facts(), @opts)
      assert line =~ "line 4 is not UTF-8"
    end
  end

  describe "--write-baseline" do
    test "no file: created with the sorted keys" do
      measured()

      expect(BaselineStoreMock, :create, fn "/repo", @path, contents ->
        assert contents ==
                 "# anchor baseline for behaviour-locality; shrink only\n#{@key}\n#{@key}\n"

        :ok
      end)

      assert {0, ["behaviour locality: wrote #{@path} with 2 entries"]} ==
               Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
    end

    test "an existing file: exit 2, left as it is" do
      measured()
      expect(BaselineStoreMock, :create, fn "/repo", @path, _contents -> {:error, :exists} end)

      assert {2, [line]} = Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
      assert line =~ "already exists and was left as it is"
    end

    test "a path it cannot write: exit 3" do
      measured()
      expect(BaselineStoreMock, :create, fn "/repo", @path, _contents -> {:error, :eacces} end)

      assert {3, [line]} = Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
      assert line =~ "cannot be written (:eacces)"
    end
  end

  describe "the views" do
    test "json says the whole picture" do
      measured()
      baseline({:ok, [@key]})

      assert {0, [json]} = Sabotage.behaviours(facts(%{format: :json}), @opts)

      assert %{
               "mode" => "report",
               "baseline" => @path,
               "new" => [@key],
               "stale" => [],
               "grew" => nil,
               "failed" => false,
               "unconfirmed" => ["test/u_test.exs::test u"],
               "behaviours" => [
                 %{
                   "test" => @key,
                   "directories" => ["lib/a", "lib/b"],
                   "confirmed" => ["A.f/0", "B.g/0"]
                 }
               ]
             } = JSON.decode!(json)
    end

    test "killers and sources that did not line up are said" do
      config()
      coverage_read()

      records(
        @record <>
          "```anchor-kills\n# id\tfile\tmfa\toperator\tstatus\tkillers\nc\tlib/c.ex\tC.h/0\top\tkilled\ttest/gone_test.exs:1 test gone\nd\tlib/d.ex\tD.i/0\top\tkilled\ttest/u_test.exs:3 test u\n```\n"
      )

      expect(SourceSourceMock, :list, fn "/repo" -> ["lib/broken.ex"] end)

      expect(SourceSourceMock, :read, fn "/repo", ["lib/broken.ex"] ->
        %{"lib/broken.ex" => {:error, :unparseable}}
      end)

      baseline({:ok, [@key, @key]})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      output = text(lines)
      assert output =~ "1 source files could not be read (first: lib/broken.ex)"
      assert output =~ "1 killers name no test of the map"
      assert output =~ "first: test/gone_test.exs::test gone"
      assert output =~ "1 kills are of a function the map says their test never executed"
    end

    test "a confirmed cause with no source shows generated on its line" do
      config()
      coverage_read()

      records(
        "```anchor-kills\n# id\tfile\tmfa\toperator\tstatus\tkillers\na\t\tA.f/0\top\tkilled\ttest/t_test.exs:1 test t\n```\n"
      )

      expect(SourceSourceMock, :list, fn "/repo" -> [] end)
      expect(SourceSourceMock, :read, fn "/repo", [] -> %{} end)
      baseline({:ok, []})

      assert {0, lines} = Sabotage.behaviours(facts(), @opts)
      assert text(lines) =~ "0\t#{@key}\t\t(generated) A.f/0"
    end
  end
end
