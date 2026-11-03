defmodule Anchor.Domain.Aggregates.Persistence do
  @moduledoc """
  Which modules of a graph persist (DND-5659) — a **Domain** module (ADR
  001). Pure: it reads the graph only, and never loads or calls a project
  module. Under `aggregates: declare: none`
  (`Anchor.Domain.Aggregates.Config`), `Anchor.Domain.Aggregates.Index`
  reports each one as `:persists_under_none`.

  A module persists when, in this order (the first that holds is its
  reason, so one module is one finding):

    1. it exports `__schema__/1` (an Ecto schema, `use Ecto.Schema`);
    2. it declares `@behaviour Ecto.Repo` (a repo, `use Ecto.Repo`);
    3. it declares `@anchor_aggregate` (an aggregate, which `none` denies);
    4. one of its functions calls a database write
       (`Anchor.Domain.EffectPrimitives.repo_write?/1`: a write on a module
       whose last name segment ends in `Repo`), or any function of
       `Ecto.Repo`, `Ecto.Multi` or an `Ecto.Adapters.*` module; the reason
       names the call with the lowest line.

  Not seen: a read through a repo the project does not define (a
  dependency's `Repo.get/2`), and a call on a computed module. Both leave a
  repo or a schema in the project, or a write, which the rows above see.
  """

  alias Anchor.Domain.EffectPrimitives
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.ViolationKey

  @ecto_modules [Ecto.Repo, Ecto.Multi]

  @doc """
  Every module of `graph` that persists, with its reason, sorted by module:
  `[{module_node, reason}]`.
  """
  @spec modules(Graph.t()) :: [{ModuleNode.t(), String.t()}]
  def modules(%Graph{modules: modules} = graph) do
    calls = first_calls(graph)

    for {module, node} <- Enum.sort_by(modules, &elem(&1, 0)),
        reason = reason(node, Map.get(calls, module)),
        reason != nil,
        do: {node, reason}
  end

  @doc "Whether a call of `mfa` is a persistence call (rule 4 of the moduledoc)."
  @spec call?(mfa()) :: boolean()
  def call?({module, _name, _arity} = mfa),
    do: EffectPrimitives.repo_write?(mfa) or module in @ecto_modules or adapter?(module)

  defp reason(%ModuleNode{} = node, call) do
    cond do
      Map.has_key?(node.functions, {:__schema__, 1}) -> "it exports __schema__/1 (an Ecto schema)"
      Ecto.Repo in node.behaviours -> "it declares @behaviour Ecto.Repo"
      Keyword.has_key?(node.attributes, :anchor_aggregate) -> "it declares @anchor_aggregate"
      call != nil -> "it calls #{ViolationKey.mfa(call.to)} (line #{call.line || "?"})"
      true -> nil
    end
  end

  # The persistence call of each module with the lowest line (a call with no
  # line sorts last), then by callee, so the reason does not depend on order.
  defp first_calls(%Graph{calls: calls}) do
    calls
    |> Enum.filter(&persistence_call?/1)
    |> Enum.group_by(&elem(&1.from, 0))
    |> Map.new(fn {module, group} ->
      {module, Enum.min_by(group, &{&1.line || :infinity, inspect(&1.to)})}
    end)
  end

  defp persistence_call?(%Call{to: {:dynamic, _name, _arity, _receiver}}), do: false
  defp persistence_call?(%Call{to: to}), do: call?(to)

  defp adapter?(module),
    do: module |> Atom.to_string() |> String.starts_with?("Elixir.Ecto.Adapters.")
end
