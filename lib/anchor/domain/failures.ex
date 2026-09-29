defmodule Anchor.Domain.Failures do
  @moduledoc """
  The reports Anchor makes when it could not check something — a **Domain**
  module (ADR 001). Pure: it turns a failure reason into a
  `%Anchor.Domain.Violation{kind: :fail_closed}` and does no IO.

  Anchor fails closed (DND-1265). A run that checked nothing must never read
  the same as a run that found nothing, so each of these is a Credo issue:

    * **No `.anchor.yml`** — `{:config_not_found, searched}`. The issue names
      every candidate path the lookup searched, and sits on the first one.
    * **A config that did not load** — `{:config_load_failed, path, detail}`,
      where `detail` is `{:read, posix}`, `{:yaml, message}`,
      `{:invalid_rule, message}` or `{:invalid_config, message}`. The issue sits
      on `path` and says what failed.
    * **A source file Anchor could not parse** — `unparseable_violation/2`,
      on that file at the parser's line.
    * **A rule that selected fewer files than its floor** (DND-1290) —
      `selection_floor_violation/4`, on the config the rule came from.
    * **A rule no enabled check reads** (DND-1290) —
      `unchecked_rule_violation/3`, on the config the rule came from.

  A rule is named as `rule_label/1` names it: its position and, when it has
  one, its `id` (`rule 2 (id: "web", no_direct_dependency)`).

  Every message says what was searched or what failed, that no Anchor rule was
  checked because of it, and ends with a `Fix:` line. A reason of a shape this
  module does not recognise is still reported (a config loader is a behaviour,
  so a new loader can return anything); it is never dropped.
  """

  alias Anchor.Domain.RuleCoverage
  alias Anchor.Domain.Violation

  @config_filename ".anchor.yml"
  @schema_pointer "the README section \"Config schema: rule keys at a glance\" and its " <>
                    "table \"Keys each rule type accepts\""

  @type config_reason ::
          {:config_not_found, [String.t()]}
          | {:config_load_failed, String.t(), term()}
          | term()

  @doc """
  Builds the violation for a config that could not be found or loaded.
  """
  @spec config_violation(config_reason()) :: Violation.t()
  def config_violation({:config_not_found, [first | _rest] = searched}) do
    fail_closed(
      first,
      "Anchor found no #{@config_filename}, so no Anchor rule was checked. " <>
        "Searched: #{Enum.join(searched, ", ")}. " <>
        "Fix: create #{@config_filename} at one of the searched paths (the project root, or the " <>
        "umbrella root), or run credo from the directory that holds it."
    )
  end

  def config_violation({:config_load_failed, path, detail}) when is_binary(path) do
    fail_closed(path, load_failed_message(path, detail))
  end

  def config_violation(reason) do
    fail_closed(
      @config_filename,
      "Anchor could not load its configuration (#{inspect(reason)}), so no Anchor rule was " <>
        "checked. Fix: make #{@config_filename} load; the reason above names what failed."
    )
  end

  @doc """
  Builds the violation for a source file Anchor could not parse, at the
  parser's `line` (or `nil`) with the parser's `message`. It sits on the file
  the check ran on (`filename: nil`).
  """
  @spec unparseable_violation(pos_integer() | nil, String.t()) :: Violation.t()
  def unparseable_violation(line, message) do
    %Violation{
      line: line,
      trigger: nil,
      kind: :fail_closed,
      message:
        "Anchor could not parse this file, so no Anchor rule was checked against it: " <>
          "#{message}. Fix: correct the syntax error (`mix compile` reports it too)."
    }
  end

  @doc """
  Builds the violation for a rule that selected fewer files than its floor
  (`min_files`, default 1) among the `file_count` files its check ran on
  (DND-1290). It sits on the config the rule came from, `config_path` (or
  `.anchor.yml` when the config was not read from a file).
  """
  @spec selection_floor_violation(map(), non_neg_integer(), non_neg_integer(), String.t() | nil) ::
          Violation.t()
  def selection_floor_violation(rule, selected, file_count, config_path) do
    floor = RuleCoverage.min_files(rule)
    config = config_path || @config_filename

    rule_violation(
      rule,
      config,
      "Anchor #{rule_label(rule)} selected #{selected} of the #{files(file_count)} this " <>
        "check ran on, below its floor of #{floor} (min_files), so it " <>
        "#{shortfall(selected)}. Fix: correct its selector (paths, pattern or uses_module) " <>
        "in #{config} so it selects the files it is meant to check#{lower_floor(selected)}, " <>
        "or remove the rule."
    )
  end

  @doc """
  Builds the violation for a rule whose type no enabled Credo check reads
  (DND-1290), naming `check`, the Anchor check that would read it.
  """
  @spec unchecked_rule_violation(map(), module() | nil, String.t() | nil) :: Violation.t()
  def unchecked_rule_violation(rule, check, config_path) do
    config = config_path || @config_filename

    rule_violation(
      rule,
      config,
      "Anchor #{rule_label(rule)} is not checked: no enabled Credo check reads " <>
        "#{rule.type} rules, so it checked nothing. Fix: enable #{check_name(check, rule)} " <>
        "in .credo.exs, or remove the rule from #{config}."
    )
  end

  @doc """
  Names a parsed rule the way a load error does: `rule 2 (id: "web", type)`, or
  `rule 2 (type)` without an id. A rule built in memory has no position.
  """
  @spec rule_label(map()) :: String.t()
  def rule_label(rule) do
    position = if index = Map.get(rule, :index), do: "rule #{index}", else: "rule"

    case Map.get(rule, :id) do
      nil -> "#{position} (#{rule.type})"
      id -> "#{position} (id: #{inspect(id)}, #{rule.type})"
    end
  end

  defp files(1), do: "1 file"
  defp files(count), do: "#{count} files"

  defp shortfall(0), do: "checked nothing"
  defp shortfall(_selected), do: "checked fewer files than it requires"

  defp lower_floor(0), do: ""
  defp lower_floor(_selected), do: " (or, if fewer files is now right, lower min_files)"

  defp check_name(nil, rule), do: "the Anchor check whose rule_type is #{rule.type}"
  defp check_name(check, _rule), do: inspect(check)

  defp rule_violation(rule, config, message) do
    %Violation{
      filename: config,
      line: nil,
      trigger: rule_label(rule),
      kind: :fail_closed,
      message: message
    }
  end

  defp fail_closed(filename, message) do
    %Violation{
      filename: filename,
      line: nil,
      trigger: @config_filename,
      kind: :fail_closed,
      message: message
    }
  end

  defp load_failed_message(path, {:read, posix}) do
    "Anchor could not read #{path} (#{inspect(posix)}), so no Anchor rule was checked. " <>
      "Fix: make #{path} a readable file."
  end

  defp load_failed_message(path, {:yaml, message}) do
    "Anchor could not parse #{path} as YAML, so no Anchor rule was checked: #{message}. " <>
      "Fix: correct the YAML syntax in #{path}."
  end

  defp load_failed_message(path, {kind, message}) when kind in [:invalid_rule, :invalid_config] do
    "Anchor rejected #{path}, so no Anchor rule was checked: #{message}. " <>
      "Fix: correct #{path} to match #{@schema_pointer}."
  end

  defp load_failed_message(path, detail) do
    "Anchor could not load #{path} (#{inspect(detail)}), so no Anchor rule was checked. " <>
      "Fix: correct #{path} to match #{@schema_pointer}."
  end
end
