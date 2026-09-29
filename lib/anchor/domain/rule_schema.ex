defmodule Anchor.Domain.RuleSchema do
  @moduledoc """
  The keys a rule may carry, per rule type, and the selector every rule needs —
  a **Domain** module (ADR 001). Pure: it inspects a decoded rule map (string
  keys) and does no IO.

  A rule that names a key Anchor does not read, or that selects no file, would
  load and check less than it says, or nothing, and read green (DND-1286). So
  `validate/2` rejects both, and `Anchor.Config.parse_rule/1` fails the load.

  ## The allowlist is `@keys_by_type`, and it is the only one

  Every rule accepts the **common keys**: `type`, the three selectors (`paths`,
  `pattern`, `uses_module`) and `recursive`, because rule selection
  (`Anchor.Domain.RuleMatching`) reads them for every type. On top of those, a
  rule accepts exactly the keys its type's check reads, as listed in
  `@keys_by_type`. Any other key fails the load.

  **To add a key** (as later tickets do for `forbidden_functions`,
  `allowed_callers`, `min_files` and `id`):

    1. Add it to its rule type's list in `@keys_by_type` below (or to
       `@common_keys` if every type reads it).
    2. Parse it in `Anchor.Config.parse_rule/1`.
    3. Add it to the README table "Keys each rule type accepts", and to the
       "Config schema: rule keys at a glance" table. A test compares the first
       table with this allowlist, so the README cannot drift.

  **To add a rule type**, add an entry here, even an empty list. The rule types
  Anchor knows are this map's keys (`rule_types/0`), and a test pins them to the
  shipped checks' `rule_type/0`s.

  ## Selectors

  A rule selects files by one of `paths` (a non-empty list of path globs),
  `pattern` (a module-name glob) or `uses_module` (a module name). These are
  exactly the fields `Anchor.Domain.RuleMatching.rule_matches_file?/2` reads;
  a rule carrying none of them selects no file. So a rule must carry at least
  one, and each one it carries must have its type: a `paths` that is a string,
  or a `pattern` that is a list, used to be skipped by those guards and select
  nothing too. An explicit `paths: []` is documented as "no path selector" and
  stays valid beside a `pattern` or `uses_module`.
  """

  @common_keys ~w(paths pattern recursive type uses_module)

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

  @selector_keys ~w(paths pattern uses_module)

  # A misspelling this close to a known key (String.jaro_distance/2) is
  # suggested as that key.
  @suggestion_threshold 0.8

  @doc "The keys every rule type accepts, sorted."
  @spec common_keys() :: [String.t()]
  def common_keys, do: Enum.sort(@common_keys)

  @doc """
  The keys a rule of `type` accepts: the common keys plus its type's own,
  sorted. `type` must be one of `rule_types/0`.
  """
  @spec known_keys(atom()) :: [String.t()]
  def known_keys(type), do: Enum.sort(@common_keys ++ Map.fetch!(@keys_by_type, type))

  @doc "The rule types Anchor knows, sorted: one per shipped check."
  @spec rule_types() :: [atom()]
  def rule_types, do: @keys_by_type |> Map.keys() |> Enum.sort()

  @doc "The keys that select files, sorted."
  @spec selector_keys() :: [String.t()]
  def selector_keys, do: Enum.sort(@selector_keys)

  @doc """
  Checks a decoded rule map (string keys) of the already-validated `type`.

  Returns `:ok`, or `{:error, reason}` for the first failure of: an unknown
  key (every unknown key is named, with the known keys for `type`), a
  malformed selector, or no selector at all.
  """
  @spec validate(map(), atom()) :: :ok | {:error, String.t()}
  def validate(rule, type) when is_map(rule) do
    with :ok <- validate_keys(rule, type),
         :ok <- validate_selector_types(rule) do
      require_selector(rule)
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
    if Enum.any?(@selector_keys, &selects?(&1, Map.get(rule, &1))) do
      :ok
    else
      {:error,
       "the rule has no selector, so it would select no file; give it one of: " <>
         "paths (a non-empty list of path globs), pattern (a module-name glob), " <>
         "uses_module (a module the file uses)"}
    end
  end

  defp selects?("paths", paths), do: is_list(paths) and paths != []
  defp selects?(_key, value), do: is_binary(value)
end
