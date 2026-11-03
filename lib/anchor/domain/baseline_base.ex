defmodule Anchor.Domain.BaselineBase do
  @moduledoc """
  Finds a rule's baseline at the `--base` ref by the rule's id (DND-5629) — a
  **Domain** module (ADR 001). Pure: the runner reads the base config's graph
  rules through `Anchor.Adapters.GitBase.rules/3`, this decides.

  GREW compares a rule's baseline with its copy at the ref. Found by the
  branch's `baseline:` path, a renamed path was absent at the ref, so every
  entry read as a first landing and the list could grow unchecked. Found by
  the rule's `id` in the base config instead:

    * the rule had a `baseline:` there: `{:path, path}`, its path at the ref,
      whatever the branch calls it now;
    * the rule was there with no `baseline:`: `:no_baseline`, compared with
      an empty baseline, so every entry is GREW;
    * no rule had that id there, or there was no config: `:new_rule`, a first
      landing, printed loudly with the id (`gone/2` names the ids that had a
      baseline at the ref and are not rules now, so a renamed id, a remove
      plus an add, shows review both).
  """

  @type located :: {:path, String.t()} | :no_baseline | :new_rule

  @doc "Where rule `id`'s baseline was at the ref; see the moduledoc."
  @spec locate(:absent | [map()], String.t()) :: located()
  def locate(:absent, _id), do: :new_rule

  def locate(base_rules, id) when is_list(base_rules) do
    case Enum.find(base_rules, &(Map.get(&1, :id) == id)) do
      nil -> :new_rule
      %{baseline: path} when is_binary(path) -> {:path, path}
      %{} -> :no_baseline
    end
  end

  @doc """
  The ids of the rules that had a `baseline:` at the ref and are not among
  `rules` now, sorted.
  """
  @spec gone(:absent | [map()], [map()]) :: [String.t()]
  def gone(:absent, _rules), do: []

  def gone(base_rules, rules) do
    now = MapSet.new(rules, &Map.get(&1, :id))

    base_rules
    |> Enum.filter(&(is_binary(Map.get(&1, :baseline)) and not MapSet.member?(now, &1[:id])))
    |> Enum.map(& &1.id)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
