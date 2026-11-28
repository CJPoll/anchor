defmodule Anchor.Test.TransitiveDependencyOracle do
  @moduledoc """
  The `no_transitive_dependency` detection as it was before DND-8208, kept as
  the oracle the parity tests compare the check against. For each module it
  takes the reachable set from
  `Anchor.Domain.DependencyAnalyzer.find_transitive_dependencies/2`, and for each
  finding it runs a fresh targeted search (`find_dependency_path/3` below). That
  is correct and slow: one search per finding, each over the reachable graph.

  It is a frozen copy of the check's code at that point: the targeted search
  (`find_dependency_path/3`, which lived in the check until DND-8208), the
  forbidden test and its module-name glob, the message and the line lookup. So
  a later change to the check is compared against this copy rather than
  against itself. Only `find_transitive_dependencies/2` (compared with the
  tree in `DependencyTreeTest`) and the rule's `shape/1` text, neither changed
  by DND-8208, are still called live.

  `detect_violations/3` also returns the modules the per-finding searches
  expanded, so a test can compare the work the two do.
  """

  alias Anchor.Domain.Checks.NoTransitiveDependency
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @doc "`{violations, expanded}` for `ast`, as the check found them before DND-8208."
  @spec detect_violations(Macro.t(), [map()], map()) :: {[Violation.t()], non_neg_integer()}
  def detect_violations(ast, rules, modules_map) do
    {per_module, expanded} =
      ast
      |> DependencyAnalyzer.extract_module_names()
      |> Enum.map_reduce(0, &violations_for_module(&1, modules_map, rules, ast, &2))

    {Enum.concat(per_module), expanded}
  end

  defp violations_for_module(module_name, modules_map, rules, ast, expanded) do
    transitive_deps =
      modules_map
      |> DependencyAnalyzer.find_transitive_dependencies(module_name)
      |> MapSet.delete(module_name)
      |> MapSet.to_list()

    {per_rule, expanded} =
      Enum.map_reduce(rules, expanded, fn rule, expanded ->
        forbidden = rule.forbidden_modules || []
        forbidden_patterns = Map.get(rule, :forbidden_patterns, []) || []

        transitive_deps
        |> Enum.filter(&forbidden?(&1, forbidden, forbidden_patterns))
        |> Enum.map_reduce(expanded, fn forbidden_module, expanded ->
          {violation, searched} = build_violation(forbidden_module, module_name, modules_map, ast)

          {RuleShapes.with_shape(violation, NoTransitiveDependency.shape(rule)),
           expanded + searched}
        end)
      end)

    {Enum.concat(per_rule), expanded}
  end

  defp forbidden?(module, forbidden_modules, forbidden_patterns) do
    module in forbidden_modules or
      Enum.any?(forbidden_patterns, &matches_module_pattern?(to_string(module), &1))
  end

  # The module-name glob as `Anchor.Domain.GlobPattern` matched it before
  # DND-8208: each `*` is `.*`, every other character a literal, anchored, tried
  # on the qualified name and its alias form. A copy, so the parity test does
  # not compare the new matcher with itself.
  defp matches_module_pattern?(module_name, pattern) do
    regex =
      pattern
      |> String.split("*")
      |> Enum.map_join(".*", &Regex.escape/1)
      |> then(&Regex.compile!("\\A#{&1}\\z"))

    Enum.any?(module_name_forms(module_name), &Regex.match?(regex, &1))
  end

  defp module_name_forms("Elixir." <> alias_form = module_name), do: [module_name, alias_form]
  defp module_name_forms(module_name), do: [module_name]

  defp build_violation(forbidden_module, current_module, modules_map, ast) do
    {path, searched} = find_dependency_path(modules_map, current_module, forbidden_module)

    violation = %Violation{
      message:
        "Module has transitive dependency on forbidden module #{inspect(forbidden_module)}#{format_dependency_path(path)}",
      line: find_module_reference_line(ast, Enum.at(path, 1)),
      trigger: inspect(forbidden_module)
    }

    {violation, searched}
  end

  @doc """
  One dependency path from `start_module` to `target_module` over `modules_map`,
  and the number of modules the search expanded (read the dependencies of).

  The path is a depth-first search in `direct_dependencies` order and returns the
  first path that order reaches, or `nil` when there is none. One visited set is
  shared by every branch of the search, so each module is expanded at most once
  and the search is linear in the graph's size. A module the search has left
  without reaching the target reaches it, if at all, only through a module still
  on the current branch, which a simple path from that branch cannot revisit
  either; so skipping it later reports the same path a search of every simple
  path would.

  The count is there so a test can see how much was searched. This is the
  check's `find_dependency_path/3` as it was before DND-8208, moved here
  unchanged: the check now reads every finding's path from the module's one
  search tree (`Anchor.Domain.DependencyTree`), and the tests compare that tree
  with this single-target search.
  """
  @spec find_dependency_path(map(), module(), module()) :: {[module()] | nil, non_neg_integer()}
  def find_dependency_path(modules_map, start_module, target_module) do
    {reversed_path, %{expanded: expanded}} =
      search(modules_map, start_module, target_module, [], %{visited: MapSet.new(), expanded: 0})

    {reversed_path && Enum.reverse(reversed_path), expanded}
  end

  # `reversed_path` holds the modules above `current`, nearest first.
  # `state.visited` is every module expanded so far, on any branch;
  # `state.expanded` counts the expansions, apart from the set, so a search that
  # expanded a module twice would say so.
  defp search(_modules_map, target, target, reversed_path, state),
    do: {[target | reversed_path], state}

  defp search(modules_map, current, target, reversed_path, state) do
    if MapSet.member?(state.visited, current) do
      {nil, state}
    else
      modules_map
      |> dependencies_of(current)
      |> search_each(modules_map, target, [current | reversed_path], expand(state, current))
    end
  end

  defp expand(%{visited: visited, expanded: expanded}, module),
    do: %{visited: MapSet.put(visited, module), expanded: expanded + 1}

  defp search_each(deps, modules_map, target, reversed_path, state) do
    Enum.reduce_while(deps, {nil, state}, fn dep, {nil, acc} ->
      modules_map |> search(dep, target, reversed_path, acc) |> continue_unless_found()
    end)
  end

  defp continue_unless_found({nil, state}), do: {:cont, {nil, state}}
  defp continue_unless_found(found), do: {:halt, found}

  defp dependencies_of(modules_map, module) do
    case Map.get(modules_map, module) do
      nil -> []
      %{direct_dependencies: deps} -> deps
    end
  end

  defp format_dependency_path(nil), do: ""
  defp format_dependency_path(path) when length(path) <= 2, do: ""

  defp format_dependency_path(path),
    do: " (dependency chain: #{Enum.map_join(path, " -> ", &inspect/1)})"

  defp find_module_reference_line(ast, module) do
    module_parts = module |> Module.split() |> Enum.map(&String.to_atom/1)

    {_ast, line} =
      Macro.prewalk(ast, nil, fn
        {:__aliases__, meta, ^module_parts} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        {{:., _, [{:__aliases__, meta, ^module_parts}, _]}, _, _} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
