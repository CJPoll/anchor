defmodule Anchor.Domain.CallMatrix do
  @moduledoc """
  The `architecture:` calls matrix as answers (DND-5442) — a **Domain** module
  (ADR 001). Pure.

  A row lists the buckets a bucket may call, each with a scope: `:any` (a bare
  bucket name), `:same_context` (`"<bucket>:same_context"`: the caller's and
  callee's contexts are equal and not nil) or `:other_context`
  (`"<bucket>:other_context"`: both contexts are known and differ). The matrix
  denies by default: a bucket absent from a row, a missing row, and a scoped
  entry whose context is nil all deny.

  `route/3` is the shortest bucket path through allowed edges (scopes ignored,
  since a route names buckets, not modules), by breadth-first search visiting
  each row in its file order, so equal-length routes resolve the same way
  every run.
  """

  alias Anchor.Domain.Architecture

  @typedoc "What the matrix reads of a classified module: its bucket and context."
  @type side :: %{required(:bucket) => String.t(), required(:context) => String.t() | nil}

  @doc "Whether a module of `from` may call a module of `to` under `architecture`."
  @spec allowed?(Architecture.t(), side(), side()) :: boolean()
  def allowed?(%Architecture{calls: calls}, %{bucket: from} = caller, %{bucket: to} = callee) do
    calls
    |> Map.get(from, [])
    |> Enum.any?(fn {bucket, scope} -> bucket == to and in_scope?(scope, caller, callee) end)
  end

  @doc """
  The shortest bucket path from `from` to `to` through allowed edges,
  `[from, ..., to]`, or `:none` when the matrix gives no route. A bucket to
  itself is searched like any other pair: `[b, b]` when b's row lists b,
  else a longer route or `:none`.
  """
  @spec route(Architecture.t(), String.t(), String.t()) :: [String.t()] | :none
  def route(%Architecture{calls: calls}, from, to) do
    bfs(calls, to, :queue.from_list([[from]]), MapSet.new([from]))
  end

  @doc "The row of `bucket` as written: `framework may call: framework, managers`."
  @spec row(Architecture.t(), String.t()) :: String.t()
  def row(%Architecture{calls: calls}, bucket) do
    case Map.get(calls, bucket, []) do
      [] -> "#{bucket} may call nothing"
      entries -> "#{bucket} may call: " <> Enum.map_join(entries, ", ", &entry/1)
    end
  end

  defp entry({bucket, :any}), do: bucket
  defp entry({bucket, scope}), do: "#{bucket}:#{scope}"

  defp in_scope?(:any, _caller, _callee), do: true

  defp in_scope?(:same_context, %{context: context}, %{context: context}),
    do: not is_nil(context)

  defp in_scope?(:same_context, _caller, _callee), do: false

  defp in_scope?(:other_context, %{context: from}, %{context: to}),
    do: not is_nil(from) and not is_nil(to) and from != to

  defp bfs(calls, to, queue, seen) do
    case :queue.out(queue) do
      {:empty, _queue} ->
        :none

      {{:value, [last | _] = path}, rest} ->
        next = calls |> Map.get(last, []) |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

        if to in next do
          Enum.reverse([to | path])
        else
          fresh = Enum.reject(next, &MapSet.member?(seen, &1))
          queue = Enum.reduce(fresh, rest, &:queue.in([&1 | path], &2))
          bfs(calls, to, queue, MapSet.union(seen, MapSet.new(fresh)))
        end
    end
  end
end
