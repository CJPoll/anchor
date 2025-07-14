defmodule Anchor.Check.CaseOnBareArg do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check discourages using case statements on bare function arguments.
      
      When a case statement operates directly on a function argument, it's often better
      to use function head pattern matching instead. This leads to clearer, more
      idiomatic Elixir code.
      
      Bad:
          def process(status) do
            case status do
              :ok -> handle_success()
              :error -> handle_failure()
            end
          end
      
      Good (using function heads):
          def process(:ok), do: handle_success()
          def process(:error), do: handle_failure()
      
      Good (case on expression):
          def process(data) do
            case validate(data) do
              :ok -> handle_success()
              :error -> handle_failure()
            end
          end
      """
    ]

  @doc false
  def rule_type, do: :case_on_bare_arg

  @doc false
  def check_file(source_file, _rules, params) do
    ast = Credo.Code.ast(source_file)
    violations = find_case_on_bare_args(ast)
    Enum.map(violations, &create_issue(source_file, &1, params))
  end

  defp find_case_on_bare_args({:ok, ast}), do: find_case_on_bare_args(ast)
  defp find_case_on_bare_args(ast) do
    {_, violations} =
      Macro.prewalk(ast, [], fn node, acc ->
        case node do
          # Function with guards must come before regular functions
          # because the regular pattern would match the :when atom as the function name
          {:def, _meta, [{:when, _, [{name, _, args} | _guards]}, body]} when is_atom(name) and is_list(args) ->
            arg_names = extract_arg_names(args)
            violations = find_case_violations_in_body(body, arg_names, name)
            {node, acc ++ violations}

          {:defp, _meta, [{:when, _, [{name, _, args} | _guards]}, body]} when is_atom(name) and is_list(args) ->
            arg_names = extract_arg_names(args)
            violations = find_case_violations_in_body(body, arg_names, name)
            {node, acc ++ violations}
            
          # Match regular function definitions
          {:def, _meta, [{name, _, args}, body]} when is_atom(name) and is_list(args) ->
            arg_names = extract_arg_names(args)
            violations = find_case_violations_in_body(body, arg_names, name)
            {node, acc ++ violations}

          {:defp, _meta, [{name, _, args}, body]} when is_atom(name) and is_list(args) ->
            arg_names = extract_arg_names(args)
            violations = find_case_violations_in_body(body, arg_names, name)
            {node, acc ++ violations}

          _ ->
            {node, acc}
        end
      end)

    violations
  end

  defp extract_arg_names(args) do
    Enum.flat_map(args, fn
      {name, _, nil} when is_atom(name) -> [name]
      _ -> []
    end)
  end

  defp find_case_violations_in_body(body, arg_names, function_name) do
    {_, violations} =
      Macro.prewalk(body, [], fn
        {:case, meta, [{arg_name, _, nil}, _clauses]} = node, acc when is_atom(arg_name) ->
          if arg_name in arg_names do
            line_no = Keyword.get(meta, :line)
            violation = %{
              function_name: function_name,
              arg_name: arg_name,
              line_no: line_no
            }
            {node, [violation | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    violations
  end

  defp create_issue(source_file, %{function_name: function_name, arg_name: arg_name, line_no: line_no}, _params) do
    format_issue(
      source_file,
      message: "Case statement operates on bare argument `#{arg_name}` in function `#{function_name}`. Consider using function head pattern matching instead.",
      line_no: line_no,
      trigger: "case"
    )
  end
end
