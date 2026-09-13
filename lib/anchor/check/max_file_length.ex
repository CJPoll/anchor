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

  # Thin Framework delegate: acquire the file's lines (via `Source`) and hand
  # them, the bare AST already acquired at the edge, the Manager-selected rules,
  # and the filename to the pure Domain detector; `Base` maps the returned
  # `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(source_file, ast, rules, _context) do
    lines = Source.to_lines(source_file)

    Anchor.Domain.Checks.MaxFileLength.detect_violations(
      lines,
      ast,
      rules,
      source_file.filename
    )
  end
end
