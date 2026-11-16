defmodule Anchor.Check.MustUseModule do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules must use specific modules
      as specified in the .anchor.yml configuration file: every module under
      `required_modules`, or at least one of the modules under
      `required_any_of_modules` (the two keys cannot be combined on one rule).
      """
    ]

  @doc false
  def rule_type, do: :must_use_module

  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.MustUseModule.detect_violations(ast, rules)
  end
end
