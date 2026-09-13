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
  def detect_violations(_source_file, ast, rules, _context) do
    uses = DependencyAnalyzer.extract_uses(ast)

    Enum.flat_map(rules, fn rule ->
      required = rule.required_modules || []

      required
      |> Enum.reject(&(&1 in uses))
      |> Enum.map(&create_violation/1)
    end)
  end

  defp create_violation(required_module) do
    %Violation{
      message: "Module must use #{inspect(required_module)}",
      line: 1,
      trigger: inspect(required_module)
    }
  end
end
