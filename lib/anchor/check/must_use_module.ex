defmodule Anchor.Check.MustUseModule do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.MustUseModule,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules must use specific modules
      as specified in the .anchor.yml configuration file: every module under
      `required_modules`, or at least one of the modules under
      `required_any_of_modules` (the two keys cannot be combined on one rule).
      """
    ]
end
