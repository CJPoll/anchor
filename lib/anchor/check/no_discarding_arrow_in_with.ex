defmodule Anchor.Check.NoDiscardingArrowInWith do
  use Anchor.Check.Base,
    category: :refactoring,
    explanations: [
      check: """
      This check ensures that `with` expressions don't use unnecessary arrows (`<-`) when the
      pattern only discards the value.

      The arrow operator should only be used when you need to pattern match on the result.
      If you're only discarding the value with `_` or a variable starting with underscore (like `_result`),
      the arrow is unnecessary and should be removed.

      ## Examples

      # Bad - arrow is unnecessary
      with _ <- some_function() do
        :ok
      end

      with _result <- some_function() do
        :ok
      end

      # Good - no arrow when discarding
      with some_function() do
        :ok
      end

      # Good - arrow used for meaningful pattern matching
      with {:ok, value} <- some_function() do
        value
      end

      with {:ok, _} <- some_function() do
        :ok
      end
      """
    ]

  @doc false
  def rule_type, do: :no_discarding_arrow_in_with

  # Thin Framework delegate: the Manager hands over the bare AST; detection
  # lives in the pure Domain module, and Base maps the returned
  # `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, _rules, _context) do
    Anchor.Domain.Checks.NoDiscardingArrowInWith.detect_violations(ast)
  end
end
