defmodule Anchor.Check.NoTupleMatchInHead do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check prevents direct pattern matching on :ok and :error tuples in function heads.

      Pattern matching on result tuples in function heads couples the function to its callers
      and reduces reusability. Instead, use control flow structures like `case` or `with`
      to handle these tuples within the function body.

      Forbidden patterns:
      - Direct tuple matching: `def process({:ok, data})`
      - Three-element error tuples: `def handle({:error, type, details})`
      - With guards: `def process({:ok, data}) when is_binary(data)`

      Allowed patterns:
      - Nested in collections: `def process([{:ok, data} | rest])`
      - Inside maps: `def handle(%{result: {:error, reason}})`
      """
    ]

  @doc false
  def rule_type, do: :no_tuple_match_in_head

  @doc false
  def check_file(source_file, rules, params) do
    source_code = source_file |> Credo.SourceFile.source()

    Enum.flat_map(rules, fn _rule ->
      source_code
      |> find_function_definitions()
      |> Enum.filter(&has_ok_error_pattern_in_args?/1)
      |> Enum.map(&create_issue(source_file, &1, params))
    end)
  end

  defp find_function_definitions(source_code) do
    # Match function definitions including those with guards
    ~r/^\s*(defp?)\s+(\w+)\s*\(([^)]*)\)(\s+when\s+[^\n]+)?/m
    |> Regex.scan(source_code, return: :index)
    |> Enum.map(fn matches ->
      [{full_start, _full_length} | captures] = matches

      [_, {name_start, name_length}, {args_start, args_length} | guard_capture] = captures

      def_type =
        String.slice(source_code, elem(Enum.at(captures, 0), 0), elem(Enum.at(captures, 0), 1))

      function_name = String.slice(source_code, name_start, name_length)
      args_string = String.slice(source_code, args_start, args_length)

      has_guard =
        case guard_capture do
          [{_guard_start, guard_length}] when guard_length > 0 -> true
          _ -> false
        end

      line_no = count_lines_before(source_code, full_start) + 1

      %{
        type: def_type,
        name: function_name,
        args: args_string,
        has_guard: has_guard,
        line: line_no
      }
    end)
  end

  defp has_ok_error_pattern_in_args?(%{args: args}) do
    # Only check for direct tuple patterns (not nested in collections or maps)
    # Also check if it's a direct argument (not inside [] or %{})
    has_direct_ok_pattern = args =~ ~r/^\s*\{:ok\s*,/ || args =~ ~r/,\s*\{:ok\s*,/
    has_direct_error_pattern = args =~ ~r/^\s*\{:error\s*,/ || args =~ ~r/,\s*\{:error\s*,/

    # Don't flag if it's nested in a collection or map
    is_nested = args =~ ~r/[\[%][^,\]]*\{:(?:ok|error)\s*,/

    (has_direct_ok_pattern || has_direct_error_pattern) && !is_nested
  end

  defp count_lines_before(source_code, position) do
    source_code
    |> String.slice(0, position)
    |> String.split("\n")
    |> length()
    |> Kernel.-(1)
  end

  defp create_issue(source_file, %{name: function_name, line: line_no, type: def_type}, _params) do
    visibility_text = if def_type == "def", do: "public", else: "private"

    format_issue(
      source_file,
      message:
        "Function `#{function_name}` pattern matches on :ok/:error tuple in its #{visibility_text} function head. Use case or with instead.",
      line_no: line_no,
      trigger: function_name
    )
  end
end
