defmodule Anchor.Domain.GraphAlgorithms do
  @moduledoc """
  Graph algorithms over `Anchor.Domain.Digraph` (DND-5444): dominators,
  post-dominators, weakly connected components, strongly connected components
  and the condensation. Pure **Domain**: plain maps and lists, no `:digraph`,
  no ETS, no processes, no IO.

  Every result is deterministic for the same graph, whatever order its nodes
  and edges were given in: traversals visit successors in Erlang term order,
  and every list whose order carries no meaning is sorted.

  ## Dominators

  `dominators/2` is Cooper, Harvey and Kennedy's iterative algorithm ("A Simple,
  Fast Dominance Algorithm", 2001) over a reverse postorder from an iterative
  depth-first search. It adds `Digraph.virtual_root/0` with an edge to every
  root, so several roots work: a node reachable from two roots by paths that
  share no other node has the virtual root as its immediate dominator
  (`shared?/2`). A node no root reaches is listed in `unreachable` and given no
  dominator. `post_dominators/2` is the same computation on the reversed graph
  from `Digraph.virtual_exit/0`, which every exit flows to.

  The result:

    * `idom` — every reachable node to its immediate dominator (the virtual
      node allowed);
    * `unreachable` — the nodes the roots do not reach, sorted;
    * `children` — the dominator tree, each node (the virtual one included) to
      the nodes it immediately dominates, sorted;
    * `roots` — the roots given, sorted; `virtual` — the virtual node.
  """

  alias Anchor.Domain.Digraph

  @type dominators :: %{
          idom: %{term() => term()},
          unreachable: [term()],
          children: %{term() => [term()]},
          roots: [term()],
          virtual: atom()
        }

  @doc "Weakly connected components (direction ignored): each sorted, the list sorted by first element."
  @spec components(Digraph.t()) :: [[term()]]
  def components(%Digraph{} = graph) do
    nodes = Digraph.nodes(graph)
    forest = Map.new(nodes, &{&1, {&1, 0}})

    forest =
      graph
      |> Digraph.edges()
      |> Enum.reduce(forest, fn {from, to}, forest -> union(forest, from, to) end)

    {groups, _forest} =
      Enum.reduce(nodes, {%{}, forest}, fn node, {groups, forest} ->
        {root, forest} = find(forest, node)
        {Map.update(groups, root, [node], &[node | &1]), forest}
      end)

    groups
    |> Map.values()
    |> Enum.map(&Enum.sort/1)
    |> Enum.sort()
  end

  @doc """
  The condensation: a DAG with one node per SCC (its index in `sccs/1`) and an
  edge between two SCCs when an edge joins their members, and each original
  node's SCC index.
  """
  @spec condensation(Digraph.t()) :: {Digraph.t(), %{term() => non_neg_integer()}}
  def condensation(%Digraph{} = graph) do
    components = sccs(graph)

    index =
      components
      |> Enum.with_index()
      |> Enum.flat_map(fn {members, i} -> Enum.map(members, &{&1, i}) end)
      |> Map.new()

    edges =
      graph
      |> Digraph.edges()
      |> Enum.map(fn {from, to} -> {index[from], index[to]} end)
      |> Enum.reject(fn {from, to} -> from == to end)

    {Digraph.new(Enum.to_list(0..(length(components) - 1)//1), edges), index}
  end

  @doc "The SCCs that hold a cycle: more than one node, or one node with an edge to itself."
  @spec cyclic_sccs(Digraph.t()) :: [[term()]]
  def cyclic_sccs(%Digraph{} = graph) do
    Enum.filter(sccs(graph), fn
      [node] -> node in Digraph.successors(graph, node)
      _members -> true
    end)
  end

  @doc "Whether `a` dominates `b` (every node dominates itself)."
  @spec dominates?(dominators(), term(), term()) :: boolean()
  def dominates?(%{idom: idom, virtual: virtual}, a, b) do
    cond do
      a == b -> true
      b == virtual -> false
      true -> climbs_to?(idom, virtual, a, Map.get(idom, b))
    end
  end

  @doc """
  The immediate dominator of every node `roots` reach. Raises `ArgumentError`
  for an empty `roots` (a check with no roots checks nothing) or a root the
  graph does not hold.
  """
  @spec dominators(Digraph.t(), [term()]) :: dominators()
  def dominators(%Digraph{} = graph, roots) when is_list(roots) do
    compute(graph, roots, Digraph.virtual_root(), "roots")
  end

  @doc """
  The immediate post-dominator of every node that reaches an exit: dominators
  of the reversed graph from a virtual exit every exit flows to. Nodes that
  reach no exit are `unreachable`. Raises `ArgumentError` for an empty `exits`
  or an exit the graph does not hold.
  """
  @spec post_dominators(Digraph.t(), [term()]) :: dominators()
  def post_dominators(%Digraph{} = graph, exits) when is_list(exits) do
    compute(Digraph.reverse(graph), exits, Digraph.virtual_exit(), "exits")
  end

  @doc """
  Strongly connected components by Tarjan's algorithm (iterative), in the order
  Tarjan completes them, which is reverse topological: an SCC comes after every
  SCC it has an edge to (callees before callers). Each SCC sorted.
  """
  @spec sccs(Digraph.t()) :: [[term()]]
  def sccs(%Digraph{} = graph) do
    state = %{index: %{}, low: %{}, stack: [], on_stack: MapSet.new(), next: 0, out: []}

    graph
    |> Digraph.nodes()
    |> Enum.reduce(state, fn node, state ->
      if Map.has_key?(state.index, node), do: state, else: tarjan_visit([], graph, state, node)
    end)
    |> Map.fetch!(:out)
    |> Enum.reverse()
  end

  @doc "Whether `node` is reachable only through the virtual node: reached from several roots, not a root itself."
  @spec shared?(dominators(), term()) :: boolean()
  def shared?(%{idom: idom, roots: roots, virtual: virtual}, node),
    do: Map.get(idom, node) == virtual and node not in roots

  defp children(idom) do
    idom
    |> Enum.group_by(fn {_node, parent} -> parent end, fn {node, _parent} -> node end)
    |> Map.new(fn {parent, nodes} -> {parent, Enum.sort(nodes)} end)
  end

  defp climbs_to?(_idom, _virtual, _a, nil), do: false
  defp climbs_to?(_idom, _virtual, a, a), do: true
  defp climbs_to?(_idom, virtual, _a, virtual), do: false

  defp climbs_to?(idom, virtual, a, node),
    do: climbs_to?(idom, virtual, a, Map.fetch!(idom, node))

  defp compute(graph, roots, virtual, what) do
    roots = roots |> Enum.uniq() |> Enum.sort()
    refuse_roots(graph, roots, what)

    successors = fn
      ^virtual -> roots
      node -> Digraph.successors(graph, node)
    end

    postorder = postorder(virtual, successors)
    number = postorder |> Enum.with_index() |> Map.new()
    order = postorder |> Enum.reverse() |> tl()
    root_set = MapSet.new(roots)

    predecessors = fn node ->
      preds = Enum.filter(Digraph.predecessors(graph, node), &Map.has_key?(number, &1))
      if MapSet.member?(root_set, node), do: [virtual | preds], else: preds
    end

    idom = fixpoint(%{virtual => virtual}, order, predecessors, number)
    idom = Map.delete(idom, virtual)

    %{
      idom: idom,
      unreachable: graph |> Digraph.nodes() |> Enum.reject(&Map.has_key?(number, &1)),
      children: children(idom),
      roots: roots,
      virtual: virtual
    }
  end

  defp find(forest, node) do
    {parent, rank} = Map.fetch!(forest, node)

    if parent == node do
      {node, forest}
    else
      {root, forest} = find(forest, parent)
      {root, Map.put(forest, node, {root, rank})}
    end
  end

  defp fixpoint(idom, order, predecessors, number) do
    {idom, changed?} =
      Enum.reduce(order, {idom, false}, fn node, {idom, changed?} ->
        new =
          node
          |> predecessors.()
          |> Enum.filter(&Map.has_key?(idom, &1))
          |> new_idom(idom, number)

        if Map.get(idom, node) == new,
          do: {idom, changed?},
          else: {Map.put(idom, node, new), true}
      end)

    if changed?, do: fixpoint(idom, order, predecessors, number), else: idom
  end

  defp intersect(a, a, _idom, _number), do: a

  defp intersect(a, b, idom, number) do
    if number[a] < number[b],
      do: intersect(Map.fetch!(idom, a), b, idom, number),
      else: intersect(a, Map.fetch!(idom, b), idom, number)
  end

  defp new_idom([first | rest], idom, number),
    do: Enum.reduce(rest, first, &intersect(&1, &2, idom, number))

  # Iterative depth-first postorder from `start`, successors in the order given.
  defp postorder(start, successors) do
    walk_postorder([{start, successors.(start)}], MapSet.new([start]), [], successors)
  end

  defp walk_postorder([], _seen, out, _successors), do: Enum.reverse(out)

  defp walk_postorder([{node, []} | frames], seen, out, successors),
    do: walk_postorder(frames, seen, [node | out], successors)

  defp walk_postorder([{node, [next | rest]} | frames], seen, out, successors) do
    if MapSet.member?(seen, next) do
      walk_postorder([{node, rest} | frames], seen, out, successors)
    else
      frames = [{next, successors.(next)}, {node, rest} | frames]
      walk_postorder(frames, MapSet.put(seen, next), out, successors)
    end
  end

  defp refuse_roots(_graph, [], what),
    do: raise(ArgumentError, "GraphAlgorithms: #{what} must not be empty")

  defp refuse_roots(graph, roots, what) do
    case Enum.reject(roots, &MapSet.member?(graph.nodes, &1)) do
      [] ->
        :ok

      missing ->
        raise ArgumentError, "GraphAlgorithms: #{what} not in the graph: #{inspect(missing)}"
    end
  end

  # Tarjan's strongconnect with an explicit stack of {node, successors left} frames.
  defp tarjan([], _graph, state), do: state

  defp tarjan([{node, []} | frames], graph, state) do
    state = if state.low[node] == state.index[node], do: pop_scc(state, node, []), else: state

    state =
      case frames do
        [{parent, _rest} | _frames] -> lower(state, parent, state.low[node])
        [] -> state
      end

    tarjan(frames, graph, state)
  end

  defp tarjan([{node, [next | rest]} | frames], graph, state) do
    frames = [{node, rest} | frames]

    cond do
      not Map.has_key?(state.index, next) ->
        tarjan_visit(frames, graph, state, next)

      MapSet.member?(state.on_stack, next) ->
        tarjan(frames, graph, lower(state, node, state.index[next]))

      true ->
        tarjan(frames, graph, state)
    end
  end

  defp tarjan_visit(frames, graph, state, node) do
    state = %{
      state
      | index: Map.put(state.index, node, state.next),
        low: Map.put(state.low, node, state.next),
        next: state.next + 1,
        stack: [node | state.stack],
        on_stack: MapSet.put(state.on_stack, node)
    }

    tarjan([{node, Digraph.successors(graph, node)} | frames], graph, state)
  end

  defp lower(state, node, value),
    do: %{state | low: Map.update!(state.low, node, &min(&1, value))}

  defp pop_scc(%{stack: [top | rest]} = state, node, members) do
    state = %{state | stack: rest, on_stack: MapSet.delete(state.on_stack, top)}

    if top == node,
      do: %{state | out: [Enum.sort([top | members]) | state.out]},
      else: pop_scc(state, node, [top | members])
  end

  defp union(forest, a, b) do
    {root_a, forest} = find(forest, a)
    {root_b, forest} = find(forest, b)
    {_parent_a, rank_a} = Map.fetch!(forest, root_a)
    {_parent_b, rank_b} = Map.fetch!(forest, root_b)

    cond do
      root_a == root_b -> forest
      rank_a < rank_b -> Map.put(forest, root_a, {root_b, rank_a})
      rank_a > rank_b -> Map.put(forest, root_b, {root_a, rank_b})
      true -> forest |> Map.put(root_b, {root_a, rank_b}) |> Map.put(root_a, {root_a, rank_a + 1})
    end
  end
end
