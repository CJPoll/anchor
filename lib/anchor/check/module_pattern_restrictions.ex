defmodule Anchor.Check.ModulePatternRestrictions do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules matching specific patterns only define
      allowed functions as specified in the .anchor.yml configuration file.
      """
    ]

  @doc false
  def rule_type, do: :module_pattern_restrictions

  @doc false
  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)

    Enum.flat_map(rules, fn rule ->
      allowed_functions = rule.allowed_functions || []

      ast
      |> extract_defined_functions()
      |> Enum.reject(&(&1 in allowed_functions))
      |> Enum.map(&create_issue(source_file, &1, ast, params))
    end)
  end

  defp extract_defined_functions(ast) do
    {_, functions} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:def, _, [{name, _, _} | _]} = node, acc when is_atom(name) ->
          {node, MapSet.put(acc, to_string(name))}

        {:defp, _, [{name, _, _} | _]} = node, acc when is_atom(name) ->
          {node, MapSet.put(acc, to_string(name))}

        node, acc ->
          {node, acc}
      end)

    MapSet.to_list(functions)
  end

  defp create_issue(source_file, function_name, ast, _params) do
    line_no = find_function_line(ast, function_name)

    format_issue(
      source_file,
      message: "Module defines non-allowed function: #{function_name}",
      line_no: line_no,
      trigger: function_name
    )
  end

  defp find_function_line(ast, function_name) do
    function_atom = String.to_atom(function_name)

    {_, line} =
      Macro.prewalk(ast, nil, fn
        {:def, meta, [{^function_atom, _, _} | _]} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        {:defp, meta, [{^function_atom, _, _} | _]} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
