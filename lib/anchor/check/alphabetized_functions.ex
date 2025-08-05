defmodule Anchor.Check.AlphabetizedFunctions do
  use Anchor.Check.Base,
    category: :readability,
    explanations: [
      check: """
      This check ensures that functions in a module are ordered alphabetically.

      Three modes are available:
      - :all - All functions must be in alphabetical order, regardless of visibility
      - :public_only - Only public functions must be in alphabetical order
      - :separate (default) - Public functions must be alphabetized, and private functions must be alphabetized separately.
        Additionally, in this mode, all public functions must appear before any private functions.

      Functions with the same name but different arities are sorted by arity (e.g., foo/0 before foo/1).
      Sorting is case-insensitive.
      
      In :separate mode, the check enforces two rules:
      1. Alphabetical ordering within each visibility group (public and private)
      2. Structural ordering: all public functions must come before all private functions
      """
    ]

  @doc false
  def rule_type, do: :alphabetized_functions

  @doc false
  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)

    Enum.flat_map(rules, fn rule ->
      mode = get_mode(rule)
      functions = extract_functions(ast)

      case mode do
        :all ->
          check_all_functions(functions, source_file, params)

        :public_only ->
          check_public_functions_only(functions, source_file, params)

        :separate ->
          check_separate_visibility(functions, source_file, params)
      end
    end)
  end

  defp get_mode(rule) do
    case Map.get(rule, "mode") do
      nil -> :separate
      mode when is_binary(mode) -> String.to_atom(mode)
      mode when is_atom(mode) -> mode
    end
  end

  defp extract_functions(ast) do
    {_, functions} =
      Macro.prewalk(ast, [], fn
        # Handle functions with guards first (more specific pattern)
        {:def, meta, [{:when, _, [{name, _, args} | _]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :public,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        {:defp, meta, [{:when, _, [{name, _, args} | _]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :private,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        # Handle macros with guards
        {:defmacro, meta, [{:when, _, [{name, _, args} | _]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :public,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        {:defmacrop, meta, [{:when, _, [{name, _, args} | _]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :private,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        # Handle regular functions (less specific patterns)
        {:def, meta, [{name, _, args}, _body]} = node, acc when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :public,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        {:defp, meta, [{name, _, args}, _body]} = node, acc when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :private,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        # Handle macros
        {:defmacro, meta, [{name, _, args}, _body]} = node, acc when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :public,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        {:defmacrop, meta, [{name, _, args}, _body]} = node, acc when is_atom(name) and is_list(args) ->
          func = %{
            name: name,
            arity: length(args),
            line: meta[:line],
            visibility: :private,
            original_name: to_string(name)
          }
          {node, [func | acc]}

        node, acc ->
          {node, acc}
      end)

    functions
    |> Enum.reverse()
    |> Enum.sort_by(&{&1.line})
  end

  defp check_all_functions(functions, source_file, params) do
    find_ordering_issues(functions, source_file, params, :all)
  end

  defp check_public_functions_only(functions, source_file, params) do
    public_functions = Enum.filter(functions, &(&1.visibility == :public))
    find_ordering_issues(public_functions, source_file, params, :public_only)
  end

  defp check_separate_visibility(functions, source_file, params) do
    {public_functions, private_functions} = 
      Enum.split_with(functions, &(&1.visibility == :public))

    public_issues = find_ordering_issues(public_functions, source_file, params, :separate_public)
    private_issues = find_ordering_issues(private_functions, source_file, params, :separate_private)
    
    # Check for structural violations: private functions before public functions
    structural_issues = find_structural_violations(functions, source_file, params)

    public_issues ++ private_issues ++ structural_issues
  end

  defp find_ordering_issues(functions, source_file, params, mode) do
    sorted = Enum.sort_by(functions, fn func ->
      {String.downcase(func.original_name), func.arity}
    end)

    functions
    |> Enum.with_index()
    |> Enum.flat_map(fn {func, actual_index} ->
      expected_index = Enum.find_index(sorted, &(&1 == func))

      if actual_index != expected_index do
        [create_issue(func, source_file, params, mode, sorted, actual_index, expected_index)]
      else
        []
      end
    end)
  end

  defp create_issue(func, source_file, _params, mode, sorted_functions, _actual_index, expected_index) do
    expected_previous = if expected_index > 0 do
      prev = Enum.at(sorted_functions, expected_index - 1)
      "#{prev.original_name}/#{prev.arity}"
    else
      "the beginning"
    end

    visibility_text = case mode do
      :all -> ""
      :public_only -> "public "
      :separate_public -> "public "
      :separate_private -> "private "
    end

    format_issue(
      source_file,
      message: "#{visibility_text}function `#{func.original_name}/#{func.arity}` is not in alphabetical order. " <>
               "It should appear after #{expected_previous}.",
      line_no: func.line,
      trigger: "#{func.original_name}/#{func.arity}"
    )
  end

  defp find_structural_violations(functions, source_file, _params) do
    # Find the last public function's line number
    last_public_line = 
      functions
      |> Enum.filter(&(&1.visibility == :public))
      |> Enum.map(& &1.line)
      |> Enum.max(fn -> 0 end)

    # Return early if no public functions
    if last_public_line == 0 do
      []
    else
      # Find all private functions that appear before the last public function
      functions
      |> Enum.filter(&(&1.visibility == :private && &1.line < last_public_line))
      |> Enum.map(fn func ->
        format_issue(
          source_file,
          message: "private function `#{func.original_name}/#{func.arity}` appears before public functions. " <>
                   "In :separate mode, all public functions must come before private functions.",
          line_no: func.line,
          trigger: "#{func.original_name}/#{func.arity}"
        )
      end)
    end
  end
end