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

  @modules_map_key :__no_transitive_dependency_modules_map__

  @doc false
  def rule_type, do: :no_transitive_dependency

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    case Config.load() do
      {:ok, config} ->
        # Build the modules map once for all files
        modules_map = build_modules_map(source_files)

        # Store modules_map in params for check_file
        params_with_map = Keyword.put(params, @modules_map_key, modules_map)

        issues =
          source_files
          |> Enum.flat_map(&process_file(&1, config, params_with_map))

        exec
        |> Credo.Execution.ExecutionIssues.append(issues)

      {:error, _reason} ->
        exec
    end
  end

  @doc false
  def check_file(source_file, rules, params) do
    modules_map = Keyword.get(params, @modules_map_key, %{})

    ast = Credo.Code.ast(source_file)
    module_name = DependencyAnalyzer.extract_module_name(ast)

    # Find all transitive dependencies for this module
    transitive_deps =
      DependencyAnalyzer.find_transitive_dependencies(modules_map, module_name)
      # Remove self from dependencies
      |> MapSet.delete(module_name)
      |> MapSet.to_list()

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []

      forbidden
      |> Enum.filter(&(&1 in transitive_deps))
      |> Enum.map(&create_issue(source_file, &1, module_name, modules_map, ast))
    end)
  end

  defp build_modules_map(source_files) do
    # Build a map of module -> dependencies
    Enum.reduce(source_files, %{}, fn source_file, acc ->
      analysis = DependencyAnalyzer.analyze_file(source_file)

      if analysis.module do
        Map.put(acc, analysis.module, analysis)
      else
        acc
      end
    end)
  end

  defp create_issue(source_file, forbidden_module, current_module, modules_map, ast) do
    # Find the dependency path
    path = find_dependency_path(modules_map, current_module, forbidden_module)
    path_description = format_dependency_path(path)

    # Try to find the line where we reference the direct dependency
    direct_dep = Enum.at(path, 1)
    line_no = if direct_dep, do: find_module_reference_line(ast, direct_dep)

    format_issue(
      source_file,
      message:
        "Module has transitive dependency on forbidden module #{inspect(forbidden_module)}#{path_description}",
      line_no: line_no,
      trigger: inspect(forbidden_module)
    )
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
