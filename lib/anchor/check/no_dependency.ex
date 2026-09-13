defmodule Anchor.Check.NoDependency do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have direct dependencies on forbidden modules
      as specified in the .anchor.yml configuration file.
      """
    ]

  @doc false
  def rule_type, do: :no_direct_dependency

  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    dependencies = DependencyAnalyzer.extract_direct_dependencies(ast)

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []

      forbidden
      |> Enum.filter(&(&1 in dependencies))
      |> Enum.map(&create_violation(&1, ast))
    end)
  end

  defp create_violation(forbidden_module, ast) do
    line_no = find_module_reference_line(ast, forbidden_module)

    %Violation{
      message: "Module has forbidden direct dependency on #{inspect(forbidden_module)}",
      line: line_no,
      trigger: inspect(forbidden_module)
    }
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
