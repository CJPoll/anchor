defmodule Anchor.Check.ModulePatternRestrictions do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.ModulePatternRestrictions,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules matching specific patterns only define
      allowed functions as specified in the .anchor.yml configuration file.
      """
    ]
end
