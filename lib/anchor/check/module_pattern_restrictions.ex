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

  # Thin Framework delegate: the Manager hands over the bare AST and the rules it
  # already selected; detection lives in the pure Domain module, and Base maps the
  # returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.ModulePatternRestrictions.detect_violations(ast, rules)
  end
end
