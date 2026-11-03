defmodule Anchor.Domain.DataFlow do
  @moduledoc """
  Intra-function data flow over one function clause's SOURCE AST (DND-5439).
  Pure **Domain**: no IO, no process dictionary, no compile, no evaluation; the
  AST is only walked.

  Elixir bindings are single-assignment, so each rebinding is a fresh key
  (`Anchor.Domain.DataFlow.Scope`) and def-use chains inside a clause are exact
  without alias analysis. The consumers propose or make source edits, so this
  reads the source as written (with source lines), not expanded code:
  expression placement (regions and slices), the sabotage generator (which
  mutation orphans a variable) and write-source resolution (the slice that
  produces a write's argument).

  ## The structure

    * `nodes` — node id => `%Anchor.Domain.DataFlow.Node{}`, one per expression
      of every block (the clause body is block `[]`; a branch node's clause
      bodies are blocks `id ++ [:clause, k]`, a `try`'s `after` block
      `id ++ [:after]`).
    * `defs` — var key => the node id that binds it, or `:param` for a key the
      clause head binds. A key bound inside a node's own scope (a clause
      pattern, a `fn` argument) points at that node.
    * `uses` — var key => the sorted node ids that read it. A key no binding
      reaches is `{name, context, :free}`, with no `defs` entry.
    * `params` — the keys the clause head binds, in order.
    * `guard_uses` — the keys the clause's guards read.
    * `result` — the id of the clause's final expression (`nil` for an empty
      body).
    * `blocks` — block id => its node ids, in order.

  ## Unsliceable forms

  `receive`, the process dictionary (`Process.get/put/delete/get_keys`,
  `:erlang.get/put/erase/get_keys`), `var!/1,2` and `binding/0,1` move values
  in ways one clause's def-use cannot follow. A node holding one is flagged
  (`Node.unsliceable`) with its reason, and `sinks/2` always includes it, so it
  is never reported dead. `binding/0,1` also counts as reading every variable
  in scope.

  Not recognised, and so able to make a live expression look dead: a process
  dictionary call through an alias of `Process` (`alias Process, as: P`) or an
  imported `get/1`/`put/2`. A caller whose code may hold those passes an effect
  predicate that matches them.
  """

  alias Anchor.Domain.DataFlow.Builder
  alias Anchor.Domain.DataFlow.Forms
  alias Anchor.Domain.DataFlow.Node
  alias Anchor.Domain.DataFlow.Region
  alias Anchor.Domain.DataFlow.Scope

  @enforce_keys [:nodes, :params, :result]
  defstruct nodes: %{}, defs: %{}, uses: %{}, params: [], guard_uses: [], result: nil, blocks: %{}

  @type t :: %__MODULE__{
          nodes: %{Node.id() => Node.t()},
          defs: %{Scope.var_key() => Node.id() | :param},
          uses: %{Scope.var_key() => [Node.id()]},
          params: [Scope.var_key()],
          guard_uses: [Scope.var_key()],
          result: Node.id() | nil,
          blocks: %{Node.id() => [Node.id()]}
        }

  @doc """
  Analyses one clause, given as `{args, guards, body}` the way
  `Code.string_to_quoted/2` or Credo produce them. Raises `ArgumentError` for
  anything that is not such a triple (a caller bug). An AST it does not
  recognise is read conservatively: one node that uses every variable in it.
  """
  @spec analyze({[Macro.t()], [Macro.t()], Macro.t()}) :: t()
  def analyze({args, guards, body}) when is_list(args) and is_list(guards),
    do: Builder.build(args, guards, body)

  def analyze(other) do
    raise ArgumentError,
          "DataFlow.analyze/1 takes a clause {args, guards, body} with args and guards as lists, got: " <>
            inspect(other)
  end

  @doc """
  The nodes whose values reach a sink through def-use, plus control
  dependence: every enclosing branch of a node in the slice (whose own uses are
  its scrutinee, conditions, guards, pins and steps), and, for a branch whose
  value is needed, the final expression of each of its value blocks. Raises
  `ArgumentError` for a sink id the structure does not hold.
  """
  @spec backward_slice(t(), [Node.id()]) :: MapSet.t(Node.id())
  def backward_slice(%__MODULE__{} = flow, sinks) when is_list(sinks) do
    Enum.each(sinks, &fetch_node!(flow, &1))
    slice(Enum.map(sinks, &{&1, :value}), flow, MapSet.new(), MapSet.new())
  end

  @doc """
  The nodes on no slice of any sink, sorted by line (then id). A branch node
  holding a slice member is never dead.
  """
  @spec dead(t(), (Macro.t() -> boolean())) :: [Node.id()]
  def dead(%__MODULE__{} = flow, effect?) when is_function(effect?, 1) do
    live = backward_slice(flow, sinks(flow, effect?))

    flow.nodes
    |> Map.keys()
    |> Enum.reject(fn id -> MapSet.member?(live, id) or Enum.any?(live, &inside?(&1, id)) end)
    |> Enum.sort_by(&{flow.nodes[&1].line, &1})
  end

  @doc """
  The variable keys `id` binds that some node outside it reads: what removing
  the node would leave unbound. Raises `ArgumentError` for an unknown id.
  """
  @spec orphans_if_removed(t(), Node.id()) :: [Scope.var_key()]
  def orphans_if_removed(%__MODULE__{} = flow, id) do
    fetch_node!(flow, id)

    flow.defs
    |> Enum.filter(fn {_key, definer} -> definer == id end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(fn key -> Enum.any?(Map.get(flow.uses, key, []), &(not within?(&1, id))) end)
    |> Enum.sort()
  end

  @doc """
  Every single-exit region of every block: each contiguous run of a block's
  expressions whose values leave it through at most one exit, where an exit is
  a variable bound in the run and read after it, or the block's own value when
  the run ends the block. See `Anchor.Domain.DataFlow.Region`.
  """
  @spec regions(t()) :: [Region.t()]
  def regions(%__MODULE__{} = flow) do
    flow.blocks
    |> Enum.sort()
    |> Enum.flat_map(fn {block, ids} -> block_regions(flow, block, ids) end)
  end

  @doc """
  The sinks of the clause: its final expression; the final expression of each
  value block of a branch whose value is the clause's (recursively); every
  node `effect?` holds for (given the node's whole AST, nested expressions
  included); every unsliceable node; and every refutable node
  (`Node.refutable`: a refutable `=`, a `case` with no catch-all clause, a
  `with` step written with a refutable `=`), which asserts a shape even when
  nothing reads what it binds.
  `effect?` is required: this module never decides what an effect is.
  """
  @spec sinks(t(), (Macro.t() -> boolean())) :: [Node.id()]
  def sinks(%__MODULE__{} = flow, effect?) when is_function(effect?, 1) do
    effects =
      flow.nodes
      |> Map.values()
      |> Enum.filter(fn node ->
        node.unsliceable != nil or node.refutable or effect?.(node.ast) == true
      end)
      |> Enum.map(& &1.id)

    (result_chain(flow, flow.result) ++ effects) |> Enum.uniq() |> Enum.sort()
  end

  defp block_regions(flow, block, ids) do
    last = length(ids) - 1

    for i <- 0..last//1,
        j <- i..last//1,
        region = region(flow, block, Enum.slice(ids, i..j), j == last),
        region do
      region
    end
  end

  defp definer_mode(flow, key, definer) do
    if key in flow.nodes[definer].binds, do: :value, else: :control
  end

  defp deps(flow, node) do
    definers =
      node.uses
      |> Enum.map(&{&1, Map.get(flow.defs, &1)})
      |> Enum.filter(fn {_key, definer} -> is_list(definer) end)
      |> Enum.map(fn {key, definer} -> {definer, definer_mode(flow, key, definer)} end)

    if node.parent, do: [{node.parent, :control} | definers], else: definers
  end

  defp fetch_node!(flow, id) do
    case Map.fetch(flow.nodes, id) do
      {:ok, node} -> node
      :error -> raise ArgumentError, "DataFlow: no node #{inspect(id)} in this clause"
    end
  end

  defp finals(flow, id) do
    depth = length(id) + 2

    flow.blocks
    |> Enum.filter(fn {block, members} ->
      members != [] and length(block) == depth and Enum.take(block, depth - 1) == id ++ [:clause]
    end)
    |> Enum.map(fn {_block, members} -> List.last(members) end)
  end

  # `id` lies strictly inside the node `outer` (in one of its sub-blocks).
  defp inside?(id, outer),
    do: length(id) > length(outer) and Enum.take(id, length(outer)) == outer

  defp region(flow, block, run, ends_block?) do
    members =
      flow.nodes
      |> Map.keys()
      |> Enum.filter(fn id -> Enum.any?(run, &within?(id, &1)) end)
      |> MapSet.new()

    member? = &MapSet.member?(members, &1)

    escaping =
      flow.defs
      |> Enum.filter(fn {_key, definer} -> member?.(definer) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.filter(fn key -> Enum.any?(Map.get(flow.uses, key, []), &(not member?.(&1))) end)
      |> Enum.sort()

    exits = if ends_block?, do: escaping ++ [:block_value], else: escaping

    if length(exits) <= 1 do
      %Region{
        block: block,
        nodes: run,
        inputs: region_inputs(flow, members),
        output: region_output(exits),
        lines: region_lines(flow, members)
      }
    end
  end

  defp region_inputs(flow, members) do
    members
    |> Enum.flat_map(&flow.nodes[&1].uses)
    |> Enum.reject(&MapSet.member?(members, Map.get(flow.defs, &1)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp region_lines(flow, members) do
    lines =
      members
      |> Enum.flat_map(&[flow.nodes[&1].line, Forms.last_line(flow.nodes[&1].ast)])
      |> Enum.reject(&is_nil/1)

    if lines == [], do: nil, else: Enum.min(lines)..Enum.max(lines)//1
  end

  defp region_output([]), do: :none
  defp region_output([:block_value]), do: :block_value
  defp region_output([key]), do: {:var, key}

  defp result_chain(_flow, nil), do: []
  defp result_chain(flow, id), do: [id | Enum.flat_map(finals(flow, id), &result_chain(flow, &1))]

  defp slice([], _flow, value, control), do: MapSet.union(value, control)

  defp slice([{id, :value} | rest], flow, value, control) do
    cond do
      MapSet.member?(value, id) ->
        slice(rest, flow, value, control)

      MapSet.member?(control, id) ->
        slice(
          Enum.map(finals(flow, id), &{&1, :value}) ++ rest,
          flow,
          MapSet.put(value, id),
          control
        )

      true ->
        next = Enum.map(finals(flow, id), &{&1, :value}) ++ deps(flow, flow.nodes[id])
        slice(next ++ rest, flow, MapSet.put(value, id), control)
    end
  end

  defp slice([{id, :control} | rest], flow, value, control) do
    if MapSet.member?(value, id) or MapSet.member?(control, id),
      do: slice(rest, flow, value, control),
      else: slice(deps(flow, flow.nodes[id]) ++ rest, flow, value, MapSet.put(control, id))
  end

  # `id` is `outer` itself or lies inside it.
  defp within?(id, outer), do: id == outer or inside?(id, outer)
end
