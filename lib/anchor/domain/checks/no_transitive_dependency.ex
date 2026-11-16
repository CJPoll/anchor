defmodule Anchor.Domain.Checks.NoTransitiveDependency do
  @moduledoc """
  Pure detection for the `no_transitive_dependency` check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired AST, the `no_transitive_dependency` rules that apply
  to a file, and the cross-file module dependency graph, it returns the
  `%Anchor.Domain.Violation{}` list for every forbidden module a module in the
  file can reach *transitively*. It is side-effect-free — same AST, rules, and
  graph in, same violations out — with **zero `Credo.*`** and no IO: mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.NoTransitiveDependency` via `Anchor.Check.Base`), rule
  *selection* is the Manager's (`Anchor.Managers.Lint`), and building the
  `modules_map` is the Manager's too (it declares `needs_module_graph?/0` on the
  check and reduces `Anchor.Domain.DependencyAnalyzer.module_dependencies/1` over
  the source files). This function receives the finished graph.

  ## What it detects

  For each module the file defines, it computes the transitively-reachable set
  (`Anchor.Domain.DependencyAnalyzer.find_transitive_dependencies/2`) with the
  module itself removed — a module is never its own transitive dependency, and
  self-edges/cycles terminate rather than loop. Every forbidden module in that
  set yields one violation, carrying:

    * the forbidden module's inspected name as the trigger,
    * the line of the module's *direct* reference that begins the path, and
    * a message naming the forbidden module and, when the path has more than two
      nodes, the full `A -> B -> ... -> Forbidden` dependency chain. A path of
      length two (a direct dependency that also counts as transitive) carries no
      chain suffix.
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @impl Anchor.Domain.RuleShape
  def shape(rule) do
    forbidden =
      Enum.map(Map.get(rule, :forbidden_modules) || [], &inspect/1) ++
        (Map.get(rule, :forbidden_patterns) || [])

    "no chain of dependencies from the module reaches #{Enum.join(forbidden, ", ")}; cut " <>
      "the chain where it first enters a module that depends on it"
  end

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`
  and the cross-file `modules_map`.

  `rules` is the list of already-selected `no_transitive_dependency` rule maps,
  each carrying `:forbidden_modules` (a possibly-`nil` list of module atoms).
  `modules_map` maps each module to `%{direct_dependencies: [module]}` — the
  graph the Manager builds. Each module the file defines contributes one
  violation per forbidden module it can reach transitively (self removed).
  """
  @spec detect_violations(Macro.t(), [map()], map()) :: [Violation.t()]
  def detect_violations(ast, rules, modules_map) do
    ast
    |> DependencyAnalyzer.extract_module_names()
    |> Enum.flat_map(&violations_for_module(&1, modules_map, rules, ast))
  end

  defp violations_for_module(module_name, modules_map, rules, ast) do
    transitive_deps =
      modules_map
      |> DependencyAnalyzer.find_transitive_dependencies(module_name)
      |> MapSet.delete(module_name)
      |> MapSet.to_list()

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []
      forbidden_patterns = Map.get(rule, :forbidden_patterns, []) || []

      transitive_deps
      |> Enum.filter(&forbidden?(&1, forbidden, forbidden_patterns))
      |> Enum.map(
        &RuleShapes.with_shape(build_violation(&1, module_name, modules_map, ast), shape(rule))
      )
    end)
  end

  # Gap A (DND-142): a transitively-reachable module is forbidden when it is an
  # exact `forbidden_modules` entry OR its module name matches a
  # `forbidden_patterns` glob. Graph edges stay reference-based; `match` mode is
  # A'-scoped to `NoDependency` and is not consulted here.
  defp forbidden?(module, forbidden_modules, forbidden_patterns) do
    module in forbidden_modules or matches_any_pattern?(module, forbidden_patterns)
  end

  defp matches_any_pattern?(module, patterns) do
    module_name = to_string(module)
    Enum.any?(patterns, &GlobPattern.matches_module_pattern?(module_name, &1))
  end

  defp build_violation(forbidden_module, current_module, modules_map, ast) do
    {path, _expanded} = find_dependency_path(modules_map, current_module, forbidden_module)
    path_description = format_dependency_path(path)

    # The line where the current module references the first hop of the path.
    direct_dep = Enum.at(path, 1)
    line = if direct_dep, do: find_module_reference_line(ast, direct_dep)

    %Violation{
      message:
        "Module has transitive dependency on forbidden module #{inspect(forbidden_module)}#{path_description}",
      line: line,
      trigger: inspect(forbidden_module)
    }
  end

  @doc """
  One dependency path from `start_module` to `target_module` over `modules_map`,
  and the number of modules the search expanded (read the dependencies of).

  The path is a depth-first search in `direct_dependencies` order and returns the
  first path that order reaches, or `nil` when there is none. One visited set is
  shared by every branch of the search, so each module is expanded at most once
  and the search is linear in the graph's size. A module the search has left
  without reaching the target cannot reach it by a route the search has not
  already tried, so skipping it later reports the same path a search of every
  route would.
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

  defp format_dependency_path(path) do
    chain =
      path
      |> Enum.map(&inspect/1)
      |> Enum.join(" -> ")

    " (dependency chain: #{chain})"
  end

  # The line where `module` is referenced in `ast`, or `nil` when it is not
  # located. (Behaviour preserved verbatim from the pre-extraction check.)
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
