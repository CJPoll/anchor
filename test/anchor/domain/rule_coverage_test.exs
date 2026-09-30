defmodule Anchor.Domain.RuleCoverageTest do
  # DND-1290: which rules checked nothing in a run, decided from facts the run
  # already has. Pure Domain; the Manager wiring is tested in
  # `Anchor.Managers.LintTest`.
  #
  # Sabotage record: ../../sabotage_records/rule_coverage-20260929-dnd_1290_empty_relation_list.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.RuleCoverage

  @lib_a %{filename: "lib/a.ex", module_names: ["Elixir.App.A"], uses: []}
  @lib_b %{filename: "lib/b.ex", module_names: ["Elixir.App.B"], uses: [App.Base]}
  @unparsed %{filename: "lib/broken.ex", module_names: [], uses: [], parsed?: false}

  defp paths_rule(globs, extra \\ %{}),
    do: Map.merge(%{type: :must_use_module, paths: globs, recursive: false}, extra)

  describe "below_floor/2" do
    test "a rule selecting no file is below the default floor, with its count" do
      rule = paths_rule(["test/*.ex"])

      assert RuleCoverage.below_floor([rule], [@lib_a, @lib_b]) == [{rule, 0}]
    end

    test "a rule selecting at least its floor is not reported" do
      assert RuleCoverage.below_floor([paths_rule(["lib/*.ex"])], [@lib_a, @lib_b]) == []
    end

    test "min_files raises the floor" do
      rule = paths_rule(["lib/*.ex"], %{min_files: 3})

      assert RuleCoverage.below_floor([rule], [@lib_a, @lib_b]) == [{rule, 2}]
    end

    test "no files at all leaves every rule below its floor" do
      rule = paths_rule(["lib/*.ex"])

      assert RuleCoverage.below_floor([rule], []) == [{rule, 0}]
    end

    test "an unparseable file counts toward a paths rule only when its path matches" do
      assert RuleCoverage.below_floor([paths_rule(["lib/*.ex"])], [@unparsed]) == []

      rule = paths_rule(["test/*.ex"])
      assert RuleCoverage.below_floor([rule], [@unparsed]) == [{rule, 0}]
    end

    test "an unparseable file may be what a module-selector rule selects" do
      pattern_rule = %{type: :must_use_module, pattern: "App.Nope"}
      uses_rule = %{type: :must_use_module, uses_module: "App.Nope"}

      assert RuleCoverage.below_floor([pattern_rule, uses_rule], [@unparsed]) == []
    end

    test "a module-selector rule is counted by the parsed files it matches" do
      rule = %{type: :must_use_module, uses_module: "App.Base", min_files: 2}

      assert RuleCoverage.below_floor([rule], [@lib_a, @lib_b]) == [{rule, 1}]
    end
  end

  # DND-1269: an allowed caller no selected file defines is dead config that a
  # later module of that name would silently revive, so it is reported.
  # Sabotage record: ../../sabotage_records/rule_coverage-20260929-dnd_1269_allowed_callers.md
  describe "missing_allowed_callers/2" do
    @adapter %{
      filename: "lib/adapter.ex",
      module_names: ["Elixir.App.Adapter"],
      uses: [],
      defined_modules: [App.Adapter, String.Chars.App.Adapter]
    }
    @other %{
      filename: "lib/other.ex",
      module_names: ["Elixir.App.Other"],
      uses: [],
      defined_modules: [App.Other]
    }
    @test_file %{
      filename: "test/gone.ex",
      module_names: ["Elixir.App.Gone"],
      uses: [],
      defined_modules: [App.Gone]
    }

    defp dep_rule(allowed, globs \\ ["lib/*.ex"]) do
      %{type: :no_direct_dependency, paths: globs, recursive: false, allowed_callers: allowed}
    end

    test "a caller a selected file defines is not reported" do
      rule = dep_rule([App.Adapter])
      assert RuleCoverage.missing_allowed_callers([rule], [@adapter, @other]) == []
    end

    test "a caller no file defines is reported, with every missing entry in order" do
      rule = dep_rule([App.Renamed, App.Adapter, App.AlsoGone])

      assert RuleCoverage.missing_allowed_callers([rule], [@adapter, @other]) ==
               [{rule, [App.Renamed, App.AlsoGone]}]
    end

    test "a caller defined only in a file the rule does not select is reported" do
      rule = dep_rule([App.Gone])

      assert RuleCoverage.missing_allowed_callers([rule], [@adapter, @test_file]) ==
               [{rule, [App.Gone]}]
    end

    test "a defimpl module counts as defined" do
      rule = dep_rule([String.Chars.App.Adapter])
      assert RuleCoverage.missing_allowed_callers([rule], [@adapter]) == []
    end

    test "a rule with no allowed callers is never reported" do
      assert RuleCoverage.missing_allowed_callers([dep_rule([]), %{type: :x}], [@adapter]) == []
    end

    test "a rule that selects no file is left to the floor report" do
      assert RuleCoverage.missing_allowed_callers([dep_rule([App.Gone], ["x/*.ex"])], [@adapter]) ==
               []
    end

    test "a rule that may select an unparsed file is not reported (the parse failure is)" do
      rule = dep_rule([App.Gone])
      assert RuleCoverage.missing_allowed_callers([rule], [@adapter, @unparsed]) == []
    end
  end

  describe "min_files/1" do
    test "is the rule's min_files, or the default of 1" do
      assert RuleCoverage.min_files(%{min_files: 4}) == 4
      assert RuleCoverage.min_files(%{min_files: nil}) == 1
      assert RuleCoverage.min_files(%{}) == 1
      assert RuleCoverage.default_min_files() == 1
    end
  end

  describe "unchecked/2" do
    test "names the rules whose type is not enabled" do
      flow = %{type: :single_control_flow}
      dep = %{type: :no_direct_dependency}

      assert RuleCoverage.unchecked([flow, dep], [:no_direct_dependency]) == [flow]
      assert RuleCoverage.unchecked([flow, dep], []) == [flow, dep]
    end
  end
end
