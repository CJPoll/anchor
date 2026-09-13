defmodule Anchor.Domain.RuleMatching do
  @moduledoc """
  Pure rule-selection predicates: does a parsed rule apply to a given file?

  Domain bucket (ADR 001): these functions operate only on a parsed rule map and
  a set of **already-derived facts** about the file. They never read source,
  never parse an AST, and never call Credo. Deriving the facts (running the AST
  through `Anchor.DependencyAnalyzer`, reading `source_file.filename`) is the
  caller's job — `Anchor.Check.Base` does it and hands the results in.

  A rule selects a file by exactly one of three selectors, tried in order:

    1. `paths` — a list of globs matched against the filename (recursive `**`
       semantics when `recursive` is true, single-`*` semantics otherwise).
    2. `pattern` — a module-name glob matched against any of the file's module
       names.
    3. `uses_module` — the file `use`s the named module.

  A rule carrying none of these selects nothing (deny by default).
  """

  alias Anchor.Domain.GlobPattern

  @typedoc """
  Facts about a source file, derived by the caller before selection.

    * `:filename` — the file's path, as a string.
    * `:module_names` — the module names the file defines, as strings. A file
      with several modules is selectable if ANY of them matches a module
      `pattern` rule.
    * `:uses` — the modules the file `use`s, as module atoms.
  """
  @type facts :: %{
          :filename => String.t(),
          :module_names => [String.t()],
          :uses => [module()],
          optional(any()) => any()
        }

  @doc """
  Returns `true` when the rule's `type` equals `rule_type`.

  This is the first, cheap gate: a check only considers rules declared for it.
  """
  @spec rule_matches_type?(map(), atom()) :: boolean()
  def rule_matches_type?(rule, rule_type), do: rule.type == rule_type

  @doc """
  Returns `true` when `rule` selects the file described by `facts`.

  Selection is by `paths`, then module `pattern`, then `uses_module`; a rule
  with none of those selectors returns `false` (deny by default).
  """
  @spec rule_matches_file?(map(), facts()) :: boolean()
  def rule_matches_file?(%{paths: paths, recursive: recursive}, %{filename: filename})
      when is_list(paths) do
    Enum.any?(paths, fn pattern ->
      if recursive do
        GlobPattern.matches_recursive_pattern?(filename, pattern)
      else
        GlobPattern.matches_pattern?(filename, pattern)
      end
    end)
  end

  def rule_matches_file?(%{pattern: pattern}, %{module_names: module_names})
      when is_binary(pattern) do
    Enum.any?(module_names, &GlobPattern.matches_module_pattern?(&1, pattern))
  end

  def rule_matches_file?(%{uses_module: uses_module}, %{uses: uses})
      when is_binary(uses_module) do
    Module.concat([uses_module]) in uses
  end

  def rule_matches_file?(_rule, _facts), do: false
end
