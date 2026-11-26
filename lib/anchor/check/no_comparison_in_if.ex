defmodule Anchor.Check.NoComparisonInIf do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.NoComparisonInIf,
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
end
