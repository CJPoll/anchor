defmodule Anchor.Check.NoForwardingFunction do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      A function whose every clause only hands its arguments, unchanged and in
      order, to another function of the same module is an inert hop: it adds
      depth and causes nothing. Inside one module no boundary is crossed.

      Not reported: a function marked `@impl` (a behaviour callback is a
      boundary) or `@deprecated` (an API transition), any argument change,
      reordering, guard, pattern or default, and a call to another module
      (the graph rule `no_inert_hop` judges those).

      ## Examples

      Avoid:
      ```elixir
      def total(items, tax), do: do_total(items, tax)
      defp do_total(items, tax), do: Enum.sum(items) * (1 + tax)
      ```

      Prefer:
      ```elixir
      def total(items, tax), do: Enum.sum(items) * (1 + tax)
      ```
      """
    ]

  @doc false
  def rule_type, do: :no_forwarding_function

  # Thin Framework delegate: detection is the pure Domain module's.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.NoForwardingFunction.detect_violations(ast, rules)
  end
end
