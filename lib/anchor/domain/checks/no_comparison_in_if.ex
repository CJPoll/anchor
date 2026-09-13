defmodule Anchor.Domain.Checks.NoComparisonInIf do
  @moduledoc """
  Pure detection for the "no direct comparisons in `if`/`unless`" check — the
  **Domain** bucket (ADR 001).

  Given an already-acquired AST and the rules already selected for the file
  (the Manager does rule selection; the Framework edge acquires the AST),
  this returns the `%Anchor.Domain.Violation{}` list the check reports. Every
  function here is side-effect-free: same AST and rules in, same violations
  out. There is **zero `Credo.*`** and no IO — mapping a `%Violation{}` onto a
  `Credo.Issue` is the Framework's job (`Anchor.Check.Base`), and acquiring the
  AST is `Anchor.Check.Source`'s.

  ## What it detects

  Both `if` and `unless` nodes whose condition contains a direct comparison
  (`==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`), whether at the top level of
  the condition, inside `and`/`or`/`not`, or nested inside a function call
  argument. Each flagged node reports which keyword triggered it (`"if"` or
  `"unless"`).
  """

  alias Anchor.Domain.Violation

  @comparison_operators [:==, :!=, :===, :!==, :<, :>, :<=, :>=]

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected
  `rules`. Each rule contributes the same set of violations (this check does
  not vary its detection by rule content).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn _rule ->
      find_if_with_comparisons(ast)
    end)
  end

  defp find_if_with_comparisons(ast) do
    {_ast, violations} =
      Macro.prewalk(ast, [], fn
        {keyword, meta, [condition, _body]} = node, acc when keyword in [:if, :unless] ->
          case has_comparison?(condition) do
            true ->
              violation = build_violation(meta, keyword)
              {node, [violation | acc]}

            false ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(violations)
  end

  defp has_comparison?(ast) do
    {_ast, has_comp} =
      Macro.prewalk(ast, false, fn
        # Comparison operators
        {op, _meta, [_left, _right]} = node, _acc
        when op in @comparison_operators ->
          {node, true}

        # Logical operators that might contain comparisons
        {:and, _meta, [left, right]} = node, acc ->
          {node, acc || has_comparison?(left) || has_comparison?(right)}

        {:or, _meta, [left, right]} = node, acc ->
          {node, acc || has_comparison?(left) || has_comparison?(right)}

        {:not, _meta, [expr]} = node, acc ->
          {node, acc || has_comparison?(expr)}

        node, acc ->
          {node, acc}
      end)

    has_comp
  end

  defp build_violation(meta, keyword) do
    line_no = Keyword.get(meta, :line, 1)
    trigger = Atom.to_string(keyword)

    %Violation{
      message:
        "Avoid direct comparisons in `#{trigger}` statements. " <>
          "Extract the comparison to a function in the appropriate module with a descriptive name.",
      line: line_no,
      trigger: trigger
    }
  end
end
