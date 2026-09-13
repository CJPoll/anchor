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

  A `forbidden_modules` entry may be an Elixir alias (`MyApp.Repo`) or a bare
  Erlang/OTP atom (`:telemetry`); the latter matches a bare-atom remote call and
  is located by its call-callee node (never `Module.split/1`, which raises on a
  non-Elixir atom).
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`.

  Each rule contributes one violation per forbidden module the AST directly
  references; each distinct forbidden module is reported once, at its first
  reference line.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn rule ->
      dependencies = dependencies_for(ast, Map.get(rule, :match, :reference))
      forbidden_modules = rule.forbidden_modules || []
      forbidden_patterns = Map.get(rule, :forbidden_patterns, []) || []

      dependencies
      |> Enum.filter(&forbidden?(&1, forbidden_modules, forbidden_patterns))
      |> Enum.map(&build_violation(&1, ast))
    end)
  end

  # Gap A' (DND-142): the dependency set the rule consults. `:call` mode looks at
  # call-position dependencies only (honoring the router carve-out); `:reference`
  # (default) at every referenced module, as before.
  defp dependencies_for(ast, :call), do: DependencyAnalyzer.extract_call_dependencies(ast)
  defp dependencies_for(ast, _match), do: DependencyAnalyzer.extract_direct_dependencies(ast)

  # A dependency is forbidden when it is an exact `forbidden_modules` entry (Gap
  # B lets that be a bare Erlang atom) OR its module name matches a
  # `forbidden_patterns` glob (Gap A). A module matched by both is filtered once,
  # so it is reported once.
  defp forbidden?(dependency, forbidden_modules, forbidden_patterns) do
    dependency in forbidden_modules or matches_any_pattern?(dependency, forbidden_patterns)
  end

  defp matches_any_pattern?(dependency, patterns) do
    module_name = to_string(dependency)
    Enum.any?(patterns, &GlobPattern.matches_module_pattern?(module_name, &1))
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
  #
  # An Elixir alias module (`MyApp.Repo`) is located by its `:__aliases__` parts.
  # A bare-atom Erlang/OTP module (`:telemetry`) is located by its remote-call
  # callee node instead — `Module.split/1` raises on a non-Elixir atom, so it is
  # never called for one.
  defp first_reference_line(ast, module) do
    if elixir_module?(module) do
      alias_reference_line(ast, module |> Module.split() |> Enum.map(&String.to_atom/1))
    else
      atom_reference_line(ast, module)
    end
  end

  defp elixir_module?(module), do: match?("Elixir." <> _, Atom.to_string(module))

  defp alias_reference_line(ast, module_parts) do
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

  defp atom_reference_line(ast, atom) do
    {_ast, line} =
      Macro.prewalk(ast, nil, fn
        {{:., _, [^atom, _fun]}, meta, _args} = node, nil ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
