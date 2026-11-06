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
  # Sabotage record (DND-5715): ../../sabotage_records/analyses_complete-20261106-dnd_5715_bucket_split.md
  # Sabotage record (DND-5632): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5447, DND-5454 rows): ../../sabotage_records/rule_schema-20261103-dnd_5447_graph_rules_c.md
  # The DND-1292 rows (glob metacharacters, the `***` match-all, `*?`):
  #   ../../sabotage_records/rule_schema-20260929-dnd_1292_glob_escape.md
  # The DND-1267 `forbidden_functions` rows:
  #   ../../sabotage_records/rule_schema-20260929-dnd_1267_forbidden_functions.md
  # The DND-1269 `allowed_callers` rows:
  #   ../../sabotage_records/rule_schema-20260929-dnd_1269_allowed_callers.md
  # The DND-5451 `pure_patterns`, DND-5452 `no_forwarding_function` and
  # DND-5453 `owned_namespaces` rows:
  #   ../../sabotage_records/rule_schema-20261103-dnd_5451_ast_batch.md
  # The DND-5441 rows (enforcement, ast baseline, the graph common keys):
  #   ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5476 (aggregate_declarations rows): ../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  # DND-5459 (aggregate_write_sources rows): ../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.RuleShapes

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
             ~w(forbidden_functions forbidden_modules forbidden_patterns)

    assert RuleSchema.relation_keys(:no_transitive_dependency) ==
             ~w(forbidden_modules forbidden_patterns)

    assert RuleSchema.relation_keys(:must_use_module) == ~w(required_modules)
  end

  test "two rules with the same id are refused, naming both positions" do
    rule = Map.put(base(:single_control_flow), "id", "style")

    assert {:error, {:invalid_rule, reason}} =
             Config.parse_config(%{"rules" => [rule, base(:case_on_bare_arg), rule]})

    assert reason =~ ~s(rules 1 and 3 share the id "style")
  end

  test "three rules sharing an id are named in one list" do
    rule = Map.put(base(:single_control_flow), "id", "style")

    assert {:error, {:invalid_rule, reason}} =
             Config.parse_config(%{"rules" => [rule, rule, base(:case_on_bare_arg), rule]})

    assert reason =~ ~s(rules 1, 2 and 4 share the id "style")
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
      # DND-1292: a regex metacharacter in a selector glob is a literal.
      {"positive: a paths glob with regex metacharacters (literal)",
       Map.put(base, "paths", ["lib/c++/(old)/**/*.ex"]), :accepted},
      {"positive: a pattern glob with regex metacharacters (literal)",
       Map.put(no_selector, "pattern", "*.Webs?.*"), :accepted},
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
       {:refused, "`id` must be a non-empty string"}},
      # DND-5441: report or enforce, on both engines.
      {"positive: enforcement: report", Map.put(base, "enforcement", "report"), :accepted},
      {"positive: enforcement: :enforce", Map.put(base, "enforcement", ":enforce"), :accepted},
      {"enforcement: warn (neither)", Map.put(base, "enforcement", "warn"),
       {:refused, "`enforcement` must be report or enforce"}},
      # DND-5632: an ast rule's Credo check compares its findings with its
      # baseline, under the same path rules as a graph rule's.
      {"positive: baseline with an id",
       Map.merge(base, %{"id" => "r", "baseline" => ".anchor/baselines/r.txt"}), :accepted},
      {"baseline without id (entries start with it)",
       Map.put(base, "baseline", ".anchor/baselines/r.txt"),
       {:refused, "`baseline` needs the rule's `id`"}},
      {"an absolute baseline path", Map.merge(base, %{"id" => "r", "baseline" => "/tmp/r.txt"}),
       {:refused, "must be a path relative to the project root with no `..`"}},
      {"bucket on an ast rule (a graph selector)", Map.put(base, "bucket", "domain"),
       {:refused, "`bucket` applies to graph rules only"}}
    ]
  end

  # DND-5441: the graph common keys (shared contract section 3.2), checked by
  # `RuleSchema.validate_common/4` with a graph rule type of no keys of its
  # own. Every graph rule type's table starts with these rows (through
  # `Config.parse_config/1`), once one ships.
  test "graph common keys: every rule that checks nothing is refused, the positive rows load" do
    failures =
      graph_common_rows()
      |> Enum.map(fn {label, rule, expected} ->
        result = RuleSchema.validate_common(rule, :graph, [], :a_graph_type)

        case {result, expected} do
          {:ok, :accepted} ->
            nil

          {{:error, reason}, {:refused, fragment}} ->
            unless reason =~ fragment, do: "#{label}: #{reason}"

          {other, _expected} ->
            "#{label}: #{inspect(other)}"
        end
      end)
      |> Enum.reject(&is_nil/1)

    assert failures == [], Enum.join(failures, "\n")
  end

  test "every graph common key has a row in graph_common_rows" do
    covered =
      Enum.flat_map(graph_common_rows(), fn {_label, rule, _expected} -> Map.keys(rule) end)

    for key <- RuleSchema.common_keys(:graph), do: assert(key in covered, key)
  end

  defp graph_common_rows do
    base = %{"type" => "a_graph_type", "bucket" => "domain"}
    no_selector = Map.delete(base, "bucket")

    [
      {"positive: a bucket selector", base, :accepted},
      {"positive: a paths selector (always recursive)",
       Map.put(no_selector, "paths", ["lib/**/*.ex"]), :accepted},
      {"positive: a pattern selector", Map.put(no_selector, "pattern", "MyApp.*"), :accepted},
      {"positive: min_modules, id, enforcement and baseline",
       Map.merge(base, %{
         "min_modules" => 3,
         "id" => "r",
         "enforcement" => "report",
         "baseline" => ".anchor/baselines/r.txt"
       }), :accepted},
      {"no selector", no_selector, {:refused, "no selector, so it would select no module"}},
      {"bucket and pattern (only bucket was read)", Map.put(base, "pattern", "MyApp.*"),
       {:refused, "more than one selector (bucket, pattern)"}},
      {"bucket that is not a string", Map.put(no_selector, "bucket", ["domain"]),
       {:refused, "`bucket` must be a non-empty string"}},
      {"an empty bucket", Map.put(no_selector, "bucket", ""),
       {:refused, "`bucket` must be a non-empty string"}},
      {"uses_module (an ast selector)", Map.put(base, "uses_module", "MyApp.Base"),
       {:refused, "`uses_module` applies to ast rules only"}},
      {"recursive (graph paths are always recursive)", Map.put(base, "recursive", true),
       {:refused, "unknown key \"recursive\""}},
      {"min_files (the graph floor is min_modules)", Map.put(base, "min_files", 2),
       {:refused, "did you mean \"min_modules\"?"}},
      {"min_modules: 0 (no floor)", Map.put(base, "min_modules", 0),
       {:refused, "`min_modules` must be a positive integer"}},
      {"min_modules that is not an integer", Map.put(base, "min_modules", "2"),
       {:refused, "`min_modules` must be a positive integer"}},
      {"an empty id", Map.put(base, "id", ""), {:refused, "`id` must be a non-empty string"}},
      {"enforcement: warn", Map.put(base, "enforcement", "warn"),
       {:refused, "`enforcement` must be report or enforce"}},
      {"baseline without id (entries start with it)",
       Map.put(base, "baseline", ".anchor/baselines/r.txt"),
       {:refused, "`baseline` needs the rule's `id`"}},
      {"an absolute baseline path", Map.merge(base, %{"id" => "r", "baseline" => "/tmp/r.txt"}),
       {:refused, "must be a path relative to the project root with no `..`"}},
      {"a baseline path climbing out", Map.merge(base, %{"id" => "r", "baseline" => "../x.txt"}),
       {:refused, "must be a path relative to the project root with no `..`"}},
      {"a baseline path with an inner ..",
       Map.merge(base, %{"id" => "r", "baseline" => ".anchor/../../x.txt"}),
       {:refused, "with no `..` segment"}},
      {"an empty baseline", Map.merge(base, %{"id" => "r", "baseline" => " "}),
       {:refused, "`baseline` must be a non-empty path"}}
    ]
  end

  defp table(type) when type in [:no_direct_dependency, :no_transitive_dependency] do
    no_relation = Map.drop(base(type), ~w(forbidden_modules forbidden_patterns))
    missing = missing_relation(type)

    common_rows(type) ++
      [
        {"positive: forbidden_patterns alone",
         Map.put(no_relation, "forbidden_patterns", ["*.Web.*"]), :accepted},
        # DND-1292: a regex metacharacter in a module glob is a literal.
        {"positive: forbidden_patterns with regex metacharacters (literal)",
         Map.put(no_relation, "forbidden_patterns", ["*.Webs?.*", "*.C++.*"]), :accepted},
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
        # DND-1292: after escaping, a glob of only wildcards is the one match-all.
        {"allowed_functions: [\"***\"] allows every function",
         Map.put(base, "allowed_functions", ["***"]),
         {:refused, "allows every function, so the rule checks nothing"}},
        # DND-1292: `*?` was a lazy regex match-all that loaded and checked
        # nothing. `?` is now a literal, so it allows the predicates only (the
        # matcher side is tested in the check's and GlobPattern's suites).
        {"positive: `*?` allows the predicates (a literal `?`)",
         Map.put(base, "allowed_functions", ["*?", "*!"]), :accepted},
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

  # DND-5451: `pure_patterns` widens what the rule reports (the stdlib pure set
  # applies without it), so it is not a relation. A match-all entry declares
  # every module pure, so every call would read as having no effect.
  defp table(:no_discarded_pure_expression) do
    base = base(:no_discarded_pure_expression)
    list = "`pure_patterns` must be a list of non-empty strings"
    match_all = "declares every module pure"

    common_rows(:no_discarded_pure_expression) ++
      [
        {"positive: pure_patterns", Map.put(base, "pure_patterns", ["MyApp.*.Domain.*"]),
         :accepted},
        {"positive: pure_patterns: [] (the stdlib pure set only)",
         Map.put(base, "pure_patterns", []), :accepted},
        {"pure_patterns that is a string", Map.put(base, "pure_patterns", "MyApp.*"),
         {:refused, list}},
        {"pure_patterns of empty strings", Map.put(base, "pure_patterns", [""]),
         {:refused, list}},
        {"pure_patterns of a non-string", Map.put(base, "pure_patterns", [1]), {:refused, list}},
        {"pure_patterns: [\"*\"] declares every module pure",
         Map.put(base, "pure_patterns", ["MyApp.*", "*"]), {:refused, match_all}},
        {"pure_patterns: [\"**\"] declares every module pure",
         Map.put(base, "pure_patterns", ["**"]), {:refused, match_all}},
        {"an unknown key (pure_modules)", Map.put(base, "pure_modules", ["MyApp.Calc"]),
         {:refused, ~s(unknown key "pure_modules" in a no_discarded_pure_expression rule)}}
      ]
  end

  # DND-5452: no key of its own, so any other key is unknown.
  defp table(:no_forwarding_function) do
    common_rows(:no_forwarding_function) ++
      [
        {"an unknown key (pure_patterns belongs to another type)",
         Map.put(base(:no_forwarding_function), "pure_patterns", ["MyApp.*"]),
         {:refused, ~s(unknown key "pure_patterns" in a no_forwarding_function rule)}}
      ]
  end

  # DND-5453: `owned_namespaces` narrows which structs are checked, so it is
  # not a relation. Each entry names one module exactly; `[]` checks nothing.
  defp table(:struct_owned_by_module) do
    base = base(:struct_owned_by_module)
    not_a_module = "is not an exact Elixir module name"

    common_rows(:struct_owned_by_module) ++
      [
        {"positive: owned_namespaces", Map.put(base, "owned_namespaces", ["App"]), :accepted},
        {"positive: nested namespaces", Map.put(base, "owned_namespaces", ["App", "Lib.Core"]),
         :accepted},
        {"owned_namespaces: [] checks no struct", Map.put(base, "owned_namespaces", []),
         {:refused, "`owned_namespaces: []` checks no struct"}},
        {"an owned_namespaces glob", Map.put(base, "owned_namespaces", ["App.*"]),
         {:refused, not_a_module}},
        {"an owned_namespaces Erlang module", Map.put(base, "owned_namespaces", [":app"]),
         {:refused, not_a_module}},
        {"an owned_namespaces empty string", Map.put(base, "owned_namespaces", [""]),
         {:refused, "`owned_namespaces` must be a list of non-empty strings"}},
        {"owned_namespaces that is a string", Map.put(base, "owned_namespaces", "App"),
         {:refused, "`owned_namespaces` must be a list of non-empty strings"}},
        {"a malformed owned_namespaces entry after a valid one",
         Map.put(base, "owned_namespaces", ["App", "app.core"]), {:refused, ~s("app.core")}}
      ]
  end

  # The types with no relation and no key of their own: they check every file
  # they select, so only the common rows apply.
  # DND-5442, DND-5445, DND-5447, DND-5476: the graph types, none reading a key of its own.
  # Their rows are the graph common rows, loaded through
  # `Config.parse_config/1` with an `architecture:` section (`parse_one/1`),
  # plus what only a whole document decides.
  defp table(type)
       when type in [
              :aggregate_declarations,
              :aggregate_write_sources,
              :layering,
              :context_acyclic,
              :effects_match_bucket
            ],
       do: graph_rows(type)

  # DND-5715: analyses_complete's three floors, each a positive integer like
  # `min_modules`; each is a positive control, so 0 would judge nothing.
  defp table(:analyses_complete) do
    base = %{"type" => "analyses_complete", "bucket" => "domain"}

    graph_rows(:analyses_complete) ++
      for key <- ~w(min_absent_parameters min_apply_sites min_functions),
          {label, value, expected} <- [
            {"positive: #{key}", 5, :accepted},
            {"#{key}: 0 (no floor)", 0, {:refused, "`#{key}` must be a positive integer"}},
            {"#{key} that is not an integer", "5",
             {:refused, "`#{key}` must be a positive integer"}}
          ],
          do: {label, Map.put(base, key, value), expected}
  end

  # DND-5454: the graph half of struct ownership reads the AST half's one
  # optional key, `owned_namespaces`, under the same rules.
  defp table(:struct_owned_by_module_flow) do
    base = %{"type" => "struct_owned_by_module_flow", "bucket" => "domain"}
    not_a_module = "is not an exact Elixir module name"

    graph_rows(:struct_owned_by_module_flow) ++
      [
        {"positive: owned_namespaces", Map.put(base, "owned_namespaces", ["App"]), :accepted},
        {"owned_namespaces: [] checks no struct", Map.put(base, "owned_namespaces", []),
         {:refused, "`owned_namespaces: []` checks no struct"}},
        {"an owned_namespaces glob", Map.put(base, "owned_namespaces", ["App.*"]),
         {:refused, not_a_module}},
        {"owned_namespaces that is a string", Map.put(base, "owned_namespaces", "App"),
         {:refused, "`owned_namespaces` must be a list of non-empty strings"}}
      ]
  end

  # DND-5443: interface's own key, `max_width`, a positive integer.
  defp table(:interface) do
    base = %{"type" => "interface", "bucket" => "domain"}

    graph_rows(:interface)
    |> Enum.concat([
      {"positive: max_width", Map.put(base, "max_width", 12), :accepted},
      {"max_width: 0 (fails every context with an interface)", Map.put(base, "max_width", 0),
       {:refused, "`max_width` must be a positive integer"}},
      {"max_width that is not an integer", Map.put(base, "max_width", "12"),
       {:refused, "`max_width` must be a positive integer"}}
    ])
  end

  defp table(type), do: common_rows(type)

  defp graph_rows(type) do
    name = Atom.to_string(type)
    base = %{"type" => name, "bucket" => "domain"}

    graph_common_rows()
    |> Enum.map(fn {label, rule, expected} ->
      {label, Map.put(rule, "type", name), expected}
    end)
    |> Enum.concat([
      {"a bucket naming no architecture bucket", Map.put(base, "bucket", "web"),
       {:refused, "`bucket: web` names no architecture: bucket"}},
      {"positive: a pattern rule with the architecture section",
       %{"type" => name, "pattern" => "MyApp.*"}, :accepted}
    ])
  end

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
    ] ++ forbidden_functions_rows() ++ allowed_callers_rows()
  end

  defp extra_rows(:no_transitive_dependency), do: []

  # DND-1267: `forbidden_functions` is a relation of `no_direct_dependency`
  # alone, so it satisfies the relation on its own, and every entry must name
  # exactly one function. The token grammar's full table is in
  # `Anchor.Domain.FunctionRefTest`; these rows prove the load refuses it.
  defp forbidden_functions_rows do
    no_relation = Map.drop(base(:no_direct_dependency), ~w(forbidden_modules forbidden_patterns))
    missing = missing_relation(:no_direct_dependency)
    malformed = "is not a function reference"

    [
      {"positive: forbidden_functions alone",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack.user_info"]), :accepted},
      {"positive: forbidden_functions with arities and an Erlang module",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack.user_info/2", ":ets.insert"]),
       :accepted},
      {"positive: an empty forbidden_functions beside forbidden_modules",
       Map.put(base(:no_direct_dependency), "forbidden_functions", []), :accepted},
      {"forbidden_functions: []", Map.put(no_relation, "forbidden_functions", []),
       {:refused, missing}},
      {"forbidden_functions of empty strings", Map.put(no_relation, "forbidden_functions", [""]),
       {:refused, "`forbidden_functions` must be a list of non-empty strings"}},
      {"forbidden_functions of blank strings",
       Map.put(no_relation, "forbidden_functions", ["  "]),
       {:refused, "`forbidden_functions` must be a list of non-empty strings"}},
      {"forbidden_functions that is a string",
       Map.put(no_relation, "forbidden_functions", "MyApp.Slack.user_info"),
       {:refused, "`forbidden_functions` must be a list of non-empty strings"}},
      {"a forbidden_functions nil entry (a bare `-` in YAML)",
       Map.put(no_relation, "forbidden_functions", [nil]),
       {:refused, "`forbidden_functions` must be a list of non-empty strings"}},
      {"a forbidden_functions entry naming a module only",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack"]), {:refused, malformed}},
      {"a forbidden_functions entry with a bad arity",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack.user_info/x"]),
       {:refused, malformed}},
      {"match on a rule with only forbidden_functions (nothing reads it)",
       Map.merge(no_relation, %{"forbidden_functions" => ["MyApp.Slack.f"], "match" => "call"}),
       {:refused, "`match` applies only to `forbidden_modules` and `forbidden_patterns`"}},
      {"positive: match beside forbidden_functions and forbidden_modules",
       Map.merge(base(:no_direct_dependency), %{
         "forbidden_functions" => ["MyApp.Slack.f"],
         "match" => "call"
       }), :accepted},
      {"a forbidden_functions glob (globs are forbidden_patterns' job)",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack.*"]), {:refused, malformed}},
      {"a malformed entry after a valid one",
       Map.put(no_relation, "forbidden_functions", ["MyApp.Slack.user_info", "slack.user_info"]),
       {:refused, ~s("slack.user_info")}},
      {"forbidden_functions on no_transitive_dependency (not its key)",
       Map.put(base(:no_transitive_dependency), "forbidden_functions", ["MyApp.Slack.f"]),
       {:refused, ~s(unknown key "forbidden_functions" in a no_transitive_dependency rule)}}
    ]
  end

  # DND-1269: `allowed_callers` narrows a rule, so it is not a relation, and
  # every entry must name exactly one Elixir module. A glob would widen the rule
  # to every module a later change gives a matching name (and `*` allows every
  # caller, so the rule checks nothing); an Erlang module is never defined in
  # Elixir source, so it could never be found. A listed caller that the run does
  # not find is the run-time report, tested in `Anchor.Domain.RuleCoverageTest`.
  defp allowed_callers_rows do
    base = base(:no_direct_dependency)
    no_relation = Map.drop(base, ~w(forbidden_modules forbidden_patterns))
    not_a_module = "is not a module name"
    glob = "is a glob"

    [
      {"positive: allowed_callers beside forbidden_modules",
       Map.put(base, "allowed_callers", ["MyApp.Adapter"]), :accepted},
      {"positive: allowed_callers beside forbidden_functions",
       Map.merge(no_relation, %{
         "forbidden_functions" => ["MyApp.Slack.user_info"],
         "allowed_callers" => ["MyApp.Adapter", "MyApp.Other.Adapter"]
       }), :accepted},
      {"positive: allowed_callers: [] (no caller exempt)", Map.put(base, "allowed_callers", []),
       :accepted},
      {"allowed_callers alone is no relation",
       Map.put(no_relation, "allowed_callers", ["MyApp.Adapter"]),
       {:refused, missing_relation(:no_direct_dependency)}},
      {"a match-all allowed_callers glob allows every caller, so the rule checks nothing",
       Map.put(base, "allowed_callers", ["*"]), {:refused, glob}},
      {"a ** allowed_callers glob allows every caller", Map.put(base, "allowed_callers", ["**"]),
       {:refused, glob}},
      {"an allowed_callers namespace glob widens with every new module",
       Map.put(base, "allowed_callers", ["MyApp.Adapters.*"]), {:refused, glob}},
      {"an allowed_callers Erlang module is never defined in source",
       Map.put(base, "allowed_callers", [":telemetry"]), {:refused, "an Erlang module"}},
      {"an allowed_callers entry that is not a module name",
       Map.put(base, "allowed_callers", ["my_app.adapter"]), {:refused, not_a_module}},
      {"an allowed_callers entry with an empty segment",
       Map.put(base, "allowed_callers", ["MyApp..Adapter"]), {:refused, not_a_module}},
      {"an allowed_callers entry naming a function",
       Map.put(base, "allowed_callers", ["MyApp.Adapter.call/1"]), {:refused, not_a_module}},
      {"a malformed allowed_callers entry after a valid one",
       Map.put(base, "allowed_callers", ["MyApp.Adapter", "MyApp.adapter"]),
       {:refused, ~s("MyApp.adapter")}},
      {"allowed_callers of empty strings", Map.put(base, "allowed_callers", [""]),
       {:refused, "`allowed_callers` must be a list of non-empty strings"}},
      {"allowed_callers that is a string", Map.put(base, "allowed_callers", "MyApp.Adapter"),
       {:refused, "`allowed_callers` must be a list of non-empty strings"}},
      {"an allowed_callers nil entry (a bare `-` in YAML)",
       Map.put(base, "allowed_callers", [nil]),
       {:refused, "`allowed_callers` must be a list of non-empty strings"}},
      {"allowed_callers on no_transitive_dependency (not its key)",
       Map.put(base(:no_transitive_dependency), "allowed_callers", ["MyApp.Adapter"]),
       {:refused, ~s(unknown key "allowed_callers" in a no_transitive_dependency rule)}}
    ]
  end

  defp missing_relation(:no_direct_dependency),
    do: "forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty"

  defp missing_relation(:no_transitive_dependency),
    do: "forbidden_modules and forbidden_patterns are missing or empty"

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
  defp parse_one(%{"type" => type} = rule) do
    Config.parse_config(document(rule, RuleSchema.engine(String.to_existing_atom(type))))
  rescue
    error -> {:raised, Exception.message(error) |> String.split("\n") |> hd()}
  end

  # A graph rule needs the `architecture:` section (DND-5441), so its rows
  # load beside one that has a `domain` bucket; a rule that reads the write
  # analysis needs an `aggregates:` section too (DND-5459).
  defp document(rule, :ast), do: %{"rules" => [rule]}

  defp document(%{"type" => type} = rule, :graph) do
    if RuleSchema.needs_aggregates?(String.to_existing_atom(type)),
      do: Map.put(graph_document(rule), "aggregates", %{"repos" => ["MyApp.Repo"]}),
      else: graph_document(rule)
  end

  defp graph_document(rule) do
    %{
      "rules" => [rule],
      "architecture" => %{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{"name" => "domain", "role" => "domain", "select" => [%{"paths" => ["lib/**"]}]}
        ],
        "calls" => %{"domain" => ["domain"]}
      }
    }
  end

  defp row_result({:raised, message}, _expected), do: "RAISED: #{message}"

  defp row_result(%Config{rules: [_rule]}, :accepted), do: nil
  defp row_result(result, :accepted), do: "refused: #{inspect(result)}"

  # DND-5446: the issue a refusal becomes carries exactly one `Fix:`.
  defp row_result({:error, {:invalid_rule, reason}}, {:refused, fragment}) do
    issue =
      Failures.config_violation({:config_load_failed, ".anchor.yml", {:invalid_rule, reason}})

    cond do
      not (reason =~ ~r/\Arule 1( \(id: "[^"]*"\))?: / and reason =~ fragment) ->
        "wrong reason (want #{inspect(fragment)}): #{reason}"

      RuleShapes.fix_count(issue.message) != 1 ->
        "the issue carries #{RuleShapes.fix_count(issue.message)} Fix: lines: #{issue.message}"

      true ->
        nil
    end
  end

  defp row_result(result, {:refused, _fragment}), do: "LOADED: #{inspect(result, limit: 4)}"
end
