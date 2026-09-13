defmodule Anchor.Check.NoTransitiveDependency do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have transitive dependencies on forbidden modules
      as specified in the .anchor.yml configuration file. A transitive dependency means that
      the module depends on another module that eventually depends on the forbidden module,
      even if not directly.
      """
    ]

  @doc false
  def rule_type, do: :no_transitive_dependency

  @doc false
  # This check needs the cross-file module dependency graph; the Manager builds
  # it once and hands it in via `context.modules_map`.
  def needs_module_graph?, do: true

  @doc false
  def detect_violations(_source_file, ast, rules, context) do
    modules_map = context.modules_map

    ast
    |> DependencyAnalyzer.extract_module_names()
    |> Enum.flat_map(&violations_for_module(&1, modules_map, rules, ast))
  end

  defp violations_for_module(module_name, modules_map, rules, ast) do
    # Find all transitive dependencies for this module (self removed).
    transitive_deps =
      modules_map
      |> DependencyAnalyzer.find_transitive_dependencies(module_name)
      |> MapSet.delete(module_name)
      |> MapSet.to_list()

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []

      forbidden
      |> Enum.filter(&(&1 in transitive_deps))
      |> Enum.map(&create_violation(&1, module_name, modules_map, ast))
    end)
  end

  defp create_violation(forbidden_module, current_module, modules_map, ast) do
    # Find the dependency path
    path = find_dependency_path(modules_map, current_module, forbidden_module)
    path_description = format_dependency_path(path)

    # Try to find the line where we reference the direct dependency
    direct_dep = Enum.at(path, 1)
    line_no = if direct_dep, do: find_module_reference_line(ast, direct_dep)

    %Violation{
      message:
        "Module has transitive dependency on forbidden module #{inspect(forbidden_module)}#{path_description}",
      line: line_no,
      trigger: inspect(forbidden_module)
    }
  end

  defp find_dependency_path(modules_map, start_module, target_module) do
    find_path_dfs(modules_map, start_module, target_module, [], MapSet.new())
  end

  defp find_path_dfs(modules_map, current, target, path, visited) do
    new_path = path ++ [current]

    if current == target do
      new_path
    else
      if MapSet.member?(visited, current) do
        nil
      else
        visited = MapSet.put(visited, current)

        case Map.get(modules_map, current) do
          nil ->
            nil

          %{direct_dependencies: deps} ->
            Enum.find_value(deps, fn dep ->
              find_path_dfs(modules_map, dep, target, new_path, visited)
            end)
        end
      end
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

  defp find_module_reference_line(ast, module) do
    module_parts = Module.split(module) |> Enum.map(&String.to_atom/1)

    {_, line} =
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
