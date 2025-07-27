defmodule Anchor.Check.MaxFileLength do
  use Anchor.Check.Base,
    category: :readability,
    explanations: [
      check: """
      This check ensures that files do not exceed a maximum number of lines.

      Large files are harder to understand, navigate, and maintain. By limiting file length,
      you encourage better code organization and separation of concerns.

      The default maximum is 400 lines, but this can be configured.
      """
    ]

  @doc false
  def rule_type, do: :max_file_length

  @doc false
  def check_file(source_file, rules, params) do
    lines = Credo.Code.to_lines(source_file)
    line_count = length(lines)

    Enum.flat_map(rules, fn rule ->
      max_lines = get_max_lines(rule)

      if line_count > max_lines do
        [create_issue(source_file, line_count, max_lines, params)]
      else
        []
      end
    end)
  end

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
      message: "File contains #{line_count} lines (maximum allowed: #{max_lines}). " <>
               "Consider breaking this file into smaller, more focused modules.",
      line_no: 1,
      trigger: source_file.filename
    )
  end
end