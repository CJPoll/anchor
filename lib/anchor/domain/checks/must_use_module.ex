defmodule Anchor.Domain.Checks.MustUseModule do
  @moduledoc """
  Pure detection for the `must_use_module` check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired AST and the `must_use_module` rules that apply to a
  file, it returns the `%Anchor.Domain.Violation{}` list for every required
  module the file does not `use`, and one when a rule's `required_any_of_modules`
  has no alternative the file `use`s. It is side-effect-free — same AST and rules in,
  same violations out — with **zero `Credo.*`** and no IO: the mapping from
  `%Violation{}` to `Credo.Issue` stays at the Framework edge
  (`Anchor.Check.MustUseModule` via `Anchor.Check.Base`), and rule *selection*
  stays in the Manager (`Anchor.Managers.Lint`), which hands this function only
  the already-matched rules.

  The set of modules a file `use`s comes from
  `Anchor.Domain.DependencyAnalyzer.extract_uses/1`, so `use Mod, opts` counts as
  a use of `Mod` (the options are irrelevant to the requirement).
  """

  use Anchor.Domain.Detector

  @doc "The rule type this detector reads (DND-8063)."
  @impl Anchor.Domain.Detector
  def rule_type, do: :must_use_module

  @doc "Detects one file's `%Anchor.Domain.Detector.Input{}` (DND-8063)."
  @impl Anchor.Domain.Detector
  def detect(%Anchor.Domain.Detector.Input{} = input),
    do: detect_violations(input.ast, input.rules)

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @impl Anchor.Domain.RuleShape
  def shape(rule) do
    case Map.get(rule, :required_any_of_modules) || [] do
      [] ->
        "use #{names(Map.get(rule, :required_modules) || [])} in the module's own defmodule body"

      any_of ->
        "use one of #{names(any_of)} in the module's own defmodule body"
    end
  end

  defp names(modules), do: Enum.map_join(modules, ", ", &inspect/1)

  @doc """
  Returns a `%Violation{}` for each required module that `ast` does not `use`.

  `rules` is the list of already-selected `must_use_module` rule maps, each
  carrying `:required_modules` (a possibly-`nil` list of module atoms: the file
  must use every one) and/or `:required_any_of_modules` (a possibly-`nil` list:
  the file must use at least one). A module present in the file's `use`s is
  satisfied; every absent required module yields one violation, reported on
  line 1 with the module's inspected name as the trigger. When none of the
  any-of alternatives is used, one violation names every accepted alternative
  (message `Module must use one of A, B`, trigger `A | B`).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    uses = DependencyAnalyzer.extract_uses(ast)

    Enum.flat_map(rules, fn rule ->
      every_of_violations(rule, uses) ++ any_of_violations(rule, uses)
    end)
  end

  defp every_of_violations(rule, uses) do
    (Map.get(rule, :required_modules) || [])
    |> Enum.reject(&(&1 in uses))
    |> Enum.map(&RuleShapes.with_shape(build_violation(&1), shape(rule)))
  end

  defp any_of_violations(rule, uses) do
    any_of = Map.get(rule, :required_any_of_modules) || []

    if any_of == [] or Enum.any?(any_of, &(&1 in uses)) do
      []
    else
      [RuleShapes.with_shape(build_any_of_violation(any_of), shape(rule))]
    end
  end

  defp build_any_of_violation(any_of) do
    %Violation{
      message: "Module must use one of #{names(any_of)}",
      line: 1,
      trigger: Enum.map_join(any_of, " | ", &inspect/1)
    }
  end

  defp build_violation(required_module) do
    %Violation{
      message: "Module must use #{inspect(required_module)}",
      line: 1,
      trigger: inspect(required_module)
    }
  end
end
