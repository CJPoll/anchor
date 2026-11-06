defmodule Anchor.Domain.Aggregates.ConfigTest do
  # DND-5476: the `aggregates:` section of `.anchor.yml`. Pure Domain.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Config, as: AggregatesConfig
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.FunctionRef

  @entry %{
    "name" => "MyApp.Threads.ThreadSpace",
    "schemas" => ["MyApp.Threads.Thread", "MyApp.Threads.Message"],
    "tables" => ["thread_reads"],
    "owners" => ["MyApp.Threads.ThreadStore"]
  }

  @section %{
    "declare" => [@entry],
    "repos" => ["MyApp.Repo"],
    "write_functions" => ["MyApp.Repo.soft_delete/2"],
    "transaction_functions" => ["GenSaas.UnitOfWork.transaction/3"]
  }

  describe "parse/1" do
    test "C1: a full section parses every field as given" do
      assert {:ok, %AggregatesConfig{} = config} = AggregatesConfig.parse(@section)

      assert config.declare == [
               %Declaration{
                 name: "MyApp.Threads.ThreadSpace",
                 schemas: [MyApp.Threads.Thread, MyApp.Threads.Message],
                 tables: ["thread_reads"],
                 owners: [MyApp.Threads.ThreadStore],
                 sites: [:config]
               }
             ]

      assert config.repos == [MyApp.Repo]

      assert config.write_functions == [
               %FunctionRef{module: MyApp.Repo, function: :soft_delete, arity: 2}
             ]

      assert config.transaction_functions == [
               %FunctionRef{module: GenSaas.UnitOfWork, function: :transaction, arity: 3}
             ]

      assert_accepted(@section)
    end

    test "C2: a bare section (nil) and an empty mapping have no declarations" do
      assert {:ok, %AggregatesConfig{declare: [], repos: []}} = AggregatesConfig.parse(nil)
      assert {:ok, %AggregatesConfig{declare: []}} = AggregatesConfig.parse(%{})
    end

    test "an entry with only a name and tables defaults schemas and owners to []" do
      section = %{"declare" => [%{"name" => "A", "tables" => ["t"]}]}

      assert {:ok, %{declare: [%Declaration{name: "A", schemas: [], owners: [], tables: ["t"]}]}} =
               AggregatesConfig.parse(section)
    end

    # C3: one row per refused shape. Each must name the offending key path and
    # end its message with a Fix: that gives the conforming shape.
    @refused [
      {"not a map", ["MyApp.Space"], "aggregates must be a mapping"},
      {"an unknown top key", Map.put(@section, "declares", []),
       ~s[aggregates: unknown key(s) "declares"]},
      {"declare not a list", %{"declare" => @entry}, "aggregates.declare must be a list"},
      {"an entry not a map", %{"declare" => ["MyApp.Space"]},
       "aggregates.declare[1] must be a mapping"},
      {"an entry with no name", %{"declare" => [Map.delete(@entry, "name")]},
       "aggregates.declare[1] has no `name`"},
      {"an unknown entry key", %{"declare" => [Map.put(@entry, "owner", true)]},
       ~s{aggregates.declare[1]: unknown key(s) "owner"}},
      {"a lower-case name", %{"declare" => [Map.put(@entry, "name", "lower.case")]},
       ~s{aggregates.declare[1].name "lower.case" is not a module-name token}},
      {"an Elixir.-prefixed name", %{"declare" => [Map.put(@entry, "name", "Elixir.MyApp.S")]},
       ~s{aggregates.declare[1].name "Elixir.MyApp.S" is not a module-name token}},
      {"a name that is not a string", %{"declare" => [Map.put(@entry, "name", 3)]},
       "aggregates.declare[1].name 3 is not a module-name token"},
      {"schemas a string", %{"declare" => [Map.put(@entry, "schemas", "X")]},
       "aggregates.declare[1].schemas must be a list of exact module names"},
      {"a schema that is not a module",
       %{"declare" => [Map.put(@entry, "schemas", ["not a module"])]},
       ~s{aggregates.declare[1].schemas must be a list of exact module names: "not a module"}},
      {"a schema glob", %{"declare" => [Map.put(@entry, "schemas", ["MyApp.*"])]},
       "aggregates.declare[1].schemas must be a list of exact module names"},
      {"an owner that is not a module", %{"declare" => [Map.put(@entry, "owners", [":ets"])]},
       "aggregates.declare[1].owners must be a list of exact module names"},
      {"an empty table", %{"declare" => [Map.put(@entry, "tables", [""])]},
       "aggregates.declare[1].tables must be a list of non-empty table names"},
      {"tables a string", %{"declare" => [Map.put(@entry, "tables", "t")]},
       "aggregates.declare[1].tables must be a list of non-empty table names"},
      {"a duplicate name", %{"declare" => [@entry, Map.put(@entry, "schemas", [])]},
       ~s(aggregates.declare names "MyApp.Threads.ThreadSpace" more than once)},
      {"a malformed write function", Map.put(@section, "write_functions", ["bad"]),
       ~s(aggregates.write_functions: "bad" is not a function reference)},
      {"a malformed transaction function", Map.put(@section, "transaction_functions", [3]),
       "aggregates.transaction_functions: 3 is not a string"},
      {"write_functions not a list", Map.put(@section, "write_functions", "X.f/1"),
       "aggregates.write_functions: must be a list"},
      {"repos not module names", Map.put(@section, "repos", ["repo"]),
       "aggregates.repos must be a list of exact module names"},
      {"the second entry malformed", %{"declare" => [@entry, %{"name" => "B", "tables" => [1]}]},
       "aggregates.declare[2].tables"}
    ]

    for {label, section, expected} <- @refused do
      @tag section: section, expected: expected
      test "C3: refused: #{label}", %{section: section, expected: expected} do
        assert_refused(section, expected)
      end
    end
  end

  # DND-5659: `declare: none` with a required `reason:` says on purpose that
  # the repo persists nothing.
  describe "parse/1, declare: none" do
    @reason "Anchor reads beams and YAML; it has no database"

    test "Z1: none with a reason parses to a section with no declarations and that reason" do
      assert {:ok, %AggregatesConfig{none: @reason, declare: [], repos: []}} =
               AggregatesConfig.parse(%{"declare" => "none", "reason" => @reason})
    end

    test "Z1: a section without none has none: nil" do
      assert {:ok, %AggregatesConfig{none: nil}} = AggregatesConfig.parse(@section)
      assert {:ok, %AggregatesConfig{none: nil}} = AggregatesConfig.parse(nil)
    end

    @none_refused [
      {"an empty declare list", %{"declare" => []},
       "aggregates.declare is an empty list, which says nothing on purpose"},
      {"none without a reason", %{"declare" => "none"},
       "aggregates: declare: none needs a reason:"},
      {"none with an empty reason", %{"declare" => "none", "reason" => "  "},
       "aggregates: declare: none needs a reason:"},
      {"none with a reason that is not a string", %{"declare" => "none", "reason" => 3},
       "aggregates: declare: none needs a reason:"},
      {"a reason without none", %{"declare" => [@entry], "reason" => @reason},
       "aggregates.reason is only read with declare: none"},
      {"a reason with no declare", %{"reason" => @reason},
       "aggregates.reason is only read with declare: none"},
      {"none with repos", %{"declare" => "none", "reason" => @reason, "repos" => ["MyApp.Repo"]},
       ~s(aggregates: declare: none says nothing persists, but it also sets "repos")},
      {"none with write_functions",
       %{"declare" => "none", "reason" => @reason, "write_functions" => []},
       ~s(aggregates: declare: none says nothing persists, but it also sets "write_functions")},
      {"none with transaction_functions",
       %{"declare" => "none", "reason" => @reason, "transaction_functions" => ["X.t/1"]},
       ~s(aggregates: declare: none says nothing persists, but it also sets ) <>
         ~s("transaction_functions")},
      {"a declare string other than none", %{"declare" => "None", "reason" => @reason},
       "aggregates.declare must be a list of declarations or none"}
    ]

    for {label, section, expected} <- @none_refused do
      @tag section: section, expected: expected
      test "Z2: refused: #{label}", %{section: section, expected: expected} do
        assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
        assert String.starts_with?(message, expected), "got: #{message}"
        assert [_problem, fix] = String.split(message, ". Fix: ", parts: 2)
        assert fix =~ "declare: none"
      end
    end
  end

  describe "Anchor.Config.parse_config/1" do
    test "an aggregates section loads into :aggregates" do
      assert %Config{aggregates: %AggregatesConfig{declare: [%Declaration{}]}} =
               Config.parse_config(%{"rules" => [], "aggregates" => @section})
    end

    test "Z1: an aggregates: declare: none section loads with its reason" do
      assert %Config{aggregates: %AggregatesConfig{none: "no database"}} =
               Config.parse_config(%{
                 "rules" => [],
                 "aggregates" => %{"declare" => "none", "reason" => "no database"}
               })
    end

    test "no aggregates section is nil (no declarations), never an empty section" do
      assert %Config{aggregates: nil} = Config.parse_config(%{"rules" => []})
    end

    test "a malformed section fails the whole load with its Fix:" do
      assert {:error, {:invalid_config, message}} =
               Config.parse_config(%{"rules" => [], "aggregates" => %{"declare" => "x"}})

      assert message =~ "aggregates.declare must be a list"
      assert message =~ "Fix: "
    end
  end

  # The positive control runs through the same helper's acceptance branch.
  defp assert_accepted(section), do: assert({:ok, _config} = AggregatesConfig.parse(section))

  defp assert_refused(section, expected) do
    assert {:error, {:invalid_config, message}} = AggregatesConfig.parse(section)
    assert String.starts_with?(message, expected), "got: #{message}"
    assert [_problem, fix] = String.split(message, ". Fix: ", parts: 2)
    assert fix =~ "aggregates: declare: - name:" or fix =~ "Module.function"
  end
end
