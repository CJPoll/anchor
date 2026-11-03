defmodule Anchor.Domain.DynamicCalls do
  @moduledoc """
  Resolves a dynamic call through behaviours (DND-5442) — a **Domain** module
  (ADR 001). Pure, over the graph.

  A call whose module Core does not name (`mod.fetch(x)` with `mod` a
  variable or computed) can only reach a module implementing a behaviour
  that declares that callback. `candidates/2` answers every project module
  whose `@behaviour`s include a behaviour declaring `name/arity` (an
  implementation without `@impl` counts), or `:unresolved` when no behaviour
  of the project declares it: then its target cannot be checked, which a
  rule reports, never skips. An arity of `nil` (`apply/3` with a non-literal
  argument list) matches a callback of that name at any arity.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode

  @doc "The project modules a dynamic call of `name/arity` may reach, sorted, or `:unresolved`."
  @spec candidates(Graph.t(), {atom(), arity() | nil}) :: {:ok, [module()]} | :unresolved
  def candidates(%Graph{modules: modules}, {name, arity}) do
    case declaring(modules, name, arity) do
      [] ->
        :unresolved

      behaviours ->
        {:ok,
         for(
           {module, %ModuleNode{behaviours: implemented}} <- modules,
           Enum.any?(implemented, &(&1 in behaviours)),
           do: module
         )
         |> Enum.sort()}
    end
  end

  defp declaring(modules, name, arity) do
    for {module, %ModuleNode{callbacks: callbacks}} <- modules,
        Enum.any?(callbacks, &declares?(&1, name, arity)),
        do: module
  end

  defp declares?({name, _arity}, name, nil), do: true
  defp declares?({name, arity}, name, arity), do: true
  defp declares?(_callback, _name, _arity), do: false
end
