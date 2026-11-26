defmodule Anchor.Check.SingleControlFlow do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.SingleControlFlow,
    category: :design,
    explanations: [
      check: """
      This check ensures that function clauses contain at most one control-flow structure.

      Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive.

      This promotes simpler, more focused functions that are easier to understand and test.
      """
    ]
end
