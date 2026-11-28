defmodule Anchor.Domain.DependencyTree do
  @moduledoc """
  One module's depth-first search tree over a module dependency graph — the
  **Domain** bucket (ADR 001). Pure: a `modules_map` and a start module in, a
  struct out.

  `build/2` walks the graph once from `start`, in `direct_dependencies` order,
  expanding each reachable module exactly once, and records for every module it
  reaches the module whose dependencies it was first found among (its parent).
  From that one walk:

    * `reachable/1` is the set of modules reachable from `start`, `start`
      included: the set `Anchor.Domain.DependencyAnalyzer.find_transitive_dependencies/2`
      returns, built in the same pre-order;
    * `path/2` is the dependency path from `start` to a target, read back
      along the parents, in time linear in the path's length.

  ## Why the path is the one a targeted search reports

  Before DND-8208, `Anchor.Domain.Checks.NoTransitiveDependency` ran a
  targeted search for each finding (kept now as the tests' reference,
  `find_dependency_path/3` in `Anchor.Test.TransitiveDependencyOracle`): depth
  first from `start` in the same order, with one visited set shared by every
  branch, stopping the first time it meets the target. Until that moment it
  does exactly what this walk does: the same modules, expanded in the same
  order, with the same visited set. So when it meets the target, its current
  branch is this walk's branch at the moment it first reaches the target,
  which is the parent chain recorded here. Building the tree once and reading
  every target's path from it reports the same path as one search per target,
  without the repeated walk.

  `expanded` counts the modules whose dependencies the walk read, so a test can
  see that each is read once.
  """

  @enforce_keys [:start, :parents, :reached, :expanded]
  defstruct [:start, :parents, :reached, :expanded]

  @type t :: %__MODULE__{
          start: module(),
          parents: %{module() => module()},
          reached: MapSet.t(module()),
          expanded: non_neg_integer()
        }

  @doc """
  The search tree of `start` over `modules_map` (each module mapped to
  `%{direct_dependencies: [module]}`). A module with no entry has no
  dependencies; cycles and self-edges terminate.
  """
  @spec build(map(), module()) :: t()
  def build(modules_map, start) do
    initial = %__MODULE__{start: start, parents: %{}, reached: MapSet.new(), expanded: 0}
    walk(modules_map, start, initial)
  end

  defp dependencies_of(modules_map, module) do
    case Map.get(modules_map, module) do
      nil -> []
      %{direct_dependencies: deps} -> deps
    end
  end

  @doc """
  The dependency path from the tree's start to `target`, both ends included, or
  `nil` when `target` is not reachable. The path to the start itself is
  `[start]`.
  """
  @spec path(t(), module()) :: [module()] | nil
  def path(%__MODULE__{} = tree, target) do
    if MapSet.member?(tree.reached, target), do: path_to(tree, target, [target])
  end

  defp path_to(%__MODULE__{start: start}, start, path), do: path

  defp path_to(tree, module, path) do
    parent = Map.fetch!(tree.parents, module)
    path_to(tree, parent, [parent | path])
  end

  @doc "Every module reachable from the tree's start, the start included."
  @spec reachable(t()) :: MapSet.t(module())
  def reachable(%__MODULE__{reached: reached}), do: reached

  defp visit(modules_map, parent, dep, tree) do
    if MapSet.member?(tree.reached, dep) do
      tree
    else
      walk(modules_map, dep, %{tree | parents: Map.put(tree.parents, dep, parent)})
    end
  end

  # Pre-order, in dependency order: a module is marked reached when it is
  # expanded, and each dependency met for the first time records `current` as
  # its parent before it is expanded in turn.
  defp walk(modules_map, current, tree) do
    tree = %{tree | reached: MapSet.put(tree.reached, current), expanded: tree.expanded + 1}

    modules_map
    |> dependencies_of(current)
    |> Enum.reduce(tree, &visit(modules_map, current, &1, &2))
  end
end
