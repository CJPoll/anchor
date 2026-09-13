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

  ## Same-context scoping (Gap F)

  A rule may set `same_context: true` to scope its `forbidden_patterns` matches
  to the checked file's own context (its first `context_depth` namespace
  segments) — reporting a pattern match only when the dependency shares that
  context. Exact `forbidden_modules` matches are never scoped, a
  fewer-than-`context_depth` or `nil` context is the deny-side (nothing
  reported), and `same_context: false`/absent reports every match exactly as
  before. `detect_violations/3` carries the full semantics; the `/2` back-compat
  entry point passes `file_context: nil` (no scoping).
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`.

  Back-compat entry point: delegates to `detect_violations/3` with
  `file_context: nil`, i.e. no `same_context` scoping — identical to the
  behavior before Gap F (DND-150).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules), do: detect_violations(ast, rules, nil)

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`,
  scoping `forbidden_patterns` matches to the checked file's own context when a
  rule sets `same_context: true` (Gap F, DND-150).

  `file_context` is the checked file's own context — the list of leading
  namespace segments of its defining module (e.g. `["WaltUi", "Contacts"]`) — or
  `nil` when the file has no derivable module name. It is compared segment-for-
  segment against each dependency's own context, truncated to the rule's
  `context_depth`.

  Scoping rules (only when a rule's `same_context` is `true`):

    * A `forbidden_patterns` match is reported **iff** the dependency's context
      equals the file's context (both truncated to `context_depth`).
    * A dependency (or the file) with fewer than `context_depth` namespace
      segments has no derivable context → treated as **not** same-context → not
      reported.
    * `file_context: nil` under a `same_context` rule reports nothing for that
      rule's pattern matches — the deny-side default: with no file context to
      compare, a scoped match cannot be confirmed same-context.

  Exact `forbidden_modules` matches are **never** scoped — they always report,
  regardless of `same_context`. When `same_context` is `false`/absent, every
  pattern match is reported exactly as before (hard back-compat guarantee).
  """
  @spec detect_violations(Macro.t(), [map()], [String.t()] | nil) :: [Violation.t()]
  def detect_violations(ast, rules, file_context) do
    Enum.flat_map(rules, fn rule ->
      dependencies = dependencies_for(ast, Map.get(rule, :match, :reference))
      forbidden_modules = rule.forbidden_modules || []
      forbidden_patterns = Map.get(rule, :forbidden_patterns, []) || []
      same_context = Map.get(rule, :same_context, false)
      context_depth = Map.get(rule, :context_depth, 2)

      dependencies
      |> Enum.filter(
        &forbidden?(
          &1,
          forbidden_modules,
          forbidden_patterns,
          same_context,
          context_depth,
          file_context
        )
      )
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
  # `forbidden_patterns` glob (Gap A) that is in-scope for this rule (Gap F). A
  # module matched by both is filtered once, so it is reported once.
  #
  # Exact `forbidden_modules` matches are NEVER scoped by `same_context` — they
  # name absolute IO modules (`Repo`, `:telemetry`) for which a same-subdomain
  # qualifier is meaningless. Only `forbidden_patterns` matches are scoped.
  defp forbidden?(
         dependency,
         forbidden_modules,
         forbidden_patterns,
         same_context,
         context_depth,
         file_context
       ) do
    dependency in forbidden_modules or
      pattern_forbidden?(
        dependency,
        forbidden_patterns,
        same_context,
        context_depth,
        file_context
      )
  end

  defp pattern_forbidden?(dependency, patterns, same_context, context_depth, file_context) do
    matches_any_pattern?(dependency, patterns) and
      in_scope?(dependency, same_context, context_depth, file_context)
  end

  # Gap F scoping gate. `same_context: false`/absent => every pattern match is in
  # scope (report it), preserving pre-Gap-F behavior exactly. When `true`, a
  # match is in scope only if the dependency and the file share a context: both
  # module names must have at least `context_depth` segments and their first
  # `context_depth` segments must be equal. A `nil` file context (no derivable
  # module name) is the deny-side default — nothing to compare, so not in scope.
  defp in_scope?(_dependency, false, _context_depth, _file_context), do: true

  defp in_scope?(dependency, true, context_depth, file_context) do
    file_ctx = context_prefix(file_context, context_depth)
    dep_ctx = context_prefix(dependency_segments(dependency), context_depth)

    not is_nil(file_ctx) and not is_nil(dep_ctx) and file_ctx == dep_ctx
  end

  # The first `context_depth` segments of a segment list, or `nil` when there are
  # fewer than `context_depth` of them (no derivable context). A `nil` input
  # (absent file context) stays `nil`.
  defp context_prefix(nil, _context_depth), do: nil

  defp context_prefix(segments, context_depth) do
    if length(segments) >= context_depth, do: Enum.take(segments, context_depth), else: nil
  end

  # A dependency's own namespace segments, as bare strings (`["WaltUi",
  # "Contacts", ...]`). A bare Erlang/OTP atom (`:telemetry`) has no Elixir
  # namespace, so it yields `[]` and never derives a context — `Module.split/1`
  # would raise on it, so it is never called for one.
  defp dependency_segments(dependency) do
    if elixir_module?(dependency), do: Module.split(dependency), else: []
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
