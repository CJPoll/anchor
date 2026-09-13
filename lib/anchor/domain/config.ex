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

    * `:max_lines` — an integer (or `nil` when absent) read by
      `Anchor.Check.MaxFileLength`.
    * `:mode` — an atom (`:all` / `:public_only` / `:separate`), coerced from a
      bare YAML token, read by `Anchor.Check.AlphabetizedFunctions`. An unknown
      token coerces to `:separate`; an absent `mode` stays `nil` so the check
      applies its own default.

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
    %__MODULE__{rules: Enum.map(rules, &parse_rule/1)}
  end

  def parse_config(_data), do: %__MODULE__{}

  @doc """
  Parses a single YAML rule map (string keys) into the internal rule map
  (atom keys).
  """
  def parse_rule(rule) when is_map(rule) do
    %{
      type: rule["type"] |> to_string() |> String.to_atom(),
      paths: rule["paths"] || [],
      pattern: rule["pattern"],
      uses_module: rule["uses_module"],
      forbidden_modules: parse_modules(rule["forbidden_modules"]),
      required_modules: parse_modules(rule["required_modules"]),
      allowed_functions: rule["allowed_functions"] || [],
      recursive: rule["recursive"] || false,
      max_lines: rule["max_lines"],
      mode: parse_mode(rule["mode"])
    }
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

  # BUG 2: `mode` arrives as a bare YAML token (a string), not a colon-prefixed
  # atom. Coerce the known tokens; fall back to `:separate` for an unknown
  # token, and leave an absent `mode` as `nil` so the check applies its default.
  defp parse_mode(nil), do: nil
  defp parse_mode("all"), do: :all
  defp parse_mode("public_only"), do: :public_only
  defp parse_mode("separate"), do: :separate
  defp parse_mode(_token), do: :separate
end
