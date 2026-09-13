defmodule Anchor.Domain.Checks.ModulePatternRestrictions do
  @moduledoc """
  Pure detection for the `module_pattern_restrictions` check — the **Domain**
  bucket (ADR 001).

  A `module_pattern_restrictions` rule says: a module the rule selects may only
  define functions named in the rule's `allowed_functions` list. Given an
  already-acquired AST and the rules for a file, this returns one
  `%Anchor.Domain.Violation{}` for every defined function (public **or** private)
  that is not allowed. Every function here is side-effect-free — same AST and
  rules in, same violations out — with **zero `Credo.*`** and no IO: mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.ModulePatternRestrictions` via `Anchor.Check.Base`).

  ## Selection

  Unlike `no_dependency`/`must_use_module`, this check's `pattern` / `uses_module`
  selector is intrinsic to what it means: it names *which* modules are
  restricted. So detection applies that module-based selection itself, reusing
  T5's plural `Anchor.Domain.DependencyAnalyzer.extract_module_names/1` (matched
  through `Anchor.Domain.GlobPattern.matches_module_pattern?/2`) for a `pattern`
  rule and `extract_uses/1` for a `uses_module` rule. A rule that carries neither
  module-based selector is treated as selected — path-scoping (`paths`) stays the
  Manager's concern (`Anchor.Managers.Lint` via `Anchor.Domain.RuleMatching`), so
  a legitimately path-selected rule is never dropped here.

  The former `paths: []` selection shadow — where every *parsed* rule was stamped
  with `paths: []`, so `RuleMatching` never selected a `pattern`/`uses_module`
  rule in the real config flow — was fixed in Gap D (DND-140):
  `Anchor.Config.parse_rule/1` now surfaces an absent `paths` as `nil` and
  `Anchor.Domain.RuleMatching` gates its path clause on a non-empty list, so a
  `pattern`/`uses_module` rule is selected by `RuleMatching` in the real config
  flow. This check's own module-based selection (below) is unchanged; it is
  exercised via **sparse** rule maps (no `:paths` key).

  ## Allowed-function matching

  An `allowed_functions` entry containing `*` is a name glob (`with_*` allows
  `with_status`), matched through `Anchor.Domain.GlobPattern.matches_pattern?/2`.
  An entry with no `*` is matched by exact name equality, preserving the original
  literal-membership behavior (and avoiding treating a trailing `?`/`!` in a
  function name as a regex metacharacter).
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-typed `rules`.

  For each rule that selects the file, every defined function (public or private)
  not permitted by the rule's `allowed_functions` yields one violation, reported
  at the function's definition line with the function name as the trigger. A
  function defined by several clauses is reported once (name-deduped). A rule
  whose `pattern`/`uses_module` selector does not match the file contributes no
  violations.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn rule ->
      if rule_selects_file?(rule, ast) do
        allowed = Map.get(rule, :allowed_functions) || []

        ast
        |> extract_defined_functions()
        |> Enum.reject(&allowed?(&1, allowed))
        |> Enum.map(&build_violation(&1, ast))
      else
        []
      end
    end)
  end

  # `pattern` (module-name glob over the file's module names) and `uses_module`
  # (the file `use`s the named module) are the module-based selectors this check
  # owns. A rule carrying neither is treated as selected — its `paths` scoping,
  # if any, was already applied by the Manager.
  defp rule_selects_file?(rule, ast) do
    cond do
      is_binary(Map.get(rule, :pattern)) ->
        ast
        |> DependencyAnalyzer.extract_module_names()
        |> Enum.map(&to_string/1)
        |> Enum.any?(&GlobPattern.matches_module_pattern?(&1, rule.pattern))

      is_binary(Map.get(rule, :uses_module)) ->
        Module.concat([rule.uses_module]) in DependencyAnalyzer.extract_uses(ast)

      true ->
        true
    end
  end

  defp allowed?(function_name, allowed_functions) do
    Enum.any?(allowed_functions, &function_matches?(function_name, &1))
  end

  # A glob entry (`with_*`) goes through GlobPattern; a literal entry is an exact
  # name match, so a function name ending in `?`/`!` is never read as a regex.
  defp function_matches?(function_name, entry) do
    if String.contains?(entry, "*") do
      GlobPattern.matches_pattern?(function_name, entry)
    else
      function_name == entry
    end
  end

  defp extract_defined_functions(ast) do
    {_ast, functions} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:def, _meta, [{name, _, _} | _]} = node, acc when is_atom(name) ->
          {node, MapSet.put(acc, to_string(name))}

        {:defp, _meta, [{name, _, _} | _]} = node, acc when is_atom(name) ->
          {node, MapSet.put(acc, to_string(name))}

        node, acc ->
          {node, acc}
      end)

    MapSet.to_list(functions)
  end

  defp build_violation(function_name, ast) do
    %Violation{
      message: "Module defines non-allowed function: #{function_name}",
      line: find_function_line(ast, function_name),
      trigger: function_name
    }
  end

  defp find_function_line(ast, function_name) do
    function_atom = String.to_atom(function_name)

    {_ast, line} =
      Macro.prewalk(ast, nil, fn
        {:def, meta, [{^function_atom, _, _} | _]} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        {:defp, meta, [{^function_atom, _, _} | _]} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
