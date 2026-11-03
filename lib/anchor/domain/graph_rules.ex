defmodule Anchor.Domain.GraphRules do
  @moduledoc """
  The registry of graph rules and what each rule selects (DND-5440, shared
  contract section 6) — a **Domain** module (ADR 001). Pure.

  `all/0` lists every module implementing `Anchor.Domain.GraphRule`. No graph
  rule type ships with the runner itself: the rule tickets (layering,
  interfaces, context_acyclic, struct flow, ...) each add their module here
  and their type to `Anchor.Domain.RuleSchema` with engine `:graph`. A test
  holds the two sets equal, so a graph type with no module (scheduled but
  never run) or a module with no type (never loadable) fails the suite.

  ## Selecting and floors

  A graph rule selects modules by exactly one of:

    * `bucket` — the modules classified into that `architecture:` bucket;
    * `paths` — source-path globs (`**` always recursive), over each
      classified module's repo-relative source file;
    * `pattern` — a module-name glob, over each classified module's name.

  Globs go through `Anchor.Domain.GlobPattern` only. `below_floor/2` reports
  each rule that selects fewer modules than its `min_modules` (default 1): a
  rule selecting nothing checks nothing, and must not read as a pass.

  ## Needs

  `needs/1` reads a rule module's optional `needs/0`
  (`Anchor.Domain.GraphRule`): what the runner must compute before the rule's
  `check/2`. A need the runner does not compute, or a return that is not a
  list, raises, so a rule asking for something it would never get is reported
  (the runner reads it under the rule's guard), never run without it.
  """

  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Model

  @default_min_modules 1

  # What the runner computes on demand (`Anchor.Managers.Graph`).
  @provided_needs [:cfa]

  # Every module implementing `Anchor.Domain.GraphRule`. The rule tickets add
  # theirs here (see the moduledoc).
  @rules []

  @doc "Every graph rule module."
  @spec all() :: [module()]
  def all, do: @rules

  @doc "The rule types `modules` check, as `%{type => module}`."
  @spec by_type([module()]) :: %{atom() => module()}
  def by_type(modules), do: Map.new(modules, &{&1.rule_type(), &1})

  @doc "The fewest modules `rule` must select: its `min_modules`, or #{@default_min_modules}."
  @spec min_modules(map()) :: pos_integer()
  def min_modules(rule), do: Map.get(rule, :min_modules) || @default_min_modules

  @doc """
  The analyses `module` needs (its `needs/0`, or `[]` when it has none),
  without duplicates. Raises `ArgumentError` with a `Fix:` when it names one
  the runner does not compute (#{inspect(@provided_needs)}) or is not a list.
  """
  @spec needs(module()) :: [:cfa]
  def needs(module) do
    module
    |> declared_needs()
    |> provided_needs!(module)
  end

  @doc """
  The modules `rule` selects among the model's classified modules, sorted. A
  rule with none of `bucket`, `paths` or `pattern` selects none (the loader
  refuses such a rule; here it reads as empty and so falls below its floor).
  """
  @spec select(Model.t(), map()) :: [module()]
  def select(%Model{classification: classification}, rule) do
    classification
    |> Map.values()
    |> Enum.filter(&selects?(rule, &1))
    |> Enum.map(& &1.module)
    |> Enum.sort()
  end

  @doc "Each rule of `rules` that selects fewer modules than its floor, with the number it selected."
  @spec below_floor(Model.t(), [map()]) :: [{map(), non_neg_integer()}]
  def below_floor(%Model{} = model, rules) do
    rules
    |> Enum.map(&{&1, length(select(model, &1))})
    |> Enum.filter(fn {rule, selected} -> selected < min_modules(rule) end)
  end

  defp declared_needs(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :needs, 0),
      do: module.needs(),
      else: []
  end

  defp provided_needs!(needs, module) when is_list(needs) do
    case Enum.reject(needs, &(&1 in @provided_needs)) do
      [] ->
        Enum.uniq(needs)

      unknown ->
        raise ArgumentError,
              "#{inspect(module)}.needs/0 names #{inspect(unknown)}, which the graph runner " <>
                "does not compute. Fix: declare only #{inspect(@provided_needs)}."
    end
  end

  defp provided_needs!(other, module) do
    raise ArgumentError,
          "#{inspect(module)}.needs/0 returned #{inspect(other, limit: 5)}, not a list. " <>
            "Fix: return a list of #{inspect(@provided_needs)}."
  end

  defp selects?(%{bucket: bucket}, classified) when is_binary(bucket),
    do: classified.bucket == bucket

  defp selects?(%{paths: [_ | _] = globs}, %{source_file: file}) when is_binary(file),
    do: Enum.any?(globs, &GlobPattern.matches_recursive_pattern?(file, &1))

  defp selects?(%{pattern: pattern}, classified) when is_binary(pattern),
    do: GlobPattern.matches_module_pattern?(Atom.to_string(classified.module), pattern)

  defp selects?(_rule, _classified), do: false
end
