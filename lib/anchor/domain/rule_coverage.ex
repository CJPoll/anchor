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
  alias Anchor.Domain.RuleSchema

  @default_min_files 1

  @doc """
  The AST-engine rules in `rules` that select fewer files than their floor,
  among the files described by `facts`, each with the number it selected.

  A graph-engine rule (DND-5437) selects modules, not files, and its floor
  (`min_modules`) is judged by `mix anchor.graph` (DND-5440), so it is never
  reported here. `engine_of` gives a type's engine (default: RuleSchema's; a
  type RuleSchema does not know is read as `:ast`, so it is still judged).
  """
  @spec below_floor([map()], [RuleMatching.facts()], (atom() -> RuleSchema.engine())) ::
          [{map(), non_neg_integer()}]
  def below_floor(rules, facts, engine_of \\ &engine/1) do
    rules
    |> ast_rules(engine_of)
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
  already reported. A graph-engine rule is never reported here (as with
  `below_floor/3`).
  """
  @spec missing_allowed_callers(
          [map()],
          [RuleMatching.facts()],
          (atom() -> RuleSchema.engine())
        ) :: [{map(), [module()]}]
  def missing_allowed_callers(rules, facts, engine_of \\ &engine/1) do
    for rule <- ast_rules(rules, engine_of),
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

  @doc """
  The AST-engine rules in `rules` whose type is not one of `enabled_types`.

  A graph-engine rule (DND-5437) is run by `mix anchor.graph`, never by a Credo
  check, so no enabled check reading it is not a gap and it is never reported
  here. `engine_of` gives a type's engine; it defaults to
  `Anchor.Domain.RuleSchema.engine/1`.
  """
  @spec unchecked([map()], [atom()], (atom() -> RuleSchema.engine())) :: [map()]
  def unchecked(rules, enabled_types, engine_of \\ &RuleSchema.engine/1) do
    Enum.reject(rules, &(engine_of.(&1.type) == :graph or &1.type in enabled_types))
  end

  defp ast_rules(rules, engine_of), do: Enum.reject(rules, &(engine_of.(&1.type) == :graph))

  # RuleSchema raises for a type it does not know; such a rule is no graph
  # rule, so it is judged like any AST rule.
  defp engine(type) do
    if type in RuleSchema.rule_types(), do: RuleSchema.engine(type), else: :ast
  end

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
