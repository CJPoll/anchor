defmodule Anchor.Check.MustUseModule do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules must use specific modules
      as specified in the .anchor.yml configuration file.
      """
    ]

  @doc false
  def rule_type, do: :must_use_module

  @doc false
  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)
    uses = DependencyAnalyzer.extract_uses(ast)

    Enum.flat_map(rules, fn rule ->
      required = rule.required_modules || []

      required
      |> Enum.reject(&(&1 in uses))
      |> Enum.map(&create_issue(source_file, &1, params))
    end)
  end

  defp create_issue(source_file, required_module, _params) do
    format_issue(
      source_file,
      message: "Module must use #{inspect(required_module)}",
      line_no: 1,
      trigger: inspect(required_module)
    )
  end
end
