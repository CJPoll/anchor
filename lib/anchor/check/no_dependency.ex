defmodule Anchor.Check.NoDependency do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.NoDependency,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have direct dependencies on forbidden modules
      as specified in the .anchor.yml configuration file.
      """
    ]
end
