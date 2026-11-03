defmodule Anchor.Domain.Digraph do
  @moduledoc """
  A plain directed graph value (DND-5444): a set of nodes (any terms) and
  directed edges, held as successor and predecessor maps. Pure **Domain**:
  unlike Erlang's `:digraph`, it is an immutable value with no ETS table behind
  it, so passing it around shares nothing.

  Nothing here knows about Elixir modules or functions; the graph algorithms
  in `Anchor.Domain.GraphAlgorithms` run over it.

  Two atoms are reserved for those algorithms, `virtual_root/0` and
  `virtual_exit/0`; `new/2` refuses a node equal to either.
  """

  @virtual_exit :"$anchor_virtual_exit"
  @virtual_root :"$anchor_virtual_root"

  @enforce_keys [:nodes, :out, :in]
  defstruct nodes: MapSet.new(), out: %{}, in: %{}

  @type t :: %__MODULE__{
          nodes: MapSet.t(term()),
          out: %{term() => MapSet.t(term())},
          in: %{term() => MapSet.t(term())}
        }

  @doc "Every edge as `{from, to}`, sorted."
  @spec edges(t()) :: [{term(), term()}]
  def edges(%__MODULE__{out: out}) do
    out
    |> Enum.flat_map(fn {from, tos} -> Enum.map(tos, &{from, &1}) end)
    |> Enum.sort()
  end

  @doc """
  The graph with `nodes` and `edges`. An edge to or from a node not in `nodes`
  adds that node. Raises `ArgumentError` when a node is a reserved atom.
  """
  @spec new([term()], [{term(), term()}]) :: t()
  def new(nodes, edges) when is_list(nodes) and is_list(edges) do
    all = MapSet.new(nodes ++ Enum.flat_map(edges, fn {from, to} -> [from, to] end))
    Enum.each([@virtual_root, @virtual_exit], &refuse_reserved(all, &1))
    empty = Map.new(all, &{&1, MapSet.new()})

    %__MODULE__{
      nodes: all,
      out:
        Enum.reduce(edges, empty, fn {from, to}, acc ->
          Map.update!(acc, from, &MapSet.put(&1, to))
        end),
      in:
        Enum.reduce(edges, empty, fn {from, to}, acc ->
          Map.update!(acc, to, &MapSet.put(&1, from))
        end)
    }
  end

  @doc "The nodes, sorted."
  @spec nodes(t()) :: [term()]
  def nodes(%__MODULE__{nodes: nodes}), do: Enum.sort(nodes)

  @doc "The nodes with an edge to `node`, sorted (`[]` for a node not in the graph)."
  @spec predecessors(t(), term()) :: [term()]
  def predecessors(%__MODULE__{in: in_map}, node),
    do: in_map |> Map.get(node, MapSet.new()) |> Enum.sort()

  @doc "The same graph with every edge reversed."
  @spec reverse(t()) :: t()
  def reverse(%__MODULE__{out: out, in: in_map} = graph), do: %{graph | out: in_map, in: out}

  @doc "The graph induced by the nodes of `keep` that it holds: edges with both ends kept."
  @spec subgraph(t(), [term()]) :: t()
  def subgraph(%__MODULE__{} = graph, keep) when is_list(keep) do
    kept = MapSet.intersection(graph.nodes, MapSet.new(keep))

    new(
      MapSet.to_list(kept),
      Enum.filter(edges(graph), fn {from, to} -> from in kept and to in kept end)
    )
  end

  @doc "The nodes `node` has an edge to, sorted (`[]` for a node not in the graph)."
  @spec successors(t(), term()) :: [term()]
  def successors(%__MODULE__{out: out}, node),
    do: out |> Map.get(node, MapSet.new()) |> Enum.sort()

  @doc "The atom `GraphAlgorithms.post_dominators/2` adds as the exit every exit flows to."
  @spec virtual_exit() :: atom()
  def virtual_exit, do: @virtual_exit

  @doc "The atom `GraphAlgorithms.dominators/2` adds as the root above every root."
  @spec virtual_root() :: atom()
  def virtual_root, do: @virtual_root

  defp refuse_reserved(nodes, reserved) do
    if MapSet.member?(nodes, reserved) do
      raise ArgumentError,
            "Digraph: #{inspect(reserved)} is reserved for the graph algorithms and cannot be a node"
    end
  end
end
