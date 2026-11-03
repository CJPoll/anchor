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

    test "1: a function the map lists selects its tests as file:line, over the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:coverage, ["test/a_test.exs:10", "test/b_test.exs:4"]}
    end

    test "2: a function the map does not list falls back to the mirror" do
      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, @index)

      assert TestSelection.select(mutant("lib/x.ex", M, {:g, 0}), inputs) ==
               {:mirror, ["test/x_test.exs"]}
    end

    test "no map at all is the mirror, as before" do
      inputs = Map.put(inputs(["test/x_test.exs"]), :coverage, nil)

      assert TestSelection.select(mutant("lib/x.ex", M, {:f, 1}), inputs) ==
               {:mirror, ["test/x_test.exs"]}
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
