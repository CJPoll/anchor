defmodule Anchor.Domain.RuleSchema do
  @moduledoc """
  What a rule must carry to check something: the keys it may carry, per rule
  type, the one selector every rule needs, and the relation a relation-bearing
  type needs — a **Domain** module (ADR 001). Pure: it inspects a decoded rule
  map (string keys) and does no IO.

  ## The class: a rule that loads but checks nothing

  A rule that loads but checks nothing reads the same as a rule that found
  nothing: green. DND-1265 (an unknown type), DND-1286 (an unknown key, no
  selector) and DND-1290 (an empty relation, and the rest of the class) each
  closed part of it. `validate/2` refuses every member load time can decide, and
  `Anchor.Config.parse_rule/1` fails the load with the reason, through
  `Anchor.Domain.Failures`:

    * a key the rule's type does not read (a typo, or another type's key);
    * no selector, a selector of the wrong shape, or **more than one** selector
      (`Anchor.Domain.RuleMatching` reads only the first of `paths`, `pattern`,
      `uses_module`, so a second one was silently ignored);
    * `recursive` without `paths` (nothing reads it), or not a boolean;
    * `match` on a `no_direct_dependency` rule with neither `forbidden_modules`
      nor `forbidden_patterns` (DND-1267): `forbidden_functions` is matched in
      every call shape whatever `match` says, so nothing reads it;
    * a `min_files` that is not a positive integer (a floor of 0 is no floor),
      or an `id` that is not a non-empty string;
    * a relation list of the wrong shape: not a list, or holding an entry that
      is not a non-blank string (`forbidden_modules: [""]`, a bare `-`);
    * a `forbidden_functions` entry that does not name exactly one function
      (`"MyApp.Repo"`, `"MyApp.Repo.*"`, `"MyApp.Repo.insert/x"`), per
      `Anchor.Domain.FunctionRef`'s grammar (DND-1267);
    * an `allowed_callers` entry that is not exactly one Elixir module name: a
      glob (`"*"` allows every caller, so the rule checks nothing; any other
      glob widens it with every later module of a matching name), an Erlang
      module, or a malformed name (`Anchor.Domain.AllowedCallers`, DND-1269);
    * a relation-bearing rule whose relation is missing or empty (see below);
    * a `pure_patterns` entry that is a match-all glob, which declares every
      module pure (DND-5451);
    * an `owned_namespaces` list that is empty, which checks no struct, or that
      holds an entry that is not exactly one Elixir module name (DND-5453);
    * a `module_pattern_restrictions` rule whose `allowed_functions` holds a
      match-all glob (only wildcards: `*`, `**`), which allows every function.
      Since DND-1292 every other glob character is a literal, so no other entry
      matches everything (`Anchor.Domain.GlobPattern.wildcard_only?/1`).

  What load time cannot decide is decided at run time: a rule that selects
  fewer files than its floor (`min_files`, default 1), and a rule whose type no
  enabled check reads. See `Anchor.Managers.Lint`.

  ## The allowlist is `@keys_by_type`, and it is the only one

  Every rule accepts its engine's **common keys** (`@common_keys_by_engine`,
  `common_keys/1`):

    * `ast`: `type`, the three selectors (`paths`, `pattern`, `uses_module`),
      `recursive`, the floor keys `min_files` and `id`, `enforcement`
      (DND-5441) and `baseline` (DND-5632);
    * `graph` (shared contract section 3.2, DND-5441): `type`, `id`, the three
      selectors (`bucket`, `paths`, `pattern`), the floor `min_modules`,
      `enforcement` and `baseline`.

  On top of those, a rule accepts exactly the keys its type's check reads, as
  listed in `@keys_by_type`. Any other key fails the load; a common key of the
  other engine is named as such (`uses_module` on a graph rule).

  `enforcement` is `report` or `enforce` (default). `baseline` is a path
  relative to the project root with no `..` segment, and needs `id` (every
  baseline entry starts with it). An `ast` rule's is read by its Credo check
  (`Anchor.Managers.Lint`, DND-5632), a graph rule's by `mix anchor.graph`.
  A graph rule needs
  the config's `architecture:` section, and its `bucket` must name one of its
  buckets: `validate_architecture/3`, which `Anchor.Config` calls once the
  whole document is parsed.

  ## The relation is `@relations_by_type`

  A rule's **relation** is what it checks the selected files against. A
  relation-bearing type lists its relation keys in `@relations_by_type`, and a
  rule of that type must carry **at least one of them as a non-empty list**:

    * `no_direct_dependency`: `forbidden_functions`, `forbidden_modules`,
      `forbidden_patterns`;
    * `no_transitive_dependency`: `forbidden_modules`, `forbidden_patterns`;
    * `must_use_module`: `required_modules`.

  Every other type maps to `[]`, which says, explicitly, that the type has no
  relation to require:

    * `module_pattern_restrictions` checks against `allowed_functions`, but an
      absent or empty allow-list forbids every function, which over-reports
      loudly rather than checking nothing. Its one "checks nothing" is a
      match-all entry, refused on its own.
    * `alphabetized_functions` and `max_file_length` read one optional
      parameter with a default (`mode`, `max_lines`), so they always check.
    * `case_on_bare_arg`, `no_comparison_in_if`, `no_discarding_arrow_in_with`,
      `no_forwarding_function`, `no_tuple_match_in_head`, `single_control_flow`,
      `struct_getter_convention` read no key of their own: they check every
      file they select.
    * `struct_owned_by_module` (DND-5453) and its graph half
      `struct_owned_by_module_flow` (DND-5454) read one optional key,
      `owned_namespaces`, that narrows which structs it checks; without it
      every struct is checked. An empty list, and an entry that is not an
      exact module name, are refused.
    * `no_discarded_pure_expression` (DND-5451) reads one optional key,
      `pure_patterns`, that widens what it reports; without it the stdlib pure
      set still applies, so it always checks. A match-all entry
      (`GlobPattern.wildcard_only?/1`) is refused on its own.

  ## Extending it

  **To add a key** (as DND-1267 did for `forbidden_functions`, and DND-1269
  for `allowed_callers`):

    1. Add it to its rule type's list in `@keys_by_type` (or to `@common_keys`
       if every type reads it).
    2. If it is something the rule checks against, add it to that type's list
       in `@relations_by_type` too, with a description in
       `@relation_descriptions`. A rule then satisfies its relation with that
       key alone: T3 (DND-1267) added `forbidden_functions` to
       `no_direct_dependency` this way, and a rule carrying only
       `forbidden_functions` has a relation. If the key holds a list of
       strings, add it to `@string_list_keys`. A key that narrows a rule
       rather than giving it something to check (`allowed_callers`, DND-1269)
       is not a relation.
    3. Parse it in `Anchor.Config.parse_rule/1`.
    4. Add it to the README tables "Keys each rule type accepts" (its keys and
       relation columns) and "Config schema: rule keys at a glance". A test
       compares the first table with this module, so the README cannot drift.
    5. Add its rows to its type's table in
       `test/anchor/domain/rule_checks_nothing_test.exs`: every way the key can
       make a rule check nothing, as a refused row, and a positive row. A test
       fails until every accepted key has a row.

  **To add a rule type**, add an entry to `@keys_by_type`, to
  `@relations_by_type` (`[]` when it has no relation) **and** to
  `@engine_by_type` (compilation fails when the three disagree), and give it a
  table in that test file. The rule types Anchor knows are `rule_types/0`, and a
  test pins them to the shipped checks' `rule_type/0`s.

  ## The engine is `@engine_by_type`

  Each rule type has exactly one authoritative engine (DND-5437): `:ast` when
  the property is about the text the author wrote (a Credo check reads the
  source AST), `:graph` when it is about what the program does (`mix
  anchor.graph` reads the compiled graph). `engine/1` answers it, and
  `Anchor.Domain.RuleCoverage.unchecked/3` reads it so Credo never reports a
  graph rule as unchecked. The README's "Keys each rule type accepts" table has
  an Engine column, compared with this map by a test.

  ## Selectors

  An `ast` rule selects files by **exactly one** of `paths` (a non-empty list
  of path globs), `pattern` (a module-name glob) or `uses_module` (a module
  name). These are exactly the fields
  `Anchor.Domain.RuleMatching.rule_matches_file?/2` reads, in that order,
  stopping at the first. An explicit `paths: []` is "no path selector" and
  stays valid beside a `pattern` or `uses_module`. A `graph` rule selects
  modules by exactly one of `bucket`, `paths` or `pattern`, the fields
  `Anchor.Domain.GraphRules.select/2` reads.
  """

  alias Anchor.Domain.AllowedCallers
  alias Anchor.Domain.Failures
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.GlobPattern

  @type engine :: :ast | :graph

  # The keys every rule of an engine accepts (DND-5441: `enforcement` on both
  # engines; `baseline` on both since DND-5632; the graph common keys are
  # shared contract section 3.2). See the moduledoc, "Common keys per engine".
  @common_keys_by_engine %{
    ast: ~w(baseline enforcement id min_files paths pattern recursive type uses_module),
    graph: ~w(baseline bucket enforcement id min_modules paths pattern type)
  }

  # The selectors of an engine, in the order its selection reads them.
  @selector_keys_by_engine %{
    ast: ~w(paths pattern uses_module),
    graph: ~w(bucket paths pattern)
  }

  @selector_descriptions %{
    "bucket" => "bucket (an architecture: bucket name)",
    "paths" => "paths (a non-empty list of path globs)",
    "pattern" => "pattern (a module-name glob)",
    "uses_module" => "uses_module (a module the file uses)"
  }

  @enforcements %{"enforce" => :enforce, "report" => :report}

  # THE per-type key allowlist. Keys beyond `@common_keys`, one entry per
  # shipped check's `rule_type/0`. See the moduledoc before extending it.
  @keys_by_type %{
    # DND-5476: aggregate_declarations reads only the graph common keys (the
    # declarations are the `aggregates:` section's and the modules').
    aggregate_declarations: [],
    alphabetized_functions: ~w(mode),
    case_on_bare_arg: [],
    # DND-5445: context_acyclic reads only the graph common keys (the contexts
    # are the `architecture:` section's).
    context_acyclic: [],
    # DND-5447: effects_match_bucket reads only the graph common keys (the
    # buckets, effects and roots are the `architecture:` section's).
    effects_match_bucket: [],
    # DND-5443: interface reads `max_width` (optional, a positive integer: a
    # context whose interface exports more public functions is a violation).
    interface: ~w(max_width),
    # DND-5442: the graph engine's layering rule reads only the graph common
    # keys (its matrix is the `architecture:` section's `calls`).
    layering: [],
    max_file_length: ~w(max_lines),
    module_pattern_restrictions: ~w(allowed_functions),
    must_use_module: ~w(required_modules),
    no_comparison_in_if: [],
    no_direct_dependency:
      ~w(allowed_callers context_depth forbidden_functions forbidden_modules forbidden_patterns
         match same_context),
    no_discarded_pure_expression: ~w(pure_patterns),
    no_discarding_arrow_in_with: [],
    no_forwarding_function: [],
    no_transitive_dependency: ~w(forbidden_modules forbidden_patterns),
    no_tuple_match_in_head: [],
    single_control_flow: [],
    struct_getter_convention: [],
    struct_owned_by_module: ~w(owned_namespaces),
    struct_owned_by_module_flow: ~w(owned_namespaces)
  }

  # THE relation each type checks against: a rule of the type must carry at
  # least one of these as a non-empty list. `[]` is a decision, not an omission:
  # the type has no relation to require (see the moduledoc for why, per type).
  @relations_by_type %{
    aggregate_declarations: [],
    alphabetized_functions: [],
    case_on_bare_arg: [],
    context_acyclic: [],
    effects_match_bucket: [],
    interface: [],
    layering: [],
    max_file_length: [],
    module_pattern_restrictions: [],
    must_use_module: ~w(required_modules),
    no_comparison_in_if: [],
    no_direct_dependency: ~w(forbidden_functions forbidden_modules forbidden_patterns),
    no_discarded_pure_expression: [],
    no_discarding_arrow_in_with: [],
    no_forwarding_function: [],
    no_transitive_dependency: ~w(forbidden_modules forbidden_patterns),
    no_tuple_match_in_head: [],
    single_control_flow: [],
    struct_getter_convention: [],
    struct_owned_by_module: [],
    struct_owned_by_module_flow: []
  }

  # THE engine each type runs on (DND-5437): `:ast` (a Credo check reads the
  # source AST) or `:graph` (`mix anchor.graph` reads the compiled graph). One
  # authoritative engine per type; compilation fails when a type has none.
  @engine_by_type %{
    aggregate_declarations: :graph,
    alphabetized_functions: :ast,
    case_on_bare_arg: :ast,
    context_acyclic: :graph,
    effects_match_bucket: :graph,
    interface: :graph,
    layering: :graph,
    max_file_length: :ast,
    module_pattern_restrictions: :ast,
    must_use_module: :ast,
    no_comparison_in_if: :ast,
    no_direct_dependency: :ast,
    no_discarded_pure_expression: :ast,
    no_discarding_arrow_in_with: :ast,
    no_forwarding_function: :ast,
    no_transitive_dependency: :ast,
    no_tuple_match_in_head: :ast,
    single_control_flow: :ast,
    struct_getter_convention: :ast,
    struct_owned_by_module: :ast,
    struct_owned_by_module_flow: :graph
  }

  @engines [:ast, :graph]

  # DND-5491: the engine split. An `:ast` type here is a write-time early
  # warning of the `:graph` type it maps to, which is the authority: it runs
  # before compile (in the pre-write hook, with exact lines), and
  # test/anchor/integration/layering_parity_test.exs holds the two equal on
  # macro-free code. Compilation fails unless every key is an ast type and
  # every value a graph type.
  @early_warning_of %{
    no_direct_dependency: :layering,
    no_transitive_dependency: :layering
  }

  @relation_descriptions %{
    "forbidden_functions" => ~s(a list of "Module.function" or "Module.function/arity"),
    "forbidden_modules" => "a list of module names",
    "forbidden_patterns" => "a list of module-name globs",
    "required_modules" => "a list of module names"
  }

  # Keys whose value is a list of strings, each of which must be non-blank.
  @string_list_keys ~w(allowed_callers allowed_functions forbidden_functions forbidden_modules
                       forbidden_patterns owned_namespaces pure_patterns required_modules)

  # A misspelling this close to a known key (String.jaro_distance/2) is
  # suggested as that key.
  @suggestion_threshold 0.8

  if Map.keys(@keys_by_type) != Map.keys(@relations_by_type) do
    raise CompileError,
      description:
        "Anchor.Domain.RuleSchema: @keys_by_type and @relations_by_type must name the " <>
          "same rule types; give every type a relation entry ([] for none)"
  end

  if Map.keys(@keys_by_type) != Map.keys(@engine_by_type) or
       Enum.any?(Map.values(@engine_by_type), &(&1 not in @engines)) do
    raise CompileError,
      description:
        "Anchor.Domain.RuleSchema: @keys_by_type and @engine_by_type must name the same " <>
          "rule types; give every rule type an engine (:ast or :graph)"
  end

  for {type, target} <- @early_warning_of do
    unless Map.get(@engine_by_type, type) == :ast and Map.get(@engine_by_type, target) == :graph do
      raise CompileError,
        description:
          "Anchor.Domain.RuleSchema: @early_warning_of maps #{type} to #{target}; an early " <>
            "warning is an :ast rule type of a :graph rule type (its authority)"
    end
  end

  for {type, keys} <- @relations_by_type, key <- keys do
    unless key in @keys_by_type[type] and Map.has_key?(@relation_descriptions, key) do
      raise CompileError,
        description:
          "Anchor.Domain.RuleSchema: relation key #{key} of #{type} must be in its " <>
            "@keys_by_type list and in @relation_descriptions"
    end
  end

  @doc "The keys every `ast` rule accepts, sorted (`common_keys(:ast)`)."
  @spec common_keys() :: [String.t()]
  def common_keys, do: common_keys(:ast)

  @doc "The keys every rule of `engine` accepts, sorted."
  @spec common_keys(engine()) :: [String.t()]
  def common_keys(engine) when engine in @engines,
    do: Enum.sort(Map.fetch!(@common_keys_by_engine, engine))

  @doc """
  The parsed `enforcement` of a rule (DND-5441): `:report` or `:enforce` (the
  default). A rule map built in memory may carry the atom or the string.
  """
  @spec enforcement(map()) :: :enforce | :report
  def enforcement(rule) do
    case Map.get(rule, :enforcement) do
      value when value in [:report, "report"] -> :report
      _enforce -> :enforce
    end
  end

  @doc """
  Parses an `enforcement` token (a leading colon accepted), already validated
  by `validate/2`: `nil` (absent) is `:enforce`.
  """
  @spec parse_enforcement(String.t() | nil) :: :enforce | :report
  def parse_enforcement(nil), do: :enforce
  def parse_enforcement(":" <> token), do: parse_enforcement(token)
  def parse_enforcement(token), do: Map.fetch!(@enforcements, token)

  @doc """
  The engine that runs rules of `type` (DND-5437): `:ast` (a Credo check) or
  `:graph` (`mix anchor.graph`). Raises `KeyError` for a type that is not one of
  `rule_types/0`: callers pass parsed types only.
  """
  @spec engine(atom()) :: engine()
  def engine(type), do: Map.fetch!(@engine_by_type, type)

  @doc """
  The graph rule type `type` is a write-time early warning of (DND-5491), or
  `nil`. `no_direct_dependency` and `no_transitive_dependency` warn of
  `layering`: the graph engine is layering's authority, and the AST rules
  catch the same calls before compile, held equal to it by the parity test.
  """
  @spec early_warning_of(atom()) :: atom() | nil
  def early_warning_of(type), do: Map.get(@early_warning_of, type)

  @doc "The rule types run by `engine`, sorted."
  @spec rule_types_for_engine(engine()) :: [atom()]
  def rule_types_for_engine(engine) when engine in @engines do
    for {type, ^engine} <- Enum.sort(@engine_by_type), do: type
  end

  @doc """
  The keys a rule of `type` accepts: the common keys plus its type's own,
  sorted. `type` must be one of `rule_types/0`.
  """
  @spec known_keys(atom()) :: [String.t()]
  def known_keys(type),
    do: Enum.sort(common_keys(engine(type)) ++ Map.fetch!(@keys_by_type, type))

  @doc """
  The relation keys of `type`, sorted: a rule of the type must carry at least
  one of them as a non-empty list. `[]` for a type with no relation.
  """
  @spec relation_keys(atom()) :: [String.t()]
  def relation_keys(type), do: @relations_by_type |> Map.fetch!(type) |> Enum.sort()

  @doc "The rule types Anchor knows, sorted: one per shipped check."
  @spec rule_types() :: [atom()]
  def rule_types, do: @keys_by_type |> Map.keys() |> Enum.sort()

  @doc "The keys that select an `ast` rule's files, sorted (`selector_keys(:ast)`)."
  @spec selector_keys() :: [String.t()]
  def selector_keys, do: selector_keys(:ast)

  @doc "The keys that select a rule of `engine`'s files or modules, sorted."
  @spec selector_keys(engine()) :: [String.t()]
  def selector_keys(engine) when engine in @engines,
    do: Enum.sort(Map.fetch!(@selector_keys_by_engine, engine))

  @doc """
  Checks a decoded rule map (string keys) of the already-validated `type`.

  Returns `:ok`, or `{:error, reason}` for the first failure, in this order: an
  unknown key (every unknown key is named, with the known keys for `type`), a
  malformed selector, no selector, more than one selector, a misused
  `recursive`, a malformed `min_files` or `id`, a malformed string list, a
  missing or empty relation, and a match-all `allowed_functions` entry.
  """
  @spec validate(map(), atom()) :: :ok | {:error, String.t()}
  def validate(rule, type) when is_map(rule) do
    with :ok <- validate_common(rule, engine(type), Map.fetch!(@keys_by_type, type), type),
         :ok <- validate_string_lists(rule),
         :ok <- validate_function_refs(rule),
         :ok <- validate_allowed_callers(rule),
         :ok <- require_relation(rule, type),
         :ok <- refuse_unread_match(rule),
         :ok <- refuse_all_pure(rule),
         :ok <- validate_owned_namespaces(rule) do
      refuse_allow_all(rule)
    end
  end

  @doc """
  The checks every rule of `engine` shares (DND-5441), the first part of
  `validate/2`: no key outside the engine's common keys and `type_keys`, one
  selector of the engine's (`selector_keys/1`), `recursive`, the floor
  (`min_files` for `ast`, `min_modules` for `graph`), `id`, `enforcement` and
  `baseline`. `label` names the rule type in the unknown-key message.
  """
  @spec validate_common(map(), engine(), [String.t()], atom() | String.t()) ::
          :ok | {:error, String.t()}
  def validate_common(rule, engine, type_keys, label) when engine in @engines do
    with :ok <- validate_keys(rule, engine, type_keys, label),
         :ok <- validate_selector_types(rule, engine),
         :ok <- require_selector(rule, engine),
         :ok <- require_single_selector(rule, engine),
         :ok <- validate_recursive(rule, engine),
         :ok <- validate_floor(rule),
         :ok <- validate_min_modules(rule),
         :ok <- validate_max_width(rule),
         :ok <- validate_id(rule),
         :ok <- validate_enforcement(rule) do
      validate_baseline(rule)
    end
  end

  @doc """
  Checks a parsed graph rule (atom keys) against the config's `architecture:`
  section (DND-5441), which load time knows only once the whole document is
  parsed: every graph rule needs the section (the runner classifies modules
  by its buckets), and a `bucket` selector must name one of its buckets.
  `engine` is the rule type's (`engine/1`); `bucket_names` is `nil` when the
  section is absent. An `ast` rule is `:ok`.
  """
  @spec validate_architecture(map(), engine(), [String.t()] | nil) :: :ok | {:error, String.t()}
  def validate_architecture(_rule, :ast, _bucket_names), do: :ok

  def validate_architecture(%{type: type}, :graph, nil) do
    {:error,
     "a #{type} rule runs on the graph engine (mix anchor.graph), which classifies modules " <>
       "by the architecture: section, and the config has none; add an architecture: section " <>
       "(the README section \"The `architecture:` section\"), or remove the rule"}
  end

  def validate_architecture(%{bucket: bucket}, :graph, names) when is_binary(bucket) do
    if bucket in names do
      :ok
    else
      {:error,
       "`bucket: #{bucket}` names no architecture: bucket, so the rule would select no module; " <>
         "name one of: #{Enum.join(names, ", ")}"}
    end
  end

  def validate_architecture(_rule, :graph, _names), do: :ok

  defp validate_enforcement(%{"enforcement" => token}) do
    case token do
      ":" <> bare when is_map_key(@enforcements, bare) -> :ok
      bare when is_map_key(@enforcements, bare) -> :ok
      other -> {:error, "`enforcement` must be report or enforce, got: #{inspect(other)}"}
    end
  end

  defp validate_enforcement(_rule), do: :ok

  # A baseline path is relative to the project root and stays inside it: the
  # runner reads it, `--write-baseline` creates it and `--base` reads it with
  # `git show`, so an absolute path or a `..` segment is refused. Every entry
  # starts with the rule's id, so a baseline needs one.
  defp validate_baseline(%{"baseline" => path} = rule) do
    cond do
      not is_binary(path) or String.trim(path) == "" ->
        {:error,
         "`baseline` must be a non-empty path relative to the project root, got: " <>
           inspect(path)}

      Path.type(path) != :relative or ".." in Path.split(path) ->
        {:error,
         "`baseline: #{path}` must be a path relative to the project root with no `..` " <>
           "segment (convention: .anchor/baselines/<rule-id>.txt)"}

      not (is_binary(rule["id"]) and rule["id"] != "") ->
        {:error,
         "`baseline` needs the rule's `id`: every baseline entry starts with it; give the rule " <>
           "an id"}

      true ->
        :ok
    end
  end

  defp validate_baseline(_rule), do: :ok

  defp validate_min_modules(%{"min_modules" => min})
       when not is_integer(min) or min < 1 do
    {:error,
     "`min_modules` must be a positive integer (the fewest modules the rule must select), " <>
       "got: #{inspect(min)}"}
  end

  defp validate_min_modules(_rule), do: :ok

  # DND-5443: an interface rule's `max_width`. Zero would fail every context
  # with an interface at all; a non-integer would compare as nothing.
  defp validate_max_width(%{"max_width" => max})
       when not is_integer(max) or max < 1 do
    {:error,
     "`max_width` must be a positive integer (the most public functions a context's " <>
       "interface may export), got: #{inspect(max)}"}
  end

  defp validate_max_width(_rule), do: :ok

  # DND-5453: `owned_namespaces` names the namespaces whose structs are
  # checked, each one exact Elixir module name (`AllowedCallers`' grammar). A
  # glob would widen with every later module of a matching name, an Erlang
  # module is never a struct, and an empty list would check no struct. Runs
  # after `validate_string_lists/1`, so each entry is a non-blank string here.
  defp validate_owned_namespaces(%{"owned_namespaces" => []}),
    do: {:error, Failures.owned_namespaces_empty()}

  defp validate_owned_namespaces(%{"owned_namespaces" => namespaces}) do
    case Enum.find(namespaces, &match?({:error, _reason}, AllowedCallers.parse(&1))) do
      nil -> :ok
      entry -> {:error, Failures.owned_namespaces_not_a_module(entry)}
    end
  end

  defp validate_owned_namespaces(_rule), do: :ok

  # DND-5451: a `pure_patterns` entry of only wildcards declares every module
  # pure, so every call to anything would read as an expression with no
  # effect. Runs after `validate_string_lists/1`, so each entry is a non-blank
  # string here.
  defp refuse_all_pure(rule) do
    case Enum.find(rule["pure_patterns"] || [], &GlobPattern.wildcard_only?/1) do
      nil ->
        :ok

      entry ->
        {:error, Failures.pure_patterns_match_all(entry)}
    end
  end

  # DND-1267: `match` chooses which module-level dependency set
  # `forbidden_modules` and `forbidden_patterns` are checked against. A
  # `forbidden_functions` token is matched against every call shape whatever
  # `match` says, so on a rule with neither module-level key nothing reads it,
  # and it would read as if it narrowed the rule.
  defp refuse_unread_match(%{"match" => _match} = rule) do
    if Enum.all?(~w(forbidden_modules forbidden_patterns), &(rule[&1] in [nil, []])) do
      {:error,
       "`match` applies only to `forbidden_modules` and `forbidden_patterns`, and the rule " <>
         "has neither, so nothing reads it (`forbidden_functions` matches every call shape " <>
         "whatever `match` says); remove `match`"}
    else
      :ok
    end
  end

  defp refuse_unread_match(_rule), do: :ok

  defp validate_keys(rule, engine, type_keys, type) do
    known = Enum.sort(common_keys(engine) ++ type_keys)

    case rule |> Map.keys() |> Enum.reject(&(&1 in known)) |> Enum.sort() do
      [] -> :ok
      unknown -> {:error, unknown_keys_reason(unknown, type, known, engine)}
    end
  end

  defp unknown_keys_reason(unknown, type, known, engine) do
    noun = if match?([_], unknown), do: "key", else: "keys"
    named = Enum.map_join(unknown, ", ", &inspect/1)
    hints = unknown |> Enum.flat_map(&hints(&1, known, engine)) |> Enum.join("; ")

    "unknown #{noun} #{named} in a #{type} rule#{hints_clause(hints)}; " <>
      "known keys for #{type}: #{Enum.join(known, ", ")}"
  end

  defp hints_clause(""), do: ""
  defp hints_clause(hints), do: " (#{hints})"

  # A hint for one unknown key: the known key it is probably a misspelling of,
  # and the other rule types that read it, when any do.
  defp hints(key, known, engine) when is_binary(key) do
    Enum.reject([suggestion(key, known), elsewhere(key), other_engine(key, engine)], &is_nil/1)
  end

  defp hints(_key, _known, _engine), do: []

  # A common key of the other engine (`bucket` on an ast rule, `uses_module`
  # on a graph rule) says which rules read it.
  defp other_engine(key, engine) do
    [other] = @engines -- [engine]

    if key in @common_keys_by_engine[other] and key not in @common_keys_by_engine[engine],
      do: "`#{key}` applies to #{other} rules only"
  end

  defp suggestion(key, known) do
    best = Enum.max_by(known, &String.jaro_distance(key, &1))

    if String.jaro_distance(key, best) >= @suggestion_threshold,
      do: "#{inspect(key)}: did you mean #{inspect(best)}?"
  end

  defp elsewhere(key) do
    case for({type, keys} <- Enum.sort(@keys_by_type), key in keys, do: type) do
      [] -> nil
      types -> "`#{key}` applies to: #{Enum.join(types, ", ")}"
    end
  end

  defp validate_selector_types(rule, engine) do
    Enum.find_value(
      @selector_keys_by_engine[engine],
      :ok,
      &selector_type_error(&1, Map.get(rule, &1))
    )
  end

  defp selector_type_error(_key, nil), do: nil

  defp selector_type_error("paths", paths) do
    unless is_list(paths) and Enum.all?(paths, &(is_binary(&1) and &1 != "")) do
      {:error, "`paths` must be a list of non-empty path-glob strings, got: #{inspect(paths)}"}
    end
  end

  defp selector_type_error(key, value) do
    unless is_binary(value) and value != "" do
      {:error, "`#{key}` must be a non-empty string, got: #{inspect(value)}"}
    end
  end

  defp require_selector(rule, engine) do
    if selectors(rule, engine) == [] do
      keys = @selector_keys_by_engine[engine]

      {:error,
       "the rule has no selector, so it would select no #{selected_noun(engine)}; give it " <>
         "one of: " <> Enum.map_join(keys, ", ", &Map.fetch!(@selector_descriptions, &1))}
    else
      :ok
    end
  end

  defp selected_noun(:ast), do: "file"
  defp selected_noun(:graph), do: "module"

  # DND-1290 (DND-1291): `RuleMatching` reads the first selector present and
  # ignores the rest, so a second selector narrowed nothing and read as if it
  # did.
  defp require_single_selector(rule, engine) do
    case selectors(rule, engine) do
      [_one] ->
        :ok

      several ->
        {:error,
         "the rule has more than one selector (#{Enum.join(several, ", ")}), but only the " <>
           "first is read (#{Enum.join(@selector_keys_by_engine[engine], ", then ")}); " <>
           "keep exactly one"}
    end
  end

  # The selectors the rule carries, in the order its engine's selection tries
  # them (`RuleMatching` for ast, `GraphRules.select/2` for graph).
  defp selectors(rule, engine),
    do: Enum.filter(@selector_keys_by_engine[engine], &selects?(&1, Map.get(rule, &1)))

  defp selects?("paths", paths), do: is_list(paths) and paths != []
  defp selects?(_key, value), do: is_binary(value)

  defp validate_recursive(%{"recursive" => recursive}, _engine) when not is_boolean(recursive) do
    {:error, "`recursive` must be true or false, got: #{inspect(recursive)}"}
  end

  defp validate_recursive(%{"recursive" => _recursive} = rule, engine) do
    if selects?("paths", rule["paths"]) do
      :ok
    else
      {:error,
       "`recursive` applies only to `paths`, and the rule selects by " <>
         "#{hd(selectors(rule, engine))}, so nothing reads it; remove `recursive`, or select " <>
         "by `paths`"}
    end
  end

  defp validate_recursive(_rule, _engine), do: :ok

  defp validate_floor(%{"min_files" => min_files})
       when not is_integer(min_files) or min_files < 1 do
    {:error,
     "`min_files` must be a positive integer (the fewest files the rule must select), " <>
       "got: #{inspect(min_files)}"}
  end

  defp validate_floor(_rule), do: :ok

  defp validate_id(%{"id" => id}) when not is_binary(id) or id == "" do
    {:error, "`id` must be a non-empty string, got: #{inspect(id)}"}
  end

  defp validate_id(_rule), do: :ok

  defp validate_string_lists(rule) do
    Enum.find_value(@string_list_keys, :ok, &string_list_error(&1, Map.fetch(rule, &1)))
  end

  defp string_list_error(_key, :error), do: nil

  defp string_list_error(key, {:ok, value}) do
    unless is_list(value) and Enum.all?(value, &non_blank_string?/1) do
      {:error, "`#{key}` must be a list of non-empty strings, got: #{inspect(value)}"}
    end
  end

  defp non_blank_string?(value), do: is_binary(value) and String.trim(value) != ""

  # DND-1267: every `forbidden_functions` entry must name exactly one function.
  # A token that names none would match nothing, so the rule would check less
  # than it says. Runs after `validate_string_lists/1`, so each entry is a
  # non-blank string here.
  defp validate_function_refs(rule) do
    rule
    |> Map.get("forbidden_functions", [])
    |> Enum.find_value(:ok, &function_ref_error/1)
  end

  defp function_ref_error(token) do
    case FunctionRef.parse(token) do
      {:ok, _ref} -> nil
      {:error, reason} -> {:error, "`forbidden_functions` entry #{reason}"}
    end
  end

  # DND-1269: every `allowed_callers` entry must name exactly one Elixir module
  # (`Anchor.Domain.AllowedCallers`). A glob would widen the rule with every
  # later module of a matching name (`*` allows every caller, so the rule would
  # check nothing). Runs after `validate_string_lists/1`, so each entry is a
  # non-blank string here.
  defp validate_allowed_callers(rule) do
    rule
    |> Map.get("allowed_callers", [])
    |> Enum.find_value(:ok, &allowed_caller_error/1)
  end

  defp allowed_caller_error(token) do
    case AllowedCallers.parse(token) do
      {:ok, _module} -> nil
      {:error, reason} -> {:error, "`allowed_callers` entry #{inspect(token)} #{reason}"}
    end
  end

  defp require_relation(rule, type) do
    case relation_keys(type) do
      [] ->
        :ok

      keys ->
        if Enum.any?(keys, &(rule[&1] not in [nil, []])), do: :ok, else: no_relation(type, keys)
    end
  end

  defp no_relation(type, keys) do
    {:error,
     "a #{type} rule has no relation, so it checks nothing: #{missing_phrase(keys)} " <>
       "missing or empty; give it #{choice(keys)}: " <>
       Enum.map_join(keys, ", ", &"#{&1} (#{relation_description(&1)})")}
  end

  defp missing_phrase([key]), do: "#{key} is"

  defp missing_phrase(keys) do
    {init, [last]} = Enum.split(keys, -1)
    "#{Enum.join(init, ", ")} and #{last} are"
  end

  defp choice([_key]), do: "a non-empty list"
  defp choice(_keys), do: "at least one non-empty list of"

  defp relation_description(key), do: Map.fetch!(@relation_descriptions, key)

  # An allow-list entry of only wildcards (`*`, `**`, …) matches every function
  # name, so the rule allows everything and checks nothing. Since DND-1292 every
  # other glob character is a literal, so this is the only match-all entry
  # (`*?` allows the predicates, not everything); `GlobPattern` decides it.
  defp refuse_allow_all(rule) do
    case Enum.find(rule["allowed_functions"] || [], &GlobPattern.wildcard_only?/1) do
      nil ->
        :ok

      entry ->
        {:error,
         "`allowed_functions` entry #{inspect(entry)} allows every function, so the rule " <>
           "checks nothing; list the functions the module may define, or remove the rule"}
    end
  end
end
