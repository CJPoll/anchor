defmodule Anchor.Check.MaxFileLength do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.MaxFileLength,
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
end
