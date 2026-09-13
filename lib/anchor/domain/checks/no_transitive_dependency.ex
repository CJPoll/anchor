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
  alias Anchor.Domain.Violation

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
      |> Enum.map(&build_violation(&1, module_name, modules_map, ast))
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
    path = find_dependency_path(modules_map, current_module, forbidden_module)
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

  # Pure DFS for one concrete path from `start_module` to `target_module` over
  # the graph, terminating on cycles (visited set). Returns the node list or
  # `nil` when no path exists.
  defp find_dependency_path(modules_map, start_module, target_module) do
    find_path_dfs(modules_map, start_module, target_module, [], MapSet.new())
  end

  defp find_path_dfs(modules_map, current, target, path, visited) do
    new_path = path ++ [current]

    cond do
      current == target ->
        new_path

      MapSet.member?(visited, current) ->
        nil

      true ->
        descend(modules_map, current, target, new_path, MapSet.put(visited, current))
    end
  end

  defp descend(modules_map, current, target, path, visited) do
    case Map.get(modules_map, current) do
      nil ->
        nil

      %{direct_dependencies: deps} ->
        Enum.find_value(deps, fn dep ->
          find_path_dfs(modules_map, dep, target, path, visited)
        end)
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
