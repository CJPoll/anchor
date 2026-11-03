defmodule Anchor.Domain.Sabotage.TestSelectionTest do
  # DND-5473: which tests a mutant runs (this ticket: the mirror test file).
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Config
  alias Anchor.Domain.Sabotage.TestMirror
  alias Anchor.Domain.Sabotage.TestSelection

  @rules %Config{}.test_mirror

  defp mutant(file), do: %{file: file}

  defp inputs(existing), do: %{mirror: @rules, existing_tests: MapSet.new(existing)}

  describe "select/2" do
    test "1: an umbrella app file selects its app's mirror test" do
      assert TestSelection.select(
               mutant("apps/core/lib/core/a/b.ex"),
               inputs(["apps/core/test/core/a/b_test.exs", "test/x_test.exs"])
             ) == {:mirror, ["apps/core/test/core/a/b_test.exs"]}
    end

    test "2: a lib file selects test/<rest>_test.exs" do
      assert TestSelection.select(mutant("lib/x.ex"), inputs(["test/x_test.exs"])) ==
               {:mirror, ["test/x_test.exs"]}

      assert TestSelection.select(mutant("lib/a/b/c.ex"), inputs(["test/a/b/c_test.exs"])) ==
               {:mirror, ["test/a/b/c_test.exs"]}
    end

    test "3: a mirror target that does not exist selects nothing" do
      assert TestSelection.select(mutant("lib/x.ex"), inputs(["test/y_test.exs"])) ==
               {:none, []}
    end

    test "a file no rule matches selects nothing" do
      assert TestSelection.select(mutant("src/x.ex"), inputs(["test/x_test.exs"])) ==
               {:none, []}
    end
  end

  describe "select/2 with a coverage index (DND-5474)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
    defp mutant(file, module, function), do: %{file: file, module: module, function: function}

    @index %{"M.f/1" => ["test/a_test.exs:10", "test/b_test.exs:4"]}
    @ref_files ["test/a_test.exs", "test/b_test.exs"]

    test "1: a function the map lists selects its tests as file:line, over the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs" | @ref_files]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4"]}
    end

    test "2: a function the map does not list falls back to the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:g, 0}), inputs) ==
               {:mirror, ["test/x_test.exs"]}
    end

    test "a selected test file changed since the map was built runs whole, never by a stale line" do
      inputs =
        inputs(["test/x_test.exs" | @ref_files])
        |> Map.put(:coverage, @index)
        |> Map.put(:stale_tests, MapSet.new(["test/b_test.exs"]))

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:10", "test/b_test.exs"]}
    end

    test "a mirror file changed since the map was built is added whole: its new tests run" do
      inputs =
        inputs(["test/x_test.exs" | @ref_files])
        |> Map.put(:coverage, @index)
        |> Map.put(:stale_tests, MapSet.new(["test/x_test.exs"]))

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4", "test/x_test.exs"]}
    end

    test "when what changed is unknown (:all), every selected file runs whole, the mirror too" do
      inputs =
        inputs(["test/x_test.exs" | @ref_files])
        |> Map.put(:coverage, @index)
        |> Map.put(:stale_tests, :all)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs", "test/b_test.exs", "test/x_test.exs"]}
    end

    test "a ref whose file no longer exists is dropped; with none left, the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs", "test/a_test.exs"]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:10"]}

      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:mirror, ["test/x_test.exs"]}

      stale = Map.put(inputs, :stale_tests, :all)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), stale) ==
               {:mirror, ["test/x_test.exs"]}
    end

    test "coverage_files/2 names the test files a coverage selection could pass" do
      assert TestSelection.coverage_files(mutant("lib/x.ex", M, {:f, 1}), @index) ==
               ["test/a_test.exs", "test/b_test.exs"]

      assert TestSelection.coverage_files(mutant("lib/x.ex", M, {:g, 0}), @index) == []
      assert TestSelection.coverage_files(mutant("lib/x.ex", M, {:f, 1}), nil) == []
    end

    test "no map at all is the mirror, as before" do
      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, nil)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:mirror, ["test/x_test.exs"]}
    end
  end

  describe "select/2 with a kill map (DND-5484)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
    defp km_mutant(function), do: %{file: "lib/x.ex", module: M, function: function}

    @kill_map %{"M.f/1" => ["test/t1_test.exs"]}

    test "1: a function earlier records show killed selects its killers' files, and the mirror's" do
      inputs = Map.put(inputs(["test/x_test.exs", "test/t1_test.exs"]), :kill_map, @kill_map)

      assert TestSelection.select(km_mutant({:f, 1}), inputs) ==
               {:kill_map, ["test/t1_test.exs", "test/x_test.exs"]}

      # No mirror file: the killers alone.
      inputs = Map.put(inputs(["test/t1_test.exs"]), :kill_map, @kill_map)
      assert TestSelection.select(km_mutant({:f, 1}), inputs) == {:kill_map, ["test/t1_test.exs"]}
    end

    test "2: a function with no kill-map row falls back to the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs", "test/t1_test.exs"]), :kill_map, @kill_map)

      assert TestSelection.select(km_mutant({:g, 0}), inputs) == {:mirror, ["test/x_test.exs"]}
    end

    test "coverage comes first; a killer file that no longer exists is dropped" do
      inputs =
        inputs(["test/x_test.exs", "test/t1_test.exs", "test/a_test.exs"])
        |> Map.put(:kill_map, @kill_map)
        |> Map.put(:coverage, %{"M.f/1" => ["test/a_test.exs:3"]})

      assert TestSelection.select(km_mutant({:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:3"]}

      gone = Map.put(inputs(["test/x_test.exs"]), :kill_map, @kill_map)
      assert TestSelection.select(km_mutant({:f, 1}), gone) == {:mirror, ["test/x_test.exs"]}
    end
  end

  describe "select/2 checks every path it emits (DND-5640)" do
    # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5640_test_path.md
    # The inputs here skip the parse-time checks, as an index built some
    # other way would: the emit-time check alone must hold the argv.
    @bad ["--include_test.exs", "../outside_test.exs", "/abs/x_test.exs", "a/../b_test.exs"]

    test "a kill-map killer that is an option or outside the project is never selected" do
      inputs =
        inputs(["test/x_test.exs" | @bad])
        |> Map.put(:kill_map, %{"M.f/1" => @bad})

      assert TestSelection.select(%{file: "lib/x.ex", module: M, function: {:f, 1}}, inputs) ==
               {:mirror, ["test/x_test.exs"]}
    end

    test "a coverage ref that is an option or outside the project is never selected" do
      inputs =
        inputs(["test/x_test.exs" | @bad])
        |> Map.put(:coverage, %{"M.f/1" => Enum.map(@bad, &(&1 <> ":3"))})

      assert TestSelection.select(%{file: "lib/x.ex", module: M, function: {:f, 1}}, inputs) ==
               {:mirror, ["test/x_test.exs"]}
    end

    test "a mirror target outside the project is never selected" do
      rules = [%{from: "lib/**/*.ex", to: "../{rest}_test.exs"}]
      assert TestSelection.mirror_path(%{file: "lib/x.ex"}, rules) == "../x_test.exs"
      inputs = %{mirror: rules, existing_tests: MapSet.new(["../x_test.exs"])}

      assert TestSelection.select(%{file: "lib/x.ex"}, inputs) == {:none, []}
    end

    test "positive control: safe paths of each source are selected" do
      inputs =
        inputs(["test/x_test.exs", "test/k_test.exs"])
        |> Map.put(:kill_map, %{"M.f/1" => ["test/k_test.exs"]})

      assert TestSelection.select(%{file: "lib/x.ex", module: M, function: {:f, 1}}, inputs) ==
               {:kill_map, ["test/k_test.exs", "test/x_test.exs"]}
    end
  end

  describe "mirror_path/2" do
    test "names the path the mirror looked for, or nil" do
      assert TestSelection.mirror_path(mutant("lib/x.ex"), @rules) == "test/x_test.exs"
      assert TestSelection.mirror_path(mutant("src/x.ex"), @rules) == nil
    end
  end

  describe "TestMirror" do
    test "the first matching `from` wins: an umbrella path never falls to the lib rule" do
      assert TestMirror.first_target(@rules, "apps/core/lib/x.ex") == "apps/core/test/x_test.exs"
    end

    test "a literal segment must match exactly and the suffix must be there" do
      rule = %{from: "lib/**/*.ex", to: "test/{rest}_test.exs"}

      assert TestMirror.target(rule, "lib/x.exs") == nil
      assert TestMirror.target(rule, "libs/x.ex") == nil
      assert TestMirror.target(rule, "lib/.ex") == nil
      assert TestMirror.target(rule, "lib/x.ex") == "test/x_test.exs"
    end

    test "validate/2 refuses a partial wildcard, two `**`, and an unknown token" do
      assert {:from, _} = TestMirror.validate("lib/a*/*.ex", "test/{rest}")
      assert {:from, _} = TestMirror.validate("**/lib/**/*.ex", "test/{rest}")
      assert {:to, _} = TestMirror.validate("lib/**/*.ex", "test/{name}")
      assert :ok = TestMirror.validate("apps/*/lib/**/*.ex", "apps/{app}/test/{rest}")
    end
  end
end
