defmodule Anchor.Check.NoComparisonInIf do
  use Anchor.Check.Base,
    category: :readability,
    explanations: [
      check: """
      This check ensures that `if` statements do not contain direct comparisons
      in their conditionals. Instead, comparisons should be extracted to private
      functions with descriptive names that convey domain meaning.

      This improves code readability by expressing intent rather than implementation.

      ## Examples

      Avoid:
      ```elixir
      if user.age >= 18 do
        # ...
      end

      if user.status == :active and user.verified? do
        # ...
      end
      ```

      Prefer:
      ```elixir
      if adult?(user) do
        # ...
      end

      if eligible_user?(user) do
        # ...
      end

      defp adult?(user), do: user.age >= 18
      defp eligible_user?(user), do: user.status == :active and user.verified?
      ```
      """
    ]

  @doc false
  def rule_type, do: :no_comparison_in_if

  @doc false
  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)

    Enum.flat_map(rules, fn _rule ->
      find_if_with_comparisons(ast, source_file, params)
    end)
  end

  defp find_if_with_comparisons(ast, source_file, params) do
    {_ast, issues} =
      Macro.prewalk(ast, [], fn
        {:if, meta, [condition, _body]} = node, acc ->
          case has_comparison?(condition) do
            true ->
              issue = create_issue(source_file, meta, params)
              {node, [issue | acc]}

            false ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    issues
  end

  defp has_comparison?(ast) do
    {_ast, has_comp} =
      Macro.prewalk(ast, false, fn
        # Comparison operators
        {op, _meta, [_left, _right]} = node, _acc
        when op in [:==, :!=, :===, :!==, :<, :>, :<=, :>=] ->
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

  defp create_issue(source_file, meta, _params) do
    line_no = Keyword.get(meta, :line, 1)

    format_issue(
      source_file,
      message: "Avoid direct comparisons in `if` statements. " <>
               "Extract the comparison to a function in the appropriate module with a descriptive name.",
      line_no: line_no,
      trigger: "if"
    )
  end
end
