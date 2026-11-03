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
  """

  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Model

  @default_min_modules 1

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

  defp selects?(%{bucket: bucket}, classified) when is_binary(bucket),
    do: classified.bucket == bucket

  defp selects?(%{paths: [_ | _] = globs}, %{source_file: file}) when is_binary(file),
    do: Enum.any?(globs, &GlobPattern.matches_recursive_pattern?(file, &1))

  defp selects?(%{pattern: pattern}, classified) when is_binary(pattern),
    do: GlobPattern.matches_module_pattern?(Atom.to_string(classified.module), pattern)

  defp selects?(_rule, _classified), do: false
end
