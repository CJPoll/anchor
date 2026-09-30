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
      bare YAML token (a leading colon is accepted), read by
      `Anchor.Check.AlphabetizedFunctions`. An unknown token fails the rule
      (DND-1265); an absent `mode` stays `nil` so the check applies its own
      default.
    * `:match` — `:reference` (default) or `:call`, coerced the same way. An
      unknown token fails the rule (DND-1265, A9).
    * `:same_context` — a boolean (default `false`) on a `no_direct_dependency`
      rule (Gap F, DND-149). When `true`, a `forbidden_patterns` match is a
      violation only if the dependency shares the checked file's own context;
      exact `forbidden_modules` matches are never scoped. See
      `Anchor.Domain.Checks.NoDependency` for the detection semantics.
    * `:forbidden_functions` — a list of `%Anchor.Domain.FunctionRef{}` (default
      `[]`) on a `no_direct_dependency` rule (DND-1267), parsed from
      `"Mod.fun"` / `"Mod.fun/arity"` tokens. A malformed token fails the rule.
    * `:allowed_callers` — a list of module atoms (default `[]`) on a
      `no_direct_dependency` rule (DND-1269): the modules exempt from the rule.
      Each entry names one module exactly; a glob, an Erlang module or a
      malformed name fails the rule (`Anchor.Domain.AllowedCallers`).
    * `:context_depth` — a positive integer (default `2`) on a
      `no_direct_dependency` rule: how many leading namespace segments define a
      "context". Inert unless `:same_context` is `true`.

  A malformed `:same_context` (non-boolean), a non-positive `:context_depth`, or
  a `same_context: true` rule with no `forbidden_patterns` to scope makes
  `parse_rule/1` return `{:error, {:invalid_rule, reason}}`, which
  `parse_config/1` propagates so a malformed rule fails the load (via
  `Anchor.Adapters.ConfigFile`) rather than becoming a silent green no-op.

  ## Failing closed (DND-1265)

  A config that names something Anchor does not know is rejected, never parsed
  into a rule that checks nothing: a missing or unknown rule `type`, an unknown
  `match` or `mode` token, a rule that is not a mapping, and a document whose
  shape is not `rules: [...]` (empty, a misspelt top-level key, a non-list
  `rules`). `Anchor.Domain.Failures` turns each rejection into the Credo issue
  the user sees.

  One level down (DND-1286), a key inside a rule that its type does not read,
  and a rule with no selector (or a selector of the wrong shape), are rejected
  too. The per-type key allowlist and the selector rule live in
  `Anchor.Domain.RuleSchema`, and nowhere else: a new rule key is added there,
  then parsed here.

  ## Module tokens (`forbidden_modules` / `required_modules`)

  Each entry is turned into the module it names. A CamelCase token
  (`"MyApp.Repo"`) is an Elixir alias and becomes the module atom `MyApp.Repo`
  via `Module.concat`. A **leading-colon** token (`":telemetry"`) names an
  Erlang/OTP module and is kept as the raw atom `:telemetry` (via
  `String.to_atom` on the un-prefixed name), so a rule can target a bare-atom
  dependency such as `:telemetry.execute(...)`.
  """

  alias Anchor.Domain.AllowedCallers
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.RuleCoverage
  alias Anchor.Domain.RuleSchema

  # `path` is where the config was read from, set by the loader (nil when the
  # config was built in memory). A run-time report about a rule sits on it.
  defstruct rules: [], path: nil

  @matches %{"call" => :call, "reference" => :reference}

  @modes %{"all" => :all, "public_only" => :public_only, "separate" => :separate}

  # The rule types are the keys of the per-type key allowlist, which holds one
  # entry per shipped check's `rule_type/0`. A drift test pins it to
  # `Anchor.checks/0`; the Domain cannot ask the (Framework) checks itself.
  @rule_types Map.new(RuleSchema.rule_types(), &{Atom.to_string(&1), &1})

  @top_level_keys ["rules"]

  @type t :: %__MODULE__{rules: [map()], path: String.t() | nil}

  @doc """
  The rule `type`s Anchor knows: one per shipped check's `rule_type/0`
  (`Anchor.checks/0`). A rule of any other type fails the load (DND-1265, A8),
  because no check would ever read it.
  """
  @spec rule_types() :: [atom()]
  def rule_types, do: Map.values(@rule_types)

  @doc """
  Builds a `%Anchor.Config{}` from a decoded YAML document.

  The document must be a mapping whose only key is `rules`, holding a list of
  rule mappings. Anything else fails with `{:error, {:invalid_config, reason}}`
  (DND-1265): an empty document (the `nil` an empty file decodes to), a missing
  or misspelt `rules` key, and a `rules` that is not a list would each
  otherwise load as zero rules and check nothing. An explicit `rules: []` is a
  deliberate empty config and loads.

  A rule that fails validation surfaces `{:error, {:invalid_rule, reason}}`,
  its reason prefixed with the rule's 1-based position (`rule 2: ...`).
  """
  def parse_config(data) when is_map(data) do
    with :ok <- validate_top_level_keys(data),
         {:ok, rules} <- fetch_rules(data),
         {:ok, parsed} <- parse_rules(rules) do
      %__MODULE__{rules: parsed}
    end
  end

  def parse_config(nil) do
    {:error, {:invalid_config, "the document is empty; it needs a `rules:` list"}}
  end

  def parse_config(data) do
    {:error,
     {:invalid_config,
      "the top level must be a mapping with a `rules:` list, got: #{inspect(data)}"}}
  end

  @doc """
  Parses a single YAML rule map (string keys) into the internal rule map
  (atom keys).

  Returns the atom-keyed rule map, or `{:error, {:invalid_rule, reason}}` when
  the rule fails validation — surfaced up through `parse_config/1` and the load
  adapter so a malformed rule never silently becomes a green no-op. Validated:
  the Gap F `same_context` / `context_depth` keys, and (DND-1265) the `type`
  (present and one of `rule_types/0`), the `match` token and the `mode` token,
  and (DND-1286) every key against its type's allowlist and the selector,
  through `Anchor.Domain.RuleSchema.validate/2`. A rule that is not a mapping is
  rejected too.
  """
  def parse_rule(rule) when is_map(rule) do
    with {:ok, type} <- parse_type(rule["type"]),
         :ok <- validate_schema(rule, type),
         :ok <- validate_new_keys(rule, type),
         {:ok, match} <- parse_match(rule["match"], type),
         {:ok, mode} <- parse_mode(rule["mode"], type) do
      build_rule(rule, type, match, mode)
    end
  end

  def parse_rule(rule) do
    {:error, {:invalid_rule, "a rule must be a mapping, got: #{inspect(rule)}"}}
  end

  defp validate_top_level_keys(data) do
    case data |> Map.keys() |> Enum.reject(&(&1 in @top_level_keys)) do
      [] ->
        :ok

      unknown ->
        {:error,
         {:invalid_config,
          "unknown top-level key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}; " <>
            "the only top-level key is `rules`"}}
    end
  end

  defp fetch_rules(%{"rules" => rules}) when is_list(rules), do: {:ok, rules}

  defp fetch_rules(%{"rules" => rules}) do
    {:error, {:invalid_config, "`rules` must be a list of rules, got: #{inspect(rules)}"}}
  end

  defp fetch_rules(_data), do: {:error, {:invalid_config, "the document has no `rules:` list"}}

  # Gap F (DND-149) / DND-1265: propagate the FIRST invalid rule, naming its
  # position, so a malformed rule fails the load (via
  # `Anchor.Adapters.ConfigFile`) instead of becoming a silent green no-op.
  defp parse_rules(rules) do
    with {:ok, parsed} <- rules |> Enum.with_index(1) |> parse_indexed_rules() do
      refuse_shared_ids(parsed)
    end
  end

  defp parse_indexed_rules(indexed_rules) do
    indexed_rules
    |> Enum.reduce_while({:ok, []}, &parse_indexed_rule/2)
    |> reverse_parsed()
  end

  # DND-1290: a parsed rule carries its 1-based position, so a run-time report
  # (`Anchor.Domain.Failures`) can name it as a load-time one does. A refused
  # rule is named by its position and, when it has one, its `id`.
  defp parse_indexed_rule({rule, index}, {:ok, acc}) do
    case parse_rule(rule) do
      {:error, {:invalid_rule, reason}} ->
        {:halt, {:error, {:invalid_rule, "#{raw_rule_label(rule, index)}: #{reason}"}}}

      parsed ->
        {:cont, {:ok, [Map.put(parsed, :index, index) | acc]}}
    end
  end

  defp raw_rule_label(%{"id" => id}, index) when is_binary(id) and id != "" do
    "rule #{index} (id: #{inspect(id)})"
  end

  defp raw_rule_label(_rule, index), do: "rule #{index}"

  defp reverse_parsed({:ok, parsed}), do: {:ok, Enum.reverse(parsed)}
  defp reverse_parsed(error), do: error

  # DND-1290 (DND-1268): an `id` names one rule, so a report or a ratchet keyed
  # on it cannot be ambiguous. Two rules sharing one fail the load.
  defp refuse_shared_ids(parsed) do
    parsed
    |> Enum.reject(&is_nil(&1.id))
    |> Enum.group_by(& &1.id, & &1.index)
    |> Enum.find(fn {_id, indexes} -> length(indexes) > 1 end)
    |> shared_id_result(parsed)
  end

  defp shared_id_result(nil, parsed), do: {:ok, parsed}

  defp shared_id_result({id, indexes}, _parsed) do
    {:error,
     {:invalid_rule,
      "rules #{join_positions(indexes)} share the id #{inspect(id)}; " <>
        "an id names one rule, so give each rule its own"}}
  end

  # "1 and 3", "1, 2 and 4".
  defp join_positions(indexes) do
    {init, [last]} = Enum.split(indexes, -1)
    Enum.join(init, ", ") <> " and #{last}"
  end

  # DND-1265 (A8): the type must name a shipped check. The lookup is a map of
  # known strings, so an arbitrary token is never turned into a new atom.
  # A leading colon is accepted, as for `match` and `mode`.
  defp parse_type(":" <> type), do: parse_type(type)

  defp parse_type(type) when is_binary(type) do
    case Map.fetch(@rule_types, type) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, {:invalid_rule, "unknown rule type #{inspect(type)}; " <> known_types()}}
    end
  end

  defp parse_type(nil), do: {:error, {:invalid_rule, "the rule has no `type`; " <> known_types()}}

  defp parse_type(type) do
    {:error,
     {:invalid_rule, "the rule type must be a string, got: #{inspect(type)}; " <> known_types()}}
  end

  # DND-1286: an unknown key inside the rule, and a rule with no selector, fail
  # the rule. The allowlist lives in `Anchor.Domain.RuleSchema`, and only there.
  defp validate_schema(rule, type) do
    case RuleSchema.validate(rule, type) do
      :ok -> :ok
      {:error, reason} -> {:error, {:invalid_rule, reason}}
    end
  end

  defp known_types do
    "known types: " <> (@rule_types |> Map.keys() |> Enum.sort() |> Enum.join(", "))
  end

  defp build_rule(rule, type, match, mode) do
    %{
      type: type,
      # DND-1290 (DND-1268): an optional name for the rule, carried into its
      # reports, and the fewest files it must select (default 1). A rule that
      # selects fewer checked nothing, or less than it says, and
      # `Anchor.Managers.Lint` reports it. `:index` (the rule's position) is
      # added by `parse_config/1`.
      id: rule["id"],
      min_files: rule["min_files"] || RuleCoverage.default_min_files(),
      # Gap D (DND-140): surface an ABSENT `paths` as `nil`, not `[]`. An empty
      # list is a valid list, which `RuleMatching`'s path clause would match and
      # then shadow the `pattern`/`uses_module` selectors with `Enum.any?([], …)`.
      # A `nil` (or `[]`) `paths` now falls through to those selectors. A present
      # list is preserved as-is.
      paths: rule["paths"],
      pattern: rule["pattern"],
      uses_module: rule["uses_module"],
      forbidden_modules: parse_modules(rule["forbidden_modules"]),
      # DND-1267: `"Mod.fun"` / `"Mod.fun/arity"` tokens, as
      # `%Anchor.Domain.FunctionRef{}`s. `RuleSchema.validate/2` has already
      # refused a malformed token, so every one parses here. Absent => `[]`.
      forbidden_functions: parse_function_refs(rule["forbidden_functions"]),
      # DND-1269: the modules exempt from a `no_direct_dependency` rule, each
      # named exactly (`Anchor.Domain.AllowedCallers`). `RuleSchema.validate/2`
      # has already refused a malformed entry. Absent => `[]` (no exemption).
      allowed_callers: parse_allowed_callers(rule["allowed_callers"]),
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
      mode: mode,
      # Gap A' (DND-142): which dependency set the `no_direct_dependency` check
      # consults — `:reference` (default, every referenced module) or `:call`
      # (only modules in call position, honoring ADR-001's Domain-router-holds-
      # atoms carve-out). Coerced from a bare YAML token by `parse_match/2`; an
      # unknown token fails the rule (DND-1265, A9).
      match: match,
      # Gap F (DND-149): scope a `no_direct_dependency` `forbidden_patterns`
      # match to the checked file's own context. `same_context` (default
      # `false`) turns scoping on; `context_depth` (default `2`) is how many
      # leading namespace segments define a context. These keys are ADDITIVE —
      # detection (A2) is unchanged here, so a rule lacking them behaves exactly
      # as today. Validation of the keys happens in `validate_new_keys/2` before
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
  # defaults applied in `build_rule/1`. `type` is the parsed type atom, so a
  # leading-colon spelling reads the same as a bare one in the message.
  defp validate_new_keys(rule, type) do
    same_context = Map.get(rule, "same_context")
    context_depth = Map.get(rule, "context_depth")
    forbidden_patterns = rule["forbidden_patterns"] || []

    cond do
      not is_nil(same_context) and not is_boolean(same_context) ->
        {:error,
         {:invalid_rule,
          "same_context must be a boolean, got: #{inspect(same_context)} " <>
            "(rule type: #{type})"}}

      not is_nil(context_depth) and not (is_integer(context_depth) and context_depth > 0) ->
        {:error,
         {:invalid_rule,
          "context_depth must be a positive integer, got: #{inspect(context_depth)} " <>
            "(rule type: #{type})"}}

      same_context == true and forbidden_patterns == [] ->
        {:error,
         {:invalid_rule,
          "same_context: true requires forbidden_patterns to scope (nothing to scope) " <>
            "(rule type: #{type})"}}

      true ->
        :ok
    end
  end

  defp parse_function_refs(nil), do: []

  defp parse_function_refs(tokens) do
    Enum.map(tokens, fn token ->
      {:ok, ref} = FunctionRef.parse(token)
      ref
    end)
  end

  defp parse_allowed_callers(nil), do: []

  defp parse_allowed_callers(tokens) do
    Enum.map(tokens, fn token ->
      {:ok, module} = AllowedCallers.parse(token)
      module
    end)
  end

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

  # BUG 2: `mode` arrives as a bare YAML token (a string), not an atom. An absent
  # `mode` stays `nil` so the check applies its own default. DND-1265: an
  # unknown token fails the rule; it used to fall back to `:separate`, which is
  # also what the README's own `mode: :all` (the string ":all") silently became.
  # A leading colon is accepted, so the README's spelling means what it says.
  defp parse_mode(nil, _type), do: {:ok, nil}
  defp parse_mode(token, type), do: parse_token("mode", token, @modes, type)

  # Gap A' (DND-142): `match` arrives as a bare YAML token (a string). An absent
  # `match` defaults to `:reference`. DND-1265 (A9): an unknown token fails the
  # rule instead of falling back to `:reference`. A leading colon is accepted.
  defp parse_match(nil, _type), do: {:ok, :reference}
  defp parse_match(token, type), do: parse_token("match", token, @matches, type)

  defp parse_token(key, ":" <> token, known, type), do: parse_token(key, token, known, type)

  defp parse_token(key, token, known, type) do
    case Map.fetch(known, token) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error,
         {:invalid_rule,
          "unknown #{key} #{inspect(token)} (rule type: #{type}); expected one of: " <>
            (known |> Map.keys() |> Enum.sort() |> Enum.join(", "))}}
    end
  end
end
