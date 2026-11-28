defmodule Anchor.Test.CountingTransitiveDetector do
  @moduledoc """
  `Anchor.Domain.Checks.NoTransitiveDependency` as a detector that also
  reports, to the calling process, the start module of every search tree each
  `detect/1` call built (DND-8208). `Anchor.Managers.Lint` runs a detector in
  the caller's process, so a test handing this one to `Lint.run/4` receives a
  `{:transitive_walks, [module]}` message per detect call and can count the
  walks a whole run makes.
  """

  use Anchor.Domain.Detector

  alias Anchor.Domain.Checks.NoTransitiveDependency

  @impl Anchor.Domain.Detector
  def detect(%Anchor.Domain.Detector.Input{} = input) do
    {violations, trees} =
      NoTransitiveDependency.detect_with_trees(input.ast, input.rules, input.modules_map)

    send(self(), {:transitive_walks, Enum.map(trees, & &1.start)})
    violations
  end

  @impl Anchor.Domain.Detector
  def needs_module_graph?, do: true

  @impl Anchor.Domain.Detector
  def rule_type, do: NoTransitiveDependency.rule_type()
end
