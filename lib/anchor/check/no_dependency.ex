defmodule Anchor.Check.NoDependency do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      This check ensures that modules do not have direct dependencies on forbidden modules
      as specified in the .anchor.yml configuration file.
      """
    ]

  @doc false
  def rule_type, do: :no_direct_dependency

  # Thin Framework delegate: the Manager hands over the bare AST and the rules it
  # already selected; detection lives in the pure Domain module, and Base maps the
  # returned `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  #
  # Gap F (DND-150): derive the checked file's own context from the file's
  # defining module name (threaded by the Manager as `context.module_names`) and
  # pass it into the Domain detector so `same_context` rules can scope their
  # `forbidden_patterns` matches. The file context is the leading namespace
  # segments of the file's FIRST defining module; the Domain truncates it to each
  # rule's `context_depth`. A file with no derivable module name yields a `nil`
  # context (no scoping, no crash).
  @doc false
  def detect_violations(_source_file, ast, rules, context) do
    file_context =
      context
      |> Map.get(:module_names, [])
      |> file_context()

    Anchor.Domain.Checks.NoDependency.detect_violations(ast, rules, file_context)
  end

  # The file's own context: the namespace segments of its first defining module,
  # as bare strings (leading `Elixir.` dropped so real Manager-supplied names and
  # test-supplied bare names both work). `nil` when the file defines no module.
  defp file_context([]), do: nil
  defp file_context([module_name | _rest]), do: name_segments(module_name)

  defp name_segments(module_name) do
    case String.split(module_name, ".") do
      ["Elixir" | rest] -> rest
      segments -> segments
    end
  end
end
