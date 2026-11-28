defmodule Anchor.Domain.Checks.NoTransitiveDependency do
  @moduledoc """
  Pure detection for the `no_transitive_dependency` check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired AST, the `no_transitive_dependency` rules that apply
  to a file, and the cross-file module dependency graph, it returns the
  `%Anchor.Domain.Violation{}` list for every forbidden module a module in the
  file can reach *transitively*. It is side-effect-free — same AST, rules, and
  graph in, same violations out — with **zero `Credo.*`** and no IO: mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.NoTransitiveDependency` via `Anchor.Check.Base`), rule
  *selection* is the Manager's (`Anchor.Managers.Lint`), and building the
  `modules_map` is the Manager's too (it declares `needs_module_graph?/0` on the
  check and reduces `Anchor.Domain.DependencyAnalyzer.module_dependencies/1` over
  the source files). This function receives the finished graph.

  ## What it detects

  For each module the file defines, it walks the graph once per call
  (`Anchor.Domain.DependencyTree.build/2`) and takes the transitively-reachable
  set (the set `Anchor.Domain.DependencyAnalyzer.find_transitive_dependencies/2`
  returns) with the module itself removed — a module is never its own
  transitive dependency, and self-edges/cycles terminate rather than loop. Every forbidden module in that
  set yields one violation, carrying:

    * the forbidden module's inspected name as the trigger,
    * the line of the module's *direct* reference that begins the path, and
    * a message naming the forbidden module and, when the path has more than two
      nodes, the full `A -> B -> ... -> Forbidden` dependency chain. A path of
      length two (a direct dependency that also counts as transitive) carries no
      chain suffix.
  """

  use Anchor.Domain.Detector

  @doc "The rule type this detector reads (DND-8063)."
  @impl Anchor.Domain.Detector
  def rule_type, do: :no_transitive_dependency

  @doc false
  @impl Anchor.Domain.Detector
  def needs_module_graph?, do: true

  @doc "Detects one file's `%Anchor.Domain.Detector.Input{}` (DND-8063)."
  @impl Anchor.Domain.Detector
  def detect(%Anchor.Domain.Detector.Input{} = input),
    do: detect_violations(input.ast, input.rules, input.modules_map)

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.DependencyTree
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @impl Anchor.Domain.RuleShape
  def shape(rule) do
    forbidden =
      Enum.map(Map.get(rule, :forbidden_modules) || [], &inspect/1) ++
        (Map.get(rule, :forbidden_patterns) || [])

    "no chain of dependencies from the module reaches #{Enum.join(forbidden, ", ")}; cut " <>
      "the chain where it first enters a module that depends on it"
  end

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`
  and the cross-file `modules_map`.

  `rules` is the list of already-selected `no_transitive_dependency` rule maps,
  each carrying `:forbidden_modules` (a possibly-`nil` list of module atoms).
  `modules_map` maps each module to `%{direct_dependencies: [module]}` — the
  graph the Manager builds. Each module the file defines contributes one
  violation per forbidden module it can reach transitively (self removed).

  Each call does one depth-first walk per module the file defines
  (`Anchor.Domain.DependencyTree.build/2`): its tree gives both the reachable
  set and the path to every forbidden module the module reaches, so the work
  does not grow with the number of findings (DND-8208). It is one walk per
  module per call, not per run: `Anchor.Managers.Lint` calls the detector once
  for a file's rules without a `baseline:` and once more for each baselined
  rule, so a module that k baselined rules select is walked 1 + k times (k
  alone when every selecting rule is baselined). `detect_with_trees/3` also
  returns the trees, so a test can count the walks.
  """
  @spec detect_violations(Macro.t(), [map()], map()) :: [Violation.t()]
  def detect_violations(ast, rules, modules_map) do
    {violations, _trees} = detect_with_trees(ast, rules, modules_map)
    violations
  end

  @doc """
  `detect_violations/3`'s violations, and every search tree the detection
  built, in the order it built them: one per module the file defines. A tree's
  `expanded` is how many modules its walk read the dependencies of. The check
  uses only the violations; the trees are there so a test can see the work.
  """
  @spec detect_with_trees(Macro.t(), [map()], map()) :: {[Violation.t()], [DependencyTree.t()]}
  def detect_with_trees(ast, rules, modules_map) do
    {per_module, trees} =
      ast
      |> DependencyAnalyzer.extract_module_names()
      |> Enum.map(&violations_and_tree(DependencyTree.build(modules_map, &1), rules, ast))
      |> Enum.unzip()

    {Enum.concat(per_module), trees}
  end

  defp violations_and_tree(tree, rules, ast), do: {violations_for_module(tree, rules, ast), tree}

  defp violations_for_module(tree, rules, ast) do
    transitive_deps =
      tree
      |> DependencyTree.reachable()
      |> MapSet.delete(tree.start)
      |> MapSet.to_list()

    Enum.flat_map(rules, fn rule ->
      forbidden = rule.forbidden_modules || []

      matches_pattern? =
        GlobPattern.module_pattern_matcher(Map.get(rule, :forbidden_patterns) || [])

      transitive_deps
      |> Enum.filter(&forbidden?(&1, forbidden, matches_pattern?))
      |> Enum.map(&RuleShapes.with_shape(build_violation(&1, tree, ast), shape(rule)))
    end)
  end

  # Gap A (DND-142): a transitively-reachable module is forbidden when it is an
  # exact `forbidden_modules` entry OR its module name matches a
  # `forbidden_patterns` glob. Graph edges stay reference-based; `match` mode is
  # A'-scoped to `NoDependency` and is not consulted here.
  # The patterns are compiled once per rule and module (`matches_pattern?`), not
  # once per reachable module (DND-8208).
  defp forbidden?(module, forbidden_modules, matches_pattern?) do
    module in forbidden_modules or matches_pattern?.(to_string(module))
  end

  # The path is read from the module's one search tree, and is the path a
  # targeted first-hit search reports (see `Anchor.Domain.DependencyTree`).
  defp build_violation(forbidden_module, tree, ast) do
    path = DependencyTree.path(tree, forbidden_module)
    path_description = format_dependency_path(path)

    # The line where the current module references the first hop of the path.
    # The forbidden module is reachable and is not the current module, so the
    # path always has a first hop.
    line = find_module_reference_line(ast, Enum.at(path, 1))

    %Violation{
      message:
        "Module has transitive dependency on forbidden module #{inspect(forbidden_module)}#{path_description}",
      line: line,
      trigger: inspect(forbidden_module)
    }
  end

  defp format_dependency_path(nil), do: ""
  defp format_dependency_path(path) when length(path) <= 2, do: ""

  defp format_dependency_path(path) do
    chain =
      path
      |> Enum.map(&inspect/1)
      |> Enum.join(" -> ")

    " (dependency chain: #{chain})"
  end

  # The line where `module` is referenced in `ast`, or `nil` when it is not
  # located. (Behaviour preserved verbatim from the pre-extraction check.)
  defp find_module_reference_line(ast, module) do
    module_parts = module |> Module.split() |> Enum.map(&String.to_atom/1)

    {_ast, line} =
      Macro.prewalk(ast, nil, fn
        {:__aliases__, meta, ^module_parts} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        {{:., _, [{:__aliases__, meta, ^module_parts}, _]}, _, _} = node, _acc ->
          {node, Keyword.get(meta, :line)}

        node, acc ->
          {node, acc}
      end)

    line
  end
end
