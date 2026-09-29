defmodule Anchor.Domain.RuleChecksNothingTest do
  # DND-1290: "a rule that loads but checks nothing", as one class. An unknown
  # type (DND-1265), an unknown key (DND-1286) and an empty relation list
  # (DND-1290) were found one at a time; this file enumerates the class per rule
  # type, so the next member is a missing row, not a missing ticket.
  #
  # ONE table per rule type (`table/1`). Every `:refused` row is a rule that
  # would load and check nothing (or check less than it says); it must fail the
  # load, and the reason must say why. Every `:accepted` row is a rule that
  # checks something and must load.
  #
  # Extension rule (enforced by "every key of every type has a row"): a new rule
  # key or rule type MUST add its rows to its type's table. That test fails
  # until it does.
  #
  # What load time cannot decide (a selector that matches zero files, a rule
  # whose check is not enabled) is the run-time floor, tested in
  # `Anchor.Managers.LintTest` and the e2e suite.
  #
  # Sabotage record: ../../sabotage_records/rule_schema-20260929-dnd_1290_empty_relation_list.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.RuleSchema

  # The relation each relation-bearing type checks, and a valid value for it.
  @relations %{
    must_use_module: %{"required_modules" => ["MyApp.Base"]},
    no_direct_dependency: %{"forbidden_modules" => ["MyApp.Repo"]},
    no_transitive_dependency: %{"forbidden_modules" => ["MyApp.Repo"]}
  }

  for type <- RuleSchema.rule_types() do
    @tag rule_type: type
    test "#{type}: every rule that checks nothing is refused, and the positive rows load",
         %{rule_type: type} do
      # Every row is checked, and every failing row is listed, so one run shows
      # the whole table's state rather than its first failure.
      failures = type |> table() |> Enum.map(&row_failure(type, &1)) |> Enum.reject(&is_nil/1)

      assert failures == [], Enum.join(failures, "\n")
    end
  end

  test "every key of every type has a row in that type's table" do
    for type <- RuleSchema.rule_types() do
      covered = type |> table() |> Enum.flat_map(fn row -> row |> elem(1) |> Map.keys() end)

      for key <- RuleSchema.known_keys(type) do
        assert key in covered,
               "#{type}: no row in table(#{inspect(type)}) carries #{inspect(key)}"
      end
    end
  end

  test "the relation keys of a type are keys that type accepts" do
    for type <- RuleSchema.rule_types(),
        key <- RuleSchema.relation_keys(type) do
      assert key in RuleSchema.known_keys(type), "#{type}: relation key #{key} is not accepted"
    end
  end

  test "exactly these types carry a relation" do
    with_relation = Enum.filter(RuleSchema.rule_types(), &(RuleSchema.relation_keys(&1) != []))

    assert with_relation == [:must_use_module, :no_direct_dependency, :no_transitive_dependency]

    assert RuleSchema.relation_keys(:no_direct_dependency) ==
             ~w(forbidden_modules forbidden_patterns)

    assert RuleSchema.relation_keys(:must_use_module) == ~w(required_modules)
  end

  test "two rules with the same id are refused, naming both positions" do
    rule = Map.put(base(:single_control_flow), "id", "style")

    assert {:error, {:invalid_rule, reason}} =
             Config.parse_config(%{"rules" => [rule, base(:case_on_bare_arg), rule]})

    assert reason =~ ~s(rules 1 and 3 share the id "style")
  end

  test "a refused rule with an id names the id beside its position" do
    rule = base(:must_use_module) |> Map.delete("required_modules") |> Map.put("id", "bases")

    assert {:error, {:invalid_rule, reason}} = Config.parse_config(%{"rules" => [rule]})
    assert reason =~ ~s|rule 1 (id: "bases"): |
  end

  test "a parsed rule carries its position, id and floor" do
    rule = base(:single_control_flow) |> Map.merge(%{"id" => "flow", "min_files" => 3})

    assert %Config{rules: [first, second]} =
             Config.parse_config(%{"rules" => [base(:case_on_bare_arg), rule]})

    assert %{index: 1, id: nil, min_files: 1} = first
    assert %{index: 2, id: "flow", min_files: 3} = second
  end

  # --- the tables ---------------------------------------------------------

  # Rows every type shares: the selector, `recursive`, `min_files` and `id`.
  defp common_rows(type) do
    base = base(type)
    no_selector = Map.drop(base, ~w(paths recursive))

    [
      {"positive: the base rule", base, :accepted},
      {"positive: a pattern selector", Map.put(no_selector, "pattern", "*.Domain.*"), :accepted},
      {"positive: a uses_module selector", Map.put(no_selector, "uses_module", "MyApp.Base"),
       :accepted},
      {"positive: paths: [] beside a pattern",
       Map.merge(no_selector, %{"paths" => [], "pattern" => "*.Domain.*"}), :accepted},
      {"positive: min_files and id", Map.merge(base, %{"min_files" => 2, "id" => "r"}),
       :accepted},
      {"no selector", no_selector, {:refused, "the rule has no selector"}},
      {"paths: [] alone", Map.put(no_selector, "paths", []), {:refused, "no selector"}},
      {"paths and pattern (only paths was read)", Map.put(base, "pattern", "*.Domain.*"),
       {:refused, "more than one selector (paths, pattern)"}},
      {"pattern and uses_module (only pattern was read)",
       Map.merge(no_selector, %{"pattern" => "*.Domain.*", "uses_module" => "MyApp.Base"}),
       {:refused, "more than one selector (pattern, uses_module)"}},
      {"recursive without paths (read by nothing)",
       Map.merge(no_selector, %{"pattern" => "*.Domain.*", "recursive" => true}),
       {:refused, "`recursive` applies only to `paths`"}},
      {"recursive that is not a boolean", Map.put(base, "recursive", "yes"),
       {:refused, "`recursive` must be true or false"}},
      {"min_files: 0 (no floor)", Map.put(base, "min_files", 0),
       {:refused, "`min_files` must be a positive integer"}},
      {"min_files that is not an integer", Map.put(base, "min_files", "2"),
       {:refused, "`min_files` must be a positive integer"}},
      {"an empty id", Map.put(base, "id", ""), {:refused, "`id` must be a non-empty string"}},
      {"an id that is not a string", Map.put(base, "id", 7),
       {:refused, "`id` must be a non-empty string"}}
    ]
  end

  defp table(type) when type in [:no_direct_dependency, :no_transitive_dependency] do
    no_relation = Map.drop(base(type), ~w(forbidden_modules forbidden_patterns))
    missing = "forbidden_modules and forbidden_patterns are missing or empty"

    common_rows(type) ++
      [
        {"positive: forbidden_patterns alone",
         Map.put(no_relation, "forbidden_patterns", ["*.Web.*"]), :accepted},
        {"positive: an empty forbidden_modules beside forbidden_patterns",
         Map.merge(no_relation, %{"forbidden_modules" => [], "forbidden_patterns" => ["*.W.*"]}),
         :accepted},
        {"no relation", no_relation, {:refused, missing}},
        {"forbidden_modules: []", Map.put(no_relation, "forbidden_modules", []),
         {:refused, missing}},
        {"forbidden_patterns: []", Map.put(no_relation, "forbidden_patterns", []),
         {:refused, missing}},
        {"both empty",
         Map.merge(no_relation, %{"forbidden_modules" => [], "forbidden_patterns" => []}),
         {:refused, missing}},
        {"forbidden_modules of empty strings", Map.put(no_relation, "forbidden_modules", [""]),
         {:refused, "`forbidden_modules` must be a list of non-empty strings"}},
        {"forbidden_modules of blank strings", Map.put(no_relation, "forbidden_modules", ["  "]),
         {:refused, "`forbidden_modules` must be a list of non-empty strings"}},
        {"forbidden_patterns of empty strings", Map.put(no_relation, "forbidden_patterns", [""]),
         {:refused, "`forbidden_patterns` must be a list of non-empty strings"}},
        {"forbidden_modules that is a string", Map.put(no_relation, "forbidden_modules", "A.B"),
         {:refused, "`forbidden_modules` must be a list of non-empty strings"}},
        {"a nil entry (a bare `-` in YAML)", Map.put(no_relation, "forbidden_modules", [nil]),
         {:refused, "`forbidden_modules` must be a list of non-empty strings"}}
      ] ++ extra_rows(type)
  end

  defp table(:must_use_module) do
    no_relation = Map.delete(base(:must_use_module), "required_modules")
    missing = "required_modules is missing or empty"

    common_rows(:must_use_module) ++
      [
        {"no relation", no_relation, {:refused, missing}},
        {"required_modules: []", Map.put(no_relation, "required_modules", []),
         {:refused, missing}},
        {"required_modules of empty strings", Map.put(no_relation, "required_modules", [""]),
         {:refused, "`required_modules` must be a list of non-empty strings"}},
        {"required_modules that is a string", Map.put(no_relation, "required_modules", "A"),
         {:refused, "`required_modules` must be a list of non-empty strings"}}
      ]
  end

  defp table(:module_pattern_restrictions) do
    base = base(:module_pattern_restrictions)

    common_rows(:module_pattern_restrictions) ++
      [
        # No allow-list forbids every function: it over-reports, loudly. It
        # checks something, so it loads (the example config documents it).
        {"positive: allowed_functions: [] (no function allowed)",
         Map.put(base, "allowed_functions", []), :accepted},
        {"positive: a name glob", Map.put(base, "allowed_functions", ["with_*", "new"]),
         :accepted},
        {"allowed_functions: [\"*\"] allows every function",
         Map.put(base, "allowed_functions", ["new", "*"]),
         {:refused, "allows every function, so the rule checks nothing"}},
        {"allowed_functions: [\"**\"] allows every function",
         Map.put(base, "allowed_functions", ["**"]),
         {:refused, "allows every function, so the rule checks nothing"}},
        {"allowed_functions that is a string", Map.put(base, "allowed_functions", "new"),
         {:refused, "`allowed_functions` must be a list of non-empty strings"}},
        {"allowed_functions of empty strings", Map.put(base, "allowed_functions", [""]),
         {:refused, "`allowed_functions` must be a list of non-empty strings"}}
      ]
  end

  defp table(:alphabetized_functions) do
    common_rows(:alphabetized_functions) ++
      for mode <- ~w(all public_only separate) do
        {"positive: mode #{mode}", Map.put(base(:alphabetized_functions), "mode", mode),
         :accepted}
      end
  end

  defp table(:max_file_length) do
    common_rows(:max_file_length) ++
      [
        {"positive: max_lines", Map.put(base(:max_file_length), "max_lines", 200), :accepted}
      ]
  end

  # The types with no relation and no key of their own: they check every file
  # they select, so only the common rows apply.
  defp table(type), do: common_rows(type)

  defp extra_rows(:no_direct_dependency) do
    base = base(:no_direct_dependency)

    [
      {"positive: match call", Map.put(base, "match", "call"), :accepted},
      {"positive: same_context with patterns and a depth",
       Map.merge(base, %{
         "forbidden_patterns" => ["*.Web.*"],
         "same_context" => true,
         "context_depth" => 3
       }), :accepted},
      {"same_context with nothing to scope", Map.put(base, "same_context", true),
       {:refused, "same_context: true requires forbidden_patterns"}}
    ]
  end

  defp extra_rows(:no_transitive_dependency), do: []

  defp base(type) do
    Map.merge(
      %{"type" => Atom.to_string(type), "paths" => ["lib/**/*.ex"], "recursive" => true},
      Map.get(@relations, type, %{})
    )
  end

  # `nil` when the row holds, else a line saying how it failed.
  defp row_failure(type, {label, rule, expected}) do
    rule
    |> parse_one()
    |> row_result(expected)
    |> then(&(&1 && "#{type} / #{label}: #{&1}"))
  end

  # A parser that raises is a row failure too, reported beside the others.
  defp parse_one(rule) do
    Config.parse_config(%{"rules" => [rule]})
  rescue
    error -> {:raised, Exception.message(error) |> String.split("\n") |> hd()}
  end

  defp row_result({:raised, message}, _expected), do: "RAISED: #{message}"

  defp row_result(%Config{rules: [_rule]}, :accepted), do: nil
  defp row_result(result, :accepted), do: "refused: #{inspect(result)}"

  defp row_result({:error, {:invalid_rule, reason}}, {:refused, fragment}) do
    if reason =~ "rule 1: " and reason =~ fragment,
      do: nil,
      else: "wrong reason (want #{inspect(fragment)}): #{reason}"
  end

  defp row_result(result, {:refused, _fragment}), do: "LOADED: #{inspect(result, limit: 4)}"
end
