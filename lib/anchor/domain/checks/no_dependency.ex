defmodule Anchor.Domain.Checks.NoDependency do
  @moduledoc """
  Pure detection for the "no forbidden direct dependency" check — the **Domain**
  bucket (ADR 001).

  Given an already-acquired AST and the rules already selected for the file (the
  Manager does rule selection; the Framework edge acquires the AST), this returns
  the `%Anchor.Domain.Violation{}` list the check reports. Every function here is
  side-effect-free: same AST and rules in, same violations out. There is **zero
  `Credo.*`** and no IO — mapping a `%Violation{}` onto a `Credo.Issue` is the
  Framework's job (`Anchor.Check.Base`), and acquiring the AST is
  `Anchor.Check.Source`'s.

  This is the first `Anchor.Domain.Checks.*` module; later per-check extractions
  (T6.x) mirror its shape: a pure `detect_violations/N` that takes the bare AST
  plus the pre-selected rules and returns `[%Anchor.Domain.Violation{}]`.

  ## What it detects

  For each rule, every `forbidden_modules` entry the file directly references
  (per `Anchor.Domain.DependencyAnalyzer.extract_direct_dependencies/1`) yields
  one violation. A forbidden module that appears more than once is reported once,
  at the **first** reference line (the earliest occurrence in pre-order source
  traversal); when the module cannot be located in the AST the line is `nil`
  (Credo then defaults it).
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`.

  Each rule contributes one violation per forbidden module the AST directly
  references; each distinct forbidden module is reported once, at its first
  reference line.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    dependencies = DependencyAnalyzer.extract_direct_dependencies(ast)

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []

      forbidden
      |> Enum.filter(&(&1 in dependencies))
      |> Enum.map(&build_violation(&1, ast))
    end)
  end

  defp build_violation(forbidden_module, ast) do
    %Violation{
      message: "Module has forbidden direct dependency on #{inspect(forbidden_module)}",
      line: first_reference_line(ast, forbidden_module),
      trigger: inspect(forbidden_module)
    }
  end

  # The line of the FIRST reference to `module` in `ast`. Pre-order traversal
  # visits the earliest source occurrence first, so once a line is recorded it is
  # never overwritten by a later match. `nil` when the module is not located.
  defp first_reference_line(ast, module) do
    module_parts = module |> Module.split() |> Enum.map(&String.to_atom/1)

    {_ast, line} =
      Macro.prewalk(ast, nil, fn
        {:__aliases__, meta, ^module_parts} = node, nil ->
          {node, Keyword.get(meta, :line)}

        {{:., _, [{:__aliases__, meta, ^module_parts}, _]}, _, _} = node, nil ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
