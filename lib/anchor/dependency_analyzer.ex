defmodule Anchor.DependencyAnalyzer do
  @moduledoc """
  Analyzes module dependencies in Elixir source files.
  """

  alias Credo.Code

  def analyze_file(source_file) do
    ast = Code.ast(source_file)

    %{
      module: extract_module_name(ast),
      direct_dependencies: extract_direct_dependencies(ast),
      uses: extract_uses(ast)
    }
  end

  def extract_direct_dependencies(ast) do
    ast
    |> Code.prewalk(&extract_module_references/2, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end

  def extract_uses(ast) do
    ast
    |> Code.prewalk(&extract_use_calls/2, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end

  def extract_module_name(ast) do
    case Code.Module.name(ast) do
      nil -> nil
      "<Unknown Module Name>" -> nil
      name -> Module.concat([name])
    end
  end

  def has_direct_dependency?(ast, module) do
    module in extract_direct_dependencies(ast)
  end

  def has_use?(ast, module) do
    module in extract_uses(ast)
  end

  defp extract_module_references({:__aliases__, _, parts} = node, acc) when is_list(parts) do
    module = Module.concat(parts)
    {node, MapSet.put(acc, module)}
  end

  defp extract_module_references({{:., _, [{:__aliases__, _, parts}, _fun]}, _, _} = node, acc)
       when is_list(parts) do
    module = Module.concat(parts)
    {node, MapSet.put(acc, module)}
  end

  defp extract_module_references(node, acc) do
    {node, acc}
  end

  defp extract_use_calls({:use, _, [{:__aliases__, _, parts} | _]} = node, acc)
       when is_list(parts) do
    module = Module.concat(parts)
    {node, MapSet.put(acc, module)}
  end

  defp extract_use_calls(node, acc) do
    {node, acc}
  end

  def find_transitive_dependencies(modules_map, start_module, visited \\ MapSet.new()) do
    if MapSet.member?(visited, start_module) do
      visited
    else
      visited = MapSet.put(visited, start_module)

      case Map.get(modules_map, start_module) do
        nil ->
          visited

        %{direct_dependencies: deps} ->
          Enum.reduce(deps, visited, fn dep, acc ->
            find_transitive_dependencies(modules_map, dep, acc)
          end)
      end
    end
  end
end
