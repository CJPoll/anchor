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

  @doc false
  def check_file(source_file, _rules, params) do
    ast = Credo.Code.ast(source_file)
    
    {_, issues} = Macro.prewalk(ast, [], fn node, acc ->
      case node do
        {:with, _meta, clauses} when is_list(clauses) and length(clauses) >= 2 ->
          # Extract the with clauses (everything before the do block)
          with_clauses = extract_with_clauses(clauses)
          new_issues = check_with_clauses(with_clauses, source_file, params)
          {node, acc ++ new_issues}
          
        _ ->
          {node, acc}
      end
    end)
    
    issues
  end

  defp extract_with_clauses(clauses) do
    # Find the index of the do block
    do_index = Enum.find_index(clauses, fn
      [{:do, _} | _] -> true
      _ -> false
    end)
    
    if do_index do
      # Everything before the do block are with clauses
      Enum.take(clauses, do_index)
    else
      # If no do block found, check all but last (might be single-line with)
      case List.last(clauses) do
        [{:do, _} | _] -> Enum.drop(clauses, -1)
        _ -> []
      end
    end
  end

  defp check_with_clauses(clauses, source_file, params) do
    Enum.flat_map(clauses, fn clause ->
      case clause do
        {:<-, meta, [pattern, _expr]} ->
          if is_discarding_pattern?(pattern) do
            [create_issue(pattern, meta, source_file, params)]
          else
            []
          end
          
        _ ->
          []
      end
    end)
  end

  defp is_discarding_pattern?(pattern) do
    case pattern do
      # Single underscore
      {:_, _, _} -> 
        true
        
      # Pattern with guard - check the pattern before the guard
      # MUST come before the general atom check
      {:when, _, [inner_pattern | _]} ->
        is_discarding_pattern?(inner_pattern)
        
      # Variable starting with underscore
      {var_name, _, _} when is_atom(var_name) ->
        var_name
        |> Atom.to_string()
        |> String.starts_with?("_")
        
      # Any other pattern is not just discarding
      _ -> 
        false
    end
  end

  defp create_issue(pattern, meta, source_file, _params) do
    pattern_string = case pattern do
      {:_, _, _} -> 
        "_"
      {:when, _, [{:_, _, _} | _]} -> 
        "_"
      {:when, _, [{var_name, _, _} | _]} when is_atom(var_name) -> 
        Atom.to_string(var_name)
      {var_name, _, _} when is_atom(var_name) -> 
        Atom.to_string(var_name)
      _ -> 
        "pattern"
    end
    
    format_issue(
      source_file,
      message: "Unnecessary arrow (<-) in with clause. Pattern `#{pattern_string}` only discards the value. " <>
               "Remove the arrow and pattern to simplify",
      line_no: meta[:line],
      trigger: pattern_string
    )
  end
end
