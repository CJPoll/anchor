defmodule Anchor.Domain.Checks.MaxFileLength do
  @moduledoc """
  Pure detection for the "max file length" check — the **Domain** bucket
  (ADR 001).

  Given the file's already-acquired lines plus the rules already selected for
  the file (the Manager selects rules; the Framework edge —
  `Anchor.Check.Source` — acquires the lines via `to_lines/1`), this returns
  the `%Anchor.Domain.Violation{}` list the check reports. Every function here
  is side-effect-free: same lines, rules and filename in, same violations
  out. There is **zero `Credo.*`** and no IO —
  acquiring the lines is `Anchor.Check.Source`'s job and mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's (`Anchor.Check.Base`).

  ## What it detects

  Only lines of *actual code* are counted; the following are excluded:

    * blank / whitespace-only lines,
    * lines whose first non-blank character is `#`: full-line comments (and,
      since the line alone is read, a line of a multi-line string that starts
      with `#`),
    * documentation annotations: every line of an `@moduledoc`, `@doc` or
      `@typedoc` annotation, from its `@` line to the line its value ends on,
      whatever the value is: a string, a heredoc, a sigil, an interpolated
      string, `false`, a function call or pipeline, another module attribute,
      or metadata such as `since:`. Those lines are excluded whole.

  Everything else is code, a string outside those annotations, a read of one
  (`@moduledoc` with no value) and every other attribute (`@shortdoc` among
  them) included.

  The end of an annotation is the parser's `end_of_expression` line, read by
  parsing the lines again with `token_metadata: true` (the AST a detector is
  handed does not carry it). The parser records none when code follows the
  annotation with no newline or `;` between (`\""" end`, which `mix format`
  never writes): only the `@` line is excluded then.

  For each rule, when the code-line count is **strictly greater** than the
  configured maximum, one violation is reported on line 1 with the filename as
  its trigger. The maximum is read from the rule's **atom** `:max_lines` key —
  the shape T3 (`Anchor.Config.parse_rule/1`) surfaces — defaulting to 400 when
  absent (the BUG 2 fix: the pre-refactor code read the string key
  `"max_lines"`, which the parsed rule never carries, so a configured
  `max_lines` was silently ignored end-to-end).
  """

  use Anchor.Domain.Detector

  @doc "The rule type this detector reads (DND-8063)."
  @impl Anchor.Domain.Detector
  def rule_type, do: :max_file_length

  @doc false
  @impl Anchor.Domain.Detector
  def needs_lines?, do: true

  @doc "Detects one file's `%Anchor.Domain.Detector.Input{}` (DND-8063)."
  @impl Anchor.Domain.Detector
  def detect(%Anchor.Domain.Detector.Input{} = input),
    do: detect_violations(input.lines, input.rules, input.filename)

  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @impl Anchor.Domain.RuleShape
  def shape(rule) do
    "at most #{get_max_lines(rule)} lines of code per file; split the module into smaller " <>
      "modules, each with one responsibility"
  end

  @default_max_lines 400

  @doc_attributes [:moduledoc, :doc, :typedoc]

  @typedoc "A `{line_number, line_text}` pair, as produced by `Source.to_lines/1`."
  @type line :: {integer(), String.t()}

  @doc """
  Returns the `%Violation{}` list for `lines` against the already-selected
  `rules`, attributing any violation's trigger to `filename`.

  Each rule contributes at most one violation: one when the file's code-line
  count strictly exceeds that rule's `:max_lines` (default 400).

  `lines` must be a whole file that parses; one that does not raises, which
  `Anchor.Domain.Detector.run/3` reports as a failed check.
  """
  @spec detect_violations([line()], [map()], String.t()) :: [Violation.t()]
  def detect_violations(lines, rules, filename) do
    code_line_count = count_code_lines(lines)

    Enum.flat_map(rules, fn rule ->
      max_lines = get_max_lines(rule)

      if code_line_count > max_lines do
        [
          RuleShapes.with_shape(
            build_violation(filename, code_line_count, max_lines),
            shape(rule)
          )
        ]
      else
        []
      end
    end)
  end

  defp count_code_lines(lines) do
    doc_line_ranges = extract_doc_line_ranges(lines)

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

  # The newline appended gives the file's last expression an
  # `end_of_expression` too.
  defp extract_doc_line_ranges(lines) do
    source = Enum.map_join(lines, "\n", fn {_line_number, text} -> text end)

    {_ast, ranges} =
      (source <> "\n")
      |> Code.string_to_quoted!(token_metadata: true, emit_warnings: false)
      |> Macro.prewalk([], &collect_doc_range/2)

    ranges
  end

  # A read (`@doc`) has no argument list, so only an annotation that sets a
  # value matches.
  defp collect_doc_range({:@, meta, [{attribute, _, [_value]}]} = node, ranges)
       when attribute in @doc_attributes do
    last_line = get_in(meta, [:end_of_expression, :line]) || meta[:line]
    {node, [{meta[:line], last_line} | ranges]}
  end

  defp collect_doc_range(node, ranges), do: {node, ranges}

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
