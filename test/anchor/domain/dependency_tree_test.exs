defmodule Anchor.Domain.DependencyTreeTest do
  # `Anchor.Domain.DependencyTree` (DND-8208): one depth-first walk per module,
  # giving the reachable set `DependencyAnalyzer.find_transitive_dependencies/2`
  # returns and, for every target, the path the targeted search
  # `find_dependency_path/3` returns (the check's own search before DND-8208,
  # now kept in `Anchor.Test.TransitiveDependencyOracle`). Both stay the
  # references these rows compare against.
  #
  # Sabotage record:
  #   ../../sabotage_records/dependency_tree-20261127-athena_transitive_reachability_once.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.DependencyTree
  alias Anchor.Test.TransitiveDependencyOracle
  alias Anchor.Test.TransitiveGraphFixtures

  # A walk or a path read back that stops terminating (a parent cycle followed
  # forever) fails its test at this heap bound, about 80 MB, instead of growing
  # until the host kills the run. The 5,000-module rows need a fraction of it.
  setup do
    Process.flag(:max_heap_size, %{size: 10_000_000, kill: true, error_logger: false})
    :ok
  end

  setup_all do
    {modules_map, _sources} = TransitiveGraphFixtures.graph()
    %{fixture: modules_map}
  end

  defp graph(edges), do: Map.new(edges, fn {m, deps} -> {m, %{direct_dependencies: deps}} end)

  # Every reachable target's path from the tree, beside the targeted search's.
  defp paths_both_ways(modules_map, start) do
    tree = DependencyTree.build(modules_map, start)

    for target <- DependencyTree.reachable(tree), target != start do
      {path, _expanded} =
        TransitiveDependencyOracle.find_dependency_path(modules_map, start, target)

      {target, DependencyTree.path(tree, target), path}
    end
  end

  describe "build/2 and reachable/1" do
    test "a chain, a module absent from the map, and the start itself" do
      modules_map = graph(%{A => [B], B => [C, Enum], C => []})

      assert modules_map |> DependencyTree.build(A) |> DependencyTree.reachable() ==
               MapSet.new([A, B, C, Enum])
    end

    test "a cycle and a self-edge terminate, each module expanded once" do
      modules_map = graph(%{A => [A, B], B => [C], C => [A, B]})
      tree = DependencyTree.build(modules_map, A)

      assert DependencyTree.reachable(tree) == MapSet.new([A, B, C])
      assert tree.expanded == 3
    end

    test "a start absent from the map reaches only itself" do
      tree = DependencyTree.build(%{}, A)

      assert DependencyTree.reachable(tree) == MapSet.new([A])
      assert DependencyTree.path(tree, A) == [A]
    end

    test "equals find_transitive_dependencies/2, and expands each reachable module once, on the 5,000-module fixture",
         %{fixture: modules_map} do
      for start <- TransitiveGraphFixtures.domain_modules() do
        tree = DependencyTree.build(modules_map, start)
        reference = DependencyAnalyzer.find_transitive_dependencies(modules_map, start)

        assert {start, DependencyTree.reachable(tree)} == {start, reference}
        assert {start, tree.expanded} == {start, MapSet.size(reference)}
      end
    end
  end

  describe "path/2" do
    test "an unreachable target is nil" do
      tree = DependencyTree.build(graph(%{A => [B], B => []}), A)

      assert DependencyTree.path(tree, C) == nil
    end

    test "of two routes, the first in dependency order, not the shortest" do
      modules_map = graph(%{A => [B, D], B => [C], C => [Repo], D => [Repo]})

      assert DependencyTree.path(DependencyTree.build(modules_map, A), Repo) == [A, B, C, Repo]
    end

    test "past a dead end shared by two routes, the later route's path" do
      modules_map = graph(%{A => [B, C], B => [Dead], C => [Dead, Repo], Dead => [Enum]})

      assert DependencyTree.path(DependencyTree.build(modules_map, A), Repo) == [A, C, Repo]
    end

    test "a module first met on a cycle keeps the parent it was first met from" do
      modules_map = graph(%{A => [B, C], B => [C, A], C => [B, Repo]})

      assert DependencyTree.path(DependencyTree.build(modules_map, A), Repo) == [A, B, C, Repo]
    end

    test "every target's path equals find_dependency_path/3's, on hand graphs" do
      graphs = [
        graph(%{A => [B, D], B => [C], C => [Repo], D => [Repo]}),
        graph(%{A => [B, C], B => [Dead], C => [Dead, Repo], Dead => [Enum]}),
        graph(%{A => [B, C], B => [C, A], C => [B, Repo]}),
        graph(%{A => [A, B], B => [C, B], C => [A, D], D => []})
      ]

      for modules_map <- graphs,
          {target, tree_path, search_path} <- paths_both_ways(modules_map, A) do
        assert {target, tree_path} == {target, search_path}
      end
    end

    test "every target's path equals find_dependency_path/3's, from a sample of the fixture's modules",
         %{fixture: modules_map} do
      starts = TransitiveGraphFixtures.domain_modules() |> Enum.take_every(10)

      compared =
        for start <- starts,
            {target, tree_path, search_path} <- paths_both_ways(modules_map, start) do
          assert {start, target, tree_path} == {start, target, search_path}
          length(tree_path)
        end

      # The sample is not vacuous: it compares many paths, some of them long.
      assert length(compared) > 1_000
      assert Enum.max(compared) > 5
    end
  end
end
