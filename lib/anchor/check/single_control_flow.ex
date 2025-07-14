defmodule Anchor.Check.SingleControlFlow do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that function clauses contain at most one control-flow structure.
      
      Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive.
      
      This promotes simpler, more focused functions that are easier to understand and test.
      """
    ]

  @doc false
  def rule_type, do: :single_control_flow

  @doc false
  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)

    Enum.flat_map(rules, fn _rule ->
      ast
      |> find_function_clauses()
      |> Enum.flat_map(fn {function_name, line_no, body} ->
        control_flow_count = count_control_flow_structures(body)
        
        if control_flow_count > 1 do
          [create_issue(source_file, function_name, line_no, control_flow_count, params)]
        else
          []
        end
      end)
    end)
  end

  defp find_function_clauses(ast) do
    {_, clauses} =
      Macro.prewalk(ast, [], fn
        {:def, meta, [{name, _, args}, body]} = node, acc when is_atom(name) and is_list(args) ->
          line_no = Keyword.get(meta, :line)
          clause = {to_string(name), line_no, body}
          {node, [clause | acc]}
        
        {:defp, meta, [{name, _, args}, body]} = node, acc when is_atom(name) and is_list(args) ->
          line_no = Keyword.get(meta, :line)
          clause = {to_string(name), line_no, body}
          {node, [clause | acc]}
          
        # Handle functions with guards
        {:def, meta, [{:when, _, [{name, _, args} | _]}, body]} = node, acc when is_atom(name) and is_list(args) ->
          line_no = Keyword.get(meta, :line)
          clause = {to_string(name), line_no, body}
          {node, [clause | acc]}
          
        {:defp, meta, [{:when, _, [{name, _, args} | _]}, body]} = node, acc when is_atom(name) and is_list(args) ->
          line_no = Keyword.get(meta, :line)
          clause = {to_string(name), line_no, body}
          {node, [clause | acc]}
          
        node, acc ->
          {node, acc}
      end)

    Enum.reverse(clauses)
  end

  defp count_control_flow_structures(ast) do
    {_, count} =
      Macro.prewalk(ast, 0, fn
        # Pipe chain (count as 1 if there's at least one pipe)
        {:|>, _, _} = node, acc ->
          # Only count the first pipe in a chain
          if already_in_pipe_chain?(node) do
            {node, acc}
          else
            {node, acc + 1}
          end
          
        # cond
        {:cond, _, _} = node, acc ->
          {node, acc + 1}
          
        # with
        {:with, _, _} = node, acc ->
          {node, acc + 1}
          
        # case
        {:case, _, _} = node, acc ->
          {node, acc + 1}
          
        # if
        {:if, _, _} = node, acc ->
          {node, acc + 1}
          
        # unless
        {:unless, _, _} = node, acc ->
          {node, acc + 1}
          
        # for comprehension
        {:for, _, _} = node, acc ->
          {node, acc + 1}
          
        # receive
        {:receive, _, _} = node, acc ->
          {node, acc + 1}
          
        node, acc ->
          {node, acc}
      end)

    count
  end

  # Check if this pipe is part of a larger pipe chain (i.e., its parent is also a pipe)
  defp already_in_pipe_chain?({:|>, _, [left, _right]}) do
    case left do
      {:|>, _, _} -> true
      _ -> false
    end
  end

  defp create_issue(source_file, function_name, line_no, count, _params) do
    format_issue(
      source_file,
      message: "Function clause `#{function_name}` contains #{count} control-flow structures (maximum allowed: 1)",
      line_no: line_no,
      trigger: function_name
    )
  end
end