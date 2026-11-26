defmodule Anchor.Check.NoDiscardingArrowInWith do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.NoDiscardingArrowInWith,
    category: :refactor,
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
end
