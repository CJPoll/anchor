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

  The one narrowing is declared evidence (DND-5633, `targets/2`): a receiver
  the caller's `@spec` types as a project behaviour's `t()` reaches that
  behaviour's implementers only (`Anchor.Domain.BehaviourReceiver`).

  A call whose function name is computed as well is not resolved here: any
  exported function of the project could be its target, and the rules report
  it as unresolved.
  """

  alias Anchor.Domain.BehaviourReceiver
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.ViolationKey

  @doc """
  The project modules a dynamic `call` (`{:dynamic, name, arity, receiver}`,
  name known) can reach (DND-5633): the implementers of the behaviour its
  receiver is declared to hold (`Anchor.Domain.BehaviourReceiver`), when
  there is that evidence; else every module exporting the function
  (`candidates/2`), the over-approximation `tally/1` counts.
  """
  @spec targets(Graph.t(), Call.t()) :: [module()]
  def targets(%Graph{} = graph, %Call{to: {:dynamic, name, arity, _receiver}} = call) do
    case BehaviourReceiver.behaviour(graph, call) do
      {:ok, behaviour} -> BehaviourReceiver.implementers(graph, behaviour, {name, arity})
      :none -> candidates(graph, {name, arity})
    end
  end

  @doc """
  The dynamic calls with a known function name, split by how they resolve
  (DND-5633): `narrowed` to a declared behaviour's implementers, or
  `fanned_out` to every module exporting the function. Each is a sorted list
  of `{caller_mfa, name, arity}`, one per distinct call; the summary counts
  them, so an over-approximation is never silent.
  """
  @spec tally(Graph.t()) :: %{narrowed: [tuple()], fanned_out: [tuple()]}
  def tally(%Graph{calls: calls} = graph) do
    calls
    |> Enum.filter(&match?(%Call{to: {:dynamic, name, _arity, _receiver}} when name != nil, &1))
    |> Enum.uniq_by(fn %Call{from: from, to: to} -> {from, to} end)
    |> Enum.split_with(&(BehaviourReceiver.behaviour(graph, &1) != :none))
    |> then(fn {narrowed, fanned_out} ->
      %{narrowed: summary(narrowed), fanned_out: summary(fanned_out)}
    end)
  end

  defp summary(calls) do
    calls
    |> Enum.map(fn %Call{from: from, to: {:dynamic, name, arity, _receiver}} ->
      {from, name, arity}
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

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
