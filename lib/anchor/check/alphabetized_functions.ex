defmodule Anchor.Check.AlphabetizedFunctions do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.AlphabetizedFunctions,
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
      Sorting is case-insensitive. `defguard`/`defguardp` participate in ordering, and a function with
      multiple clauses is treated as a single unit anchored at its first clause.

      In :separate mode, the check enforces two rules:
      1. Alphabetical ordering within each visibility group (public and private)
      2. Structural ordering: all public functions must come before all private functions
      """
    ]
end
