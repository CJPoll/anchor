defmodule Anchor.Check.SingleControlFlow do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that function clauses contain at most one control-flow structure.

      Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive.

      This promotes simpler, more focused functions that are easier to understand and test.
      """
    ]

  @doc false
  def rule_type, do: :single_control_flow

  # Thin Framework delegate: the Manager hands over the bare AST and the rules it
  # already selected; detection lives in the pure Domain module, and Base maps the
  # returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.SingleControlFlow.detect_violations(ast, rules)
  end
end
