defmodule Anchor.Check.NoComparisonInIf do
  use Anchor.Check.Base,
    category: :readability,
    explanations: [
      check: """
      This check ensures that `if` and `unless` statements do not contain direct
      comparisons in their conditionals. Instead, comparisons should be
      extracted to private functions with descriptive names that convey domain
      meaning.

      This improves code readability by expressing intent rather than implementation.

      ## Examples

      Avoid:
      ```elixir
      if user.age >= 18 do
        # ...
      end

      unless user.status == :active do
        # ...
      end
      ```

      Prefer:
      ```elixir
      if adult?(user) do
        # ...
      end

      unless active_status?(user) do
        # ...
      end

      defp adult?(user), do: user.age >= 18
      defp active_status?(user), do: user.status == :active
      ```
      """
    ]

  @doc false
  def rule_type, do: :no_comparison_in_if

  # Thin Framework delegate: the Manager hands over the bare AST and the rules
  # it already selected; detection lives in the pure Domain module, and Base
  # maps the returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.NoComparisonInIf.detect_violations(ast, rules)
  end
end
