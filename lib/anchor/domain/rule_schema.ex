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
    * a `min_files` that is not a positive integer (a floor of 0 is no floor),
      or an `id` that is not a non-empty string;
    * a relation list of the wrong shape: not a list, or holding an entry that
      is not a non-blank string (`forbidden_modules: [""]`, a bare `-`);
    * a relation-bearing rule whose relation is missing or empty (see below);
    * a `module_pattern_restrictions` rule whose `allowed_functions` holds a
      match-all glob (only wildcards: `*`, `**`), which allows every function.
      Since DND-1292 every other glob character is a literal, so no other entry
      matches everything (`Anchor.Domain.GlobPattern.wildcard_only?/1`).

  What load time cannot decide is decided at run time: a rule that selects
  fewer files than its floor (`min_files`, default 1), and a rule whose type no
  enabled check reads. See `Anchor.Managers.Lint`.

  ## The allowlist is `@keys_by_type`, and it is the only one

  Every rule accepts the **common keys**: `type`, the three selectors (`paths`,
  `pattern`, `uses_module`), `recursive`, and the floor keys `min_files` and
  `id`. On top of those, a rule accepts exactly the keys its type's check reads,
  as listed in `@keys_by_type`. Any other key fails the load.

  ## The relation is `@relations_by_type`

  A rule's **relation** is what it checks the selected files against. A
  relation-bearing type lists its relation keys in `@relations_by_type`, and a
  rule of that type must carry **at least one of them as a non-empty list**:

    * `no_direct_dependency`, `no_transitive_dependency`: `forbidden_modules`,
      `forbidden_patterns`;
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
      `no_tuple_match_in_head`, `single_control_flow`,
      `struct_getter_convention` read no key of their own: they check every
      file they select.

  ## Extending it

  **To add a key** (as later tickets do for `forbidden_functions` and
  `allowed_callers`):

    1. Add it to its rule type's list in `@keys_by_type` (or to `@common_keys`
       if every type reads it).
    2. If it is something the rule checks against, add it to that type's list
       in `@relations_by_type` too, with a description in
       `@relation_descriptions`. A rule then satisfies its relation with that
       key alone: T3 (DND-1267) adds `forbidden_functions` to
       `no_direct_dependency` this way, and a rule carrying only
       `forbidden_functions` has a relation. If the key holds a list of
       strings, add it to `@string_list_keys`.
    3. Parse it in `Anchor.Config.parse_rule/1`.
    4. Add it to the README tables "Keys each rule type accepts" (its keys and
       relation columns) and "Config schema: rule keys at a glance". A test
       compares the first table with this module, so the README cannot drift.
    5. Add its rows to its type's table in
       `test/anchor/domain/rule_checks_nothing_test.exs`: every way the key can
       make a rule check nothing, as a refused row, and a positive row. A test
       fails until every accepted key has a row.

  **To add a rule type**, add an entry to `@keys_by_type` **and** to
  `@relations_by_type` (`[]` when it has no relation; compilation fails when the
  two disagree), and give it a table in that test file. The rule types Anchor
  knows are `rule_types/0`, and a test pins them to the shipped checks'
  `rule_type/0`s.

  ## Selectors

  A rule selects files by **exactly one** of `paths` (a non-empty list of path
  globs), `pattern` (a module-name glob) or `uses_module` (a module name). These
  are exactly the fields `Anchor.Domain.RuleMatching.rule_matches_file?/2`
  reads, in that order, stopping at the first. An explicit `paths: []` is "no
  path selector" and stays valid beside a `pattern` or `uses_module`.
  """

  alias Anchor.Domain.GlobPattern

  @common_keys ~w(id min_files paths pattern recursive type uses_module)

  # THE per-type key allowlist. Keys beyond `@common_keys`, one entry per
  # shipped check's `rule_type/0`. See the moduledoc before extending it.
  @keys_by_type %{
    alphabetized_functions: ~w(mode),
    case_on_bare_arg: [],
    max_file_length: ~w(max_lines),
    module_pattern_restrictions: ~w(allowed_functions),
    must_use_module: ~w(required_modules),
    no_comparison_in_if: [],
    no_direct_dependency:
      ~w(context_depth forbidden_modules forbidden_patterns match same_context),
    no_discarding_arrow_in_with: [],
    no_transitive_dependency: ~w(forbidden_modules forbidden_patterns),
    no_tuple_match_in_head: [],
    single_control_flow: [],
    struct_getter_convention: []
  }

  # THE relation each type checks against: a rule of the type must carry at
  # least one of these as a non-empty list. `[]` is a decision, not an omission:
  # the type has no relation to require (see the moduledoc for why, per type).
  @relations_by_type %{
    alphabetized_functions: [],
    case_on_bare_arg: [],
    max_file_length: [],
    module_pattern_restrictions: [],
    must_use_module: ~w(required_modules),
    no_comparison_in_if: [],
    no_direct_dependency: ~w(forbidden_modules forbidden_patterns),
    no_discarding_arrow_in_with: [],
    no_transitive_dependency: ~w(forbidden_modules forbidden_patterns),
    no_tuple_match_in_head: [],
    single_control_flow: [],
    struct_getter_convention: []
  }

  @relation_descriptions %{
    "forbidden_modules" => "a list of module names",
    "forbidden_patterns" => "a list of module-name globs",
    "required_modules" => "a list of module names"
  }

  # Keys whose value is a list of strings, each of which must be non-blank.
  @string_list_keys ~w(allowed_functions forbidden_modules forbidden_patterns required_modules)

  @selector_keys ~w(paths pattern uses_module)

  # A misspelling this close to a known key (String.jaro_distance/2) is
  # suggested as that key.
  @suggestion_threshold 0.8

  if Map.keys(@keys_by_type) != Map.keys(@relations_by_type) do
    raise CompileError,
      description:
        "Anchor.Domain.RuleSchema: @keys_by_type and @relations_by_type must name the " <>
          "same rule types; give every type a relation entry ([] for none)"
  end

  for {type, keys} <- @relations_by_type, key <- keys do
    unless key in @keys_by_type[type] and Map.has_key?(@relation_descriptions, key) do
      raise CompileError,
        description:
          "Anchor.Domain.RuleSchema: relation key #{key} of #{type} must be in its " <>
            "@keys_by_type list and in @relation_descriptions"
    end
  end

  @doc "The keys every rule type accepts, sorted."
  @spec common_keys() :: [String.t()]
  def common_keys, do: Enum.sort(@common_keys)

  @doc """
  The keys a rule of `type` accepts: the common keys plus its type's own,
  sorted. `type` must be one of `rule_types/0`.
  """
  @spec known_keys(atom()) :: [String.t()]
  def known_keys(type), do: Enum.sort(@common_keys ++ Map.fetch!(@keys_by_type, type))

  @doc """
  The relation keys of `type`, sorted: a rule of the type must carry at least
  one of them as a non-empty list. `[]` for a type with no relation.
  """
  @spec relation_keys(atom()) :: [String.t()]
  def relation_keys(type), do: @relations_by_type |> Map.fetch!(type) |> Enum.sort()

  @doc "The rule types Anchor knows, sorted: one per shipped check."
  @spec rule_types() :: [atom()]
  def rule_types, do: @keys_by_type |> Map.keys() |> Enum.sort()

  @doc "The keys that select files, sorted."
  @spec selector_keys() :: [String.t()]
  def selector_keys, do: Enum.sort(@selector_keys)

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
    with :ok <- validate_keys(rule, type),
         :ok <- validate_selector_types(rule),
         :ok <- require_selector(rule),
         :ok <- require_single_selector(rule),
         :ok <- validate_recursive(rule),
         :ok <- validate_floor(rule),
         :ok <- validate_id(rule),
         :ok <- validate_string_lists(rule),
         :ok <- require_relation(rule, type) do
      refuse_allow_all(rule)
    end
  end

  defp validate_keys(rule, type) do
    known = known_keys(type)

    case rule |> Map.keys() |> Enum.reject(&(&1 in known)) |> Enum.sort() do
      [] -> :ok
      unknown -> {:error, unknown_keys_reason(unknown, type, known)}
    end
  end

  defp unknown_keys_reason(unknown, type, known) do
    noun = if match?([_], unknown), do: "key", else: "keys"
    named = Enum.map_join(unknown, ", ", &inspect/1)
    hints = unknown |> Enum.flat_map(&hints(&1, known)) |> Enum.join("; ")

    "unknown #{noun} #{named} in a #{type} rule#{hints_clause(hints)}; " <>
      "known keys for #{type}: #{Enum.join(known, ", ")}"
  end

  defp hints_clause(""), do: ""
  defp hints_clause(hints), do: " (#{hints})"

  # A hint for one unknown key: the known key it is probably a misspelling of,
  # and the other rule types that read it, when any do.
  defp hints(key, known) when is_binary(key) do
    Enum.reject([suggestion(key, known), elsewhere(key)], &is_nil/1)
  end

  defp hints(_key, _known), do: []

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

  defp validate_selector_types(rule) do
    Enum.find_value(@selector_keys, :ok, &selector_type_error(&1, Map.get(rule, &1)))
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

  defp require_selector(rule) do
    if selectors(rule) == [] do
      {:error,
       "the rule has no selector, so it would select no file; give it one of: " <>
         "paths (a non-empty list of path globs), pattern (a module-name glob), " <>
         "uses_module (a module the file uses)"}
    else
      :ok
    end
  end

  # DND-1290 (DND-1291): `RuleMatching` reads the first selector present and
  # ignores the rest, so a second selector narrowed nothing and read as if it
  # did.
  defp require_single_selector(rule) do
    case selectors(rule) do
      [_one] ->
        :ok

      several ->
        {:error,
         "the rule has more than one selector (#{Enum.join(several, ", ")}), but only the " <>
           "first is read (paths, then pattern, then uses_module); keep exactly one"}
    end
  end

  # The selectors the rule carries, in the order `RuleMatching` tries them.
  defp selectors(rule), do: Enum.filter(@selector_keys, &selects?(&1, Map.get(rule, &1)))

  defp selects?("paths", paths), do: is_list(paths) and paths != []
  defp selects?(_key, value), do: is_binary(value)

  defp validate_recursive(%{"recursive" => recursive}) when not is_boolean(recursive) do
    {:error, "`recursive` must be true or false, got: #{inspect(recursive)}"}
  end

  defp validate_recursive(%{"recursive" => _recursive} = rule) do
    if selects?("paths", rule["paths"]) do
      :ok
    else
      {:error,
       "`recursive` applies only to `paths`, and the rule selects by #{hd(selectors(rule))}, " <>
         "so nothing reads it; remove `recursive`, or select by `paths`"}
    end
  end

  defp validate_recursive(_rule), do: :ok

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
