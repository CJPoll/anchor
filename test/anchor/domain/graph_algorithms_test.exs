defmodule Anchor.Domain.GraphAlgorithmsTest do
  # DND-5444: dominators, post-dominators, components, SCCs, condensation.
  # Sabotage record: ../../sabotage_records/graph_algorithms-20261103-dnd_5439.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Digraph
  alias Anchor.Domain.GraphAlgorithms

  @vr Digraph.virtual_root()
  @vx Digraph.virtual_exit()

  defp graph(edges, nodes \\ []), do: Digraph.new(nodes, edges)

  # 30 graphs of 3 to 7 nodes: six hand-written shapes, then 24 built by a fixed
  # arithmetic rule (no random seed), each with a chain 0 -> 1 so root 0 reaches
  # something. Every third generated graph has a second root.
  defp small_graphs do
    hand = [
      {graph([{0, 1}, {1, 2}]), [0]},
      {graph([{0, 1}, {0, 2}, {1, 3}, {2, 3}]), [0]},
      {graph([{0, 1}, {1, 2}, {2, 1}, {2, 3}]), [0]},
      {graph([{0, 1}, {0, 2}, {1, 2}, {2, 1}]), [0]},
      {graph([{0, 2}, {1, 2}, {2, 3}]), [0, 1]},
      {graph([{0, 0}, {0, 1}, {1, 2}, {2, 0}], [3]), [0]}
    ]

    generated =
      for i <- 1..24 do
        n = 3 + rem(i, 5)

        edges =
          for u <- 0..(n - 1), v <- 0..(n - 1), rem(u * 5 + v * 3 + i * 7, 4) == 0, do: {u, v}

        roots = if rem(i, 3) == 0, do: [0, n - 1], else: [0]
        {graph([{0, 1} | edges], Enum.to_list(0..(n - 1))), roots}
      end

    hand ++ generated
  end

  defp reach(graph, starts, removed) do
    starts = Enum.reject(starts, &(&1 == removed))
    grow(graph, starts, MapSet.new(starts), removed)
  end

  defp grow(_graph, [], seen, _removed), do: seen

  defp grow(graph, [node | rest], seen, removed) do
    fresh =
      graph
      |> Digraph.successors(node)
      |> Enum.reject(&(&1 == removed or MapSet.member?(seen, &1)))

    grow(graph, fresh ++ rest, Enum.into(fresh, seen), removed)
  end

  # d dominates a reachable n when every root path to n passes d: with d removed,
  # n is no longer reachable.
  defp assert_brute_force_dominance(graph, roots, doms) do
    reachable = reach(graph, roots, nil)
    assert doms.unreachable == Enum.reject(Digraph.nodes(graph), &MapSet.member?(reachable, &1))

    for n <- reachable, d <- Digraph.nodes(graph) do
      expected = d == n or not MapSet.member?(reach(graph, roots, d), n)

      assert GraphAlgorithms.dominates?(doms, d, n) == expected,
             "dominates?(#{inspect(d)}, #{inspect(n)}) on #{inspect(Digraph.edges(graph))} roots #{inspect(roots)}"
    end
  end

  defp exits(graph) do
    case Enum.filter(Digraph.nodes(graph), &(Digraph.successors(graph, &1) == [])) do
      [] -> [List.last(Digraph.nodes(graph))]
      sinks -> sinks
    end
  end

  describe "dominators/2" do
    test "5: chain" do
      doms = GraphAlgorithms.dominators(graph([{:r, :a}, {:a, :b}]), [:r])

      assert doms.idom == %{r: @vr, a: :r, b: :a}
      assert doms.unreachable == []
    end

    test "6 and 14: diamond, dominates? both ways, children" do
      doms = GraphAlgorithms.dominators(graph([{:r, :a}, {:r, :b}, {:a, :c}, {:b, :c}]), [:r])

      assert doms.idom == %{r: @vr, a: :r, b: :r, c: :r}
      assert GraphAlgorithms.dominates?(doms, :r, :c)
      refute GraphAlgorithms.dominates?(doms, :a, :c)
      assert doms.children[:r] == [:a, :b, :c]
      assert doms.children[@vr] == [:r]
    end

    test "7: loop" do
      doms = GraphAlgorithms.dominators(graph([{:r, :a}, {:a, :b}, {:b, :a}, {:b, :c}]), [:r])

      assert doms.idom == %{r: @vr, a: :r, b: :a, c: :b}
    end

    test "8: irreducible" do
      doms = GraphAlgorithms.dominators(graph([{:r, :a}, {:r, :b}, {:a, :b}, {:b, :a}]), [:r])

      assert doms.idom == %{r: @vr, a: :r, b: :r}
    end

    test "9: two roots sharing a node; shared? both ways" do
      doms = GraphAlgorithms.dominators(graph([{:r1, :s}, {:r2, :s}]), [:r1, :r2])

      assert doms.idom == %{r1: @vr, r2: @vr, s: @vr}
      assert GraphAlgorithms.shared?(doms, :s)
      refute GraphAlgorithms.shared?(doms, :r1)
      refute GraphAlgorithms.dominates?(doms, :r1, :s)
    end

    test "10: self-loop" do
      doms = GraphAlgorithms.dominators(graph([{:r, :r}, {:r, :a}]), [:r])

      assert doms.idom == %{r: @vr, a: :r}
    end

    test "11: an unreachable node is listed and given no dominator" do
      doms = GraphAlgorithms.dominators(graph([{:r, :a}], [:x]), [:r])

      assert doms.unreachable == [:x]
      refute Map.has_key?(doms.idom, :x)
      refute GraphAlgorithms.dominates?(doms, :r, :x)
    end

    test "12: empty roots, or a root not in the graph, is a caller bug" do
      assert_raise ArgumentError, ~r/roots must not be empty/, fn ->
        GraphAlgorithms.dominators(graph([{:r, :a}]), [])
      end

      assert_raise ArgumentError, ~r/not in the graph/, fn ->
        GraphAlgorithms.dominators(graph([{:r, :a}]), [:zz])
      end
    end

    test "13: agrees with brute force on every small graph" do
      graphs = small_graphs()
      assert length(graphs) == 30

      for {graph, roots} <- graphs do
        assert_brute_force_dominance(graph, roots, GraphAlgorithms.dominators(graph, roots))
      end
    end

    test "15: a 20_000-node chain" do
      edges = for i <- 0..19_998, do: {i, i + 1}
      doms = GraphAlgorithms.dominators(graph(edges), [0])

      assert map_size(doms.idom) == 20_000
      assert Enum.all?(1..19_999, &(doms.idom[&1] == &1 - 1))
    end
  end

  describe "post_dominators/2" do
    test "16: two nodes into one exit" do
      pdoms = GraphAlgorithms.post_dominators(graph([{:a, :w}, {:b, :w}]), [:w])

      assert pdoms.idom == %{w: @vx, a: :w, b: :w}
    end

    test "17: two exits meet at the virtual exit" do
      pdoms = GraphAlgorithms.post_dominators(graph([{:a, :b}, {:b, :w1}, {:b, :w2}]), [:w1, :w2])

      assert pdoms.idom[:b] == @vx
      assert pdoms.idom[:a] == :b
      assert GraphAlgorithms.shared?(pdoms, :b)
    end

    test "18: a node that reaches no exit is unreachable" do
      pdoms = GraphAlgorithms.post_dominators(graph([{:a, :b}], [:c]), [:b])

      assert pdoms.unreachable == [:c]
      assert pdoms.idom == %{b: @vx, a: :b}
    end

    test "18b: empty exits is a caller bug" do
      assert_raise ArgumentError, ~r/exits must not be empty/, fn ->
        GraphAlgorithms.post_dominators(graph([{:a, :b}]), [])
      end
    end

    test "19: agrees with brute force on the reversed small graphs" do
      for {graph, _roots} <- small_graphs() do
        exits = exits(graph)
        pdoms = GraphAlgorithms.post_dominators(graph, exits)
        assert_brute_force_dominance(Digraph.reverse(graph), exits, pdoms)
      end
    end
  end

  describe "components/1" do
    test "20: two components" do
      assert GraphAlgorithms.components(graph([{:a, :b}, {:c, :d}])) == [[:a, :b], [:c, :d]]
    end

    test "21: singletons" do
      assert GraphAlgorithms.components(graph([], [:b, :a])) == [[:a], [:b]]
    end

    test "22: direction is ignored" do
      assert GraphAlgorithms.components(graph([{:a, :b}, {:c, :b}])) == [[:a, :b, :c]]
    end

    test "22b: agrees with undirected reachability on every small graph" do
      for {graph, _roots} <- small_graphs() do
        undirected =
          Digraph.new(
            Digraph.nodes(graph),
            Enum.flat_map(Digraph.edges(graph), fn {a, b} -> [{a, b}, {b, a}] end)
          )

        expected =
          graph
          |> Digraph.nodes()
          |> Enum.map(&(reach(undirected, [&1], nil) |> Enum.sort()))
          |> Enum.uniq()
          |> Enum.sort()

        assert GraphAlgorithms.components(graph) == expected
      end
    end
  end

  describe "sccs/1, condensation/1, cyclic_sccs/1" do
    test "23: the callee SCC comes first" do
      assert GraphAlgorithms.sccs(graph([{:a, :b}, {:b, :a}, {:b, :c}])) == [[:c], [:a, :b]]
    end

    test "24: a self-loop is cyclic; a singleton without one is not" do
      g = graph([{:a, :a}], [:b])

      assert GraphAlgorithms.cyclic_sccs(g) == [[:a]]
      assert [:b] in GraphAlgorithms.sccs(g)
    end

    test "25: a DAG has only singleton, acyclic SCCs" do
      g = graph([{:a, :b}, {:b, :c}])

      assert GraphAlgorithms.sccs(g) == [[:c], [:b], [:a]]
      assert GraphAlgorithms.cyclic_sccs(g) == []
    end

    test "26: every condensation edge points at an earlier SCC; SCCs are mutual reachability" do
      for {graph, _roots} <- small_graphs() do
        sccs = GraphAlgorithms.sccs(graph)
        {dag, index} = GraphAlgorithms.condensation(graph)

        assert Digraph.nodes(dag) == Enum.to_list(0..(length(sccs) - 1))

        for {from, to} <- Digraph.edges(dag),
            do: assert(to < from, "edge #{from} -> #{to} in #{inspect(sccs)}")

        for u <- Digraph.nodes(graph), v <- Digraph.nodes(graph) do
          mutual? =
            MapSet.member?(reach(graph, [u], nil), v) and
              MapSet.member?(reach(graph, [v], nil), u)

          assert index[u] == index[v] == (mutual? or u == v)
        end
      end
    end

    test "27: a 20_000-node cycle is one SCC" do
      edges = [{19_999, 0} | for(i <- 0..19_998, do: {i, i + 1})]
      [scc] = GraphAlgorithms.sccs(graph(edges))

      assert length(scc) == 20_000
    end
  end

  test "28: every function returns the same result for edges given in two orders" do
    edges = [{:r, :a}, {:a, :b}, {:b, :a}, {:b, :c}, {:c, :c}, {:d, :e}]
    one = graph(edges)
    two = graph(Enum.reverse(edges))

    for fun <- [
          &GraphAlgorithms.components/1,
          &GraphAlgorithms.sccs/1,
          &GraphAlgorithms.cyclic_sccs/1
        ] do
      assert fun.(one) == fun.(two)
    end

    assert GraphAlgorithms.condensation(one) == GraphAlgorithms.condensation(two)
    assert GraphAlgorithms.dominators(one, [:r, :d]) == GraphAlgorithms.dominators(two, [:d, :r])

    assert GraphAlgorithms.post_dominators(one, [:c, :e]) ==
             GraphAlgorithms.post_dominators(two, [:e, :c])
  end

  test "AC5: the graph modules use no :digraph, ETS, process or IO" do
    for file <- ["lib/anchor/domain/digraph.ex", "lib/anchor/domain/graph_algorithms.ex"] do
      called =
        file
        |> File.read!()
        |> Code.string_to_quoted!()
        |> Anchor.Domain.DependencyAnalyzer.extract_call_dependencies()

      assert called -- [:digraph, :digraph_utils, :ets, Process, IO, File] == called,
             "#{file}: #{inspect(called)}"

      assert MapSet in called or Map in called
    end
  end
end
