defmodule Anchor.Domain.Sabotage.ProcessOwnership do
  @moduledoc """
  Which test or module owns a process (DND-5691). Pure **Domain**.

  A process is owned when it was spawned, through any chain, by a process the
  module runner spawned inside that test's window (or inside its module, outside
  every window). It is read from spawn events, never from `$ancestors` or a
  process's dictionary, so a process whose parent has died is still owned, and
  it is resolved only once the run is over, so it does not depend on the order
  trace messages arrive in.

  A Task under a supervisor is spawned by the supervisor, so its spawn event's
  arguments name the process that asked for it. `edge/3` reads that pid (`via`),
  and an owned `via` wins over the parent: a test's task under a setup_all
  supervisor belongs to the test.
  """

  @type owner :: {:test, non_neg_integer()} | {:module, module()}
  @type edge :: {child :: pid(), parent :: pid(), via :: pid() | nil}

  @doc """
  A spawn event as an edge, or `{:error, {:task_shape, mfa}}` for a
  `Task.Supervised` spawn in a shape this does not know: the shape is private to
  Elixir, and guessing would lose a task's owner.
  """
  @spec edge(pid(), pid(), {module(), atom(), [term()]}) ::
          edge() | {:error, {:task_shape, mfa :: tuple()}}
  def edge(
        child,
        parent,
        {Task.Supervised, :noreply, [{_node, _name, owner}, _ancestors, _callers, _mfa]}
      )
      when is_pid(owner),
      do: {child, parent, owner}

  def edge(
        child,
        parent,
        {Task.Supervised, :reply, [{_node, _name, owner}, _ancestors, _monitor]}
      )
      when is_pid(owner),
      do: {child, parent, owner}

  def edge(_child, _parent, {Task.Supervised, _name, _args} = mfa),
    do: {:error, {:task_shape, mfa}}

  def edge(child, parent, _mfa), do: {child, parent, nil}

  @doc """
  Each owned process's owner. `roots` are the processes a module runner spawned,
  each with the window or module it was spawned in; `edges` are every other
  spawn. A process with no owner is absent.
  """
  @spec owners(%{pid() => owner()}, [edge()]) :: %{pid() => owner()}
  def owners(roots, edges) do
    spawned = Map.new(edges, fn {child, parent, via} -> {child, {parent, via}} end)

    edges
    |> Enum.reduce(roots, fn {child, _parent, _via}, known -> resolve(child, spawned, known) end)
    |> Map.reject(fn {_pid, owner} -> is_nil(owner) end)
  end

  # A memoised walk up the spawn forest. A process is marked unowned before its
  # ancestors are read, so a cycle (a reused pid) ends here instead of looping.
  defp resolve(pid, spawned, known) when is_map_key(known, pid) or not is_map_key(spawned, pid),
    do: Map.put_new(known, pid, nil)

  defp resolve(pid, spawned, known) do
    {parent, via} = Map.fetch!(spawned, pid)
    known = resolve(parent, spawned, Map.put(known, pid, nil))
    known = if via, do: resolve(via, spawned, known), else: known
    Map.put(known, pid, known[via] || known[parent])
  end
end
