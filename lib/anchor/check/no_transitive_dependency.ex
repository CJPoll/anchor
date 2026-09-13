defmodule Anchor.Check.NoTransitiveDependency do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have transitive dependencies on forbidden modules
      as specified in the .anchor.yml configuration file. A transitive dependency means that
      the module depends on another module that eventually depends on the forbidden module,
      even if not directly.
      """
    ]

  @doc false
  def rule_type, do: :no_transitive_dependency

  @doc false
  # This check needs the cross-file module dependency graph; the Manager builds
  # it once (because this check declares `needs_module_graph?/0 == true`) and
  # hands it in via `context.modules_map`.
  def needs_module_graph?, do: true

  # Thin Framework delegate: the Manager hands over the bare AST, the rules it
  # already selected, and the module graph; detection lives in the pure Domain
  # module, and Base maps the returned `%Anchor.Domain.Violation{}`s onto
  # `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, context) do
    Anchor.Domain.Checks.NoTransitiveDependency.detect_violations(ast, rules, context.modules_map)
  end
end
