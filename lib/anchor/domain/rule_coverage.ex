defmodule Anchor.Domain.RuleCoverage do
  @moduledoc """
  Which rules checked nothing in a run, decided from facts the run already has
  — a **Domain** module (ADR 001). Pure: it reads parsed rule maps and the
  per-file facts `Anchor.Domain.RuleMatching` selects on, and does no IO.

  `Anchor.Domain.RuleSchema` refuses, at load, every rule that would check
  nothing whatever the files are. Two members of that class depend on the run,
  so they are decided here (DND-1290, folding in DND-1268):

    * **A selector that selects too few files.** A rule's floor is its
      `min_files` (default 1). A rule that selects fewer of the files its check
      ran on checked nothing (0), or less than it says. A moved directory used
      to turn a `paths` rule into a silent no-op this way.
    * **A rule whose type no enabled check reads.** Credo runs only the checks
      `.credo.exs` enables, so a rule of any other type is never read.
  """

  alias Anchor.Domain.RuleMatching

  @default_floor 1

  @doc """
  The rules in `rules` that select fewer files than their floor, among the files
  described by `facts`, each with the number it selected.
  """
  @spec below_floor([map()], [RuleMatching.facts()]) :: [{map(), non_neg_integer()}]
  def below_floor(rules, facts) do
    rules
    |> Enum.map(
      &{&1, Enum.count(facts, fn file -> RuleMatching.rule_matches_file?(&1, file) end)}
    )
    |> Enum.filter(fn {rule, selected} -> selected < min_files(rule) end)
  end

  @doc "The fewest files `rule` must select: its `min_files`, or 1."
  @spec min_files(map()) :: pos_integer()
  def min_files(rule), do: Map.get(rule, :min_files) || @default_floor

  @doc "The rules in `rules` whose type is not one of `enabled_types`."
  @spec unchecked([map()], [atom()]) :: [map()]
  def unchecked(rules, enabled_types), do: Enum.reject(rules, &(&1.type in enabled_types))
end
