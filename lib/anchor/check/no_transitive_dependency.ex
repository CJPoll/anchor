defmodule Anchor.Check.NoTransitiveDependency do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.NoTransitiveDependency,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have transitive dependencies on forbidden modules
      as specified in the .anchor.yml configuration file. A transitive dependency means that
      the module depends on another module that eventually depends on the forbidden module,
      even if not directly.
      """
    ]
end
