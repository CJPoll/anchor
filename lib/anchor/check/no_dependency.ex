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

  # Thin Framework delegate: the Manager hands over the bare AST and the rules it
  # already selected; detection lives in the pure Domain module, and Base maps the
  # returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.NoDependency.detect_violations(ast, rules)
  end
end
