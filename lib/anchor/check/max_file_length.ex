defmodule Anchor.Check.MaxFileLength do
  use Anchor.Check.Base,
    category: :readability,
    explanations: [
      check: """
      This check ensures that files do not exceed a maximum number of lines of actual code.

      Large files are harder to understand, navigate, and maintain. By limiting file length,
      you encourage better code organization and separation of concerns.

      The check counts only lines with actual code, excluding:
      - Empty lines and whitespace-only lines
      - Comments (lines starting with #)
      - Documentation (@moduledoc, @doc, @typedoc)

      The default maximum is 400 lines of code, but this can be configured.
      """
    ]

  @doc false
  def rule_type, do: :max_file_length

  @doc false
  def check_file(source_file, rules, params) do
    lines = Credo.Code.to_lines(source_file)
    code_line_count = count_code_lines(lines, source_file)

    Enum.flat_map(rules, fn rule ->
      max_lines = get_max_lines(rule)

      if code_line_count > max_lines do
        [create_issue(source_file, code_line_count, max_lines, params)]
      else
        []
      end
    end)
  end

  defp count_code_lines(lines, source_file) do
    # Get the AST to find documentation attribute locations
    ast = Credo.Code.ast(source_file)
    doc_line_ranges = extract_doc_line_ranges(ast)
    
    lines
    |> Enum.count(fn {line_number, line_content} ->
      is_code_line?(line_content, line_number, doc_line_ranges)
    end)
  end

  defp is_code_line?(line, line_number, doc_line_ranges) do
    trimmed = String.trim(line)
    
    cond do
      # Empty or whitespace-only line
      trimmed == "" -> false
      
      # Comment line (starts with #, but not a doc attribute)
      String.starts_with?(trimmed, "#") -> false
      
      # Line is within a doc block
      in_doc_block?(line_number, doc_line_ranges) -> false
      
      # Otherwise it's a code line
      true -> true
    end
  end

  defp in_doc_block?(line_number, doc_line_ranges) do
    Enum.any?(doc_line_ranges, fn {start_line, end_line} ->
      line_number >= start_line && line_number <= end_line
    end)
  end

  defp extract_doc_line_ranges(ast) do
    case ast do
      {:ok, actual_ast} -> do_extract_doc_line_ranges(actual_ast)
      _ -> do_extract_doc_line_ranges(ast)
    end
  end

  defp do_extract_doc_line_ranges(ast) do
    {_, ranges} = Macro.prewalk(ast, [], fn node, acc ->
      case node do
        # Match @moduledoc, @doc, @typedoc with documentation
        {:@, meta, [{doc_type, _, [doc_content]}]} 
        when doc_type in [:moduledoc, :doc, :typedoc] ->
          case extract_doc_range(doc_content, meta[:line]) do
            nil -> {node, acc}
            range -> {node, [range | acc]}
          end
          
        # Also handle @doc false
        {:@, meta, [{:doc, _, [false]}]} ->
          {node, [{meta[:line], meta[:line]} | acc]}
          
        _ ->
          {node, acc}
      end
    end)
    
    ranges
  end

  defp extract_doc_range(doc_content, base_line) when is_binary(doc_content) do
    # Count lines in the string content
    lines_in_doc = doc_content |> String.split("\n") |> length()
    
    # The documentation spans from the @doc line to the closing """
    # For multiline strings, we need to include the opening and closing lines
    if String.contains?(doc_content, "\n") do
      # Multi-line doc: @doc line + content lines + closing line
      {base_line, base_line + lines_in_doc + 1}
    else
      # Single line doc
      {base_line, base_line}
    end
  end
  defp extract_doc_range(false, base_line), do: {base_line, base_line}
  defp extract_doc_range(_, _), do: nil

  defp get_max_lines(rule) do
    case Map.get(rule, "max_lines") do
      nil -> 400
      max when is_integer(max) and max > 0 -> max
      max when is_binary(max) -> String.to_integer(max)
    end
  end

  defp create_issue(source_file, line_count, max_lines, _params) do
    format_issue(
      source_file,
      message: "File contains #{line_count} lines of code (maximum allowed: #{max_lines}). " <>
               "Consider breaking this file into smaller, more focused modules.",
      line_no: 1,
      trigger: source_file.filename
    )
  end
end