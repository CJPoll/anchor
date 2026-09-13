defmodule Anchor.Domain.Checks.MustUseModule do
  @moduledoc """
  Pure detection for the `must_use_module` check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired AST and the `must_use_module` rules that apply to a
  file, it returns the `%Anchor.Domain.Violation{}` list for every required
  module the file does not `use`. It is side-effect-free — same AST and rules in,
  same violations out — with **zero `Credo.*`** and no IO: the mapping from
  `%Violation{}` to `Credo.Issue` stays at the Framework edge
  (`Anchor.Check.MustUseModule` via `Anchor.Check.Base`), and rule *selection*
  stays in the Manager (`Anchor.Managers.Lint`), which hands this function only
  the already-matched rules.

  The set of modules a file `use`s comes from
  `Anchor.Domain.DependencyAnalyzer.extract_uses/1`, so `use Mod, opts` counts as
  a use of `Mod` (the options are irrelevant to the requirement).
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.Violation

  @doc """
  Returns a `%Violation{}` for each required module that `ast` does not `use`.

  `rules` is the list of already-selected `must_use_module` rule maps, each
  carrying `:required_modules` (a possibly-`nil` list of module atoms). A module
  present in the file's `use`s is satisfied; every absent required module yields
  one violation, reported on line 1 with the module's inspected name as the
  trigger.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    uses = DependencyAnalyzer.extract_uses(ast)

    Enum.flat_map(rules, fn rule ->
      required = rule.required_modules || []

      required
      |> Enum.reject(&(&1 in uses))
      |> Enum.map(&build_violation/1)
    end)
  end

  defp build_violation(required_module) do
    %Violation{
      message: "Module must use #{inspect(required_module)}",
      line: 1,
      trigger: inspect(required_module)
    }
  end
end
