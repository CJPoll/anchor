defmodule Anchor.Domain.RuleSchemaTest do
  # DND-1286: the keys a rule may carry, per rule type, and the selector every
  # rule needs. An unknown key inside a rule (`forbiden_patterns:`, `patern:`)
  # and a rule with no selector used to load and check less than they said, or
  # nothing, and read green. Both now fail the load. The code under test is pure
  # Domain; the one IO here is the README drift row, which reads README.md by a
  # path anchored on this file (not the cwd, which sync modules change).
  #
  # Sabotage record: ../../sabotage_records/rule_schema-20260929-dnd_1286_rule_key_allowlist.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.RuleSchema

  # One valid value for every documented key, so the positive case can build a
  # rule carrying all of a type's keys at once.
  @valid_values %{
    "allowed_callers" => ["MyApp.Adapter"],
    "allowed_functions" => ["new"],
    "context_depth" => 3,
    "forbidden_functions" => ["MyApp.Repo.insert/2"],
    "forbidden_modules" => ["MyApp.Repo"],
    "forbidden_patterns" => ["*.Adapters.*"],
    "id" => "r1",
    "match" => "call",
    "max_lines" => 200,
    "min_files" => 1,
    "mode" => "all",
    "paths" => ["lib/**/*.ex"],
    "pattern" => "*.Domain.*",
    "recursive" => true,
    "required_modules" => ["MyApp.Base"],
    "same_context" => true,
    "uses_module" => "MyApp.Base"
  }

  # A typo of a key the type really reads, per type. For a type that reads no
  # key of its own, the typo is of the `paths` selector.
  @typos %{
    alphabetized_functions: "mdoe",
    case_on_bare_arg: "pahts",
    max_file_length: "max_line",
    module_pattern_restrictions: "allowed_function",
    must_use_module: "require_modules",
    no_comparison_in_if: "pahts",
    no_direct_dependency: "forbiden_patterns",
    no_discarding_arrow_in_with: "pahts",
    no_transitive_dependency: "forbiden_modules",
    no_tuple_match_in_head: "pahts",
    single_control_flow: "pahts",
    struct_getter_convention: "pahts"
  }

  defp rule(type, extra \\ %{}) do
    Map.merge(%{"type" => Atom.to_string(type), "pattern" => "*.Domain.*"}, extra)
  end

  describe "an unknown key inside a rule" do
    test "a typo'd key fails the rule, for every rule type" do
      for type <- Config.rule_types() do
        typo = Map.fetch!(@typos, type)

        assert {:error, {:invalid_rule, reason}} =
                 Config.parse_rule(rule(type, %{typo => ["x"]})),
               "#{type}: #{inspect(typo)} loaded"

        assert reason =~ ~s(unknown key "#{typo}"), "#{type}: #{reason}"
        assert reason =~ "#{type}", "#{type}: #{reason}"
      end
    end

    test "the reason names every known key for the rule's type" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(rule(:no_direct_dependency, %{"forbiden_patterns" => ["*.X.*"]}))

      assert reason =~
               "known keys for no_direct_dependency: allowed_callers, context_depth, " <>
                 "forbidden_functions, " <>
                 "forbidden_modules, " <>
                 "forbidden_patterns, id, match, min_files, paths, pattern, recursive, " <>
                 "same_context, type, uses_module"
    end

    test "the reason suggests the key a near-miss spelling was meant to be" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(rule(:no_direct_dependency, %{"forbiden_patterns" => ["*.X.*"]}))

      assert reason =~ ~s(did you mean "forbidden_patterns"?)
    end

    # The miss case: a near-miss spelling of EVERY known key of EVERY type is
    # rejected. A key compared loosely (a prefix, a case fold, a stem) would let
    # one of these through.
    test "a near-miss spelling of every known key is rejected" do
      for type <- Config.rule_types(),
          key <- RuleSchema.known_keys(type),
          miss <- near_misses(key) do
        refute miss in RuleSchema.known_keys(type), "#{miss} is itself a known key"

        assert {:error, {:invalid_rule, reason}} =
                 Config.parse_rule(Map.put(rule(type), miss, "x")),
               "#{type}: near-miss #{inspect(miss)} of #{inspect(key)} loaded"

        assert reason =~ ~s("#{miss}")
      end
    end

    test "a key another rule type reads is unknown here, and the reason says where it belongs" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(rule(:no_transitive_dependency, %{"match" => "call"}))

      assert reason =~ ~s(unknown key "match")
      assert reason =~ "`match` applies to: no_direct_dependency"
    end

    test "same_context on a no_transitive_dependency rule is unknown, not silently ignored" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(
                 rule(:no_transitive_dependency, %{
                   "same_context" => true,
                   "forbidden_patterns" => ["*.X.*"]
                 })
               )

      assert reason =~ ~s(unknown key "same_context")
    end

    test "every unknown key in the rule is named, not only the first" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(rule(:must_use_module, %{"zeta" => 1, "alpha" => 2}))

      assert reason =~ ~s(unknown keys "alpha", "zeta")
    end

    test "a non-string key is unknown" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(rule(:must_use_module, %{1 => "x"}))

      assert reason =~ "unknown key 1"
    end

    test "parse_config names the rule's 1-based position" do
      data = %{
        "rules" => [
          rule(:must_use_module, %{"required_modules" => ["A"]}),
          rule(:must_use_module, %{"patern" => "*.X"})
        ]
      }

      assert {:error, {:invalid_rule, reason}} = Config.parse_config(data)
      assert reason =~ ~s(rule 2: unknown key "patern")
    end
  end

  describe "the positive case" do
    # DND-1290: a rule takes exactly one selector, so the rule carries `paths`
    # (and `recursive`, which reads it) and leaves out `pattern` and
    # `uses_module`, which the selector tests below cover one at a time.
    test "every documented key of every type is accepted" do
      for type <- Config.rule_types() do
        data =
          for key <- RuleSchema.known_keys(type),
              key not in ~w(type pattern uses_module),
              into: %{"type" => "#{type}"} do
            {key, Map.fetch!(@valid_values, key)}
          end

        assert %{type: ^type} = Config.parse_rule(data), "#{type} rejected #{inspect(data)}"
      end
    end

    test "every rule type accepts the common keys" do
      for type <- Config.rule_types() do
        assert ~w(id min_files paths pattern recursive type uses_module) --
                 RuleSchema.known_keys(type) == []
      end
    end

    # Drift guard: the allowlist has an entry for exactly the shipped rule types.
    test "the allowlist covers exactly the rule types of Anchor.checks/0" do
      check_types = Anchor.checks() |> Enum.map(& &1.rule_type()) |> Enum.sort()

      assert RuleSchema.rule_types() == check_types
    end

    # Doc drift guard: the README's per-type key table is the allowlist. A key
    # added to one without the other turns this red.
    test "the README lists exactly the keys each rule type accepts, and its relation" do
      rows = readme_rows()
      documented = Map.new(rows, fn {type, keys, relation} -> {type, {keys, relation}} end)

      # One row per type: a duplicated row fails here instead of being merged.
      assert rows |> Enum.map(&elem(&1, 0)) |> Enum.sort() == RuleSchema.rule_types()

      for type <- RuleSchema.rule_types() do
        {keys, relation} = documented[type]

        assert Enum.sort(keys ++ RuleSchema.common_keys()) == RuleSchema.known_keys(type),
               "README keys for #{type}"

        # DND-1290: the relation column is `@relations_by_type`.
        assert Enum.sort(relation) == RuleSchema.relation_keys(type),
               "README relation for #{type}"
      end
    end
  end

  describe "a rule with no selector" do
    test "fails for every rule type, naming the selector keys" do
      for type <- Config.rule_types() do
        assert {:error, {:invalid_rule, reason}} =
                 Config.parse_rule(%{"type" => Atom.to_string(type)}),
               "#{type} loaded with no selector"

        assert reason =~ "no selector", "#{type}: #{reason}"
        assert reason =~ "paths"
        assert reason =~ "pattern"
        assert reason =~ "uses_module"
      end
    end

    test "an explicit empty `paths` is no selector" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "paths" => []})

      assert reason =~ "no selector"
    end

    test "`recursive` alone is not a selector" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "recursive" => true})

      assert reason =~ "no selector"
    end

    test "each selector alone is enough" do
      for {key, value} <- [
            {"paths", ["lib/**/*.ex"]},
            {"pattern", "*.Domain.*"},
            {"uses_module", "MyApp.Base"}
          ] do
        assert %{type: :single_control_flow} =
                 Config.parse_rule(%{"type" => "single_control_flow", key => value})
      end
    end

    test "an empty `paths` beside a `pattern` still selects by the pattern" do
      assert %{pattern: "*.Domain.*"} =
               Config.parse_rule(%{
                 "type" => "single_control_flow",
                 "paths" => [],
                 "pattern" => "*.Domain.*"
               })
    end
  end

  describe "a malformed selector" do
    # Each of these used to be skipped by `RuleMatching.rule_matches_file?/2`'s
    # guards and select nothing.
    test "a `paths` that is a string, not a list, fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "paths" => "lib/a.ex"})

      assert reason =~ "`paths` must be a list of non-empty path-glob strings"
      assert reason =~ ~s("lib/a.ex")
    end

    test "a `paths` list holding a non-string fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "paths" => ["lib/a.ex", 1]})

      assert reason =~ "`paths` must be a list of non-empty path-glob strings"
    end

    # An empty glob matches no file, so `paths: [""]` selected nothing.
    test "a `paths` list holding an empty string fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "paths" => [""]})

      assert reason =~ "`paths` must be a list of non-empty path-glob strings"
    end

    test "a `pattern` that is not a string fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "pattern" => ["*.A"]})

      assert reason =~ "`pattern` must be a non-empty string"
    end

    test "an empty `uses_module` fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "single_control_flow", "uses_module" => ""})

      assert reason =~ "`uses_module` must be a non-empty string"
    end
  end

  # Near-miss spellings of a key: the last letter dropped, a letter doubled, a
  # letter added, and the first two letters swapped.
  defp near_misses(key) do
    [
      String.slice(key, 0..-2//1),
      key <> "s",
      String.slice(key, 0..0) <> key,
      String.at(key, 1) <> String.at(key, 0) <> String.slice(key, 2..-1//1)
    ]
    |> Enum.uniq()
    |> Enum.reject(&(&1 == key))
  end

  # The rows of the README table, in order, as `{type, keys, relation}`. Only
  # the table paragraph under the heading is read, and rows are kept as a list,
  # so a duplicated row is visible to the caller rather than merged into a map.
  defp readme_rows do
    [_before, section] =
      "../../../README.md"
      |> Path.expand(__DIR__)
      |> File.read!()
      |> String.split("#### Keys each rule type accepts\n", parts: 2)

    table = section |> String.split("\n\n") |> Enum.find(&String.starts_with?(&1, "| Rule type"))

    ~r/^\| `([a-z_]+)` \| ([^|]+) \| ([^|]+) \|$/m
    |> Regex.scan(table, capture: :all_but_first)
    |> Enum.map(fn [type, keys, relation] ->
      {String.to_existing_atom(type), backticked(keys), backticked(relation)}
    end)
  end

  defp backticked(cell) do
    ~r/`([a-z_]+)`/ |> Regex.scan(cell, capture: :all_but_first) |> List.flatten()
  end
end
