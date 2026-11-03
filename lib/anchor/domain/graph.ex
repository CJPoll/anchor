defmodule Anchor.Domain.Graph do
  @moduledoc """
  The causal graph of a compiled program — **Domain** data and queries
  (DND-5438; the shared contract is the Anchor causal engine epic, section 4).

    * `:modules` — `%{module => %ModuleNode{}}`.
    * `:calls` — every `%Call{}` edge.
    * `:struct_uses` — every `%StructUse{}` edge.
    * `:unreadable` — every beam that could not be decoded, as the error map
      `%{path, module, reason}` (see `t:Anchor.Domain.Graph.Beam.decode_error/0`),
      in path order. The runner reports each; none is dropped.

  `Anchor.Domain.Graph.Builder.build/2` makes one.
  """

  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.StructUse

  defstruct modules: %{}, calls: [], struct_uses: [], unreadable: []

  @type t :: %__MODULE__{
          modules: %{module() => ModuleNode.t()},
          calls: [Call.t()],
          struct_uses: [StructUse.t()],
          unreadable: [%{path: String.t(), module: module() | nil, reason: term()}]
        }

  @doc "The calls made by the function `{m, f, a}`, or by any function of module `m`."
  @spec calls_from(t(), mfa() | module()) :: [Call.t()]
  def calls_from(%__MODULE__{calls: calls}, {_m, _f, _a} = mfa),
    do: Enum.filter(calls, &(&1.from == mfa))

  def calls_from(%__MODULE__{calls: calls}, module) when is_atom(module),
    do: Enum.filter(calls, &(elem(&1.from, 0) == module))

  @doc """
  The calls that name `{m, f, a}` as their callee, or any function of module
  `m`. A dynamic call names no callee, so it is never among them.
  """
  @spec calls_to(t(), mfa() | module()) :: [Call.t()]
  def calls_to(%__MODULE__{calls: calls}, {_m, _f, _a} = mfa),
    do: Enum.filter(calls, &(&1.to == mfa))

  def calls_to(%__MODULE__{calls: calls}, module) when is_atom(module),
    do: Enum.filter(calls, &callee_module?(&1.to, module))

  @doc "The function node for `{m, f, a}`, or `nil`."
  @spec function(t(), mfa()) :: FunctionNode.t() | nil
  def function(%__MODULE__{} = graph, {module, name, arity}) do
    case module(graph, module) do
      nil -> nil
      %ModuleNode{functions: functions} -> Map.get(functions, {name, arity})
    end
  end

  @doc "The module node for `module`, or `nil`."
  @spec module(t(), module()) :: ModuleNode.t() | nil
  def module(%__MODULE__{modules: modules}, module), do: Map.get(modules, module)

  defp callee_module?({:dynamic, _name, _arity, _receiver}, _module), do: false
  defp callee_module?({callee, _name, _arity}, module), do: callee == module
end
