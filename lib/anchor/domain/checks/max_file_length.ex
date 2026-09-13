defmodule Anchor.Domain.Checks.MaxFileLength do
  @moduledoc """
  Pure detection for the "max file length" check — the **Domain** bucket
  (ADR 001).

  Given the file's already-acquired lines and AST plus the rules already
  selected for the file (the Manager selects rules; the Framework edge —
  `Anchor.Check.Source` — acquires the lines via `to_lines/1` and the AST via
  `ast/1`), this returns the `%Anchor.Domain.Violation{}` list the check
  reports. Every function here is side-effect-free: same lines, AST, rules and
  filename in, same violations out. There is **zero `Credo.*`** and no IO —
  acquiring the lines/AST is `Anchor.Check.Source`'s job and mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's (`Anchor.Check.Base`).

  ## What it detects

  Only lines of *actual code* are counted; the following are excluded:

    * blank / whitespace-only lines,
    * full-line `#` comments,
    * `@moduledoc` / `@doc` / `@typedoc` heredoc bodies (located via the AST),
    * `@doc false` lines.

  For each rule, when the code-line count is **strictly greater** than the
  configured maximum, one violation is reported on line 1 with the filename as
  its trigger. The maximum is read from the rule's **atom** `:max_lines` key —
  the shape T3 (`Anchor.Config.parse_rule/1`) surfaces — defaulting to 400 when
  absent (the BUG 2 fix: the pre-refactor code read the string key
  `"max_lines"`, which the parsed rule never carries, so a configured
  `max_lines` was silently ignored end-to-end).
  """

  alias Anchor.Domain.Violation

  @default_max_lines 400

  @typedoc "A `{line_number, line_text}` pair, as produced by `Source.to_lines/1`."
  @type line :: {integer(), String.t()}

  @doc """
  Returns the `%Violation{}` list for `lines`/`ast` against the already-selected
  `rules`, attributing any violation's trigger to `filename`.

  Each rule contributes at most one violation: one when the file's code-line
  count strictly exceeds that rule's `:max_lines` (default 400).
  """
  @spec detect_violations([line()], Macro.t(), [map()], String.t()) :: [Violation.t()]
  def detect_violations(lines, ast, rules, filename) do
    code_line_count = count_code_lines(lines, ast)

    Enum.flat_map(rules, fn rule ->
      max_lines = get_max_lines(rule)

      if code_line_count > max_lines do
        [build_violation(filename, code_line_count, max_lines)]
      else
        []
      end
    end)
  end

  defp count_code_lines(lines, ast) do
    doc_line_ranges = extract_doc_line_ranges(ast)

    Enum.count(lines, fn {line_number, line_content} ->
      code_line?(line_content, line_number, doc_line_ranges)
    end)
  end

  defp code_line?(line, line_number, doc_line_ranges) do
    trimmed = String.trim(line)

    cond do
      # Empty or whitespace-only line
      trimmed == "" -> false
      # Comment line (starts with #)
      String.starts_with?(trimmed, "#") -> false
      # Line is within a documentation block
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
    {_ast, ranges} =
      Macro.prewalk(ast, [], fn node, acc ->
        case node do
          # @moduledoc / @doc / @typedoc with documentation content
          {:@, meta, [{doc_type, _, [doc_content]}]}
          when doc_type in [:moduledoc, :doc, :typedoc] ->
            case extract_doc_range(doc_content, meta[:line]) do
              nil -> {node, acc}
              range -> {node, [range | acc]}
            end

          # @doc false
          {:@, meta, [{:doc, _, [false]}]} ->
            {node, [{meta[:line], meta[:line]} | acc]}

          _ ->
            {node, acc}
        end
      end)

    ranges
  end

  defp extract_doc_range(doc_content, base_line) when is_binary(doc_content) do
    lines_in_doc = doc_content |> String.split("\n") |> length()

    if String.contains?(doc_content, "\n") do
      # Multi-line doc: @doc line + content lines + closing delimiter line.
      {base_line, base_line + lines_in_doc + 1}
    else
      # Single line doc.
      {base_line, base_line}
    end
  end

  defp extract_doc_range(false, base_line), do: {base_line, base_line}
  defp extract_doc_range(_content, _base_line), do: nil

  # BUG 2: the maximum lives under the ATOM key `:max_lines` on the parsed rule
  # (T3, `Anchor.Config.parse_rule/1`). The pre-refactor code read the string
  # key `"max_lines"`, which the parsed rule never carries, so a configured
  # maximum was silently discarded. An absent/`nil` value defaults to 400.
  defp get_max_lines(rule) do
    case Map.get(rule, :max_lines) do
      nil -> @default_max_lines
      max when is_integer(max) and max > 0 -> max
      max when is_binary(max) -> String.to_integer(max)
    end
  end

  defp build_violation(filename, line_count, max_lines) do
    %Violation{
      message:
        "File contains #{line_count} lines of code (maximum allowed: #{max_lines}). " <>
          "Consider breaking this file into smaller, more focused modules.",
      line: 1,
      trigger: filename
    }
  end
end
