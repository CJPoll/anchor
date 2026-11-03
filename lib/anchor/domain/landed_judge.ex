defmodule Anchor.Domain.LandedJudge do
  @moduledoc """
  What the landed judge decides about a change's rules beyond the ratchet
  (DND-5658), a **Domain** module (ADR 001). Pure: the runner reads the base
  config's rules (`Anchor.Adapters.GitBase.rules/3`) and the change's config
  (loaded with unknown rule types deferred), this decides.

  `mix anchor.graph --project DIR` runs the anchor landed on the base branch
  against a pull request. A rule type new in the pull request is one that
  anchor does not know, so it cannot judge it; a rule the pull request drops
  or retypes is a check lost, which only the owner lands:

    * a base rule (by `id`) that the change no longer has: removed, a failure
      (a rename is a remove plus an add);
    * a base rule whose type the change replaces, with a type the judge knows
      or one it set aside: retyped, a failure;
    * a set-aside rule whose id the base config lacks (or that has no id): a
      FIRST LANDING note, report-only; the change's own `--base` step judges
      it.

  With no base config to compare (`nil`: no `--base`; `:absent`: none at the
  ref), every set-aside rule is a note and nothing fails. A base rule with no
  `id` cannot be followed and is not judged here.
  """

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  @doc """
  `{failures, notes}`: the removed and retyped base rules, and a note per
  set-aside rule that is new. `config` is the config path the issues name.
  """
  @spec judge(nil | :absent | [map()], [map()], [map()], String.t(), String.t() | nil) ::
          {[Violation.t()], [Violation.t()]}
  def judge(base_rules, rules, deferred, config, ref)

  def judge(base_rules, _rules, deferred, config, ref) when base_rules in [nil, :absent],
    do: {[], Enum.map(deferred, &Failures.landed_judge_first_landing(config, &1, ref))}

  def judge(base_rules, rules, deferred, config, ref) when is_list(base_rules) do
    now = ids(rules, & &1.type)
    set_aside = ids(deferred, & &1.type)
    based = base_rules |> Enum.filter(&is_binary(Map.get(&1, :id))) |> Enum.uniq_by(& &1.id)

    failures = Enum.flat_map(based, &lost(&1, now, set_aside, config, ref))
    base_ids = MapSet.new(based, & &1.id)

    notes =
      deferred
      |> Enum.reject(&(is_binary(&1.id) and MapSet.member?(base_ids, &1.id)))
      |> Enum.map(&Failures.landed_judge_first_landing(config, &1, ref))

    {failures, notes}
  end

  defp ids(rules, type) do
    for rule <- rules, is_binary(Map.get(rule, :id)), into: %{}, do: {rule.id, type.(rule)}
  end

  defp lost(%{id: id, type: base_type}, now, set_aside, config, ref) do
    case Map.fetch(now, id) do
      {:ok, ^base_type} -> []
      {:ok, type} -> [Failures.landed_judge_rule_retyped(config, id, base_type, type, ref)]
      :error -> retyped_or_removed(id, base_type, Map.fetch(set_aside, id), config, ref)
    end
  end

  defp retyped_or_removed(id, base_type, {:ok, type}, config, ref),
    do: [Failures.landed_judge_rule_retyped(config, id, base_type, type, ref)]

  defp retyped_or_removed(id, base_type, :error, config, ref),
    do: [Failures.landed_judge_rule_removed(config, id, base_type, ref)]
end
