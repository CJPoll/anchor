defmodule Anchor.Domain.Graph do
  @moduledoc """
  The causal graph of a compiled program — **Domain** data and queries
  (DND-5438; the shared contract is the Anchor causal engine epic, section 4).

    * `:modules` — `%{module => %ModuleNode{}}`.
    * `:calls` — every `%Call{}` edge.
    * `:struct_uses` — every `%StructUse{}` edge.
    * `:unreadable` — every beam that could not be decoded, as the error map
      `%{path, module, reason}` (see `t:Anchor.Domain.Graph.Beam.decode_error/0`),
      in path order, and every extra beam of a module two ebins hold
      (`reason: {:duplicate_module, kept_path}`), and every module whose
      public function or macro has no Core body
      (`reason: {:no_core, [{name, arity}]}`, DND-5549; the module is still
      built). The runner reports each; none is dropped.

  `Anchor.Domain.Graph.Builder.build/2` makes one.
  """

  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.Inlines
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

  A stdlib function Elixir inlines before Core matches in both spellings
  (`Anchor.Domain.Graph.Inlines`, DND-5551): `{Map, :put, 3}` finds the Core
  call `:maps.put/3`, `{:maps, :put, 3}` finds it too, and module `Map` finds
  every call whose Elixir name is in `Map`.
  """
  @spec calls_to(t(), mfa() | module()) :: [Call.t()]
  def calls_to(%__MODULE__{calls: calls}, {_m, _f, _a} = mfa) do
    spellings = Inlines.spellings(mfa)
    Enum.filter(calls, &(&1.to in spellings))
  end

  def calls_to(%__MODULE__{calls: calls}, module) when is_atom(module),
    do: Enum.filter(calls, &callee_module?(&1.to, module))

  @doc """
  Every function whose Core body the graph lacks (`core: nil`), as
  `%{module => [{name, arity}]}` sorted, modules with none left out (DND-5549).
  No call or struct edge was read from them, so a count of them belongs in
  every run's summary: a missing body must never read as a function with no
  calls. A private macro and a `defp` nothing calls have none by design (the
  compiler emits no code for them); a public one is also in `unreadable` as
  `{:no_core, [{name, arity}]}`.
  """
  @spec functions_without_core(t()) :: %{module() => [{atom(), arity()}]}
  def functions_without_core(%__MODULE__{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        missing = for({name_arity, %FunctionNode{core: nil}} <- functions, do: name_arity),
        missing != [],
        into: %{},
        do: {module, Enum.sort(missing)}
  end

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

  defp callee_module?({_callee, _name, _arity} = to, module),
    do: Enum.any?(Inlines.spellings(to), &(elem(&1, 0) == module))
end
