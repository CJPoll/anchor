defmodule Anchor.Check.NoTupleMatchInHead do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check prevents direct pattern matching on :ok and :error tuples in function heads.

      Pattern matching on result tuples in function heads couples the function to its callers
      and reduces reusability. Instead, use control flow structures like `case` or `with`
      to handle these tuples within the function body.

      Forbidden patterns:
      - Direct tuple matching: `def process({:ok, data})`
      - Three-element error tuples: `def handle({:error, type, details})`
      - With guards: `def process({:ok, data}) when is_binary(data)`
      - Match assignment on a tuple: `def process({:ok, _} = result)` or `def process(result = {:ok, data})`

      Allowed patterns:
      - Nested in collections: `def process([{:ok, data} | rest])`
      - Inside maps: `def handle(%{result: {:error, reason}})`
      """
    ]

  @doc false
  def rule_type, do: :no_tuple_match_in_head

  # Thin Framework delegate: the Manager hands over the bare AST and the rules it
  # already selected; AST-based detection lives in the pure Domain module, and
  # Base maps the returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.NoTupleMatchInHead.detect_violations(ast, rules)
  end
end
