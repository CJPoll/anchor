defmodule Anchor.Check.NoDiscardedPureExpression do
  use Anchor.Check.Base,
    category: :warning,
    explanations: [
      check: """
      An expression whose value nobody uses, and which has no effect, causes
      nothing: it is dead code that reads as if it mattered. A leftover
      computation, a forgotten rebinding, a `Map.put/3` whose result was meant
      to replace the map.

      This check reports a pure expression in a non-final position of a block,
      and the right side of `_ = expr` (or `_name = expr`) there. Pure means a
      literal, a variable, an operator or container over pure parts, a call to
      a stdlib pure module (`Enum`, `Map`, `String`, ...) or to a module the
      rule's `pure_patterns` names, with pure arguments. An unknown call is
      never reported: it may be an effect.

      ## Examples

      Avoid:
      ```elixir
      def put(map, value) do
        Map.put(map, :key, value)
        map
      end

      def total(items) do
        _ = Enum.map(items, & &1.price)
        :ok
      end
      ```

      Prefer:
      ```elixir
      def put(map, value) do
        Map.put(map, :key, value)
      end

      def total(items) do
        Enum.map(items, & &1.price)
      end
      ```
      """
    ]

  @doc false
  def rule_type, do: :no_discarded_pure_expression

  # Thin Framework delegate: detection is the pure Domain module's.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.NoDiscardedPureExpression.detect_violations(ast, rules)
  end
end
