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
    * **An allowed caller that no longer exists** (DND-1269). An
      `allowed_callers` entry that no selected file defines allows nothing
      today, and silently allows whatever module is given that name later, so a
      rename or a move would widen the rule with no config change.

  A file that did not parse has facts with `parsed?: false`: its path, but no
  module names or uses. A `paths` rule is counted against its path as usual.
  A `pattern` or `uses_module` rule cannot be read off it, so the file counts
  as one it may select: the parse failure is already reported, and a floor
  report telling the user to fix the selector would be wrong advice.
  """

  alias Anchor.Domain.AllowedCallers
  alias Anchor.Domain.RuleMatching

  @default_min_files 1

  @doc """
  The rules in `rules` that select fewer files than their floor, among the files
  described by `facts`, each with the number it selected.
  """
  @spec below_floor([map()], [RuleMatching.facts()]) :: [{map(), non_neg_integer()}]
  def below_floor(rules, facts) do
    rules
    |> Enum.map(&{&1, Enum.count(facts, fn file -> may_select?(&1, file) end)})
    |> Enum.filter(fn {rule, selected} -> selected < min_files(rule) end)
  end

  @doc """
  The rules in `rules` that list an allowed caller no file they select defines,
  each with those callers in the order the rule lists them (DND-1269).

  A file's defined modules are its facts' `:defined_modules`
  (`Anchor.Domain.DependencyAnalyzer.defined_modules/1`). A rule that selects
  no file is left to `below_floor/2`. A rule that may select an unparsed file
  is not reported: that file's modules are unknown, and its parse failure is
  already reported.
  """
  @spec missing_allowed_callers([map()], [RuleMatching.facts()]) :: [{map(), [module()]}]
  def missing_allowed_callers(rules, facts) do
    for rule <- rules,
        allowed = Map.get(rule, :allowed_callers) || [],
        allowed != [],
        selected = Enum.filter(facts, &may_select?(rule, &1)),
        selected != [] and not Enum.any?(selected, &unparsed?/1),
        missing = AllowedCallers.missing(allowed, Enum.flat_map(selected, &defined_modules/1)),
        missing != [],
        do: {rule, missing}
  end

  @doc "The floor a rule gets when it names no `min_files`."
  @spec default_min_files() :: pos_integer()
  def default_min_files, do: @default_min_files

  @doc "The fewest files `rule` must select: its `min_files`, or the default."
  @spec min_files(map()) :: pos_integer()
  def min_files(rule), do: Map.get(rule, :min_files) || @default_min_files

  @doc "The rules in `rules` whose type is not one of `enabled_types`."
  @spec unchecked([map()], [atom()]) :: [map()]
  def unchecked(rules, enabled_types), do: Enum.reject(rules, &(&1.type in enabled_types))

  defp may_select?(rule, %{parsed?: false} = file) do
    RuleMatching.rule_matches_file?(rule, file) or not path_selected?(rule)
  end

  defp may_select?(rule, file), do: RuleMatching.rule_matches_file?(rule, file)

  defp path_selected?(rule), do: match?([_ | _], Map.get(rule, :paths))

  defp unparsed?(file), do: Map.get(file, :parsed?, true) == false

  # A parsed file's facts carry `:defined_modules` whenever the run has a rule
  # with allowed callers (`Anchor.Managers.Lint`). Absent, the file defines
  # nothing here, so every caller reads as missing: loud, never silent.
  defp defined_modules(file), do: Map.get(file, :defined_modules, [])
end
