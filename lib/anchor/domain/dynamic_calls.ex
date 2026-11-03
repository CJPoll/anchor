defmodule Anchor.Domain.DynamicCalls do
  @moduledoc """
  The project modules a dynamic call can reach (DND-5442) — a **Domain**
  module (ADR 001). Pure, over the graph.

  A call whose module Core does not name (`mod.fetch(x)` with `mod` a
  variable or computed) reaches whatever module `mod` holds at run time, and
  Elixir does not limit that to a behaviour's implementations: any module
  exporting `fetch/1` can be the receiver. So `candidates/2` answers every
  project module with a `def` of that name and arity (any arity when it is
  `nil`, an `apply/3` whose argument list is not literal), sorted. None means
  no project module can be the receiver, so the call reaches no bucket or
  context of the project (it goes to a dependency, such as
  `Mix.shell().info/1`), and there is nothing for a rule to judge. A
  private function or a macro cannot be called this way.

  A call whose function name is computed as well is not resolved here: any
  exported function of the project could be its target, and the rules report
  it as unresolved.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.ViolationKey

  @doc "The project modules exporting `name/arity` (any arity for `nil`), sorted."
  @spec candidates(Graph.t(), {atom(), arity() | nil}) :: [module()]
  def candidates(%Graph{modules: modules}, {name, arity}) do
    modules
    |> Enum.filter(fn {_module, %ModuleNode{functions: functions}} ->
      Enum.any?(functions, &exports?(&1, name, arity))
    end)
    |> Enum.map(fn {module, _node} -> module end)
    |> Enum.sort()
  end

  @doc """
  The message of a call from `from` (an mfa) whose function name is computed,
  with `arity` (`nil` when not literal): its target cannot be checked.
  """
  @spec computed_name_message(mfa(), arity() | nil) :: String.t()
  def computed_name_message(from, arity) do
    "#{ViolationKey.mfa(from)} calls a function it computes (?/#{arity || "?"}), so its " <>
      "target cannot be checked. Fix: call the module's function by name (a call on a " <>
      "computed module, mod.fetch(x), is judged against every module exporting it); apply " <>
      "a closure as fun.(args)."
  end

  @doc "A key's target text for a computed function name: `dynamic ?/<arity>`."
  @spec computed_name_target(arity() | nil) :: String.t()
  def computed_name_target(arity), do: "dynamic ?/#{arity || "?"}"

  defp exports?({{name, arity}, %FunctionNode{kind: :def}}, name, arity), do: true
  defp exports?({{name, _arity}, %FunctionNode{kind: :def}}, name, nil), do: true
  defp exports?(_function, _name, _arity), do: false
end
