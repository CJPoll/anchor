defmodule Anchor.Config do
  @moduledoc """
  Parsed Anchor configuration — a **Domain** module (ADR 001).

  This module is pure: it turns an already-decoded YAML map (string keys, as
  produced by a YAML parser) into the internal `%Anchor.Config{}` struct and its
  atom-keyed rule maps. It performs **no IO** — no file reads, no YAML decoding.
  Reading `.anchor.yml` off disk and decoding it is the job of the Side Effect
  adapter `Anchor.Adapters.ConfigFile`, which calls into this module.

  ## Rule fields surfaced

  Each rule map exposes atom keys consumed by the checks. In addition to the
  selector/relationship fields, this module surfaces (BUG 2 fix):

    * `:paths` — the list of path globs, or `nil` when the rule omits `paths`
      (Gap D fix, DND-140). An absent `paths` is surfaced as `nil` rather than
      `[]` so a `pattern`/`uses_module`-selected rule is not shadowed by
      `Anchor.Domain.RuleMatching`'s path clause. A present list is kept as-is.
    * `:max_lines` — an integer (or `nil` when absent) read by
      `Anchor.Check.MaxFileLength`.
    * `:mode` — an atom (`:all` / `:public_only` / `:separate`), coerced from a
      bare YAML token, read by `Anchor.Check.AlphabetizedFunctions`. An unknown
      token coerces to `:separate`; an absent `mode` stays `nil` so the check
      applies its own default.
    * `:same_context` — a boolean (default `false`) on a `no_direct_dependency`
      rule (Gap F, DND-149). When `true`, a `forbidden_patterns` match is a
      violation only if the dependency shares the checked file's own context;
      exact `forbidden_modules` matches are never scoped. See
      `Anchor.Domain.Checks.NoDependency` for the detection semantics.
    * `:context_depth` — a positive integer (default `2`) on a
      `no_direct_dependency` rule: how many leading namespace segments define a
      "context". Inert unless `:same_context` is `true`.

  A malformed `:same_context` (non-boolean), a non-positive `:context_depth`, or
  a `same_context: true` rule with no `forbidden_patterns` to scope makes
  `parse_rule/1` return `{:error, {:invalid_rule, reason}}`, which
  `parse_config/1` propagates so a malformed rule fails the load (via
  `Anchor.Adapters.ConfigFile`) rather than becoming a silent green no-op.

  ## Module tokens (`forbidden_modules` / `required_modules`)

  Each entry is turned into the module it names. A CamelCase token
  (`"MyApp.Repo"`) is an Elixir alias and becomes the module atom `MyApp.Repo`
  via `Module.concat`. A **leading-colon** token (`":telemetry"`) names an
  Erlang/OTP module and is kept as the raw atom `:telemetry` (via
  `String.to_atom` on the un-prefixed name), so a rule can target a bare-atom
  dependency such as `:telemetry.execute(...)`.
  """

  defstruct rules: []

  @type t :: %__MODULE__{rules: [map()]}

  @doc """
  Builds a `%Anchor.Config{}` from a decoded YAML document.

  A map is read for its `"rules"` list; anything else (for example the `nil` an
  empty document decodes to) yields an empty config.
  """
  def parse_config(data) when is_map(data) do
    rules = Map.get(data, "rules", [])
    parsed = Enum.map(rules, &parse_rule/1)

    # Gap F (DND-149): a rule that fails validation surfaces `{:error, reason}`
    # from `parse_rule/1`. Propagate the FIRST such error so a malformed rule
    # fails the load (via `Anchor.Adapters.ConfigFile`) instead of becoming a
    # silent green no-op. A document of only valid rules yields a `%Config{}`.
    case Enum.find(parsed, &match?({:error, _}, &1)) do
      nil -> %__MODULE__{rules: parsed}
      {:error, _reason} = error -> error
    end
  end

  def parse_config(_data), do: %__MODULE__{}

  @doc """
  Parses a single YAML rule map (string keys) into the internal rule map
  (atom keys).

  Returns the atom-keyed rule map, or `{:error, {:invalid_rule, reason}}` when
  the rule fails validation of the Gap F (`same_context` / `context_depth`)
  keys — surfaced up through `parse_config/1` and the load adapter so a
  malformed rule never silently becomes a green no-op.
  """
  def parse_rule(rule) when is_map(rule) do
    with :ok <- validate_new_keys(rule) do
      build_rule(rule)
    end
  end

  defp build_rule(rule) do
    %{
      type: rule["type"] |> to_string() |> String.to_atom(),
      # Gap D (DND-140): surface an ABSENT `paths` as `nil`, not `[]`. An empty
      # list is a valid list, which `RuleMatching`'s path clause would match and
      # then shadow the `pattern`/`uses_module` selectors with `Enum.any?([], …)`.
      # A `nil` (or `[]`) `paths` now falls through to those selectors. A present
      # list is preserved as-is.
      paths: rule["paths"],
      pattern: rule["pattern"],
      uses_module: rule["uses_module"],
      forbidden_modules: parse_modules(rule["forbidden_modules"]),
      required_modules: parse_modules(rule["required_modules"]),
      # Gap A (DND-142): module-name globs (e.g. `"*.Adapters.*"`), matched with
      # `Anchor.Domain.GlobPattern.matches_module_pattern?/2`. Absent ⇒ `[]`.
      # Patterns are strings (not run through `parse_modules`, unlike
      # `forbidden_modules`/`required_modules`), so a leading-colon token here is
      # a literal glob character, not an Erlang-atom module token.
      forbidden_patterns: rule["forbidden_patterns"] || [],
      allowed_functions: rule["allowed_functions"] || [],
      recursive: rule["recursive"] || false,
      max_lines: rule["max_lines"],
      mode: parse_mode(rule["mode"]),
      # Gap A' (DND-142): which dependency set the `no_direct_dependency` check
      # consults — `:reference` (default, every referenced module) or `:call`
      # (only modules in call position, honoring ADR-001's Domain-router-holds-
      # atoms carve-out). Coerced from a bare YAML token; an unknown token falls
      # back to `:reference` WITHOUT raising.
      match: parse_match(rule["match"]),
      # Gap F (DND-149): scope a `no_direct_dependency` `forbidden_patterns`
      # match to the checked file's own context. `same_context` (default
      # `false`) turns scoping on; `context_depth` (default `2`) is how many
      # leading namespace segments define a context. These keys are ADDITIVE —
      # detection (A2) is unchanged here, so a rule lacking them behaves exactly
      # as today. Validation of the keys happens in `validate_new_keys/1` before
      # this map is built.
      same_context: Map.get(rule, "same_context", false),
      context_depth: Map.get(rule, "context_depth", 2)
    }
  end

  # Gap F (DND-149): validate the two new keys BEFORE building the rule map, so a
  # malformed rule surfaces `{:error, {:invalid_rule, reason}}` rather than a map
  # that would be a silent no-op. Order: type of `same_context`, then
  # positivity of `context_depth`, then the "same_context true needs something to
  # scope" cross-check. An absent `same_context`/`context_depth` is valid and
  # defaults applied in `build_rule/1`.
  defp validate_new_keys(rule) do
    same_context = Map.get(rule, "same_context")
    context_depth = Map.get(rule, "context_depth")
    forbidden_patterns = rule["forbidden_patterns"] || []

    cond do
      not is_nil(same_context) and not is_boolean(same_context) ->
        {:error,
         {:invalid_rule,
          "same_context must be a boolean, got: #{inspect(same_context)} " <>
            "(rule type: #{rule_type(rule)})"}}

      not is_nil(context_depth) and not (is_integer(context_depth) and context_depth > 0) ->
        {:error,
         {:invalid_rule,
          "context_depth must be a positive integer, got: #{inspect(context_depth)} " <>
            "(rule type: #{rule_type(rule)})"}}

      same_context == true and forbidden_patterns == [] ->
        {:error,
         {:invalid_rule,
          "same_context: true requires forbidden_patterns to scope (nothing to scope) " <>
            "(rule type: #{rule_type(rule)})"}}

      true ->
        :ok
    end
  end

  defp rule_type(rule), do: rule["type"] || "unknown"

  defp parse_modules(nil), do: []

  defp parse_modules(modules) when is_list(modules) do
    Enum.map(modules, &parse_module_token/1)
  end

  # A leading-colon YAML token names an Erlang/OTP module (`":telemetry"`), which
  # must stay a RAW atom — `Module.concat` would mangle it into `Elixir.telemetry`
  # and it would never match the bare-atom dependency the analyzer records. An
  # ordinary CamelCase token (`"MyApp.Repo"`) is an Elixir alias and still goes
  # through `Module.concat`.
  defp parse_module_token(":" <> rest) when byte_size(rest) > 0, do: String.to_atom(rest)
  defp parse_module_token(token), do: Module.concat([token])

  # BUG 2: `mode` arrives as a bare YAML token (a string), not a colon-prefixed
  # atom. Coerce the known tokens; fall back to `:separate` for an unknown
  # token, and leave an absent `mode` as `nil` so the check applies its default.
  defp parse_mode(nil), do: nil
  defp parse_mode("all"), do: :all
  defp parse_mode("public_only"), do: :public_only
  defp parse_mode("separate"), do: :separate
  defp parse_mode(_token), do: :separate

  # Gap A' (DND-142): `match` arrives as a bare YAML token (a string). Coerce the
  # two known tokens; an absent `match` and any unknown token both default to
  # `:reference` (current behavior), never raising.
  defp parse_match("call"), do: :call
  defp parse_match("reference"), do: :reference
  defp parse_match(_token), do: :reference
end
